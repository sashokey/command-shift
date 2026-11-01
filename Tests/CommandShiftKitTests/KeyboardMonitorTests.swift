import CoreGraphics
import XCTest
@testable import CommandShiftKit

final class KeyboardMonitorTests: XCTestCase {
    func testStopOrRevocationCancelsAnAlreadyQueuedSwitch() throws {
        try MainActor.assumeIsolated {
            for revoke in [true, false] {
                let fixture = try TapFixture()
                var granted = true
                var count = 0
                let monitor = KeyboardMonitor(hasPermission: { granted }, makeTap: fixture.makeTap) { count += 1 }
                defer { monitor.stop() }
                XCTAssertEqual(monitor.start(), .running)
                try fixture.send(.flagsChanged, flags: [.maskCommand, .maskShift])
                try fixture.send(.flagsChanged, flags: [])
                if revoke { granted = false } else { monitor.stop() }
                Self.drainQueue()
                XCTAssertEqual(count, 0)
            }
        }
    }

    func testTimeoutDiscardsTheOldChordBeforeReenablingTap() throws {
        try MainActor.assumeIsolated {
            let fixture = try TapFixture()
            var enabled: [Bool] = []
            var count = 0
            let monitor = KeyboardMonitor(
                hasPermission: { true }, makeTap: fixture.makeTap,
                enableTap: { port, value in XCTAssertEqual(port, fixture.port); enabled.append(value) }
            ) { count += 1 }
            defer { monitor.stop() }
            XCTAssertEqual(monitor.start(), .running)
            try fixture.send(.flagsChanged, flags: [.maskCommand, .maskShift])
            try fixture.send(.tapDisabledByTimeout, flags: [])
            XCTAssertEqual(enabled, [true])
            try fixture.send(.flagsChanged, flags: [])
            Self.drainQueue()
            XCTAssertEqual(count, 0)
            try fixture.send(.flagsChanged, flags: [.maskCommand, .maskShift])
            try fixture.send(.flagsChanged, flags: [])
            Self.drainQueue()
            XCTAssertEqual(count, 1)
        }
    }

    func testDisabledTapIsInvalidatedWhenPermissionWasRevoked() throws {
        try MainActor.assumeIsolated {
            let fixture = try TapFixture()
            var granted = true
            var enabled: [Bool] = []
            let monitor = KeyboardMonitor(
                hasPermission: { granted }, makeTap: fixture.makeTap,
                enableTap: { _, value in enabled.append(value) }, onShortcut: {}
            )
            defer { monitor.stop() }
            XCTAssertEqual(monitor.start(), .running)
            granted = false
            try fixture.send(.tapDisabledByUserInput, flags: [])
            XCTAssertTrue(enabled.isEmpty)
            XCTAssertFalse(CFMachPortIsValid(fixture.port))
        }
    }

    @MainActor private static func drainQueue() {
        let drained = XCTestExpectation(description: "Main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        XCTAssertEqual(XCTWaiter.wait(for: [drained], timeout: 1), .completed)
    }

    func testCallbackPassesEventsThroughAndDefersOneSwitch() throws {
        try MainActor.assumeIsolated {
            let fixture = try TapFixture()
            let switched = XCTestExpectation(description: "Source switched")
            var count = 0
            let monitor = KeyboardMonitor(hasPermission: { true }, makeTap: fixture.makeTap) {
                count += 1
                switched.fulfill()
            }
            defer { monitor.stop() }
            XCTAssertEqual(monitor.start(), .running)
            try fixture.send(.flagsChanged, flags: [.maskCommand, .maskShift])
            try fixture.send(.flagsChanged, flags: .maskCommand)
            try fixture.send(.flagsChanged, flags: [])
            XCTAssertEqual(count, 0)
            XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 1), .completed)
            XCTAssertEqual(count, 1)
        }
    }

    func testReleasingMonitorInvalidatesItsPort() throws {
        try MainActor.assumeIsolated {
            let fixture = try TapFixture()
            var monitor: KeyboardMonitor? = KeyboardMonitor(hasPermission: { true }, makeTap: fixture.makeTap, onShortcut: {})
            XCTAssertEqual(monitor?.start(), .running)
            monitor = nil
            XCTAssertFalse(CFMachPortIsValid(fixture.port))
            CFMachPortInvalidate(fixture.port)
        }
    }

    func testStartIsIdempotentAndStopInvalidatesTheOwnedPort() throws {
        try MainActor.assumeIsolated {
            let port = try XCTUnwrap(CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil))
            defer { CFMachPortInvalidate(port) }
            var creations = 0
            let monitor = KeyboardMonitor(
                hasPermission: { true },
                makeTap: { _, _, _, _, _, _ in creations += 1; return port },
                onShortcut: {}
            )
            XCTAssertEqual(monitor.start(), .running)
            XCTAssertEqual(monitor.start(), .running)
            XCTAssertEqual(creations, 1)
            monitor.stop()
            XCTAssertFalse(CFMachPortIsValid(port))
            monitor.stop()
        }
    }

    func testMissingPermissionDoesNotCreateAnEventTap() {
        MainActor.assumeIsolated {
            var attempted = false
            let monitor = KeyboardMonitor(
                hasPermission: { false },
                makeTap: { _, _, _, _, _, _ in attempted = true; return nil },
                onShortcut: {}
            )
            XCTAssertEqual(monitor.start(), .permissionRequired)
            XCTAssertFalse(attempted)
        }
    }

    func testRegistersAPassiveSessionTapWithOnlyRequiredEvents() {
        MainActor.assumeIsolated {
            var location: CGEventTapLocation?
            var options: CGEventTapOptions?
            var mask: CGEventMask = 0
            let monitor = KeyboardMonitor(
                hasPermission: { true },
                makeTap: { tap, _, mode, events, _, _ in
                    location = tap
                    options = mode
                    mask = events
                    return nil
                },
                onShortcut: {}
            )
            XCTAssertEqual(monitor.start(), .unavailable)
            XCTAssertEqual(location, .cgSessionEventTap)
            XCTAssertEqual(options, .listenOnly)
            let required: [CGEventType] = [
                .flagsChanged, .keyDown, .keyUp, .leftMouseDown, .leftMouseUp,
                .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
                .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
            ]
            for type in required { XCTAssertNotEqual(mask & (1 << type.rawValue), 0, "\(type)") }
            XCTAssertEqual(mask & (1 << CGEventType.mouseMoved.rawValue), 0)
        }
    }
}

@MainActor
private final class TapFixture {
    let port: CFMachPort
    private var callback: CGEventTapCallBack?
    private var context: UnsafeMutableRawPointer?

    init() throws {
        port = try XCTUnwrap(CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil))
    }

    func makeTap(
        _ location: CGEventTapLocation, _ placement: CGEventTapPlacement, _ options: CGEventTapOptions,
        _ mask: CGEventMask, _ callback: CGEventTapCallBack, _ context: UnsafeMutableRawPointer?
    ) -> CFMachPort? {
        self.callback = callback
        self.context = context
        return port
    }

    func send(_ type: CGEventType, flags: CGEventFlags) throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.flags = flags
        let callback = try XCTUnwrap(callback)
        let result = callback(OpaquePointer(bitPattern: 1)!, type, event, context)
        XCTAssertTrue(result?.takeUnretainedValue() === event)
        XCTAssertEqual(event.flags, flags)
    }
}
