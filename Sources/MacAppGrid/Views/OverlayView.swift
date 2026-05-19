import SwiftUI
import AppKit

struct OverlayView: View {
    @EnvironmentObject private var catalog: AppCatalog
    @EnvironmentObject private var usage: UsageStore
    @EnvironmentObject private var folders: FolderStore
    @EnvironmentObject private var layout: LayoutStore
    @EnvironmentObject private var settings: SettingsStore
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

    private var visibleApps: [AppItem] {
        catalog.apps.filter { !settings.isHidden($0.bundleID) }
    }

    private var folderAppIDs: Set<String> {
        folders.appIDsInFolders()
    }

    private var appsForCurrentMode: [AppItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty, settings.config.hideFolderAppsInGrid else {
            return visibleApps
        }
        return visibleApps.filter { !folderAppIDs.contains($0.bundleID) }
    }

    private var filteredApps: [AppItem] {
        let ordered = layout.orderedApps(from: appsForCurrentMode)
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ordered
        }
        return ordered.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        overlaySheets(overlayAlert(overlayEvents(rootView)))
    }

    private var rootView: some View {
        ZStack {
            backgroundView

            VStack(spacing: 20) {
                searchBar
                    .padding(.top, 36)
                launcherContent
            }
        }
    }

    private func overlayEvents<Content: View>(_ content: Content) -> some View {
        content
        .onAppear {
            if catalog.apps.isEmpty {
                catalog.reloadApps()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySelectionReset)) { _ in
            searchText = ""
            focusedAppIndex = 0
            pageIndex = 0
            searchFocused = true
            if catalog.apps.isEmpty {
                catalog.reloadApps()
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .appRefreshRequested)) { _ in
            catalog.reloadApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: .layoutResetRequested)) { _ in
            layout.reset(with: visibleApps)
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
    }

    private func overlayAlert<Content: View>(_ content: Content) -> some View {
        content
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
    }

    private func overlaySheets<Content: View>(_ content: Content) -> some View {
        content
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
                    apps: visibleApps,
                    onRename: { name in
                        folders.renameFolder(folderID: folder.id, newName: name)
                    },
                    onRemove: { appID in
                        folders.removeApp(appID: appID, from: folder.id)
                    },
                    onMoveApp: { appID, targetID in
                        folders.moveApp(appID: appID, to: targetID, in: folder.id)
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

    private var backgroundView: some View {
        VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
            .ignoresSafeArea()
            .overlay(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .overlayHide, object: nil)
                    }
            )
    }

    private var searchBar: some View {
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
            if catalog.isScanning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var launcherContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                launcherSections
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

    private var launcherSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            Color.clear
                .frame(height: 1)
                .id("top")

            if !folders.folders.isEmpty {
                FolderGrid(
                    title: "폴더",
                    folders: folders.folders,
                    apps: visibleApps,
                    draggingAppID: $draggingAppID,
                    onSelect: { folderID in
                        selectedFolderID = folderID
                    },
                    onDropApp: { appID, folderID in
                        folders.addApp(appID: appID, to: folderID)
                    }
                )
            }
            if settings.config.showRecentApps {
                AppSection(title: "최근 앱", apps: usage.recentApps(from: visibleApps))
            }
            if settings.config.showFrequentApps {
                AppSection(title: "자주 쓰는 앱", apps: usage.frequentApps(from: visibleApps))
            }
            PagedAppGrid(
                title: "전체 앱",
                apps: filteredApps,
                selectedAppID: focusedApp?.bundleID,
                draggingAppID: $draggingAppID,
                pageIndex: $pageIndex,
                columnsPerPage: max(1, columnsPerRow),
                pageSize: pageSize,
                moveApp: { appID, targetID in
                    layout.move(appID: appID, to: targetID)
                },
                createFolder: { draggedAppID, targetAppID in
                    createFolderFromDrop(draggedAppID: draggedAppID, targetAppID: targetAppID)
                }
            )
            .id("apps")
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

    private func createFolderFromDrop(draggedAppID: String, targetAppID: String) {
        guard draggedAppID != targetAppID else { return }
        let appIDs = [targetAppID, draggedAppID]
        if let folderID = folders.createFolder(name: "새 폴더", initialAppIDs: appIDs) {
            selectedFolderID = folderID
        }
    }
}
