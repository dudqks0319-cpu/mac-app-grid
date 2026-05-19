import SwiftUI

struct AppSection: View {
    let title: String
    let apps: [AppItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(min(apps.count, 8))")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(apps.prefix(8))) { app in
                        CompactAppButton(app: app)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 78)
        }
        .frame(height: 108, alignment: .topLeading)
    }
}

private struct CompactAppButton: View {
    let app: AppItem

    var body: some View {
        Button {
            launch(app: app)
        } label: {
            VStack(spacing: 5) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                Text(app.name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 74)
            }
            .frame(width: 78, height: 74)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(app.name)
    }
}
