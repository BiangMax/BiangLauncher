import AppKit
import LauncherCore
import SwiftUI
import UniformTypeIdentifiers

private let accent = Color(red: 0.42, green: 0.81, blue: 0.98)
private let muted = Color.white.opacity(0.48)
// Use the property wrapper explicitly; the macOS 27 SDK also exports a State macro
// whose plugin is not bundled with Command Line Tools.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct LauncherView: View {
    @ObservedObject var model: LauncherModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            VStack(alignment: .leading, spacing: 20) {
                titleRow
                searchField
                if model.recordingShortcut { shortcutRecorder }
                content
            }
            .padding(.horizontal, 30)
            .padding(.top, 24)
            .padding(.bottom, 18)
            footer
        }
        .background {
            ZStack {
                VisualEffect()
                Color(red: 0.045, green: 0.06, blue: 0.08).opacity(0.86)
                LinearGradient(colors: [accent.opacity(0.065), .clear, .black.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.23), .white.opacity(0.06), accent.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .scaleEffect(model.launcherVisible || reduceMotion ? 1 : 0.96)
        .animation(.easeOut(duration: model.launcherVisible ? 0.22 : 0.16), value: model.launcherVisible)
        .allowsHitTesting(model.launcherVisible)
        .preferredColorScheme(.dark)
        .tint(accent)
        .onChange(of: model.query) { model.clearDrag() }
        .onChange(of: model.editingOrder) { model.clearDrag() }
        .onChange(of: model.focusRequest) { searchFocused = true }
        .onChange(of: model.recordingShortcut) { if model.recordingShortcut { searchFocused = false } }
        .alert("需要留意", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("知道了") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var brandHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            Text("BiangLauncher").font(.system(size: 14, weight: .semibold, design: .rounded))
            Text("/  StudioBiangMax").font(.system(size: 11, weight: .medium)).foregroundStyle(muted)
            Spacer()
            Menu {
                Button("选择应用…") { model.setManaging(true) }
                Button("刷新应用列表") { model.refresh() }
                Divider()
                Button("自定义快捷键…") { model.recordingShortcut = true }
                if model.preferences.shortcut != nil {
                    Button("停用快捷键") { model.setShortcut(nil) }
                }
                Divider()
                Text("BiangLauncher 0.1.0")
                Text("开发者 BiangMax · StudioBiangMax")
                Divider()
                Button("退出 BiangLauncher") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .medium)).frame(width: 30, height: 30)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("设置与快捷键").accessibilityLabel("设置与快捷键")
            Button { model.dismiss?() } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28)
            }
            .buttonStyle(QuietButtonStyle()).help("收起启动台 · Esc").accessibilityLabel("收起启动台")
        }
        .padding(.horizontal, 25).frame(height: 68)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.07)).frame(height: 1) }
    }

    private var titleRow: some View {
        HStack(alignment: .center) {
            if model.openFolder != nil && !model.managing {
                Button { model.closeFolder() } label: { Image(systemName: "chevron.left").font(.system(size: 18)) }
                    .buttonStyle(QuietButtonStyle()).accessibilityLabel("返回启动台")
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(model.managing ? "选择应用" : (model.openFolder?.name ?? "启动台")).lineLimit(1)
                        .font(.system(size: 27, weight: .semibold))
                    Text(String(model.managing ? model.apps.count : (model.openFolder?.paths.count ?? model.selectedApps.count)))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(accent.opacity(0.09), in: Capsule())
                }
                Text(model.managing ? "勾选你需要的应用，其余留在这里。" : (model.openFolder != nil ? "点击启动，右键可将应用移出文件夹。" : "你的应用，刚刚好。"))
                    .font(.system(size: 12)).foregroundStyle(muted)
            }
            Spacer()
            if model.managing {
                Button { model.setManaging(false) } label: { Label("完成", systemImage: "checkmark").padding(.horizontal, 5) }
                    .buttonStyle(AccentButtonStyle())
            } else {
                if model.selectedApps.count > 1 {
                    Button {
                        model.editingOrder.toggle()
                    } label: { Label(model.editingOrder ? "完成排序" : "排序", systemImage: "arrow.left.arrow.right") }
                        .buttonStyle(QuietButtonStyle(active: model.editingOrder))
                }
                Button { model.setManaging(true) } label: { Label("选择应用", systemImage: "plus") }
                    .buttonStyle(AccentButtonStyle())
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(muted)
            TextField(model.managing ? "搜索已安装的应用" : "搜索已选应用", text: $model.query)
                .textFieldStyle(.plain).font(.system(size: 14))
                .focused($searchFocused)
                .onSubmit {
                    if !model.managing && !model.editingOrder, let first = model.visibleApps.first { model.launch(first) }
                }
                .accessibilityLabel(model.managing ? "搜索已安装的应用" : "搜索已选应用")
            if !model.query.isEmpty {
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(muted) }
                    .buttonStyle(.plain).accessibilityLabel("清除搜索")
            } else {
                Text(model.managing ? "应用库" : "仅已选").font(.system(size: 10, weight: .medium)).foregroundStyle(muted)
            }
        }
        .padding(.horizontal, 15).frame(height: 46)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(searchFocused ? accent.opacity(0.32) : .white.opacity(0.08), lineWidth: 1))
    }

    private var shortcutRecorder: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard").foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("按下新的快捷键").font(.system(size: 12, weight: .semibold))
                Text("包含 ⌘、⌥ 或 ⌃ · Esc 取消 · Delete 停用")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            Spacer()
            Button("取消") { model.recordingShortcut = false }.buttonStyle(QuietButtonStyle())
        }
        .padding(12).background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var content: some View {
        if model.loading && model.apps.isEmpty {
            VStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("正在发现你的应用…").font(.system(size: 12)).foregroundStyle(muted)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.visibleApps.isEmpty {
            emptyState
        } else if model.managing {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(model.visibleApps) { app in
                        LibraryRow(app: app, selected: model.isSelected(app)) { model.toggle(app) }
                    }
                }.padding(.vertical, 2)
            }.scrollIndicators(.automatic)
        } else {
            GeometryReader { viewport in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), alignment: .leading, spacing: 10) {
                        ForEach(model.launcherItems) { item in
                            switch item {
                            case .app(let app): AppTile(app: app, model: model)
                            case .folder(let folder): FolderTile(folder: folder, model: model)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.automatic)
                // Keep the preview and gesture outside the scrolling/lazy content.
                // The source tile may leave the viewport during a long drag.
                .overlay(alignment: .topLeading) {
                    if let source = model.dragSource, let item = model.launcherItems.first(where: { $0.id == source }) {
                        LauncherItemIcon(item: item, model: model)
                            .frame(width: 76, height: 76)
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                            .position(model.dragLocation)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "appViewport")
                .onPreferenceChange(TileFramesKey.self) {
                    model.updateTileFrames($0, viewportSize: viewport.size)
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("appViewport"))
                        .onChanged { value in
                            guard let source = model.dragSource ?? model.dragHit(at: value.startLocation) else { return }
                            model.updateDrag(source: source, location: value.location)
                        }
                        .onEnded { value in
                            guard let source = model.dragSource else { return }
                            withAnimation(.easeInOut(duration: 0.16)) {
                                model.finishDrag(source: source, location: value.location)
                            }
                        }
                )
                .onDisappear { model.clearDrag() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: model.query.isEmpty ? "square.grid.2x2" : "magnifyingglass")
                .font(.system(size: 32, weight: .light)).foregroundStyle(accent.opacity(0.8))
                .frame(width: 76, height: 76)
                .background(accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(accent.opacity(0.1)))
            Text(model.query.isEmpty ? "为常用应用，留一个位置" : "没有找到匹配的应用")
                .font(.system(size: 17, weight: .medium))
            Text(model.query.isEmpty ? "从明日方舟到 BambuStudio，只留下你想看到的。" : (model.managing ? "试试其他名称，或手动添加应用。" : "这里只搜索已勾选的应用。"))
                .font(.system(size: 12)).foregroundStyle(muted)
            if !model.managing && model.query.isEmpty {
                Button { model.setManaging(true) } label: { Label("挑选我的应用", systemImage: "plus").padding(.horizontal, 6) }
                    .buttonStyle(AccentButtonStyle()).padding(.top, 5)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.managing {
                Toggle("只看已选 · \(model.preferences.selectedPaths.count)", isOn: $model.selectedOnly)
                    .toggleStyle(.checkbox).font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                Button { model.refresh() } label: {
                    Label(model.loading ? "刷新中" : "刷新", systemImage: "arrow.clockwise")
                }.disabled(model.loading).buttonStyle(QuietButtonStyle())
                Button { model.addApplication() } label: { Label("添加应用…", systemImage: "folder.badge.plus") }
                    .buttonStyle(QuietButtonStyle())
            } else {
                Image(systemName: model.editingOrder ? "hand.draw" : "circle.fill")
                    .font(.system(size: model.editingOrder ? 12 : 5)).foregroundStyle(accent.opacity(0.8))
                Text(model.folderReady ? "松开以创建或加入文件夹" : (model.dragSource != nil && model.openFolder == nil && model.query.isEmpty ? "悬停图标 1 秒可归入文件夹" : (model.openFolder != nil ? "拖动排序 · 右键移出文件夹" : (model.editingOrder ? "拖动排序 · 悬停 1 秒归入文件夹" : "拖动排序 · 悬停 1 秒建文件夹"))))
                    .font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                Button { model.recordingShortcut.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "keyboard")
                        Text(model.preferences.shortcut?.label ?? "设置快捷键")
                    }.font(.system(size: 11, design: .monospaced))
                }.buttonStyle(QuietButtonStyle()).help("录制自定义全局快捷键")
                Text("ESC 收起").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted.opacity(0.8))
            }
        }
        .padding(.horizontal, 28).frame(height: 54)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.065)).frame(height: 1) }
    }
}

