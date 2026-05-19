import Foundation

struct Folder: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var appIDs: [String]
}

