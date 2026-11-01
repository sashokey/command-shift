import AppKit

@MainActor
enum Alerts {
    static func error(
        _ title: String, _ message: String,
        present: @MainActor (NSAlert) -> NSApplication.ModalResponse = present
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = present(alert)
    }

    static func permissionHelp(
        present: @MainActor (NSAlert) -> NSApplication.ModalResponse = present,
        open: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        let alert = NSAlert()
        alert.messageText = "Allow Input Monitoring"
        alert.informativeText = "CommandShift needs Input Monitoring to recognize Shift + Command while another app is active. Enable CommandShift in System Settings > Privacy & Security > Input Monitoring, then reopen CommandShift from Applications. Typed text is never read or saved."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if present(alert) == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            open(url)
        }
    }

    private static func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if #available(macOS 14, *) {
            NSApplication.shared.activate()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        return alert.runModal()
    }
}
