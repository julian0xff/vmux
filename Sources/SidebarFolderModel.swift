import Foundation

// MARK: - Sidebar Item Tree

/// A node in the sidebar folder tree. Either a workspace reference or a folder containing children.
indirect enum SidebarItem: Codable, Identifiable, Equatable, Sendable {
    case workspace(id: UUID)
    case folder(SidebarFolder)

    var id: UUID {
        switch self {
        case .workspace(let id): return id
        case .folder(let folder): return folder.id
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    var isWorkspace: Bool {
        if case .workspace = self { return true }
        return false
    }

    var folder: SidebarFolder? {
        if case .folder(let f) = self { return f }
        return nil
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "workspace":
            let id = try container.decode(UUID.self, forKey: .id)
            self = .workspace(id: id)
        case "folder":
            let folder = try container.decode(SidebarFolder.self, forKey: .folder)
            self = .folder(folder)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown sidebar item type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .workspace(let id):
            try container.encode("workspace", forKey: .type)
            try container.encode(id, forKey: .id)
        case .folder(let folder):
            try container.encode("folder", forKey: .type)
            try container.encode(folder, forKey: .folder)
        }
    }
}

// MARK: - Sidebar Folder

struct SidebarFolder: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var description: String?
    var isCollapsed: Bool
    var children: [SidebarItem]

    init(id: UUID = UUID(), name: String, description: String? = nil, isCollapsed: Bool = false, children: [SidebarItem] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.isCollapsed = isCollapsed
        self.children = children
    }
}

// MARK: - Flattened Sidebar Item (for rendering)

struct SidebarFlatItem: Identifiable {
    let id: UUID
    let depth: Int
    let content: SidebarFlatItemContent
}

enum SidebarFlatItemContent {
    case workspace(visualIndex: Int)
    case folderHeader(SidebarFolder)
}

// MARK: - Tree Utilities

enum SidebarTreeUtils {
    /// Collect all sidebar item UUIDs from the tree in depth-first order.
    static func allItemIds(in items: [SidebarItem]) -> [UUID] {
        var result: [UUID] = []
        collectItemIds(items, into: &result)
        return result
    }

    private static func collectItemIds(_ items: [SidebarItem], into result: inout [UUID]) {
        for item in items {
            result.append(item.id)
            if case .folder(let folder) = item {
                collectItemIds(folder.children, into: &result)
            }
        }
    }

    /// Collect all workspace UUIDs from the tree in depth-first order.
    static func allWorkspaceIds(in items: [SidebarItem]) -> [UUID] {
        var result: [UUID] = []
        collectWorkspaceIds(items, into: &result)
        return result
    }

    private static func collectWorkspaceIds(_ items: [SidebarItem], into result: inout [UUID]) {
        for item in items {
            switch item {
            case .workspace(let id):
                result.append(id)
            case .folder(let folder):
                collectWorkspaceIds(folder.children, into: &result)
            }
        }
    }

    /// Collect visible workspace UUIDs (skipping collapsed folder children).
    static func visibleWorkspaceIds(in items: [SidebarItem]) -> [UUID] {
        var result: [UUID] = []
        collectVisibleWorkspaceIds(items, into: &result)
        return result
    }

    private static func collectVisibleWorkspaceIds(_ items: [SidebarItem], into result: inout [UUID]) {
        for item in items {
            switch item {
            case .workspace(let id):
                result.append(id)
            case .folder(let folder):
                if !folder.isCollapsed {
                    collectVisibleWorkspaceIds(folder.children, into: &result)
                }
            }
        }
    }

    /// Flatten the tree into a list of `SidebarFlatItem` for rendering (respects collapse state).
    static func flattenVisible(_ items: [SidebarItem], depth: Int = 0) -> [SidebarFlatItem] {
        var result: [SidebarFlatItem] = []
        var visualIndex = 0
        flattenVisibleImpl(items, depth: depth, result: &result, visualIndex: &visualIndex)
        return result
    }

    private static func flattenVisibleImpl(
        _ items: [SidebarItem],
        depth: Int,
        result: inout [SidebarFlatItem],
        visualIndex: inout Int
    ) {
        for item in items {
            switch item {
            case .workspace(let id):
                result.append(SidebarFlatItem(id: id, depth: depth, content: .workspace(visualIndex: visualIndex)))
                visualIndex += 1
            case .folder(let folder):
                result.append(SidebarFlatItem(id: folder.id, depth: depth, content: .folderHeader(folder)))
                if !folder.isCollapsed {
                    flattenVisibleImpl(folder.children, depth: depth + 1, result: &result, visualIndex: &visualIndex)
                }
            }
        }
    }

