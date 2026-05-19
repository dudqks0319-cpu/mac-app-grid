import AppKit

struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let bundleID: String
    let icon: NSImage
}
