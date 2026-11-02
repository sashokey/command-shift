import AppKit
import XCTest
@testable import CommandShiftKit

final class AlertsTests: XCTestCase {
    func testErrorPresentationPreservesTheFailureDetails() {
        MainActor.assumeIsolated {
            var presented: NSAlert?
            Alerts.error("Operation failed", "System error -50", present: { presented = $0; return .alertFirstButtonReturn })
            XCTAssertEqual(presented?.messageText, "Operation failed")
            XCTAssertEqual(presented?.informativeText, "System error -50")
            XCTAssertEqual(presented?.buttons.map(\.title), ["OK"])
        }
    }
}
