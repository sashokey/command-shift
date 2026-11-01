import CoreGraphics
import Foundation

@MainActor
final class KeyboardMonitor {
    enum State {
        case running
        case permissionRequired
        case unavailable
    }

    typealias TapFactory = (
        CGEventTapLocation, CGEventTapPlacement, CGEventTapOptions,
        CGEventMask, CGEventTapCallBack, UnsafeMutableRawPointer?
    ) -> CFMachPort?

    private let hasPermission: () -> Bool
    private let makeTap: TapFactory
    private let enableTap: (CFMachPort, Bool) -> Void
    private let onShortcut: () -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var shortcut = ShortcutRecognizer()
    private var generation = 0

    init(
        hasPermission: @escaping () -> Bool = CGPreflightListenEventAccess,
        makeTap: @escaping TapFactory = CGEvent.tapCreate,
        enableTap: @escaping (CFMachPort, Bool) -> Void = CGEvent.tapEnable,
        onShortcut: @escaping () -> Void
    ) {
        self.hasPermission = hasPermission
        self.makeTap = makeTap
        self.enableTap = enableTap
        self.onShortcut = onShortcut
    }

    isolated deinit {
        stop()
    }

    func start() -> State {
        guard hasPermission() else {
            stop()
            return .permissionRequired
        }
        if let tap, CFMachPortIsValid(tap) { return .running }
        stop()
        let events: [CGEventType] = [
            .flagsChanged, .keyDown, .keyUp, .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = makeTap(
            .cgSessionEventTap, .tailAppendEventTap, .listenOnly, mask,
            { _, type, event, context in
                if let context {
                    MainActor.assumeIsolated {
                        let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
                        monitor.receive(type, flags: event.flags)
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            Unmanaged.passUnretained(self).toOpaque()
        ) else { return .unavailable }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            return .unavailable
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return .running
    }

    func stop() {
        generation &+= 1
        shortcut = ShortcutRecognizer()
        if let source { CFRunLoopSourceInvalidate(source) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    private func receive(_ type: CGEventType, flags: CGEventFlags) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            generation &+= 1
            shortcut = ShortcutRecognizer()
            if hasPermission(), let tap {
                enableTap(tap, true)
            } else {
                stop()
            }
            return
        }
        if shortcut.handle(type, flags: flags) {
            let generation = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation, let tap = self.tap,
                      CFMachPortIsValid(tap) else { return }
                guard self.hasPermission() else {
                    self.stop()
                    return
                }
                self.onShortcut()
            }
        }
    }
}
