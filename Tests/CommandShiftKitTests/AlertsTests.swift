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

    func testPermissionHelpOpensOnlyTheLocalInputMonitoringPaneOnRequest() {
        MainActor.assumeIsolated {
            for response in [NSApplication.ModalResponse.alertFirstButtonReturn, .alertSecondButtonReturn] {
                var opened: [String] = []
                Alerts.permissionHelp(present: { alert in
                    XCTAssertEqual(alert.buttons.map(\.title), ["Open System Settings", "Not Now"])
                    return response
                }, open: { opened.append($0.absoluteString) })
                XCTAssertEqual(opened, response == .alertFirstButtonReturn
                    ? ["x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"] : [])
            }
        }
    }
}
