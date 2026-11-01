import AppKit
import CoreGraphics
import XCTest
@testable import CommandShiftKit

final class ApplicationDelegateTests: XCTestCase {
    func testWorkspaceSuspensionStopsListeningUntilTheSessionResumes() throws {
        try MainActor.assumeIsolated {
            let center = NotificationCenter()
            var ports: [CFMachPort] = []
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { true }, makeTap: { _, _, _, _, _, _ in
                guard let port = CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil) else { return nil }
                ports.append(port)
                return port
            }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: center,
                requestPermission: {}, showPermissionHelp: {}, showMonitorFailure: {}
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            let first = try XCTUnwrap(ports.first)
            center.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
            XCTAssertFalse(CFMachPortIsValid(first))
            center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
            XCTAssertEqual(ports.count, 1)
            center.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
            XCTAssertEqual(ports.count, 2)
            center.post(name: NSWorkspace.willSleepNotification, object: nil)
            XCTAssertFalse(CFMachPortIsValid(try XCTUnwrap(ports.last)))
            center.post(name: NSWorkspace.didWakeNotification, object: nil)
            XCTAssertEqual(ports.count, 3)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            center.post(name: NSWorkspace.didWakeNotification, object: nil)
            XCTAssertEqual(ports.count, 3)
            XCTAssertTrue(ports.allSatisfy { !CFMachPortIsValid($0) })
        }
    }

    func testMenuOpeningRetriesMonitoringAfterPermissionIsGranted() {
        MainActor.assumeIsolated {
            var granted = false
            var attempts = 0
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { granted }, makeTap: { _, _, _, _, _, _ in attempts += 1; return nil }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showPermissionHelp: {}, showMonitorFailure: {}
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            granted = true
            menu.menuWillOpen(menu.menu)
            XCTAssertEqual(attempts, 1)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        }
    }

    func testReopenDuringPermissionHelpDoesNotPresentAnotherDialog() {
        MainActor.assumeIsolated {
            var help = 0
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { false }, onShortcut: {})
            var delegate: ApplicationDelegate?
            delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showPermissionHelp: {
                    help += 1
                    if help == 1 { _ = delegate?.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true) }
                }, showMonitorFailure: {}
            )
            delegate?.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            XCTAssertEqual(help, 1)
            delegate = nil
        }
    }

    func testOpeningTheRunningApplicationAgainRestoresItsHiddenIcon() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let status = TestStatusItem()
            let menu = StatusMenuController(statusItem: status, loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { false }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showPermissionHelp: {}, showMonitorFailure: {}
            )
            menu.menu.performActionForItem(at: 1)
            XCTAssertFalse(status.isVisible)
            XCTAssertFalse(delegate.applicationShouldHandleReopen(app, hasVisibleWindows: false))
            XCTAssertTrue(status.isVisible)
            XCTAssertEqual(menu.menu.items[1].state, .off)
        }
    }

    func testLaunchRequestsPermissionOnlyOnceAndRetriesOnActivation() throws {
        try MainActor.assumeIsolated {
            var granted = false
            var requests = 0
            var help = 0
            var creations = 0
            let port = try XCTUnwrap(CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil))
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { granted }, makeTap: { _, _, _, _, _, _ in creations += 1; return port }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: { requests += 1 }, showPermissionHelp: { help += 1 }, showMonitorFailure: { XCTFail("Unexpected tap failure") }
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            XCTAssertEqual(requests, 1)
            XCTAssertEqual(help, 1)
            _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
            XCTAssertEqual(requests, 1)
            granted = true
            delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
            XCTAssertEqual(creations, 1)
            XCTAssertEqual(monitor.start(), .running)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            XCTAssertFalse(CFMachPortIsValid(port))
            CFMachPortInvalidate(port)
        }
    }
}
