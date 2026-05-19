import SwiftUI

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
