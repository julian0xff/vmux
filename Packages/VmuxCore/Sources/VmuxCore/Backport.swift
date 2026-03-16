import SwiftUI

// Centralized backports for newer SwiftUI APIs we want to use when available.
public struct Backport<Content> {
    public let content: Content

    public init(content: Content) {
        self.content = content
    }
}

extension View {
    public var backport: Backport<Self> { Backport(content: self) }

    @ViewBuilder
    public func safeHelp(_ text: String) -> some View {
        if text.isEmpty {
            self
        } else {
            self.help(text)
        }
    }
}

extension Scene {
    public var backport: Backport<Self> { Backport(content: self) }
}

/// Result type for backported onKeyPress handler
public enum BackportKeyPressResult {
    case handled
    case ignored
}

extension Backport where Content: View {
    public func pointerStyle(_ style: BackportPointerStyle?) -> some View {
        #if canImport(AppKit)
        if #available(macOS 15, *) {
            return content.pointerStyle(style?.official)
        } else {
            return content
        }
        #else
        return content
        #endif
    }

    /// Backported onKeyPress that works on macOS 14+ and is a no-op on macOS 13.
    public func onKeyPress(_ key: KeyEquivalent, action: @escaping (EventModifiers) -> BackportKeyPressResult) -> some View {
        #if canImport(AppKit)
        if #available(macOS 14, *) {
            return content.onKeyPress(key, phases: [.down, .repeat], action: { keyPress in
                switch action(keyPress.modifiers) {
                case .handled: return .handled
                case .ignored: return .ignored
                }
            })
        } else {
            return content
        }
        #else
        return content
        #endif
    }
}

public enum BackportPointerStyle {
    case `default`
    case grabIdle
    case grabActive
    case horizontalText
    case verticalText
    case link
    case resizeLeft
    case resizeRight
    case resizeUp
    case resizeDown
    case resizeUpDown
    case resizeLeftRight

    #if canImport(AppKit)
    @available(macOS 15, *)
    public var official: PointerStyle {
        switch self {
        case .default: return .default
        case .grabIdle: return .grabIdle
        case .grabActive: return .grabActive
        case .horizontalText: return .horizontalText
        case .verticalText: return .verticalText
        case .link: return .link
        case .resizeLeft: return .frameResize(position: .trailing, directions: [.inward])
        case .resizeRight: return .frameResize(position: .leading, directions: [.inward])
        case .resizeUp: return .frameResize(position: .bottom, directions: [.inward])
        case .resizeDown: return .frameResize(position: .top, directions: [.inward])
        case .resizeUpDown: return .frameResize(position: .top)
        case .resizeLeftRight: return .frameResize(position: .trailing)
        }
    }
    #endif
}
