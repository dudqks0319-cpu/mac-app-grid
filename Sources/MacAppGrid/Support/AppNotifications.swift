import Foundation

extension Notification.Name {
    static let overlayHide = Notification.Name("MacAppGrid.overlayHide")
    static let folderCreateRequest = Notification.Name("MacAppGrid.folderCreateRequest")
    static let overlayPageDelta = Notification.Name("MacAppGrid.overlayPageDelta")
    static let overlayScrollTarget = Notification.Name("MacAppGrid.overlayScrollTarget")
    static let overlaySelectionMove = Notification.Name("MacAppGrid.overlaySelectionMove")
    static let overlaySelectionActivate = Notification.Name("MacAppGrid.overlaySelectionActivate")
    static let overlaySelectionReset = Notification.Name("MacAppGrid.overlaySelectionReset")
    static let appLaunchFailed = Notification.Name("MacAppGrid.appLaunchFailed")
    static let appRefreshRequested = Notification.Name("MacAppGrid.appRefreshRequested")
    static let layoutResetRequested = Notification.Name("MacAppGrid.layoutResetRequested")
    static let settingsChanged = Notification.Name("MacAppGrid.settingsChanged")
}
