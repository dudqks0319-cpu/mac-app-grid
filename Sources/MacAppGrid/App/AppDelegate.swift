import SwiftUI
import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindow: NSWindow?
    private var overlayController: OverlayController?
    private var hotKeyManager: HotKeyManager?
    private var launchpadStyleHotKeyManager: HotKeyManager?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var globalGestureMonitor: Any?
    private var localGestureMonitor: Any?
    private var lastGlobalGestureAt: TimeInterval = 0
    private let settings = SettingsStore.shared
    private var registeredHotKey = SettingsStore.shared.config.hotKey

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
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let globalGestureMonitor {
            NSEvent.removeMonitor(globalGestureMonitor)
        }
        if let localGestureMonitor {
            NSEvent.removeMonitor(localGestureMonitor)
        }
        hotKeyManager?.tearDown()
        launchpadStyleHotKeyManager?.tearDown()
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
        menu.addItem(NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusItemVisibility()
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

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == kVK_Escape else { return }
            Task { @MainActor in
                guard self?.overlayController?.isActuallyVisible == true else { return }
                self?.hideOverlay()
            }
        }

        localGestureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .swipe]) { [weak self] event in
            self?.handleGlobalGesture(event)
            return event
        }

        globalGestureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.magnify, .swipe]) { [weak self] event in
            Task { @MainActor in
                self?.handleGlobalGesture(event)
            }
        }
    }

    private func handleGlobalGesture(_ event: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastGlobalGestureAt > 0.55 else { return }

        switch event.type {
        case .magnify:
            if event.magnification < -0.35, overlayController?.isActuallyVisible != true {
                lastGlobalGestureAt = now
                showOverlay()
            } else if event.magnification > 0.35, overlayController?.isActuallyVisible == true {
                lastGlobalGestureAt = now
                hideOverlay()
            }
        case .swipe:
            guard overlayController?.isActuallyVisible == true else { return }
            if event.deltaX < -0.5 {
                lastGlobalGestureAt = now
                NotificationCenter.default.post(name: .overlayPageDelta, object: 1)
            } else if event.deltaX > 0.5 {
                lastGlobalGestureAt = now
                NotificationCenter.default.post(name: .overlayPageDelta, object: -1)
            }
        default:
            break
        }
    }

    private func setupHotKey() {
        registerHotKey()
        registerLaunchpadStyleHotKeyIfNeeded()
    }

    private func registerHotKey() {
        hotKeyManager?.tearDown()
        let hotKey = settings.config.hotKey
        hotKeyManager = HotKeyManager(modifierFlags: hotKey.modifierFlags, keyCode: hotKey.keyCode, hotKeyID: 1) { [weak self] in
            Task { @MainActor in
                self?.toggleOverlay()
            }
        }
        let status = hotKeyManager?.register() ?? OSStatus(eventHotKeyExistsErr)
        if status != noErr {
            NSLog("MacAppGrid hotkey registration failed: \(status)")
            settings.rejectHotKey(hotKey, fallback: registeredHotKey, status: status)
        } else {
            registeredHotKey = hotKey
            settings.reportHotKeyRegistrationSuccess()
        }
    }

    private func registerLaunchpadStyleHotKeyIfNeeded() {
        launchpadStyleHotKeyManager?.tearDown()
        launchpadStyleHotKeyManager = nil

        let legacyHotKey = HotKeyConfig.launchpadStyle
        guard settings.config.hotKey != legacyHotKey else { return }

        launchpadStyleHotKeyManager = HotKeyManager(
            modifierFlags: legacyHotKey.modifierFlags,
            keyCode: legacyHotKey.keyCode,
            hotKeyID: 2
        ) { [weak self] in
            Task { @MainActor in
                self?.toggleOverlay()
            }
        }

        let status = launchpadStyleHotKeyManager?.register() ?? OSStatus(eventHotKeyExistsErr)
        if status != noErr {
            NSLog("MacAppGrid Command+L hotkey registration failed: \(status)")
            launchpadStyleHotKeyManager?.tearDown()
            launchpadStyleHotKeyManager = nil
        }
    }

    private func setupWorkspaceObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOverlayHide),
            name: .overlayHide,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }

    @objc private func handleOverlayHide() {
        hideOverlay()
    }

    @objc private func handleSettingsChanged() {
        updateStatusItemVisibility()
        registerHotKey()
        registerLaunchpadStyleHotKeyIfNeeded()
    }

    @objc private func toggleOverlay() {
        guard let controller = overlayController else { return }
        if controller.isActuallyVisible {
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

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusItemVisibility() {
        guard let statusItem else { return }
        statusItem.isVisible = settings.config.showMenuBarIcon || !settings.isHotKeyRegistered
    }
}
