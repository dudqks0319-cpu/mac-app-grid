import SwiftUI

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
