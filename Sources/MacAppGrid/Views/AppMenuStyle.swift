import Foundation

enum AppMenuStyle: Equatable {
    case addToFolder
    case removeFromFolder((String) -> Void)
    case none

    static func == (lhs: AppMenuStyle, rhs: AppMenuStyle) -> Bool {
        switch (lhs, rhs) {
        case (.addToFolder, .addToFolder), (.none, .none):
            return true
        case (.removeFromFolder, .removeFromFolder):
            return false
        default:
            return false
        }
    }
}
