// Minimal XCTest-compatible assertions for hosts with Command Line Tools only.
// The test cases themselves are shared with the Xcode XCTest target.
import Foundation

class XCTestCase {}
private var failures = 0

private func report(_ message: String, file: StaticString, line: UInt) {
    failures += 1
    print("FAIL \(file):\(line): \(message)")
}

func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    do {
        if try !expression() { report("Expected true", file: file, line: line) }
    } catch { report("Unexpected error: \(error)", file: file, line: line) }
}

func XCTAssertEqual<T: Equatable>(_ left: @autoclosure () throws -> T, _ right: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do {
        let lhs = try left(), rhs = try right()
        if lhs != rhs { report("\(lhs) != \(rhs)", file: file, line: line) }
    } catch { report("Unexpected error: \(error)", file: file, line: line) }
}

func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do {
        _ = try expression()
        report("Expected an error", file: file, line: line)
    } catch {}
}

@main
struct CoreTestRunner {
    static func main() throws {
        let suite = LauncherPreferencesTests()
        let cases: [(String, () throws -> Void)] = [
            ("Empty initial selection", suite.testStartsWithNoSelectedApps),
            ("Unique selection and removal", suite.testSelectionIsUniqueAndRemovalDoesNotAffectOthers),
            ("Drag reorder in both directions", suite.testDragInBothDirectionsPreservesOtherApps),
            ("Accessible reorder boundaries", suite.testAccessibleReorderClampsAtEdges),
            ("Persistence round trip", suite.testPersistedOrderSelectionAndShortcutRoundTrip),
            ("Corrupt preferences preserve error", suite.testCorruptFileIsReportedInsteadOfSilentlyReset),
            ("Legacy preferences migration", suite.testOldPreferencesMigrateWithoutChangingSelectionOrShortcut),
            ("Folder creation, addition and persistence", suite.testFolderCreationAdditionAndPersistence),
            ("Folder removal and dissolution", suite.testFolderRemovalAndDissolveKeepAllRemainingApps),
            ("Independent folder and child ordering", suite.testFolderAndChildOrderingAreIndependent),
            ("Folder membership normalization", suite.testFolderNormalizationRemovesStaleAndDuplicateMembership),
            ("One-second continuous folder dwell", suite.testFolderHoverRequiresOneContinuousSecondOnSameTarget)
        ]
        for (name, run) in cases {
            let before = failures
            do { try run() } catch { failures += 1; print("FAIL \(name): \(error)") }
            if failures == before { print("PASS \(name)") }
        }
        print("\(cases.count) tests, \(failures) failures")
        if failures != 0 { exit(1) }
    }
}