private struct AppTile: View {
    let app: InstalledApp
    @ObservedObject var model: LauncherModel
    @ViewState private var hovered = false
    private var targeted: Bool { model.dragTarget == app.path && model.dragSource != app.path }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if !model.editingOrder { model.launch(app) }
            } label: {
                VStack(spacing: 6) {
                    Image(nsImage: AppIcons.shared.image(for: app))
                        .resizable().interpolation(.high).frame(width: 76, height: 76)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 5)
                        .opacity(model.dragSource == app.path ? 0.25 : app.isAvailable ? 1 : 0.4)
                    Text(targeted && model.folderReady ? "松开以创建文件夹" : app.name).font(.system(size: 12, weight: .medium)).lineLimit(2)
                        .multilineTextAlignment(.center).frame(height: 32, alignment: .top)
                }.frame(maxWidth: .infinity).padding(.top, 8).padding(.horizontal, 4).padding(.bottom, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开 \(app.name)")
            if model.editingOrder {
                HStack(spacing: 14) {
                    Button { model.move(app, by: -1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("将 \(app.name) 前移").disabled(!model.canMove(app.path, by: -1))
                    Button { model.move(app, by: 1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("将 \(app.name) 后移").disabled(!model.canMove(app.path, by: 1))
                }.font(.system(size: 10, weight: .semibold)).buttonStyle(.plain).foregroundStyle(accent).padding(.bottom, 10)
            }
        }
        .background((targeted ? accent.opacity(0.15) : hovered ? .white.opacity(0.055) : .clear), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(targeted ? accent.opacity(0.65) : .white.opacity(hovered ? 0.08 : 0), lineWidth: 1))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: TileFramesKey.self, value: [app.path: geometry.frame(in: .named("appViewport"))])
            }
        }
        .onHover { hovered = $0 }
        .contextMenu {
            Button("打开") { model.launch(app) }.disabled(!app.isAvailable)
            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
            Divider()
            Button("向前移动") { model.move(app, by: -1) }.disabled(!model.canMove(app.path, by: -1))
            Button("向后移动") { model.move(app, by: 1) }.disabled(!model.canMove(app.path, by: 1))
            Divider()
            if model.preferences.folders.contains(where: { $0.paths.contains(app.path) }) {
                Button("移出文件夹") { model.removeFromFolder(app) }
            }
            Button("从启动台隐藏") { model.toggle(app) }
        }
        .help(app.isAvailable ? app.name : "应用已移动或卸载，请重新选择")
    }
}

