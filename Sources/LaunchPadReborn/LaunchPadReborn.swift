import SwiftUI
import AppKit
import Carbon

extension Notification.Name {
    static let overlayHide = Notification.Name("LaunchPadReborn.overlayHide")
    static let folderCreateRequest = Notification.Name("LaunchPadReborn.folderCreateRequest")
    static let overlayPageDelta = Notification.Name("LaunchPadReborn.overlayPageDelta")
    static let overlayScrollTarget = Notification.Name("LaunchPadReborn.overlayScrollTarget")
    static let overlaySelectionMove = Notification.Name("LaunchPadReborn.overlaySelectionMove")
    static let overlaySelectionActivate = Notification.Name("LaunchPadReborn.overlaySelectionActivate")
    static let overlaySelectionReset = Notification.Name("LaunchPadReborn.overlaySelectionReset")
    static let appLaunchFailed = Notification.Name("LaunchPadReborn.appLaunchFailed")
}

@main
struct LaunchPadRebornApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

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
            button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "LaunchPadReborn")
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

final class HotKeyManager {
    private let modifierFlags: UInt32
    private let keyCode: UInt32
    private let handler: () -> Void
    private var eventHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(modifierFlags: UInt32, keyCode: UInt32, handler: @escaping () -> Void) {
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
        self.handler = handler
    }

    func register() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handler()
            return noErr
        }

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, userData, &eventHandlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C505242), id: 1)
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)
    }

    func tearDown() {
        if let eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

@MainActor
final class OverlayController: ObservableObject {
    let window: NSWindow
    private let contentController: NSHostingController<AnyView>
    @Published private(set) var isVisible: Bool = false
    private let appCatalog = AppCatalog()
    private let usageStore = UsageStore.shared
    private let folderStore = FolderStore()
    private let layoutStore = LayoutStore()

    init() {
        let view = AnyView(
            OverlayView()
                .environmentObject(appCatalog)
                .environmentObject(usageStore)
                .environmentObject(folderStore)
                .environmentObject(layoutStore)
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

struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let bundleID: String
    let icon: NSImage
}

struct Folder: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var appIDs: [String]
}

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var orderedIDs: [String] = []

    private let orderKey = "LaunchPadReborn.layoutOrder"

    init() {
        load()
    }

    func sync(with apps: [AppItem]) {
        let appIDs = Set(apps.map { $0.bundleID })
        var updated = orderedIDs.filter { appIDs.contains($0) }

        let existing = Set(updated)
        let newIDs = apps.map { $0.bundleID }.filter { !existing.contains($0) }
        updated.append(contentsOf: newIDs)

        if updated != orderedIDs {
            orderedIDs = updated
            save()
        }
    }

    func orderedApps(from apps: [AppItem]) -> [AppItem] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        return orderedIDs.compactMap { lookup[$0] }
    }

    func move(appID: String, to targetID: String?) {
        guard let fromIndex = orderedIDs.firstIndex(of: appID) else { return }
        var updated = orderedIDs
        updated.remove(at: fromIndex)

        if let targetID, let targetIndex = updated.firstIndex(of: targetID) {
            updated.insert(appID, at: targetIndex)
        } else {
            updated.append(appID)
        }

        orderedIDs = updated
        save()
    }

    private func load() {
        guard let array = UserDefaults.standard.array(forKey: orderKey) as? [String] else { return }
        orderedIDs = array
    }

    private func save() {
        UserDefaults.standard.set(orderedIDs, forKey: orderKey)
    }
}

@MainActor
final class FolderStore: ObservableObject {
    @Published private(set) var folders: [Folder] = []

    private let foldersKey = "LaunchPadReborn.folders"

    init() {
        load()
    }

    func createFolder(name: String, initialAppID: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var folder = Folder(id: UUID().uuidString, name: trimmed, appIDs: [])
        if let appID = initialAppID {
            folder.appIDs = [appID]
        }
        folders.append(folder)
        save()
    }

    func addApp(appID: String, to folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        if !folders[index].appIDs.contains(appID) {
            folders[index].appIDs.append(appID)
            save()
        }
    }

