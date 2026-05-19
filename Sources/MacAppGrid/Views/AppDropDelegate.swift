import SwiftUI

struct AppDropDelegate: DropDelegate {
    let targetID: String?
    @Binding var draggingID: String?
    let moveApp: (String, String?) -> Void
    let createFolder: (String, String) -> Void
    let createsFolderOnDrop: Bool

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        guard !createsFolderOnDrop else { return }
        moveApp(draggingID, targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        if createsFolderOnDrop, let draggingID, let targetID, draggingID != targetID {
            createFolder(draggingID, targetID)
        }
        draggingID = nil
        return true
    }
}
