import SwiftUI
import AppKit
import Carbon

final class KeyableOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayController: ObservableObject {
    let window: NSWindow
    private let contentController: NSHostingController<AnyView>
    @Published private(set) var isVisible: Bool = false
    private var handledMagnifyGesture = false
    private let appCatalog = AppCatalog()
    private let usageStore = UsageStore.shared
    private let folderStore = FolderStore()
    private let layoutStore = LayoutStore()
    private let settingsStore = SettingsStore.shared

    init() {
        let view = AnyView(
            OverlayView()
                .environmentObject(appCatalog)
                .environmentObject(usageStore)
                .environmentObject(folderStore)
                .environmentObject(layoutStore)
                .environmentObject(settingsStore)
        )
        contentController = NSHostingController(rootView: view)

        let window = KeyableOverlayWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient, .ignoresCycle]
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.contentView = contentController.view
        self.window = window
        installGestures(on: contentController.view)
        window.makeKeyAndOrderFront(nil)
        window.orderOut(nil)
    }

    var isActuallyVisible: Bool {
        isVisible || window.isVisible || window.alphaValue > 0.01
    }

    func refresh() {
        appCatalog.reloadApps()
    }

    func show() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        window.contentView?.isHidden = false
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        NotificationCenter.default.post(name: .overlaySelectionReset, object: nil)
        isVisible = true
    }

    func hide() {
        guard isActuallyVisible else {
            isVisible = false
            return
        }
        isVisible = false
        window.resignKey()
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.contentView?.isHidden = true
        window.orderOut(nil)
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isActuallyVisible else { return false }

        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            NotificationCenter.default.post(name: .overlaySelectionMove, object: "left")
            return true
        case kVK_RightArrow:
            NotificationCenter.default.post(name: .overlaySelectionMove, object: "right")
            return true
        case kVK_UpArrow:
            NotificationCenter.default.post(name: .overlaySelectionMove, object: "up")
            return true
        case kVK_DownArrow:
            NotificationCenter.default.post(name: .overlaySelectionMove, object: "down")
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            NotificationCenter.default.post(name: .overlaySelectionActivate, object: nil)
            return true
        default:
            return false
        }
    }

    private func installGestures(on view: NSView) {
        let magnify = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        view.addGestureRecognizer(magnify)

        let twoFingerPan = NSPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.numberOfTouchesRequired = 2
        view.addGestureRecognizer(twoFingerPan)

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handleThreeFingerPan(_:)))
        pan.numberOfTouchesRequired = 3
        view.addGestureRecognizer(pan)
    }

    @objc private func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
        guard isActuallyVisible else { return }

        if recognizer.state == .began {
            handledMagnifyGesture = false
        }

        if !handledMagnifyGesture, recognizer.magnification > 0.18 {
            handledMagnifyGesture = true
            hide()
        }

        if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
            handledMagnifyGesture = false
        }
    }

    @objc private func handleTwoFingerPan(_ recognizer: NSPanGestureRecognizer) {
        guard isActuallyVisible, recognizer.state == .ended else { return }
        let translation = recognizer.translation(in: recognizer.view)
        guard abs(translation.x) > abs(translation.y), abs(translation.x) > 64 else { return }

        if translation.x < 0 {
            NotificationCenter.default.post(name: .overlayPageDelta, object: 1)
        } else {
            NotificationCenter.default.post(name: .overlayPageDelta, object: -1)
        }
    }

    @objc private func handleThreeFingerPan(_ recognizer: NSPanGestureRecognizer) {
        if recognizer.state == .ended {
            let translation = recognizer.translation(in: recognizer.view)
            if translation.x < -80 {
                NotificationCenter.default.post(name: .overlayPageDelta, object: 1)
            } else if translation.x > 80 {
                NotificationCenter.default.post(name: .overlayPageDelta, object: -1)
            } else if translation.y > 80 {
                NotificationCenter.default.post(name: .overlayScrollTarget, object: "top")
            } else if translation.y < -80 {
                NotificationCenter.default.post(name: .overlayScrollTarget, object: "apps")
            }
        }
    }
}
