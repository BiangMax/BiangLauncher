import AppKit
import SwiftUI
import Combine
import QuartzCore
import LauncherCore

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = LauncherModel()
    private let hotKey = GlobalHotKey()
    private var panel: LauncherPanel!
    private var statusItem: NSStatusItem!
    private var keyMonitor: Any?
    private var observation: AnyCancellable?
    private var wantsVisible = false
    private var visibilityGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: 840, height: 620), styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "BiangLauncher"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // Background window dragging steals SwiftUI's icon drag gestures.
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        model.dismiss = { [weak self] in self?.hide() }
        model.present = { [weak self] in self?.show() }
        model.shortcutChanged = { [weak self] shortcut in
            guard let self else { return false }
            if hotKey.register(shortcut) { return true }
            _ = hotKey.register(model.preferences.shortcut)
            model.errorMessage = "这个快捷键已被其他应用占用，或系统无法注册。请换一组组合键。"
            return false
        }
        hotKey.onPress = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.model.recordingShortcut else { return }
                self.toggle()
            }
        }
        if !hotKey.register(model.preferences.shortcut) {
            model.errorMessage = "快捷键注册失败，可能已被占用。你仍可以点击 Dock 图标打开，并在右下角设置其他快捷键。"
        }
        buildStatusItem()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, wantsVisible else { return event }
            if model.recordingShortcut {
                if event.keyCode == 53 { model.recordingShortcut = false }
                else if event.keyCode == 51 && event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty { model.setShortcut(nil) }
                else if let shortcut = GlobalHotKey.shortcut(from: event) { model.setShortcut(shortcut) }
                return nil
            }
            if event.keyCode == 53 && !model.isChoosingFile && model.errorMessage == nil {
                if model.dragSource != nil { model.clearDrag() }
                else if model.openFolder != nil { model.closeFolder() }
                else { hide() }
                return nil
            }
            return event
        }
        model.refresh()
        observation = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.resizePanel() }
        }
        show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.setManaging(false)
        show()
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard !model.isChoosingFile, model.errorMessage == nil else { return }
        hide()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    private func show() {
        guard panel != nil else { return }
        if wantsVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            model.focusRequest = UUID()
            return
        }
        wantsVisible = true
        visibilityGeneration += 1
        let generation = visibilityGeneration
        if !panel.isVisible {
            model.query = ""
            model.recordingShortcut = false
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            if let screen {
                let area = screen.visibleFrame
                let width = min(840, area.width - 40)
                let height = min(desiredHeight, area.height - 40)
                panel.setFrame(NSRect(x: area.midX - width / 2, y: area.midY - height / 2 + min(35, (area.height - height) / 4), width: width, height: height), display: false)
            }
            panel.alphaValue = 0
            model.launcherVisible = false
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        model.focusRequest = UUID()
        // Let SwiftUI lay out the initial scale before starting the entrance.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsVisible, self.visibilityGeneration == generation else { return }
            self.model.launcherVisible = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.10 : 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.panel.animator().alphaValue = 1
            }
        }
    }

    private func hide() {
        guard panel != nil, wantsVisible else { return }
        wantsVisible = false
        visibilityGeneration += 1
        let generation = visibilityGeneration
        model.clearDrag()
        model.launcherVisible = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.10 : 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // A quick reopen must not be hidden by an older completion.
                guard let self, !self.wantsVisible, self.visibilityGeneration == generation else { return }
                self.panel.orderOut(nil)
                self.model.setManaging(false)
            }
        }
    }

    private var desiredHeight: CGFloat {
        if model.managing { return 620 }
        let count = model.launcherItems.count
        let base: CGFloat = count == 0 ? 540 : min(620, 310 + CGFloat((count + 6) / 7) * 140)
        return min(700, base + (model.editingOrder ? 24 : 0) + (model.recordingShortcut ? 76 : 0))
    }

    private func resizePanel() {
        guard let panel, wantsVisible, panel.isVisible, let screen = panel.screen else { return }
        let area = screen.visibleFrame
        let height = min(desiredHeight, area.height - 40)
        guard abs(panel.frame.height - height) > 1 else { return }
        var frame = panel.frame
        frame.origin.y = max(area.minY + 20, min(area.maxY - height - 20, frame.midY - height / 2))
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    @objc private func toggle() {
        if wantsVisible { hide() } else { show() }
    }
    @objc private func openLauncher() { model.setManaging(false); show() }
    @objc private func chooseApps() { model.setManaging(true); show() }
    @objc private func recordShortcut() { show(); model.recordingShortcut = true }

    private func buildMenu() {
        let menu = NSMenu()
        let appRoot = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "打开启动台", action: #selector(openLauncher), keyEquivalent: "0").target = self
        appMenu.addItem(withTitle: "选择应用…", action: #selector(chooseApps), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "自定义快捷键…", action: #selector(recordShortcut), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 BiangLauncher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appRoot.submenu = appMenu
        menu.addItem(appRoot)
        let editRoot = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editRoot.submenu = editMenu
        menu.addItem(editRoot)
        NSApp.mainMenu = menu
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "BiangLauncher")
            button.image?.isTemplate = true
            button.toolTip = "BiangLauncher · 点击打开，右键显示菜单"
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "打开启动台", action: #selector(openLauncher), keyEquivalent: "").target = self
            menu.addItem(withTitle: "选择应用…", action: #selector(chooseApps), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出 BiangLauncher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { toggle() }
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
