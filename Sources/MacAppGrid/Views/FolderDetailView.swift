import SwiftUI

struct FolderDetailView: View {
    let folder: Folder
    let apps: [AppItem]
    let onRename: (String) -> Void
    let onRemove: (String) -> Void
    let onMoveApp: (String, String?) -> Void
    let onDeleteFolder: () -> Void
    let onClose: () -> Void
    @State private var draftName = ""
    @State private var draggingAppID: String?

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
                TextField("폴더 이름", text: $draftName)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onRename(draftName)
                    }
                Button("이름 변경") {
                    onRename(draftName)
                }
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
                                .onDrag {
                                    draggingAppID = app.bundleID
                                    return NSItemProvider(object: app.bundleID as NSString)
                                }
                                .onDrop(
                                    of: [.text],
                                    delegate: FolderAppDropDelegate(
                                        folderID: folder.id,
                                        targetID: app.bundleID,
                                        draggingID: $draggingAppID,
                                        moveApp: onMoveApp
                                    )
                                )
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .onAppear {
            draftName = folder.name
        }
        .onChange(of: folder.name) { _, newName in
            draftName = newName
        }
    }
}

private struct FolderAppDropDelegate: DropDelegate {
    let folderID: String
    let targetID: String?
    @Binding var draggingID: String?
    let moveApp: (String, String?) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        moveApp(draggingID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
