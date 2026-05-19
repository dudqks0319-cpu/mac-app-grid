import SwiftUI

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
