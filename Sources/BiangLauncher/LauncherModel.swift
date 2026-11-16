import AppKit
import Combine
import LauncherCore

enum LauncherItem: Identifiable {
    case app(InstalledApp)
    case folder(LauncherFolder)
    var id: String {
        switch self {
        case .app(let app): return app.path
        case .folder(let folder): return folder.id
        }
    }
}

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
    @Published var openFolderID: String?
    @Published private(set) var folderReady = false
    private var folderHover = FolderHover()
    private var folderHoverTask: Task<Void, Never>?
    private var tileFrames: [String: CGRect] = [:]
    private var dragViewport = CGRect.zero
    var dismiss: (() -> Void)?
    var shortcutChanged: ((KeyboardShortcut?) -> Bool)?
    var present: (() -> Void)?
    var isChoosingFile = false
    private var canSave = true
    private let file: PreferencesFile
    private let clock: () -> TimeInterval

    init(file: PreferencesFile? = nil, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.file = file ?? PreferencesFile(url: base.appendingPathComponent("StudioBiangMax/BiangLauncher/preferences.json"))
        self.clock = clock
        do { preferences = try self.file.load() }
        catch {
            canSave = false
            errorMessage = "无法读取已有配置，原文件已保留。请检查 \(self.file.url.path) 后重新启动。\n\(error.localizedDescription)"
        }
    }

    var selectedApps: [InstalledApp] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.path, $0) })
        return preferences.selectedPaths.compactMap { lookup[$0] }
    }
    var openFolder: LauncherFolder? { preferences.folders.first { $0.id == openFolderID } }
    var launcherItems: [LauncherItem] {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || openFolder != nil {
            return visibleApps.map { .app($0) }
        }
        let lookup = Dictionary(uniqueKeysWithValues: selectedApps.map { ($0.path, $0) })
        return preferences.itemOrder.compactMap { id in
            if let folder = preferences.folders.first(where: { $0.id == id }) { return .folder(folder) }
            return lookup[id].map { .app($0) }
        }
    }
    func folderApps(_ folder: LauncherFolder) -> [InstalledApp] {
        let lookup = Dictionary(uniqueKeysWithValues: selectedApps.map { ($0.path, $0) })
        return folder.paths.compactMap { lookup[$0] }
    }
    var visibleApps: [InstalledApp] {
        let source = managing ? (selectedOnly ? selectedApps : apps) : (openFolder.map { folderApps($0) } ?? selectedApps)
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
        openFolderID = nil
        managing = value
        editingOrder = false
        query = ""
        selectedOnly = false
        recordingShortcut = false
        focusRequest = UUID()
    }

    func toggle(_ app: InstalledApp) {
        clearDrag()
        preferences.setSelected(app.path, selected: !isSelected(app))
        reconcileFolder()
        save()
    }

    func move(_ source: String, to target: String) {
        preferences.move(source, to: target)
        save()
    }

    func updateTileFrames(_ frames: [String: CGRect], viewportSize: CGSize) {
        if let target = folderHover.target, tileFrames[target] != frames[target] {
            resetFolderHover()
        }
        tileFrames = frames
        dragViewport = CGRect(origin: .zero, size: viewportSize)
        // Scrolling changes the tiles under a stationary pointer too.
        if dragSource != nil { updateDragTarget() }
    }

    func dragHit(at location: CGPoint) -> String? {
        guard dragViewport.contains(location) else { return nil }
        return tileFrames.first { $0.value.contains(location) }?.key
    }

    func updateDrag(source: String, location: CGPoint) {
        dragSource = source
        dragLocation = location
        updateDragTarget()
    }

    private func updateDragTarget() {
        dragTarget = dragHit(at: dragLocation)
        var candidate: String?
        if openFolder == nil, query.isEmpty, let source = dragSource,
           preferences.selectedPaths.contains(source), let target = dragTarget, target != source,
           let frame = tileFrames[target], frame.insetBy(dx: frame.width * 0.2, dy: 10).contains(dragLocation) {
            candidate = target
        }
        let now = clock()
        if candidate != folderHover.target {
            resetFolderHover()
            folderHover.update(target: candidate, at: now)
            if let candidate {
                folderHoverTask = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: UInt64(FolderHover.delay * 1_000_000_000)) } catch { return }
                    guard let self, self.folderHover.target == candidate, self.dragSource != nil else { return }
                    self.folderReady = self.folderHover.isReady(at: self.clock())
                }
            }
        }
        folderReady = folderHover.isReady(at: now)
    }

    private func resetFolderHover() {
        folderHoverTask?.cancel()
        folderHoverTask = nil
        folderHover = FolderHover()
        folderReady = false
    }

    func finishDrag(source: String, location: CGPoint) {
        updateDrag(source: source, location: location)
        if let target = dragTarget {
            if folderHover.target == target, folderHover.isReady(at: clock()) {
                if preferences.folders.contains(where: { $0.id == target }) {
                    preferences.addToFolder(source, folderID: target)
                } else {
                    preferences.createFolder(source: source, target: target)
                }
                save()
            } else {
                move(source, to: target)
            }
        }
        clearDrag()
    }

    func clearDrag() {
        resetFolderHover()
        dragSource = nil
        dragTarget = nil
    }

    func openFolder(_ folder: LauncherFolder) {
        clearDrag()
        tileFrames = [:]
        query = ""
        openFolderID = folder.id
    }

    func closeFolder() {
        clearDrag()
        tileFrames = [:]
        query = ""
        openFolderID = nil
    }

    func removeFromFolder(_ app: InstalledApp) {
        clearDrag()
        preferences.removeFromFolder(app.path)
        reconcileFolder()
        save()
    }

    func dissolveFolder(_ id: String) {
        clearDrag()
        preferences.dissolveFolder(id)
        reconcileFolder()
        save()
    }

    private func reconcileFolder() {
        if openFolderID != nil && openFolder == nil { closeFolder() }
    }

    func promptToRenameFolder(_ id: String) {
        guard let folder = preferences.folders.first(where: { $0.id == id }) else { return }
        clearDrag()
        let alert = NSAlert()
        alert.messageText = "重命名文件夹"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: folder.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        isChoosingFile = true
        defer { isChoosingFile = false }
        if alert.runModal() == .alertFirstButtonReturn {
            preferences.renameFolder(id, name: field.stringValue)
            save()
        }
    }

    func canMove(_ id: String, by distance: Int) -> Bool {
        let scope = preferences.folders.first(where: { $0.paths.contains(id) })?.paths ?? preferences.itemOrder
        guard let index = scope.firstIndex(of: id) else { return false }
        return scope.indices.contains(index + distance)
    }

    func moveItem(_ id: String, by distance: Int) {
        clearDrag()
        preferences.move(id, by: distance)
        save()
    }

    func move(_ app: InstalledApp, by distance: Int) { moveItem(app.path, by: distance) }

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
