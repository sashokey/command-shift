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
                requestPermission: {}, showMonitorFailure: {}
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
                requestPermission: {}, showMonitorFailure: {}
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            granted = true
            menu.menuWillOpen(menu.menu)
            XCTAssertEqual(attempts, 1)
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        }
    }

    func testMissingPermissionShowsNoAppDialogOrRepeatedSystemRequest() {
        MainActor.assumeIsolated {
            var requests = 0
            var dialogs = 0
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { false }, onShortcut: {})
            var delegate: ApplicationDelegate?
            delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {
                    requests += 1
                    _ = delegate?.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
                }, showMonitorFailure: { dialogs += 1 }
            )
            delegate?.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            _ = delegate?.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
            delegate?.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
            menu.menuWillOpen(menu.menu)
            XCTAssertEqual(requests, 1)
            XCTAssertEqual(dialogs, 0)
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
                requestPermission: {}, showMonitorFailure: {}
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
            var creations = 0
            let port = try XCTUnwrap(CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil))
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { granted }, makeTap: { _, _, _, _, _, _ in creations += 1; return port }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: { requests += 1 }, showMonitorFailure: { XCTFail("Unexpected tap failure") }
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            XCTAssertEqual(requests, 1)
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

    func testPermissionGrantStartsMonitoringWithoutReopeningAndStopsPolling() throws {
        try MainActor.assumeIsolated {
            var granted = false
            var checks = 0
            var creations = 0
            let port = try XCTUnwrap(CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil))
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { checks += 1; return granted }, makeTap: { _, _, _, _, _, _ in
                creations += 1
                return port
            }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showMonitorFailure: { XCTFail("Unexpected tap failure") }
            )
            defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            granted = true
            Self.waitForPermissionCheck { creations > 0 }
            XCTAssertEqual(creations, 1)
            let checksAfterGrant = checks
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.3))
            XCTAssertEqual(checks, checksAfterGrant)
            XCTAssertEqual(creations, 1)
        }
    }

    func testPermissionPollingStopsWhenTheListenerCannotStart() {
        MainActor.assumeIsolated {
            var granted = false
            var checks = 0
            var attempts = 0
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { checks += 1; return granted }, makeTap: { _, _, _, _, _, _ in
                attempts += 1
                return nil
            }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showMonitorFailure: {}
            )
            defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            granted = true
            Self.waitForPermissionCheck { attempts > 0 }
            XCTAssertEqual(attempts, 1)
            let checksAfterGrant = checks
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.3))
            XCTAssertEqual(checks, checksAfterGrant)
            XCTAssertEqual(attempts, 1)
        }
    }

    func testPermissionPollingStopsWhenTheApplicationTerminates() {
        MainActor.assumeIsolated {
            var checks = 0
            let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
            let monitor = KeyboardMonitor(hasPermission: { checks += 1; return false }, onShortcut: {})
            let delegate = ApplicationDelegate(
                statusMenu: menu, monitor: monitor, workspaceNotifications: NotificationCenter(),
                requestPermission: {}, showMonitorFailure: {}
            )
            delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
            Self.waitForPermissionCheck { checks > 2 }
            delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            let checksAtTermination = checks
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.3))
            XCTAssertEqual(checks, checksAtTermination)
        }
    }

    func testPermissionPollingPausesWhileTheWorkspaceIsSuspended() {
        MainActor.assumeIsolated {
            let suspensions: [(Notification.Name, Notification.Name)] = [
                (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification),
                (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification)
            ]
            for (suspend, resume) in suspensions {
                let center = NotificationCenter()
                var checks = 0
                let menu = StatusMenuController(statusItem: TestStatusItem(), loginItem: TestLoginItem(), showError: { _, _ in }, quit: {})
                let monitor = KeyboardMonitor(hasPermission: { checks += 1; return false }, onShortcut: {})
                let delegate = ApplicationDelegate(
                    statusMenu: menu, monitor: monitor, workspaceNotifications: center,
                    requestPermission: {}, showMonitorFailure: {}
                )
                delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
                center.post(name: suspend, object: nil)
                let checksWhileSuspended = checks
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.3))
                XCTAssertEqual(checks, checksWhileSuspended)
                center.post(name: resume, object: nil)
                let checksAtResume = checks
                Self.waitForPermissionCheck { checks > checksAtResume }
                delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
            }
        }
    }

    @MainActor
    private static func waitForPermissionCheck(_ condition: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: 3)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertTrue(condition(), "Permission changes should be detected without reopening the app")
    }
}
