import SwiftUI

struct FolderGrid: View {
    let title: String?
    let folders: [Folder]
    let apps: [AppItem]
    @Binding var draggingAppID: String?
    let onSelect: (String) -> Void
    let onDropApp: (String, String) -> Void

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
                        .onDrop(of: [.text], isTargeted: nil) { _ in
                            guard let draggingAppID else { return false }
                            onDropApp(draggingAppID, folder.id)
                            self.draggingAppID = nil
                            return true
                        }
                }
            }
        }
    }
}
