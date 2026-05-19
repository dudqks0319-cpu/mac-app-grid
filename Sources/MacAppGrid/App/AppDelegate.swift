import SwiftUI
import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindow: NSWindow?
    private var overlayController: OverlayController?
    private var hotKeyManager: HotKeyManager?
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupOverlay()
        setupHotKey()
        setupWorkspaceObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        hotKeyManager?.tearDown()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "MacAppGrid")
            button.action = #selector(toggleOverlay)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "열기", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupOverlay() {
        let controller = OverlayController()
        overlayController = controller
        overlayWindow = controller.window

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == kVK_Escape {
                self?.hideOverlay()
                return nil
            }

            if self?.overlayController?.handleKeyDown(event) == true {
                return nil
            }
            return event
        }
    }

    private func setupHotKey() {
        hotKeyManager = HotKeyManager(modifierFlags: UInt32(optionKey), keyCode: UInt32(kVK_Space)) { [weak self] in
            Task { @MainActor in
                self?.toggleOverlay()
            }
        }
        hotKeyManager?.register()
    }

    private func setupWorkspaceObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOverlayHide),
            name: .overlayHide,
            object: nil
        )
    }

    @objc private func handleOverlayHide() {
        hideOverlay()
    }

    @objc private func toggleOverlay() {
        guard let controller = overlayController else { return }
        if controller.isVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard let controller = overlayController else { return }
        controller.refresh()
        controller.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideOverlay() {
        overlayController?.hide()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
