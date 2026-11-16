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

public struct LauncherPreferences: Codable, Equatable, Sendable {
    public var selectedPaths: [String]
    public var customPaths: [String]
    public var shortcut: KeyboardShortcut?

    public init(selectedPaths: [String] = [], customPaths: [String] = [], shortcut: KeyboardShortcut? = .initial) {
        self.selectedPaths = Self.unique(selectedPaths)
        self.customPaths = Self.unique(customPaths)
        self.shortcut = shortcut
    }

    public mutating func setSelected(_ path: String, selected: Bool) {
        if selected {
            if !selectedPaths.contains(path) { selectedPaths.append(path) }
        } else {
            selectedPaths.removeAll { $0 == path }
        }
    }

    public mutating func move(_ source: String, to target: String) {
        guard source != target,
              let sourceIndex = selectedPaths.firstIndex(of: source),
              let targetIndex = selectedPaths.firstIndex(of: target) else { return }
        selectedPaths.remove(at: sourceIndex)
        selectedPaths.insert(source, at: targetIndex)
    }

    public mutating func move(_ path: String, by distance: Int) {
        guard let index = selectedPaths.firstIndex(of: path) else { return }
        let destination = max(0, min(selectedPaths.count - 1, index + distance))
        guard destination != index else { return }
        selectedPaths.remove(at: index)
        selectedPaths.insert(path, at: destination)
    }

    public mutating func normalize() {
        selectedPaths = Self.unique(selectedPaths)
        customPaths = Self.unique(customPaths)
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
