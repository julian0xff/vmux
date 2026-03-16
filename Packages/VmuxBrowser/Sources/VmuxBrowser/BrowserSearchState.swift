import AppKit

/// Observable state for browser find-in-page.
@MainActor
public final class BrowserSearchState: ObservableObject {
    @Published public var needle: String
    @Published public var selected: UInt?
    @Published public var total: UInt?

    public init(needle: String = "") {
        self.needle = needle
    }
}

public final class BrowserPortalAnchorView: NSView {
    override public var acceptsFirstResponder: Bool { false }
    override public var isOpaque: Bool { false }

    override public func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
