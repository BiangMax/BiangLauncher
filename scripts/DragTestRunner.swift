import AppKit
import LauncherCore

// Use a temporary preferences file and deterministic clock; never touch the
// developer's selected apps or depend on sleeps for the one-second boundary.
@main
struct DragTestRunner {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = PreferencesFile(url: directory.appendingPathComponent("preferences.json"))
        var time: TimeInterval = 100
        let size = CGSize(width: 600, height: 300)
        let frames = ["A": CGRect(x: 0, y: 0, width: 100, height: 120),
                      "B": CGRect(x: 110, y: 0, width: 100, height: 120),
                      "C": CGRect(x: 220, y: 0, width: 100, height: 120),
                      "D": CGRect(x: 330, y: 0, width: 100, height: 120)]
        func fixture() throws -> LauncherModel {
            try file.save(LauncherPreferences(selectedPaths: ["A", "B", "C", "D"]))
            let model = LauncherModel(file: file, clock: { time })
            model.apps = ["A", "B", "C", "D"].map { InstalledApp(path: $0, name: $0, isAvailable: true) }
            model.updateTileFrames(frames, viewportSize: size)
            return model
        }

        let quick = try fixture()
        quick.updateDrag(source: "A", location: CGPoint(x: 160, y: 50))
        time = 100.999
        quick.finishDrag(source: "A", location: CGPoint(x: 160, y: 50))
        precondition(quick.preferences.folders.isEmpty)
        precondition(quick.preferences.itemOrder == ["B", "A", "C", "D"])
        print("PASS Drop before one second preserves ordinary reordering")

        time = 200
        let grouped = try fixture()
        grouped.updateDrag(source: "A", location: CGPoint(x: 270, y: 50))
        time = 201
        grouped.finishDrag(source: "A", location: CGPoint(x: 270, y: 50))
        let folder = grouped.preferences.folders[0]
        precondition(folder.paths == ["C", "A"])
        precondition(grouped.preferences.itemOrder == ["B", folder.id, "D"])
        let saved = try file.load()
        precondition(saved == grouped.preferences)
        grouped.updateTileFrames([folder.id: frames["C"]!], viewportSize: size)
        time = 300
        grouped.updateDrag(source: "B", location: CGPoint(x: 270, y: 50))
        time = 301
        grouped.finishDrag(source: "B", location: CGPoint(x: 270, y: 50))
        precondition(grouped.preferences.folders[0].paths == ["C", "A", "B"])
        grouped.openFolder(grouped.preferences.folders[0])
        precondition(grouped.launcherItems.map(\.id) == ["C", "A", "B"])
        grouped.query = "A"
        precondition(grouped.visibleApps.map(\.path) == ["A"])
        grouped.query = ""
        grouped.removeFromFolder(grouped.apps[0])
        precondition(grouped.openFolder?.paths == ["C", "B"])
        grouped.removeFromFolder(grouped.apps[1])
        precondition(grouped.openFolder == nil && grouped.preferences.folders.isEmpty)
        print("PASS Dwell creates and adds to persistent folders; open, search and remove retain apps")

        time = 400
        let scrolled = try fixture()
        scrolled.updateDrag(source: "A", location: CGPoint(x: 160, y: 50))
        time = 400.5
        scrolled.updateTileFrames(["B": CGRect(x: 110, y: -10, width: 100, height: 120)], viewportSize: size)
        time = 401.1
        scrolled.finishDrag(source: "A", location: CGPoint(x: 160, y: 50))
        precondition(scrolled.preferences.folders.isEmpty)
        print("PASS Scrolling resets dwell even when the target remains beneath the pointer")

        time = 500
        let switched = try fixture()
        switched.updateDrag(source: "A", location: CGPoint(x: 160, y: 50))
        time = 500.5
        switched.updateDrag(source: "A", location: CGPoint(x: 270, y: 50))
        time = 501
        switched.finishDrag(source: "A", location: CGPoint(x: 270, y: 50))
        precondition(switched.preferences.folders.isEmpty)
        print("PASS Switching targets restarts dwell")

        time = 600
        let cancelled = try fixture()
        cancelled.updateDrag(source: "A", location: CGPoint(x: 160, y: 50))
        time = 603
        cancelled.finishDrag(source: "A", location: CGPoint(x: 160, y: -50))
        precondition(cancelled.preferences.folders.isEmpty)
        precondition(cancelled.preferences.itemOrder == ["A", "B", "C", "D"])
        precondition(cancelled.dragSource == nil && !cancelled.folderReady)
        print("PASS Dropping outside the viewport cancels grouping and sorting")
        let stationary = LauncherModel(file: file)
        stationary.updateTileFrames(frames, viewportSize: size)
        stationary.updateDrag(source: "A", location: CGPoint(x: 160, y: 50))
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !stationary.folderReady && ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        precondition(stationary.folderReady)
        stationary.clearDrag()
        precondition(!stationary.folderReady)
        print("PASS Stationary pointer receives the ready cue without another mouse event")
        print("6 interaction checks, 0 failures")
    }
}