    func removeApp(appID: String, from folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].appIDs.removeAll { $0 == appID }
        save()
    }

    func deleteFolder(folderID: String) {
        folders.removeAll { $0.id == folderID }
        save()
    }

    func renameFolder(folderID: String, newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders[index].name = trimmed
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([Folder].self, from: data) {
            folders = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: foldersKey)
    }
}

@MainActor
final class AppCatalog: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var query: String = ""

    func reloadApps() {
        apps = AppCatalog.scanApplications()
    }

    private static func scanApplications() -> [AppItem] {
        let searchPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(NSHomeDirectory())/Applications"
        ]

        var found: [String: AppItem] = [:]
        let fileManager = FileManager.default

        for path in searchPaths {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.localizedNameKey], options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let item = appItem(from: fileURL) {
                        found[item.bundleID] = item
                    }
                }
            }
        }

        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func appItem(from url: URL) -> AppItem? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? url.path
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppItem(id: bundleID, name: name, path: url.path, bundleID: bundleID, icon: icon)
    }
}

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published private(set) var launchCounts: [String: Int] = [:]
    @Published private(set) var lastLaunch: [String: TimeInterval] = [:]

    private let countsKey = "LaunchPadReborn.launchCounts"
    private let lastKey = "LaunchPadReborn.lastLaunch"

    private init() {
        if let counts = UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] {
            launchCounts = counts
        }
        if let last = UserDefaults.standard.dictionary(forKey: lastKey) as? [String: TimeInterval] {
            lastLaunch = last
        }
    }

    func recordLaunch(bundleID: String) {
        launchCounts[bundleID, default: 0] += 1
        lastLaunch[bundleID] = Date().timeIntervalSince1970
        UserDefaults.standard.set(launchCounts, forKey: countsKey)
        UserDefaults.standard.set(lastLaunch, forKey: lastKey)
    }

    func recentApps(from apps: [AppItem], limit: Int = 12) -> [AppItem] {
        let sorted = apps
            .filter { (lastLaunch[$0.bundleID] ?? 0) > 0 }
            .sorted { (lastLaunch[$0.bundleID] ?? 0) > (lastLaunch[$1.bundleID] ?? 0) }
        return Array(sorted.prefix(limit))
    }

    func frequentApps(from apps: [AppItem], limit: Int = 12) -> [AppItem] {
        let sorted = apps
            .filter { (launchCounts[$0.bundleID] ?? 0) > 0 }
            .sorted { (launchCounts[$0.bundleID] ?? 0) > (launchCounts[$1.bundleID] ?? 0) }
        return Array(sorted.prefix(limit))
    }
}

struct OverlayView: View {
    @EnvironmentObject private var catalog: AppCatalog
    @EnvironmentObject private var usage: UsageStore
    @EnvironmentObject private var folders: FolderStore
    @EnvironmentObject private var layout: LayoutStore
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var pendingAppIDForFolder: String?
    @State private var selectedFolderID: String?
    @State private var draggingAppID: String?
    @State private var pageIndex: Int = 0
    @State private var focusedAppIndex: Int = 0
    @State private var scrollTarget: String?
    @State private var launchErrorMessage: String?

    private var columnsPerRow: Int {
        let width = NSScreen.main?.visibleFrame.width ?? NSScreen.main?.frame.width ?? 1200
        let reservedSpacing: CGFloat = 140
        let cellWidth: CGFloat = 88
        let spacing: CGFloat = 16
        return max(1, Int((width - reservedSpacing) / (cellWidth + spacing)))
    }

    private var pageSize: Int {
        max(1, columnsPerRow * 6)
    }

    private var focusedApp: AppItem? {
        guard filteredApps.indices.contains(focusedAppIndex) else { return nil }
        return filteredApps[focusedAppIndex]
    }

