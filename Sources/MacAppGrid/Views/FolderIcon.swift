import SwiftUI

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
