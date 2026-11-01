import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let statusMenu: StatusMenuController
    private let monitor: KeyboardMonitor
    private let workspaceNotifications: NotificationCenter
    private let requestPermission: () -> Void
    private let showPermissionHelp: () -> Void
    private let showMonitorFailure: () -> Void
    private var requestedPermission = false
    private var presentingHelp = false
    private var sleeping = false
    private var sessionInactive = false
    private var observers: [NSObjectProtocol] = []

    init(
        statusMenu: StatusMenuController,
        monitor: KeyboardMonitor,
        workspaceNotifications: NotificationCenter,
        requestPermission: @escaping () -> Void,
        showPermissionHelp: @escaping () -> Void,
        showMonitorFailure: @escaping () -> Void
    ) {
        self.statusMenu = statusMenu
        self.monitor = monitor
        self.workspaceNotifications = workspaceNotifications
        self.requestPermission = requestPermission
        self.showPermissionHelp = showPermissionHelp
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
        guard !sleeping, !sessionInactive, !presentingHelp else { return }
        presentingHelp = prompt
        defer { presentingHelp = false }
        var state = monitor.start()
        if state == .permissionRequired, prompt, !requestedPermission {
            requestedPermission = true
            requestPermission()
            state = monitor.start()
        }
        if prompt {
            switch state {
            case .permissionRequired: showPermissionHelp()
            case .unavailable: showMonitorFailure()
            case .running: break
            }
        }
    }

    private func workspaceChanged(_ name: Notification.Name) {
        switch name {
        case NSWorkspace.willSleepNotification: sleeping = true
        case NSWorkspace.didWakeNotification: sleeping = false
        case NSWorkspace.sessionDidResignActiveNotification: sessionInactive = true
        case NSWorkspace.sessionDidBecomeActiveNotification: sessionInactive = false
        default: break
        }
        if name != NSWorkspace.didActivateApplicationNotification { monitor.stop() }
        refreshMonitoring(prompt: false)
    }

    private func shutDown() {
        observers.forEach(workspaceNotifications.removeObserver)
        observers.removeAll()
        statusMenu.onOpen = nil
        monitor.stop()
    }
}
