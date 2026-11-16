import AppKit
import Combine
import LauncherCore

@MainActor
final class LauncherModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published private(set) var preferences = LauncherPreferences()
    @Published var query = ""
    @Published var managing = false
    @Published var editingOrder = false
    @Published var selectedOnly = false
    @Published var loading = false
    @Published var recordingShortcut = false
    @Published var errorMessage: String?
    @Published var focusRequest = UUID()
    @Published var dragSource: String?
    @Published var dragTarget: String?
    @Published var dragLocation = CGPoint.zero
    private var tileFrames: [String: CGRect] = [:]
    private var dragViewport = CGRect.zero
    var dismiss: (() -> Void)?
    var shortcutChanged: ((KeyboardShortcut?) -> Bool)?
    var present: (() -> Void)?
    var isChoosingFile = false
    private var canSave = true
    private let file: PreferencesFile

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = PreferencesFile(url: base.appendingPathComponent("StudioBiangMax/BiangLauncher/preferences.json"))
        do { preferences = try file.load() }
        catch {
            canSave = false
            errorMessage = "无法读取已有配置，原文件已保留。请检查 \(file.url.path) 后重新启动。\n\(error.localizedDescription)"
        }
    }

    var selectedApps: [InstalledApp] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.path, $0) })
        return preferences.selectedPaths.compactMap { lookup[$0] }
    }
    var visibleApps: [InstalledApp] {
        let source = managing ? (selectedOnly ? selectedApps : apps) : selectedApps
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return source }
        return source.filter { $0.name.localizedStandardContains(search) || $0.url.deletingPathExtension().lastPathComponent.localizedStandardContains(search) }
    }
    func isSelected(_ app: InstalledApp) -> Bool { preferences.selectedPaths.contains(app.path) }

    func refresh() {
        guard !loading else { return }
        loading = true
        let additional = preferences.customPaths + preferences.selectedPaths
        Task {
            let result = await Task.detached(priority: .userInitiated) { AppCatalog.scan(additionalPaths: additional) }.value
            AppIcons.shared.clear()
            apps = result
            loading = false
        }
    }

    func setManaging(_ value: Bool) {
        clearDrag()
        managing = value
        editingOrder = false
        query = ""
        selectedOnly = false
        recordingShortcut = false
        focusRequest = UUID()
    }

    func toggle(_ app: InstalledApp) {
        preferences.setSelected(app.path, selected: !isSelected(app))
        save()
    }

    func move(_ source: String, to target: String) {
        preferences.move(source, to: target)
        save()
    }

    func updateTileFrames(_ frames: [String: CGRect], viewportSize: CGSize) {
        tileFrames = frames
        dragViewport = CGRect(origin: .zero, size: viewportSize)
        // Scrolling changes the tiles under a stationary pointer too.
        if dragSource != nil { dragTarget = dragHit(at: dragLocation) }
    }

    func dragHit(at location: CGPoint) -> String? {
        guard dragViewport.contains(location) else { return nil }
        return tileFrames.first { $0.value.contains(location) }?.key
    }

    func updateDrag(source: String, location: CGPoint) {
        dragSource = source
        dragLocation = location
        dragTarget = dragHit(at: location)
    }

    func finishDrag(source: String, location: CGPoint) {
        if let target = dragHit(at: location) {
            move(source, to: target)
        }
        clearDrag()
    }

    func clearDrag() {
        dragSource = nil
        dragTarget = nil
    }

    func move(_ app: InstalledApp, by distance: Int) {
        preferences.move(app.path, by: distance)
        save()
    }

    func setShortcut(_ shortcut: KeyboardShortcut?) {
        recordingShortcut = false
        guard shortcutChanged?(shortcut) != false else { return }
        preferences.shortcut = shortcut
        save()
    }

    func launch(_ app: InstalledApp) {
        guard app.isAvailable else {
            errorMessage = "找不到「\(app.name)」。你可以在选择应用中取消勾选，再通过“添加应用”选择新的位置。"
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        dismiss?()
        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.present?()
                self?.errorMessage = "无法打开「\(app.name)」：\(error.localizedDescription)"
            }
        }
    }

    func addApplication() {
        isChoosingFile = true
        defer { isChoosingFile = false }
        let panel = NSOpenPanel()
        panel.title = "添加应用到 BiangLauncher"
        panel.message = "可以选择其他位置安装的应用；添加后会自动勾选。"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = url.standardizedFileURL.path
            guard path != Bundle.main.bundlePath else { continue }
            if !preferences.customPaths.contains(path) { preferences.customPaths.append(path) }
            preferences.setSelected(path, selected: true)
        }
        save()
        refresh()
    }

    private func save() {
        guard canSave else { return }
        do { try file.save(preferences) }
        catch { errorMessage = "保存失败，当前更改可能在退出后丢失：\(error.localizedDescription)" }
    }
}
