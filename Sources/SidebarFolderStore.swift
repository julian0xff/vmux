import Combine
import Foundation

@MainActor
final class SidebarFolderStore: ObservableObject {
    static let persistenceKey = "sidebarFolderTree"

    @Published var root: [SidebarItem] = []

    @Published private(set) var flatVisibleItems: [SidebarFlatItem] = []
    @Published private(set) var visibleWorkspaceIds: [UUID] = []
    @Published private(set) var allWorkspaceIdsInTreeOrder: [UUID] = []

    init() {}

    // MARK: - Reconciliation

    /// Sync the folder tree with the current set of workspace IDs.
    /// Adds orphaned workspaces to root, removes stale references.
    func reconcile(with tabIds: Set<UUID>) {
        let treeIds = Set(SidebarTreeUtils.allWorkspaceIds(in: root))

        // Remove stale workspace references
        let staleIds = treeIds.subtracting(tabIds)
        for staleId in staleIds {
            SidebarTreeUtils.removeWorkspace(staleId, from: &root)
        }

        // Add orphaned workspaces (in tabs but not in tree) to root
        let orphanedIds = tabIds.subtracting(treeIds)
        if !orphanedIds.isEmpty {
            // Maintain stable ordering: append in the order they appear in the caller's set
            // Since Set has no order, sort by UUID string for determinism
            let sorted = orphanedIds.sorted { $0.uuidString < $1.uuidString }
            for id in sorted {
                root.append(.workspace(id: id))
            }
        }

        recomputeDerivedState()
    }

    /// Reconcile with ordered tab IDs, preserving their relative order for orphans.
    func reconcile(withOrderedTabIds tabIds: [UUID]) {
        let tabIdSet = Set(tabIds)
        let treeIds = Set(SidebarTreeUtils.allWorkspaceIds(in: root))

        // Remove stale workspace references
        let staleIds = treeIds.subtracting(tabIdSet)
        for staleId in staleIds {
            SidebarTreeUtils.removeWorkspace(staleId, from: &root)
        }

        // Add orphaned workspaces in their tab order
        for id in tabIds where !treeIds.contains(id) {
            root.append(.workspace(id: id))
        }

        recomputeDerivedState()
    }

    // MARK: - Folder CRUD

    @discardableResult
    func createFolder(name: String, containingItemIds: [UUID] = [], atIndex: Int? = nil) -> UUID {
        let insertion = resolvedFolderInsertion(containingItemIds: containingItemIds, atIndex: atIndex)

        // Remove items from their current positions and collect them
        var children: [SidebarItem] = []
        for id in containingItemIds {
            if let removed = SidebarTreeUtils.removeItem(id, from: &root) {
                children.append(removed)
            }
        }

        let folder = SidebarFolder(name: name, children: children)
        let inserted = SidebarTreeUtils.insertItem(
            .folder(folder),
            intoFolder: insertion.parentFolderId,
            atIndex: insertion.index,
            in: &root
        )
        if !inserted {
            let clamped = max(0, min(insertion.index, root.count))
            root.insert(.folder(folder), at: clamped)
        }

        recomputeDerivedState()
        return folder.id
    }

    func renameFolder(id: UUID, name: String) {
        SidebarTreeUtils.renameFolder(folderId: id, name: name, in: &root)
        recomputeDerivedState()
    }

    func deleteFolder(id: UUID) {
        SidebarTreeUtils.deleteFolder(folderId: id, in: &root)
        recomputeDerivedState()
    }

    func toggleCollapse(folderId: UUID) {
        SidebarTreeUtils.toggleCollapse(folderId: folderId, in: &root)
        recomputeDerivedState()
    }

    // MARK: - Tree Mutation

    /// Move an item (workspace or folder) to a new position.
    func moveItem(_ itemId: UUID, toParent parentFolderId: UUID?, atIndex index: Int) {
        // Prevent dropping a folder into itself or its descendants
        if let parentFolderId, SidebarTreeUtils.isDescendant(parentFolderId, of: itemId, in: root) {
            return
        }
        if itemId == parentFolderId { return }

        guard let removed = SidebarTreeUtils.removeItem(itemId, from: &root) else { return }
        SidebarTreeUtils.insertItem(removed, intoFolder: parentFolderId, atIndex: index, in: &root)
        recomputeDerivedState()
    }

    func removeWorkspace(_ workspaceId: UUID) {
        SidebarTreeUtils.removeWorkspace(workspaceId, from: &root)
        recomputeDerivedState()
    }

    func insertWorkspaceAtEnd(_ workspaceId: UUID) {
        root.append(.workspace(id: workspaceId))
        recomputeDerivedState()
    }

    func insertWorkspaceAtRoot(_ workspaceId: UUID, atIndex index: Int) {
        let clamped = max(0, min(index, root.count))
        root.insert(.workspace(id: workspaceId), at: clamped)
        recomputeDerivedState()
    }

    func insertWorkspace(_ workspaceId: UUID, afterWorkspace afterId: UUID) {
        // Find the position of afterId and insert after it
        if insertWorkspaceAfter(workspaceId, afterId: afterId, in: &root) {
            recomputeDerivedState()
        } else {
            insertWorkspaceAtEnd(workspaceId)
        }
    }

