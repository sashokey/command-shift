import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let statusMenu: StatusMenuController
    private let monitor: KeyboardMonitor
    private let workspaceNotifications: NotificationCenter
    private let requestPermission: () -> Void
    private let showMonitorFailure: () -> Void
    private var requestedPermission = false
    private var refreshingMonitoring = false
    private var permissionTimer: Timer?
    private var sleeping = false
    private var sessionInactive = false
    private var observers: [NSObjectProtocol] = []

    init(
        statusMenu: StatusMenuController,
        monitor: KeyboardMonitor,
        workspaceNotifications: NotificationCenter,
        requestPermission: @escaping () -> Void,
        showMonitorFailure: @escaping () -> Void
    ) {
        self.statusMenu = statusMenu
        self.monitor = monitor
        self.workspaceNotifications = workspaceNotifications
        self.requestPermission = requestPermission
        self.showMonitorFailure = showMonitorFailure
        super.init()
    }

    isolated deinit { shutDown() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu.onOpen = { [weak self] in self?.refreshMonitoring(prompt: false) }
        let names = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification
        ]
        for name in names {
            observers.append(workspaceNotifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let name = notification.name
                MainActor.assumeIsolated { self?.workspaceChanged(name) }
            })
        }
        refreshMonitoring(prompt: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshMonitoring(prompt: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        shutDown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusMenu.showIcon()
        refreshMonitoring(prompt: true)
        return false
    }

    private func refreshMonitoring(prompt: Bool) {
        guard !sleeping, !sessionInactive, !refreshingMonitoring else { return }
        refreshingMonitoring = true
        defer { refreshingMonitoring = false }
        var state = monitor.start()
        if state == .permissionRequired, prompt, !requestedPermission {
            requestedPermission = true
            requestPermission()
            state = monitor.start()
        }
        switch state {
        case .permissionRequired:
            startPermissionPolling()
        case .unavailable:
            stopPermissionPolling()
            if prompt { showMonitorFailure() }
        case .running:
            stopPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshMonitoring(prompt: false) }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func workspaceChanged(_ name: Notification.Name) {
        switch name {
        case NSWorkspace.willSleepNotification: sleeping = true
        case NSWorkspace.didWakeNotification: sleeping = false
        case NSWorkspace.sessionDidResignActiveNotification: sessionInactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification: sessionInactive = false
        default: break
        }
        if name != NSWorkspace.didActivateApplicationNotification {
            stopPermissionPolling()
            monitor.stop()
        }
        refreshMonitoring(prompt: false)
    }

    private func shutDown() {
        stopPermissionPolling()
        observers.forEach(workspaceNotifications.removeObserver)
        observers.removeAll()
        statusMenu.onOpen = nil
        monitor.stop()
    }
}
