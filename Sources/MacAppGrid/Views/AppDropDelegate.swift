import SwiftUI

struct AppDropDelegate: DropDelegate {
    let targetID: String?
    @Binding var draggingID: String?
    @EnvironmentObject private var layout: LayoutStore

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        layout.move(appID: draggingID, to: targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
