// Nothing X Mac: control Nothing and CMF earbuds from the menu bar.
// A status item opens a popover with the SwiftUI panel; right-click shows the app menu.

import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static let appName = "Nothing X Mac"

    private let controller = EarbudsController()
    private let settings = AppSettings()
    private let navigation = PanelNavigation()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var lastClosedAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        LoginItem.enableOnFirstRun()

        let panel = PanelView()
            .environmentObject(controller)
            .environmentObject(settings)
            .environmentObject(navigation)
        let hosting = NSHostingController(rootView: panel)
        hosting.sizingOptions = .preferredContentSize // popover follows the panel's height
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.imagePosition = .imageLeading
            button.toolTip = Self.appName
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Keep the menu bar title and tooltip in sync with the buds.
        controller.$state.combineLatest(settings.$menuBarBattery)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, mode in self?.updateStatusItem(state: state, mode: mode) }
            .store(in: &cancellables)

        controller.start()

        // Dev convenience: NXM_OPEN=1 opens the panel on launch.
        if ProcessInfo.processInfo.environment["NXM_OPEN"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.showPopover() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Close the RFCOMM channel properly, or the buds refuse the next connection.
        controller.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    private func updateStatusItem(state: DeviceState, mode: MenuBarBattery) {
        guard let button = statusItem?.button else { return }
        let text = state.connected ? mode.text(for: state.battery) : nil
        button.title = text.map { " \($0)" } ?? ""
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        button.toolTip = state.connected ? "\(Self.appName) · \(state.name ?? "")" : Self.appName
    }

    // MARK: Popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(lastClosedAt) > 0.25 {
            // A click on the icon closes the transient popover first; don't reopen it.
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        controller.refreshBattery()
        navigation.page = .main
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosedAt = Date()
        navigation.page = .main
    }

    // MARK: Context menu

    private func showContextMenu() {
        let menu = NSMenu()

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        login.isEnabled = LoginItem.isSupported
        menu.addItem(login)

        let batteryItem = NSMenuItem(title: "Battery in Menu Bar", action: nil, keyEquivalent: "")
        let batteryMenu = NSMenu()
        for mode in MenuBarBattery.allCases {
            let item = NSMenuItem(title: mode.label, action: #selector(setMenuBarBattery(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settings.menuBarBattery == mode ? .on : .off
            batteryMenu.addItem(item)
        }
        batteryItem.submenu = batteryMenu
        menu.addItem(batteryItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(Self.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        // Attach temporarily so the menu drops down from the icon like a normal menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func setMenuBarBattery(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = MenuBarBattery(rawValue: raw) {
            settings.menuBarBattery = mode
        }
    }
}

#if DEBUG
MainActor.assumeIsolated { DebugSnapshots.runIfRequested() }
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
