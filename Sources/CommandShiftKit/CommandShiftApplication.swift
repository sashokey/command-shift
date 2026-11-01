import AppKit
import CoreGraphics
import ServiceManagement

@MainActor
public enum CommandShiftApplication {
    public static func run() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "CommandShift.StatusBarIcon"
        statusItem.button?.title = "⇧⌘"
        statusItem.button?.toolTip = "CommandShift — Shift + Command"
        statusItem.button?.setAccessibilityLabel("CommandShift")

        let menu = StatusMenuController(
            statusItem: statusItem,
            loginItem: SMAppService.mainApp,
            showError: { Alerts.error($0, $1) },
            quit: { application.terminate(nil) }
        )
        let monitor = KeyboardMonitor {
            let status = SystemInputSources.selectNext()
            if status != 0 {
                Alerts.error("Couldn’t Switch Input Source", "macOS returned error \(status). Check your enabled input sources in System Settings > Keyboard > Text Input.")
            }
        }
        let delegate = ApplicationDelegate(
            statusMenu: menu,
            monitor: monitor,
            workspaceNotifications: NSWorkspace.shared.notificationCenter,
            requestPermission: { _ = CGRequestListenEventAccess() },
            showPermissionHelp: { Alerts.permissionHelp() },
            showMonitorFailure: {
                Alerts.error("Couldn’t Start CommandShift", "The keyboard event listener could not be started. Quit and reopen CommandShift from Applications.")
            }
        )
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
