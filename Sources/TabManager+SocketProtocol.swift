import Foundation
import VmuxSocket

extension TabManager: SocketTabManagerProtocol {
    typealias SocketWorkspace = Workspace

    // MARK: - Wrapper: addWorkspace (3-param variant)

    @discardableResult
    func addWorkspace(
        workingDirectory: String?,
        select: Bool,
        eagerLoadTerminal: Bool
    ) -> Workspace {
        addWorkspace(
            workingDirectory: workingDirectory,
            select: select,
            eagerLoadTerminal: eagerLoadTerminal,
            placementOverride: nil,
            autoWelcomeIfNeeded: true
        )
    }

    // MARK: - Wrapper: addWorkspace (select-only variant)

    @discardableResult
    func addWorkspace(select: Bool) -> Workspace {
        addWorkspace(
            workingDirectory: nil,
            select: select,
            eagerLoadTerminal: false,
            placementOverride: nil,
            autoWelcomeIfNeeded: true
        )
    }

    // MARK: - Wrapper: newSplit (SocketSplitDirection)

    func newSplit(
        tabId: UUID,
        surfaceId: UUID,
        direction: SocketSplitDirection,
        focus: Bool
    ) -> UUID? {
        newSplit(
            tabId: tabId,
            surfaceId: surfaceId,
            direction: SplitDirection(direction),
            focus: focus
        )
    }

    // MARK: - Wrapper: updateSurfaceShellActivity (SocketShellActivityState)

    func updateSurfaceShellActivity(
        tabId: UUID,
        surfaceId: UUID,
        state: SocketShellActivityState
    ) {
        updateSurfaceShellActivity(
            tabId: tabId,
            surfaceId: surfaceId,
            state: Workspace.PanelShellActivityState(state)
        )
    }
}

// MARK: - Type bridging

extension SplitDirection {
    init(_ socket: SocketSplitDirection) {
        switch socket {
        case .left: self = .left
        case .right: self = .right
        case .up: self = .up
        case .down: self = .down
        }
    }
}

extension SocketSplitDirection {
    init(_ split: SplitDirection) {
        switch split {
        case .left: self = .left
        case .right: self = .right
        case .up: self = .up
        case .down: self = .down
        }
    }
}

extension Workspace.PanelShellActivityState {
    init(_ socket: SocketShellActivityState) {
        switch socket {
        case .unknown: self = .unknown
        case .promptIdle: self = .promptIdle
        case .commandRunning: self = .commandRunning
        }
    }
}

extension SocketShellActivityState {
    init(_ state: Workspace.PanelShellActivityState) {
        switch state {
        case .unknown: self = .unknown
        case .promptIdle: self = .promptIdle
        case .commandRunning: self = .commandRunning
        }
    }
}
