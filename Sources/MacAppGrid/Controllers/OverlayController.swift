import SwiftUI
import AppKit
import Carbon

@MainActor
final class OverlayController: ObservableObject {
    let window: NSWindow
    private let contentController: NSHostingController<AnyView>
    @Published private(set) var isVisible: Bool = false
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

        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.contentView = contentController.view
        self.window = window
        installGestures(on: contentController.view)
        window.makeKeyAndOrderFront(nil)
        window.orderOut(nil)
    }

    func refresh() {
        appCatalog.reloadApps()
    }

    func show() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        window.setFrame(screenFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .overlaySelectionReset, object: nil)
        isVisible = true
    }

    func hide() {
        window.orderOut(nil)
        isVisible = false
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

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

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handleThreeFingerPan(_:)))
        pan.numberOfTouchesRequired = 3
        view.addGestureRecognizer(pan)
    }

    @objc private func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
        if recognizer.state == .ended {
            if recognizer.magnification < -0.2 {
                hide()
            }
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
