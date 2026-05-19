import SwiftUI

struct AppDropDelegate: DropDelegate {
    let targetID: String?
    @Binding var draggingID: String?
    let moveApp: (String, String?) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        moveApp(draggingID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
