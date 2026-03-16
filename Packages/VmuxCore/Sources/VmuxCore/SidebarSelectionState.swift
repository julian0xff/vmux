import SwiftUI

@MainActor
public final class SidebarSelectionState: ObservableObject {
    @Published public var selection: SidebarSelection

    public init(selection: SidebarSelection = .tabs) {
        self.selection = selection
    }
}
