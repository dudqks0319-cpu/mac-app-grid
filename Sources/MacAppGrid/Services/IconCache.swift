import AppKit

@MainActor
final class IconCache {
    static let shared = IconCache()

    private var icons: [String: NSImage] = [:]

    private init() {}

    func icon(forPath path: String) -> NSImage {
        if let icon = icons[path] {
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }
}
