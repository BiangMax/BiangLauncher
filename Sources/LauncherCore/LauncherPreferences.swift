import Foundation

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    public static let initial = KeyboardShortcut(keyCode: 49, modifiers: 2048, label: "⌥ Space")
}

public struct LauncherFolder: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var paths: [String]

    public init(id: String = "folder:" + UUID().uuidString, name: String = "新建文件夹", paths: [String]) {
        self.id = id
        self.name = name
        self.paths = paths
    }
}

/// A continuous dwell on the same target is required; leaving it resets the clock.
public struct FolderHover: Sendable {
    public private(set) var target: String?
    private var beganAt: TimeInterval = 0
    public static let delay: TimeInterval = 1
    public init() {}

    public mutating func update(target: String?, at time: TimeInterval) {
        if self.target != target {
            self.target = target
            beganAt = time
        }
    }

    public func isReady(at time: TimeInterval) -> Bool {
        target != nil && time - beganAt >= Self.delay
    }
}

public struct LauncherPreferences: Codable, Equatable, Sendable {
    public var selectedPaths: [String]
    public var customPaths: [String]
    public var shortcut: KeyboardShortcut?
    public private(set) var folders: [LauncherFolder]
    public private(set) var itemOrder: [String]

    public init(selectedPaths: [String] = [], customPaths: [String] = [], shortcut: KeyboardShortcut? = .initial,
                folders: [LauncherFolder] = [], itemOrder: [String] = []) {
        self.selectedPaths = selectedPaths
        self.customPaths = customPaths
        self.shortcut = shortcut
        self.folders = folders
        self.itemOrder = itemOrder
        normalize()
    }

    private enum CodingKeys: String, CodingKey { case selectedPaths, customPaths, shortcut, folders, itemOrder }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedPaths = try values.decode([String].self, forKey: .selectedPaths)
        customPaths = try values.decode([String].self, forKey: .customPaths)
        shortcut = try values.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcut)
        folders = try values.decodeIfPresent([LauncherFolder].self, forKey: .folders) ?? []
        itemOrder = try values.decodeIfPresent([String].self, forKey: .itemOrder) ?? selectedPaths
        normalize()
    }

    public mutating func setSelected(_ path: String, selected: Bool) {
        if selected {
            if !selectedPaths.contains(path) { selectedPaths.append(path) }
        } else {
            selectedPaths.removeAll { $0 == path }
        }
        normalize()
    }

    @discardableResult
    public mutating func createFolder(source: String, target: String) -> String? {
        guard source != target, itemOrder.contains(source), itemOrder.contains(target),
              selectedPaths.contains(source), selectedPaths.contains(target) else { return nil }
        let folder = LauncherFolder(paths: [target, source])
        itemOrder = itemOrder.filter { $0 != source }.map { $0 == target ? folder.id : $0 }
        folders.append(folder)
        normalize()
        return folder.id
    }

    public mutating func addToFolder(_ path: String, folderID: String) {
        guard selectedPaths.contains(path), itemOrder.contains(path),
              let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].paths.append(path)
        itemOrder.removeAll { $0 == path }
        normalize()
    }

    public mutating func removeFromFolder(_ path: String) {
        guard let index = folders.firstIndex(where: { $0.paths.contains(path) }) else { return }
        let rootIndex = itemOrder.firstIndex(of: folders[index].id) ?? itemOrder.count
        folders[index].paths.removeAll { $0 == path }
        itemOrder.insert(path, at: min(rootIndex + 1, itemOrder.count))
        normalize()
    }

    public mutating func renameFolder(_ id: String, name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = String(name.prefix(60))
    }

    public mutating func dissolveFolder(_ id: String) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        itemOrder = itemOrder.flatMap { $0 == id ? folder.paths : [$0] }
        folders.removeAll { $0.id == id }
        normalize()
    }

    public mutating func move(_ source: String, to target: String) {
        guard source != target else { return }
        if itemOrder.contains(source), itemOrder.contains(target) {
            Self.reorder(&itemOrder, source: source, target: target)
            // Keep the legacy flat order stable for callers and old preferences.
            Self.reorder(&selectedPaths, source: source, target: target)
        } else if let index = folders.firstIndex(where: { $0.paths.contains(source) && $0.paths.contains(target) }) {
            Self.reorder(&folders[index].paths, source: source, target: target)
        }
    }

    public mutating func move(_ path: String, by distance: Int) {
        let scope = folders.first(where: { $0.paths.contains(path) })?.paths ?? itemOrder
        guard let index = scope.firstIndex(of: path), !scope.isEmpty else { return }
        let destination = max(0, min(scope.count - 1, index + distance))
        move(path, to: scope[destination])
    }

    public mutating func normalize() {
        selectedPaths = Self.unique(selectedPaths)
        customPaths = Self.unique(customPaths)
        let selected = Set(selectedPaths)
        var assigned = Set<String>()
        var ids = Set<String>()
        var validFolders: [LauncherFolder] = []
        for var folder in folders {
            guard folder.id.hasPrefix("folder:"), !selected.contains(folder.id), ids.insert(folder.id).inserted else { continue }
            folder.paths = folder.paths.filter { selected.contains($0) && assigned.insert($0).inserted }
            if folder.paths.count < 2 {
                itemOrder = itemOrder.flatMap { $0 == folder.id ? folder.paths : [$0] }
                for path in folder.paths { assigned.remove(path) }
            } else {
                if folder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { folder.name = "新建文件夹" }
                validFolders.append(folder)
            }
        }
        folders = validFolders
        let roots = selectedPaths.filter { !assigned.contains($0) }
        let candidates = roots + folders.map(\.id)
        let valid = Set(candidates)
        itemOrder = Self.unique(itemOrder.filter { valid.contains($0) } + candidates)
    }

    private static func reorder(_ paths: inout [String], source: String, target: String) {
        guard let from = paths.firstIndex(of: source), let to = paths.firstIndex(of: target) else { return }
        paths.remove(at: from)
        paths.insert(source, at: to)
    }

    private static func unique(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }
}

public struct PreferencesFile {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> LauncherPreferences {
        guard FileManager.default.fileExists(atPath: url.path) else { return LauncherPreferences() }
        var result = try JSONDecoder().decode(LauncherPreferences.self, from: Data(contentsOf: url))
        result.normalize()
        return result
    }

    public func save(_ preferences: LauncherPreferences) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preferences).write(to: url, options: .atomic)
    }
}