    private func insertWorkspaceAfter(_ workspaceId: UUID, afterId: UUID, in items: inout [SidebarItem]) -> Bool {
        for i in items.indices {
            if items[i].id == afterId {
                items.insert(.workspace(id: workspaceId), at: min(i + 1, items.count))
                return true
            }
            if case .folder(var folder) = items[i] {
                if insertWorkspaceAfter(workspaceId, afterId: afterId, in: &folder.children) {
                    items[i] = .folder(folder)
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Query

    func folder(byId id: UUID) -> SidebarFolder? {
        SidebarTreeUtils.findFolder(id, in: root)
    }

    func parentFolderId(of itemId: UUID) -> UUID? {
        SidebarTreeUtils.parentFolderId(of: itemId, in: root)
    }

    func allFolders() -> [SidebarFolder] {
        SidebarTreeUtils.allFolders(in: root)
    }

    func hasFolders() -> Bool {
        root.contains { $0.isFolder }
    }

    func containsItemId(_ itemId: UUID) -> Bool {
        SidebarTreeUtils.allItemIds(in: root).contains(itemId)
    }

    func normalizedGroupingSelection(from itemIds: [UUID]) -> [UUID] {
        let selectedIds = Set(itemIds)
        let orderedIds = SidebarTreeUtils.allItemIds(in: root)

        return orderedIds.filter { itemId in
            guard selectedIds.contains(itemId) else { return false }
            return !hasSelectedAncestor(itemId, selectedIds: selectedIds)
        }
    }

    // MARK: - Persistence

    func save(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(root) else { return }
        defaults.set(data, forKey: Self.persistenceKey)
    }

    func load(defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: Self.persistenceKey),
              let decoded = try? JSONDecoder().decode([SidebarItem].self, from: data) else {
            return
        }
        root = decoded
        recomputeDerivedState()
    }

    // MARK: - Derived State

    private func recomputeDerivedState() {
        allWorkspaceIdsInTreeOrder = SidebarTreeUtils.allWorkspaceIds(in: root)
        visibleWorkspaceIds = SidebarTreeUtils.visibleWorkspaceIds(in: root)
        flatVisibleItems = SidebarTreeUtils.flattenVisible(root)
    }

    private func hasSelectedAncestor(_ itemId: UUID, selectedIds: Set<UUID>) -> Bool {
        var ancestorId = parentFolderId(of: itemId)
        while let currentAncestorId = ancestorId {
            if selectedIds.contains(currentAncestorId) {
                return true
            }
            ancestorId = parentFolderId(of: currentAncestorId)
        }
        return false
    }

    private struct FolderInsertionPoint {
        let parentFolderId: UUID?
        let index: Int
    }

    private func resolvedFolderInsertion(containingItemIds: [UUID], atIndex: Int?) -> FolderInsertionPoint {
        if let atIndex {
            return FolderInsertionPoint(parentFolderId: nil, index: atIndex)
        }
        guard !containingItemIds.isEmpty else {
            return FolderInsertionPoint(parentFolderId: nil, index: root.count)
        }
        return inferredFolderInsertion(containingItemIds: containingItemIds)
            ?? FolderInsertionPoint(parentFolderId: nil, index: root.count)
    }

    private func inferredFolderInsertion(containingItemIds: [UUID]) -> FolderInsertionPoint? {
        let locations = containingItemIds.compactMap { itemLocation(for: $0, in: root) }
        guard !locations.isEmpty else { return nil }

        let parentFolderIds = Set(locations.map(\.parentFolderId))
        if parentFolderIds.count == 1 {
            return FolderInsertionPoint(
                parentFolderId: locations[0].parentFolderId,
                index: locations.map(\.index).min() ?? 0
            )
        }

        let rootIndices = containingItemIds.compactMap { topLevelIndex(of: $0) }
        guard let rootIndex = rootIndices.min() else { return nil }
        return FolderInsertionPoint(parentFolderId: nil, index: rootIndex)
    }

    private func itemLocation(
        for itemId: UUID,
        in items: [SidebarItem],
        parentFolderId: UUID? = nil
    ) -> (parentFolderId: UUID?, index: Int)? {
        for (index, item) in items.enumerated() {
            if item.id == itemId {
                return (parentFolderId, index)
            }
            if case .folder(let folder) = item,
               let location = itemLocation(
                    for: itemId,
                    in: folder.children,
                    parentFolderId: folder.id
               ) {
                return location
            }
        }
        return nil
    }

    private func topLevelIndex(of itemId: UUID) -> Int? {
        for (index, item) in root.enumerated() {
            if item.id == itemId || contains(itemId, in: item) {
                return index
            }
        }
        return nil
    }

    private func contains(_ itemId: UUID, in item: SidebarItem) -> Bool {
        switch item {
        case .workspace(let id):
            return id == itemId
        case .folder(let folder):
            return folder.children.contains { child in
                child.id == itemId || contains(itemId, in: child)
            }
        }
    }
}
