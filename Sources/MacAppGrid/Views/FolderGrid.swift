import SwiftUI

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
