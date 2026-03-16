import Foundation
import VmuxCore

// MARK: - SocketWorkspaceProtocol

/// Protocol abstracting workspace properties accessed by socket commands.
/// Workspace conforms to this in the app target.
@MainActor
public protocol SocketWorkspaceProtocol: AnyObject, Identifiable where ID == UUID {
    var id: UUID { get }
    var title: String { get }
    var customTitle: String? { get }
    var isPinned: Bool { get set }
    var customColor: String? { get }
    var currentDirectory: String { get }
    var panels: [UUID: any Panel] { get }
    var focusedPanelId: UUID? { get }
}

// MARK: - SocketTabManagerProtocol

/// Protocol interface for socket commands to access TabManager.
/// Captures every TabManager method/property that TerminalController calls.
///
/// Design: Uses an associated type for the workspace so that concrete access
/// (e.g. `tabManager.tabs.first(where:)`) returns the concrete `Workspace` type.
/// When TerminalController moves to VmuxSocket, it will become generic over
/// `<TM: SocketTabManagerProtocol>` rather than using `any SocketTabManagerProtocol`.
@MainActor
public protocol SocketTabManagerProtocol: AnyObject {
    associatedtype SocketWorkspace: SocketWorkspaceProtocol

    // MARK: - Published state

    var tabs: [SocketWorkspace] { get }
    var selectedTabId: UUID? { get set }

    // MARK: - Workspace lifecycle

    @discardableResult
    func addWorkspace(
        workingDirectory: String?,
        select: Bool,
        eagerLoadTerminal: Bool
    ) -> SocketWorkspace

    @discardableResult
    func addWorkspace(select: Bool) -> SocketWorkspace

    @discardableResult
    func addTab(select: Bool, eagerLoadTerminal: Bool) -> SocketWorkspace

    func closeWorkspace(_ workspace: SocketWorkspace)
    func closeTab(_ tab: SocketWorkspace)

    // MARK: - Selection

    func selectWorkspace(_ workspace: SocketWorkspace)
    func selectTab(_ tab: SocketWorkspace)
    func selectTab(at index: Int)
    func selectNextTab()
    func selectPreviousTab()
    func navigateBack()

    // MARK: - Reorder

    @discardableResult
    func reorderWorkspace(tabId: UUID, toIndex targetIndex: Int) -> Bool

    @discardableResult
    func reorderWorkspace(tabId: UUID, before beforeId: UUID?, after afterId: UUID?) -> Bool

    func moveTabToTop(_ tabId: UUID)

    // MARK: - Metadata

    func setCustomTitle(tabId: UUID, title: String?)
    func clearCustomTitle(tabId: UUID)
    func setPinned(_ tab: SocketWorkspace, pinned: Bool)

    // MARK: - Surface / Panel management

    func focusSurface(tabId: UUID, surfaceId: UUID)
    func focusedSurfaceId(for tabId: UUID) -> UUID?

    @discardableResult
    func focusTabFromNotification(_ tabId: UUID, surfaceId: UUID?) -> Bool

    func newSplit(tabId: UUID, surfaceId: UUID, direction: SocketSplitDirection, focus: Bool) -> UUID?

    // MARK: - Surface telemetry

    func updateSurfaceDirectory(tabId: UUID, surfaceId: UUID, directory: String)
    func updateSurfaceShellActivity(tabId: UUID, surfaceId: UUID, state: SocketShellActivityState)
}

// MARK: - Socket-boundary value types

/// Shell activity state used across the socket protocol boundary.
/// Mirrors Workspace.PanelShellActivityState for protocol decoupling.
public enum SocketShellActivityState: String, Sendable {
    case unknown
    case promptIdle
    case commandRunning
}

/// Split direction used across the socket protocol boundary.
/// Mirrors SplitDirection from the app target.
public enum SocketSplitDirection: Sendable {
    case left, right, up, down
}
