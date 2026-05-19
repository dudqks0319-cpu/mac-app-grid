import SwiftUI

struct PagedAppGrid: View {
    let title: String?
    let apps: [AppItem]
    let selectedAppID: String?
    @Binding var draggingAppID: String?
    @Binding var pageIndex: Int
    let columnsPerPage: Int
    let pageSize: Int
    let gridSpacing: CGFloat
    let moveApp: (String, String?) -> Void
    let createFolder: (String, String) -> Void
    @EnvironmentObject private var settings: SettingsStore

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
                    LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
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
                                    draggingID: $draggingAppID,
                                    moveApp: moveApp,
                                    createFolder: createFolder,
                                    createsFolderOnDrop: settings.config.dragAppOntoAppCreatesFolder
                                )
                            )
                        }
                    }
                    .padding(.vertical, 4)

                    if pages.count > 1 {
                        HStack(spacing: 8) {
                            Button {
                                pageIndex = max(0, pageIndex - 1)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .help("이전 페이지")
                            .disabled(pageIndex == 0)

                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill(index == safePageIndex ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.35))
                                    .frame(width: 7, height: 7)
                                    .onTapGesture {
                                        pageIndex = index
                                    }
                            }

                            Button {
                                pageIndex = min(pages.count - 1, pageIndex + 1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .help("다음 페이지")
                            .disabled(pageIndex >= pages.count - 1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(minHeight: 420)
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
        Array(repeating: GridItem(.fixed(settings.config.iconSize.cellWidth), spacing: gridSpacing), count: columnsPerPage)
    }

    private var safePageIndex: Int {
        guard !pages.isEmpty else { return 0 }
        return min(max(pageIndex, 0), pages.count - 1)
    }

    private var currentPageApps: [AppItem] {
        pages[safePageIndex]
    }
}
