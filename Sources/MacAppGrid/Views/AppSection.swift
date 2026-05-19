import SwiftUI

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
