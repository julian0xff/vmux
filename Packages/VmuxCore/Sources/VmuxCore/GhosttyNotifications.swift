import Foundation

/// Keys used in Ghostty notification userInfo dictionaries.
public enum GhosttyNotificationKey {
    public static let scrollbar = "ghostty.scrollbar"
    public static let cellSize = "ghostty.cellSize"
    public static let tabId = "ghostty.tabId"
    public static let surfaceId = "ghostty.surfaceId"
    public static let title = "ghostty.title"
    public static let backgroundColor = "ghostty.backgroundColor"
    public static let backgroundOpacity = "ghostty.backgroundOpacity"
    public static let backgroundEventId = "ghostty.backgroundEventId"
    public static let backgroundSource = "ghostty.backgroundSource"
}

public extension Notification.Name {
    static let ghosttyDidUpdateScrollbar = Notification.Name("ghosttyDidUpdateScrollbar")
    static let ghosttyDidUpdateCellSize = Notification.Name("ghosttyDidUpdateCellSize")
    static let ghosttySearchFocus = Notification.Name("ghosttySearchFocus")
    static let ghosttyConfigDidReload = Notification.Name("ghosttyConfigDidReload")
    static let ghosttyDefaultBackgroundDidChange = Notification.Name("ghosttyDefaultBackgroundDidChange")
    static let browserSearchFocus = Notification.Name("browserSearchFocus")
}
