import AppKit
import ServiceManagement

@MainActor
protocol StatusItemManaging: AnyObject {
    var isVisible: Bool { get set }
    var menu: NSMenu? { get set }
}

extension NSStatusItem: StatusItemManaging {}

@MainActor
protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

extension SMAppService: LoginItemManaging {
    func openSettings() { Self.openSystemSettingsLoginItems() }
}

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    var onOpen: (() -> Void)?
    private let statusItem: any StatusItemManaging
    private let loginItem: any LoginItemManaging
    private let showError: (String, String) -> Void
    private let quit: () -> Void
    private let loginMenuItem = NSMenuItem(title: "Open at Login", action: nil, keyEquivalent: "")
    private let hideMenuItem = NSMenuItem(title: "Hide Status Bar Icon", action: nil, keyEquivalent: "")

    init(
        statusItem: any StatusItemManaging,
        loginItem: any LoginItemManaging,
        showError: @escaping (String, String) -> Void,
        quit: @escaping () -> Void
    ) {
        self.statusItem = statusItem
        self.loginItem = loginItem
        self.showError = showError
        self.quit = quit
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        loginMenuItem.target = self
        loginMenuItem.action = #selector(toggleLogin)
        hideMenuItem.target = self
        hideMenuItem.action = #selector(toggleIcon)
        menu.addItem(loginMenuItem)
        menu.addItem(hideMenuItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        refresh()
    }

    @objc private func quitApplication() { quit() }

    func showIcon() {
        statusItem.isVisible = true
        hideMenuItem.state = .off
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
        onOpen?()
    }

    private func refresh() {
        let state = loginItem.status
        loginMenuItem.title = state == .requiresApproval ? "Open at Login (Pending Approval)" : "Open at Login"
        loginMenuItem.state = state == .enabled ? .on : .off
        hideMenuItem.state = statusItem.isVisible ? .off : .on
    }

    @objc private func toggleIcon() {
        statusItem.isVisible.toggle()
        hideMenuItem.state = statusItem.isVisible ? .off : .on
    }

    @objc private func toggleLogin() {
        if loginItem.status == .requiresApproval {
            loginItem.openSettings()
            return
        }
        do {
            if loginItem.status == .enabled {
                try loginItem.unregister()
            } else {
                try loginItem.register()
            }
        } catch {
            showError("Couldn’t Change Open at Login", error.localizedDescription)
        }
        refresh()
    }
}
