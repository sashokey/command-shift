import AppKit
import ServiceManagement
import XCTest
@testable import CommandShiftKit

final class StatusMenuTests: XCTestCase {
    func testHideActionAndShowIconKeepTheCheckmarkInSync() {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let status = TestStatusItem()
            let controller = StatusMenuController(statusItem: status, loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            controller.menu.performActionForItem(at: 1)
            XCTAssertFalse(status.isVisible)
            XCTAssertEqual(controller.menu.items[1].state, .on)
            controller.showIcon()
            XCTAssertTrue(status.isVisible)
            XCTAssertEqual(controller.menu.items[1].state, .off)
        }
    }

    func testLoginActionRegistersAndUnregistersWithoutLocalPreferences() {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let login = TestLoginItem()
            let controller = StatusMenuController(statusItem: TestStatusItem(), loginItem: login, showError: { _, _ in }, quit: {})
            controller.menu.performActionForItem(at: 0)
            XCTAssertEqual(login.registrations, 1)
            XCTAssertEqual(controller.menu.items[0].state, .on)
            controller.menu.performActionForItem(at: 0)
            XCTAssertEqual(login.unregistrations, 1)
            XCTAssertEqual(controller.menu.items[0].state, .off)
        }
    }

    func testPendingLoginApprovalOpensSystemSettings() {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let login = TestLoginItem()
            login.status = .requiresApproval
            let controller = StatusMenuController(statusItem: TestStatusItem(), loginItem: login, showError: { _, _ in }, quit: {})
            controller.menuWillOpen(controller.menu)
            XCTAssertEqual(controller.menu.items[0].title, "Open at Login (Pending Approval)")
            XCTAssertEqual(controller.menu.items[0].state, .off)
            controller.menu.performActionForItem(at: 0)
            XCTAssertEqual(login.settingsOpened, 1)
            XCTAssertEqual(login.registrations, 0)
        }
    }

    func testRegistrationFailureIsReportedWithoutCheckingTheItem() {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let login = TestLoginItem()
            login.error = NSError(domain: "TestLogin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration denied"])
            var errors: [String] = []
            let controller = StatusMenuController(statusItem: TestStatusItem(), loginItem: login, showError: { _, message in errors.append(message) }, quit: {})
            controller.menu.performActionForItem(at: 0)
            XCTAssertEqual(errors, ["Registration denied"])
            XCTAssertEqual(controller.menu.items[0].state, .off)
        }
    }

    func testMenuMatchesProperWMAndQuitIsWired() {
        MainActor.assumeIsolated {
            _ = NSApplication.shared
            let status = TestStatusItem()
            var quit = false
            let controller = StatusMenuController(statusItem: status, loginItem: TestLoginItem(), showError: { _, _ in }) { quit = true }
            XCTAssertEqual(controller.menu.items.map(\.title), ["Open at Login", "Hide Status Bar Icon", "", "Quit"])
            XCTAssertTrue(status.menu === controller.menu)
            if controller.menu.items.count == 4 {
                XCTAssertTrue(controller.menu.items[2].isSeparatorItem)
                XCTAssertTrue(controller.menu.items.allSatisfy { $0.keyEquivalent.isEmpty })
                controller.menu.performActionForItem(at: 3)
            }
            XCTAssertTrue(quit)
        }
    }
}

@MainActor
final class TestStatusItem: StatusItemManaging {
    var isVisible = true
    var menu: NSMenu?
}

@MainActor
final class TestLoginItem: LoginItemManaging {
    var status: SMAppService.Status = .notRegistered
    var registrations = 0
    var unregistrations = 0
    var settingsOpened = 0
    var error: Error?

    func register() throws {
        registrations += 1
        if let error { throw error }
        status = .enabled
    }

    func unregister() throws {
        unregistrations += 1
        if let error { throw error }
        status = .notRegistered
    }

    func openSettings() { settingsOpened += 1 }
}