    private var filteredApps: [AppItem] {
        let ordered = layout.orderedApps(from: catalog.apps)
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ordered
        }
        return ordered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
                .overlay(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NotificationCenter.default.post(name: .overlayHide, object: nil)
                        }
                )

            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("앱 검색", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 520)
                        .focused($searchFocused)
                    Spacer()
                    Button("새 폴더") {
                        pendingAppIDForFolder = nil
                        newFolderName = ""
                        showingNewFolder = true
                    }
                }
                .padding(.top, 36)

                ScrollViewReader { proxy in
                    ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                            Color.clear
                                .frame(height: 1)
                                .id("top")

                            if !folders.folders.isEmpty {
                                FolderGrid(
                                    title: "폴더",
                                    folders: folders.folders,
                                    apps: catalog.apps,
                                    onSelect: { folderID in
                                        selectedFolderID = folderID
                                    }
                                )
                            }
                            AppSection(title: "최근 앱", apps: usage.recentApps(from: catalog.apps))
                            AppSection(title: "자주 쓰는 앱", apps: usage.frequentApps(from: catalog.apps))
                            PagedAppGrid(
                                title: "전체 앱",
                                apps: filteredApps,
                                selectedAppID: focusedApp?.bundleID,
                                draggingAppID: $draggingAppID,
                                pageIndex: $pageIndex,
                                columnsPerPage: max(1, columnsPerRow),
                                pageSize: pageSize
                            )
                            .id("apps")
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        scrollTarget = nil
                    }
                }
            }
        }
        .onAppear {
            catalog.reloadApps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySelectionReset)) { _ in
            searchText = ""
            focusedAppIndex = 0
            pageIndex = 0
            searchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySelectionMove)) { note in
            guard let direction = note.object as? String else { return }
            moveFocusedSelection(direction)
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySelectionActivate)) { _ in
            openFocusedApp()
        }
        .onReceive(catalog.$apps) { apps in
            layout.sync(with: apps)
        }
        .onChange(of: searchText) {
            focusedAppIndex = 0
            pageIndex = 0
        }
        .onChange(of: filteredApps) {
            guard !filteredApps.isEmpty else {
                focusedAppIndex = 0
                pageIndex = 0
                return
            }

            if focusedAppIndex >= filteredApps.count {
                focusedAppIndex = filteredApps.count - 1
            }
            pageIndex = max(0, min(pageIndex, (filteredApps.count - 1) / pageSize))
            pageIndex = focusedAppIndex / pageSize
        }
        .onReceive(NotificationCenter.default.publisher(for: .folderCreateRequest)) { note in
            if let appID = note.object as? String {
                pendingAppIDForFolder = appID
            } else {
                pendingAppIDForFolder = nil
            }
            newFolderName = ""
            showingNewFolder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayPageDelta)) { note in
            guard let delta = note.object as? Int else { return }
            pageIndex = max(0, pageIndex + delta)
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayScrollTarget)) { note in
            guard let target = note.object as? String else { return }
            scrollTarget = target
        }
        .onReceive(NotificationCenter.default.publisher(for: .appLaunchFailed)) { note in
            launchErrorMessage = note.object as? String ?? "앱을 실행할 수 없습니다."
        }
        .alert(
            "앱 실행 실패",
            isPresented: Binding(
                get: { launchErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        launchErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                launchErrorMessage = nil
            }
        } message: {
            Text(launchErrorMessage ?? "")
        }
        .sheet(isPresented: $showingNewFolder) {
            NewFolderSheet(
                name: $newFolderName,
                onCreate: { name in
                    folders.createFolder(name: name, initialAppID: pendingAppIDForFolder)
                    pendingAppIDForFolder = nil
                },
                onCancel: {
                    pendingAppIDForFolder = nil
                }
            )
        }
        .sheet(item: Binding<FolderSelection?>(
            get: {
                guard let id = selectedFolderID else { return nil }
                return FolderSelection(id: id)
            },
            set: { selection in
                selectedFolderID = selection?.id
            }
        )) { selection in
            if let folder = folders.folders.first(where: { $0.id == selection.id }) {
                FolderDetailView(
                    folder: folder,
                    apps: catalog.apps,
                    onRemove: { appID in
                        folders.removeApp(appID: appID, from: folder.id)
                    },
                    onDeleteFolder: {
                        folders.deleteFolder(folderID: folder.id)
                        selectedFolderID = nil
                    },
                    onClose: {
                        selectedFolderID = nil
                    }
                )
            } else {
                EmptyView()
                }
        }
    }

    private func moveFocusedSelection(_ direction: String) {
        guard !filteredApps.isEmpty else { return }
        let maxIndex = filteredApps.count - 1
        let columns = max(1, columnsPerRow)
        var nextIndex = focusedAppIndex

        switch direction {
        case "left":
            if nextIndex % columns > 0 {
                nextIndex -= 1
            }
        case "right":
            if nextIndex % columns < columns - 1 && nextIndex < maxIndex {
                nextIndex += 1
            }
        case "up":
            let candidate = nextIndex - columns
            if candidate >= 0 {
                nextIndex = candidate
            }
        case "down":
            let candidate = nextIndex + columns
            if candidate <= maxIndex {
                nextIndex = candidate
            }
        default:
            break
        }

        if nextIndex != focusedAppIndex {
            focusedAppIndex = nextIndex
            searchFocused = false
        }

        pageIndex = min(max(nextIndex / pageSize, 0), (maxIndex / pageSize))
    }

    private func openFocusedApp() {
        guard let app = focusedApp else { return }
        launch(app: app)
    }
}