    /// Remove a workspace from the tree by ID. Returns true if found and removed.
    @discardableResult
    static func removeWorkspace(_ workspaceId: UUID, from items: inout [SidebarItem]) -> Bool {
        for i in items.indices.reversed() {
            switch items[i] {
            case .workspace(let id):
                if id == workspaceId {
                    items.remove(at: i)
                    return true
                }
            case .folder(var folder):
                if removeWorkspace(workspaceId, from: &folder.children) {
                    items[i] = .folder(folder)
                    return true
                }
            }
        }
        return false
    }

    /// Remove an item (workspace or folder) from the tree by ID. Returns the removed item.
    static func removeItem(_ itemId: UUID, from items: inout [SidebarItem]) -> SidebarItem? {
        for i in items.indices.reversed() {
            if items[i].id == itemId {
                return items.remove(at: i)
            }
            if case .folder(var folder) = items[i] {
                if let removed = removeItem(itemId, from: &folder.children) {
                    items[i] = .folder(folder)
                    return removed
                }
            }
        }
        return nil
    }

    /// Find the parent folder ID for a given item ID. Returns nil if at root.
    static func parentFolderId(of itemId: UUID, in items: [SidebarItem]) -> UUID? {
        for item in items {
            if case .folder(let folder) = item {
                for child in folder.children {
                    if child.id == itemId { return folder.id }
                }
                if let result = parentFolderId(of: itemId, in: folder.children) {
                    return result
                }
            }
        }
        return nil
    }

    /// Find a folder by ID in the tree.
    static func findFolder(_ folderId: UUID, in items: [SidebarItem]) -> SidebarFolder? {
        for item in items {
            if case .folder(let folder) = item {
                if folder.id == folderId { return folder }
                if let found = findFolder(folderId, in: folder.children) {
                    return found
                }
            }
        }
        return nil
    }

    /// Insert an item into a specific folder at a given index. If parentFolderId is nil, inserts at root.
    @discardableResult
    static func insertItem(
        _ item: SidebarItem,
        intoFolder parentFolderId: UUID?,
        atIndex index: Int,
        in items: inout [SidebarItem]
    ) -> Bool {
        if parentFolderId == nil {
            let clamped = max(0, min(index, items.count))
            items.insert(item, at: clamped)
            return true
        }
        for i in items.indices {
            if case .folder(var folder) = items[i], folder.id == parentFolderId {
                let clamped = max(0, min(index, folder.children.count))
                folder.children.insert(item, at: clamped)
                items[i] = .folder(folder)
                return true
            }
            if case .folder(var folder) = items[i] {
                if insertItem(item, intoFolder: parentFolderId, atIndex: index, in: &folder.children) {
                    items[i] = .folder(folder)
                    return true
                }
            }
        }
        return false
    }

    /// Toggle collapse state of a folder by ID.
    static func toggleCollapse(folderId: UUID, in items: inout [SidebarItem]) {
        for i in items.indices {
            if case .folder(var folder) = items[i] {
                if folder.id == folderId {
                    folder.isCollapsed.toggle()
                    items[i] = .folder(folder)
                    return
                }
                toggleCollapse(folderId: folderId, in: &folder.children)
                items[i] = .folder(folder)
            }
        }
    }

    /// Rename a folder by ID.
    static func renameFolder(folderId: UUID, name: String, in items: inout [SidebarItem]) {
        for i in items.indices {
            if case .folder(var folder) = items[i] {
                if folder.id == folderId {
                    folder.name = name
                    items[i] = .folder(folder)
                    return
                }
                renameFolder(folderId: folderId, name: name, in: &folder.children)
                items[i] = .folder(folder)
            }
        }
    }

    /// Delete a folder, promoting its children to the parent level.
    static func deleteFolder(folderId: UUID, in items: inout [SidebarItem]) {
        for i in items.indices {
            if case .folder(let folder) = items[i], folder.id == folderId {
                items.replaceSubrange(i...i, with: folder.children)
                return
            }
            if case .folder(var folder) = items[i] {
                deleteFolder(folderId: folderId, in: &folder.children)
                items[i] = .folder(folder)
            }
        }
    }

    /// Check if an item is a descendant of a folder (prevents drag cycles).
    static func isDescendant(_ itemId: UUID, of folderId: UUID, in items: [SidebarItem]) -> Bool {
        guard let folder = findFolder(folderId, in: items) else { return false }
        return containsItem(itemId, in: folder.children)
    }

    private static func containsItem(_ itemId: UUID, in items: [SidebarItem]) -> Bool {
        for item in items {
            if item.id == itemId { return true }
            if case .folder(let folder) = item {
                if containsItem(itemId, in: folder.children) { return true }
            }
        }
        return false
    }

    /// Collect all folder IDs from the tree.
    static func allFolders(in items: [SidebarItem]) -> [SidebarFolder] {
        var result: [SidebarFolder] = []
        collectFolders(items, into: &result)
        return result
    }

    private static func collectFolders(_ items: [SidebarItem], into result: inout [SidebarFolder]) {
        for item in items {
            if case .folder(let folder) = item {
                result.append(folder)
                collectFolders(folder.children, into: &result)
            }
        }
    }
}
