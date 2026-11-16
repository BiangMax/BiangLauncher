import AppKit
import Foundation

struct InstalledApp: Identifiable, Equatable, Sendable {
    let path: String
    let name: String
    let isAvailable: Bool
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
}

enum AppCatalog {
    static func scan(additionalPaths: [String]) -> [InstalledApp] {
        let manager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
        ]
        var paths = Set(additionalPaths)
        for root in roots {
            guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey], options: [.skipsHiddenFiles]) else { continue }
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension.lowercased() == "app" {
                    paths.insert(url.standardizedFileURL.path)
                    enumerator.skipDescendants()
                } else if (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true {
                    enumerator.skipDescendants()
                }
            }
        }
        return paths.filter { $0 != Bundle.main.bundlePath }.map { path in
            let url = URL(fileURLWithPath: path)
            let bundle = Bundle(url: url)
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            // Finder's localized name matches what the user sees in Applications.
            let finderName = manager.displayName(atPath: path)
            let displayName = finderName != url.lastPathComponent
                ? (finderName as NSString).deletingPathExtension : name
            return InstalledApp(path: path, name: displayName, isAvailable: manager.fileExists(atPath: path))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

@MainActor
final class AppIcons {
    static let shared = AppIcons()
    private var cache: [String: NSImage] = [:]
    func image(for app: InstalledApp) -> NSImage {
        if let image = cache[app.path] { return image }
        let image = NSWorkspace.shared.icon(forFile: app.path)
        image.size = NSSize(width: 128, height: 128)
        cache[app.path] = image
        return image
    }
    func clear() { cache.removeAll() }
}