private struct LauncherItemIcon: View {
    let item: LauncherItem
    @ObservedObject var model: LauncherModel
    var body: some View {
        switch item {
        case .app(let app):
            Image(nsImage: AppIcons.shared.image(for: app)).resizable().interpolation(.high)
        case .folder(let folder):
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 18).strokeBorder(accent.opacity(0.25))
                LazyVGrid(columns: [GridItem(.fixed(27), spacing: 3), GridItem(.fixed(27), spacing: 3)], spacing: 3) {
                    ForEach(Array(model.folderApps(folder).prefix(4))) { app in
                        Image(nsImage: AppIcons.shared.image(for: app)).resizable().frame(width: 27, height: 27)
                    }
                }
            }
        }
    }
}

private struct FolderTile: View {
    let folder: LauncherFolder
    @ObservedObject var model: LauncherModel
    @ViewState private var hovered = false
    private var targeted: Bool { model.dragTarget == folder.id && model.dragSource != folder.id }

    var body: some View {
        VStack(spacing: 0) {
            Button { if !model.editingOrder { model.openFolder(folder) } } label: {
                VStack(spacing: 6) {
                    LauncherItemIcon(item: .folder(folder), model: model)
                        .frame(width: 76, height: 76)
                        .opacity(model.dragSource == folder.id ? 0.25 : 1)
                        .scaleEffect(targeted && model.folderReady ? 1.08 : 1)
                    Text(targeted && model.folderReady ? "松开以加入文件夹" : folder.name)
                        .font(.system(size: 12, weight: .medium)).lineLimit(2)
                        .multilineTextAlignment(.center).frame(height: 32, alignment: .top)
                }
                .frame(maxWidth: .infinity).padding(.top, 8).padding(.horizontal, 4).padding(.bottom, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("打开文件夹 \(folder.name)，\(folder.paths.count) 个应用")
            if model.editingOrder {
                HStack(spacing: 14) {
                    Button { model.moveItem(folder.id, by: -1) } label: { Image(systemName: "chevron.left") }
                        .disabled(!model.canMove(folder.id, by: -1)).accessibilityLabel("前移文件夹")
                    Button { model.moveItem(folder.id, by: 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(!model.canMove(folder.id, by: 1)).accessibilityLabel("后移文件夹")
                }.font(.system(size: 10, weight: .semibold)).buttonStyle(.plain).foregroundStyle(accent).padding(.bottom, 10)
            }
        }
        .background((targeted ? accent.opacity(0.15) : hovered ? .white.opacity(0.055) : .clear), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(targeted ? accent.opacity(0.65) : .clear))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: TileFramesKey.self, value: [folder.id: geometry.frame(in: .named("appViewport"))])
            }
        }
        .onHover { hovered = $0 }
        .contextMenu {
            Button("打开文件夹") { model.openFolder(folder) }
            Button("重命名…") { model.promptToRenameFolder(folder.id) }
            Divider()
            Button("向前移动") { model.moveItem(folder.id, by: -1) }.disabled(!model.canMove(folder.id, by: -1))
            Button("向后移动") { model.moveItem(folder.id, by: 1) }.disabled(!model.canMove(folder.id, by: 1))
            Divider()
            Button("解散文件夹（保留应用）") { model.dissolveFolder(folder.id) }
        }
        .help("\(folder.name) · \(folder.paths.count) 个应用")
    }
}

private struct TileFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private struct LibraryRow: View {
    let app: InstalledApp
    let selected: Bool
    let action: () -> Void
    @ViewState private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(nsImage: AppIcons.shared.image(for: app)).resizable().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(app.isAvailable ? app.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~") : "应用已移动或卸载")
                        .font(.system(size: 10)).foregroundStyle(muted).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 2)
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .light)).foregroundStyle(selected ? accent : .white.opacity(0.23))
            }.padding(.horizontal, 13).frame(height: 70).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selected ? accent.opacity(0.075) : .white.opacity(hovered ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? accent.opacity(0.22) : .white.opacity(0.05)))
        .onHover { hovered = $0 }
        .accessibilityLabel(app.name).accessibilityValue(selected ? "已勾选" : "未勾选")
        .accessibilityHint("点击切换是否在启动台显示")
        .help(app.path)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium))
            .foregroundStyle(active ? accent : Color.white.opacity(configuration.isPressed ? 1 : 0.62))
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(.white.opacity(configuration.isPressed ? 0.09 : active ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(accent.opacity(configuration.isPressed ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.2)))
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
