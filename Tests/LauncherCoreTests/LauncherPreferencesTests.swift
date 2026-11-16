#if !STANDALONE_TESTS
import XCTest
@testable import LauncherCore
#else
import Foundation
#endif

final class LauncherPreferencesTests: XCTestCase {
    func testStartsWithNoSelectedApps() {
        XCTAssertTrue(LauncherPreferences().selectedPaths.isEmpty)
    }

    func testSelectionIsUniqueAndRemovalDoesNotAffectOthers() {
        var preferences = LauncherPreferences()
        preferences.setSelected("Arknights.app", selected: true)
        preferences.setSelected("BambuStudio.app", selected: true)
        preferences.setSelected("Arknights.app", selected: true)
        XCTAssertEqual(preferences.selectedPaths, ["Arknights.app", "BambuStudio.app"])
        preferences.setSelected("Arknights.app", selected: false)
        XCTAssertEqual(preferences.selectedPaths, ["BambuStudio.app"])
    }

    func testDragInBothDirectionsPreservesOtherApps() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"])
        preferences.move("A", to: "C")
        XCTAssertEqual(preferences.selectedPaths, ["B", "C", "A", "D"])
        preferences.move("D", to: "B")
        XCTAssertEqual(preferences.selectedPaths, ["D", "B", "C", "A"])
        preferences.move("missing", to: "A")
        preferences.move("A", to: "A")
        XCTAssertEqual(preferences.selectedPaths, ["D", "B", "C", "A"])
    }

    func testAccessibleReorderClampsAtEdges() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C"])
        preferences.move("A", by: -1)
        preferences.move("C", by: 1)
        XCTAssertEqual(preferences.selectedPaths, ["A", "B", "C"])
        preferences.move("B", by: -1)
        XCTAssertEqual(preferences.selectedPaths, ["B", "A", "C"])
    }

    func testPersistedOrderSelectionAndShortcutRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = PreferencesFile(url: directory.appendingPathComponent("settings.json"))
        XCTAssertTrue(try file.load().selectedPaths.isEmpty)
        let original = LauncherPreferences(selectedPaths: ["B", "A"], customPaths: ["/Games/A.app"], shortcut: nil)
        try file.save(original)
        XCTAssertEqual(try file.load(), original)
    }

    func testCorruptFileIsReportedInsteadOfSilentlyReset() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try PreferencesFile(url: url).load())
    }

    func testOldPreferencesMigrateWithoutChangingSelectionOrShortcut() throws {
        let json = #"{"selectedPaths":["C","A","B"],"customPaths":[],"shortcut":null}"#
        let preferences = try JSONDecoder().decode(LauncherPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(preferences.selectedPaths, ["C", "A", "B"])
        XCTAssertEqual(preferences.itemOrder, ["C", "A", "B"])
        XCTAssertTrue(preferences.folders.isEmpty)
        XCTAssertTrue(preferences.shortcut == nil)
    }

    func testFolderCreationAdditionAndPersistence() throws {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"])
        let id = preferences.createFolder(source: "A", target: "C")!
        XCTAssertEqual(preferences.itemOrder, ["B", id, "D"])
        XCTAssertEqual(preferences.folders[0].paths, ["C", "A"])
        preferences.addToFolder("D", folderID: id)
        preferences.addToFolder("D", folderID: id)
        preferences.renameFolder(id, name: "  工作  ")
        XCTAssertEqual(preferences.folders[0].paths, ["C", "A", "D"])
        XCTAssertEqual(preferences.itemOrder, ["B", id])
        XCTAssertEqual(preferences.folders[0].name, "工作")
        XCTAssertEqual(Set(preferences.selectedPaths), Set(["A", "B", "C", "D"]))
        let decoded = try JSONDecoder().decode(LauncherPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded, preferences)
    }

    func testFolderRemovalAndDissolveKeepAllRemainingApps() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"])
        let id = preferences.createFolder(source: "B", target: "A")!
        preferences.addToFolder("C", folderID: id)
        preferences.removeFromFolder("B")
        XCTAssertEqual(preferences.itemOrder, [id, "B", "D"])
        XCTAssertEqual(preferences.folders[0].paths, ["A", "C"])
        preferences.setSelected("A", selected: false)
        XCTAssertTrue(preferences.folders.isEmpty)
        XCTAssertEqual(preferences.itemOrder, ["C", "B", "D"])
        XCTAssertEqual(Set(preferences.selectedPaths), Set(["B", "C", "D"]))
        let second = preferences.createFolder(source: "C", target: "D")!
        preferences.dissolveFolder(second)
        XCTAssertTrue(preferences.folders.isEmpty)
        XCTAssertEqual(preferences.itemOrder, ["B", "D", "C"])
    }

    func testFolderAndChildOrderingAreIndependent() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"])
        let id = preferences.createFolder(source: "B", target: "A")!
        preferences.move(id, to: "D")
        XCTAssertEqual(preferences.itemOrder, ["C", "D", id])
        preferences.move("B", by: -1)
        XCTAssertEqual(preferences.folders[0].paths, ["B", "A"])
        XCTAssertEqual(preferences.itemOrder, ["C", "D", id])
        preferences.move("B", to: "C")
        XCTAssertEqual(preferences.folders[0].paths, ["B", "A"])
        XCTAssertTrue(preferences.createFolder(source: id, target: "C") == nil)
    }

    func testFolderNormalizationRemovesStaleAndDuplicateMembership() {
        let first = LauncherFolder(id: "folder:1", paths: ["A", "B", "A", "missing"])
        let second = LauncherFolder(id: "folder:2", paths: ["B", "C"])
        let preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"], folders: [first, second], itemOrder: [first.id, second.id, "D"])
        XCTAssertEqual(preferences.folders.count, 1)
        XCTAssertEqual(preferences.folders[0].paths, ["A", "B"])
        XCTAssertEqual(preferences.itemOrder, [first.id, "C", "D"])
    }

    func testFolderHoverRequiresOneContinuousSecondOnSameTarget() {
        var hover = FolderHover()
        hover.update(target: "A", at: 10)
        XCTAssertTrue(!hover.isReady(at: 10.999))
        hover.update(target: "A", at: 10.5)
        XCTAssertTrue(hover.isReady(at: 11))
        hover.update(target: "B", at: 11)
        XCTAssertTrue(!hover.isReady(at: 11.999))
        hover.update(target: nil, at: 12)
        XCTAssertTrue(!hover.isReady(at: 20))
        hover.update(target: "B", at: 20)
        XCTAssertTrue(!hover.isReady(at: 20.999))
        XCTAssertTrue(hover.isReady(at: 21))
    }
}
