import SwiftUI

struct AppGrid: View {
    let title: String?
    let apps: [AppItem]

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(apps) { app in
                    AppIconCell(app: app)
                }
            }
        }
    }
}