struct AppSection: View {
    let title: String
    let apps: [AppItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            AppGrid(title: nil, apps: apps)
        }
    }
}

struct AppGrid: View {
    let title: String?
    let apps: [AppItem]

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(apps) { app in
                    AppIconCell(app: app)
                }
            }
        }
    }
}

struct PagedAppGrid: View {
    let title: String?
    let apps: [AppItem]
    let selectedAppID: String?
    @Binding var draggingAppID: String?
    @Binding var pageIndex: Int
    let columnsPerPage: Int
    let pageSize: Int

    private var pages: [[AppItem]] {
        guard !apps.isEmpty else { return [] }
        return stride(from: 0, to: apps.count, by: pageSize).map { start in
            Array(apps[start..<min(start + pageSize, apps.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            if pages.isEmpty {
                Text("표시할 앱이 없습니다.")
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(currentPageApps) { app in
                            AppIconCell(
                                app: app,
                                isSelected: app.bundleID == selectedAppID
                            )
                            .onDrag {
                                draggingAppID = app.bundleID
                                return NSItemProvider(object: app.bundleID as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: AppDropDelegate(
                                    targetID: app.bundleID,
                                    draggingID: $draggingAppID
                                )
                            )
                        }
                    }
                    .padding(.vertical, 4)

                    if pages.count > 1 {
                        HStack(spacing: 10) {
                            Button("이전") {
                                pageIndex = max(0, pageIndex - 1)
                            }
                            .disabled(pageIndex == 0)

                            Text("\(safePageIndex + 1) / \(pages.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("다음") {
                                pageIndex = min(pages.count - 1, pageIndex + 1)
                            }
                            .disabled(pageIndex >= pages.count - 1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(minHeight: 320)
            }
        }
        .onChange(of: pages.count) { _, newCount in
            guard newCount > 0 else {
                pageIndex = 0
                return
            }
            if pageIndex >= newCount {
                pageIndex = max(0, newCount - 1)
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(72), spacing: 16), count: columnsPerPage)
    }

    private var safePageIndex: Int {
        guard !pages.isEmpty else { return 0 }
        return min(max(pageIndex, 0), pages.count - 1)
    }

    private var currentPageApps: [AppItem] {
        pages[safePageIndex]
    }
}

enum AppMenuStyle: Equatable {
    case addToFolder
    case removeFromFolder((String) -> Void)
    case none

    static func == (lhs: AppMenuStyle, rhs: AppMenuStyle) -> Bool {
        switch (lhs, rhs) {
        case (.addToFolder, .addToFolder), (.none, .none):
            return true
        case (.removeFromFolder, .removeFromFolder):
            return false
        default:
            return false
        }
    }
}

struct AppIconCell: View {
    let app: AppItem
    var menuStyle: AppMenuStyle = .addToFolder
    var isSelected: Bool = false
    @EnvironmentObject private var folders: FolderStore

    var body: some View {
        let button = Button {
            launch(app: app)
        } label: {
            VStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                Text(app.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
            .frame(width: 76, height: 88)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.85) : .clear, lineWidth: isSelected ? 3 : 0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isSelected)

        return button.applyIf(menuStyle != .none) { view in
            view.contextMenu {
                switch menuStyle {
                case .addToFolder:
                    if !folders.folders.isEmpty {
                        Menu("폴더에 추가") {
                            ForEach(folders.folders) { folder in
                                Button(folder.name) {
                                    folders.addApp(appID: app.bundleID, to: folder.id)
                                }
                            }
                        }
                    }
                    Button("새 폴더에 추가…") {
                        NotificationCenter.default.post(name: .folderCreateRequest, object: app.bundleID)
                    }
                case .removeFromFolder(let onRemove):
                    Button("폴더에서 제거") {
                        onRemove(app.bundleID)
                    }
                case .none:
                    EmptyView()
                }
            }
        }
    }
}

@MainActor
func launch(app: AppItem) {
    let url = URL(fileURLWithPath: app.path)
    guard FileManager.default.fileExists(atPath: app.path) else {
        NotificationCenter.default.post(
            name: .appLaunchFailed,
            object: "\(app.name)을 찾을 수 없습니다. 앱 목록을 새로고침해 주세요."
        )
        return
    }

    let config = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
        Task { @MainActor in
            if let error {
                NotificationCenter.default.post(
                    name: .appLaunchFailed,
                    object: "\(app.name)을 실행하지 못했습니다. \(error.localizedDescription)"
                )
                return
            }

            UsageStore.shared.recordLaunch(bundleID: app.bundleID)
            NotificationCenter.default.post(name: .overlayHide, object: nil)
        }
    }
}

struct AppDropDelegate: DropDelegate {
    let targetID: String?
    @Binding var draggingID: String?
    @EnvironmentObject private var layout: LayoutStore

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        layout.move(appID: draggingID, to: targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}

struct FolderSelection: Identifiable {
    let id: String
}

struct FolderGrid: View {
    let title: String?
    let folders: [Folder]
    let apps: [AppItem]
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(folders) { folder in
                    FolderCell(folder: folder, apps: apps)
                        .onTapGesture {
                            onSelect(folder.id)
                        }
                }
            }
        }
    }
}

struct FolderCell: View {
    let folder: Folder
    let apps: [AppItem]

    private var folderApps: [AppItem] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        return folder.appIDs.compactMap { lookup[$0] }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 88, height: 88)

                let previewApps = Array(folderApps.prefix(4))
                if previewApps.isEmpty {
                    Image(systemName: "folder")
                        .font(.title)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            FolderIcon(app: previewApps.first)
                            FolderIcon(app: previewApps.dropFirst().first)
                        }
                        HStack(spacing: 4) {
                            FolderIcon(app: previewApps.dropFirst(2).first)
                            FolderIcon(app: previewApps.dropFirst(3).first)
                        }
                    }
                }
            }
            Text(folder.name)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 96)
        }
    }
}

struct FolderIcon: View {
    let app: AppItem?

    var body: some View {
        Group {
            if let app {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .frame(width: 32, height: 32)
    }
}

struct FolderDetailView: View {
    let folder: Folder
    let apps: [AppItem]
    let onRemove: (String) -> Void
    let onDeleteFolder: () -> Void
    let onClose: () -> Void

    private var folderApps: [AppItem] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        return folder.appIDs.compactMap { lookup[$0] }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(folder.name)
                    .font(.title2)
                    .bold()
                Spacer()
                Button("폴더 삭제") {
                    onDeleteFolder()
                }
                Button("닫기") {
                    onClose()
                }
            }

            if folderApps.isEmpty {
                Text("폴더에 앱이 없습니다.")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        ForEach(folderApps) { app in
                            AppIconCell(app: app, menuStyle: .removeFromFolder(onRemove))
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}

struct NewFolderSheet: View {
    @Binding var name: String
    let onCreate: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 폴더")
                .font(.title2)
                .bold()
            TextField("폴더 이름", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("취소") {
                    onCancel()
                    dismiss()
                }
                Button("생성") {
                    onCreate(name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}

extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
