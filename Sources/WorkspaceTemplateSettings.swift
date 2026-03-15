import Foundation

// MARK: - Agent Definitions

struct AgentDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var command: String

    init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }
}

// MARK: - Template Layout

enum TemplateLayout: String, Codable, CaseIterable, Identifiable {
    case single
    case twoVertical
    case twoHorizontal
    case threeLeftWide
    case threeTopWide
    case fourGrid

    var id: String { rawValue }

    var paneCount: Int {
        switch self {
        case .single: return 1
        case .twoVertical, .twoHorizontal: return 2
        case .threeLeftWide, .threeTopWide: return 3
        case .fourGrid: return 4
        }
    }

    var displayName: String {
        switch self {
        case .single: return String(localized: "template.layout.single", defaultValue: "Single")
        case .twoVertical: return String(localized: "template.layout.twoVertical", defaultValue: "2 Side by Side")
        case .twoHorizontal: return String(localized: "template.layout.twoHorizontal", defaultValue: "2 Stacked")
        case .threeLeftWide: return String(localized: "template.layout.threeLeftWide", defaultValue: "1 + 2 Right")
        case .threeTopWide: return String(localized: "template.layout.threeTopWide", defaultValue: "1 + 2 Bottom")
        case .fourGrid: return String(localized: "template.layout.fourGrid", defaultValue: "2×2 Grid")
        }
    }
}

// MARK: - Process Assignment

struct ProcessAssignment: Codable, Identifiable, Equatable {
    let id: UUID
    var agentDefinitionId: UUID
    var count: Int

    init(id: UUID = UUID(), agentDefinitionId: UUID, count: Int = 0) {
        self.id = id
        self.agentDefinitionId = agentDefinitionId
        self.count = count
    }
}

// MARK: - Workspace Template

struct WorkspaceTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var workingDirectory: String?
    var layout: TemplateLayout
    var processAssignments: [ProcessAssignment]

    init(
        id: UUID = UUID(),
        name: String,
        workingDirectory: String? = nil,
        layout: TemplateLayout = .single,
        processAssignments: [ProcessAssignment] = []
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.layout = layout
        self.processAssignments = processAssignments
    }

    /// Total panes assigned to processes.
    var assignedPaneCount: Int {
        processAssignments.reduce(0) { $0 + $1.count }
    }

    /// Remaining panes that will be plain shells.
    var remainingPanes: Int {
        max(0, layout.paneCount - assignedPaneCount)
    }

    /// Expands process assignments into a flat list of agent IDs for each pane (in order).
    /// Remaining panes get nil (plain shell).
    func expandedPaneAgents() -> [UUID?] {
        var result: [UUID?] = []
        for assignment in processAssignments {
            for _ in 0..<assignment.count {
                result.append(assignment.agentDefinitionId)
            }
        }
        while result.count < layout.paneCount {
            result.append(nil)
        }
        return Array(result.prefix(layout.paneCount))
    }
}

// MARK: - Persistence

enum WorkspaceTemplateSettings {
    static let agentDefinitionsKey = "workspaceTemplate.agentDefinitions"
    static let templatesKey = "workspaceTemplate.templates"

    static let defaultAgentDefinitions: [AgentDefinition] = [
        AgentDefinition(name: "Claude Code", command: "claude"),
        AgentDefinition(name: "Codex", command: "codex"),
    ]

    static func normalizedAgentCommand(_ command: String) -> String {
        command
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func normalizedAgentCommandKey(_ command: String) -> String? {
        let normalized = normalizedAgentCommand(command)
        return normalized.isEmpty ? nil : normalized.lowercased()
    }

    static func sanitizedAgentDefinitions(_ defs: [AgentDefinition]) -> [AgentDefinition] {
        var seenKeys: Set<String> = []
        var sanitized: [AgentDefinition] = []

        for var definition in defs {
            guard let commandKey = normalizedAgentCommandKey(definition.command) else { continue }
            guard seenKeys.insert(commandKey).inserted else { continue }

            definition.command = normalizedAgentCommand(definition.command)
            let trimmedName = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty || trimmedName == "New Process" {
                definition.name = definition.command.components(separatedBy: .whitespaces).first ?? definition.command
            } else {
                definition.name = trimmedName
            }
            sanitized.append(definition)
        }

        return sanitized
    }

    // MARK: Agent Definitions

    static func agentDefinitions(defaults: UserDefaults = .standard) -> [AgentDefinition] {
        guard let data = defaults.data(forKey: agentDefinitionsKey) else {
            return defaultAgentDefinitions
        }

        guard let defs = try? JSONDecoder().decode([AgentDefinition].self, from: data) else {
            setAgentDefinitions(defaultAgentDefinitions, defaults: defaults)
            return defaultAgentDefinitions
        }

        let sanitized = sanitizedAgentDefinitions(defs)
        if sanitized != defs {
            setAgentDefinitions(sanitized, defaults: defaults)
        }
        return sanitized
    }

    static func setAgentDefinitions(_ defs: [AgentDefinition], defaults: UserDefaults = .standard) {
        let sanitized = sanitizedAgentDefinitions(defs)
        if let data = try? JSONEncoder().encode(sanitized) {
            defaults.set(data, forKey: agentDefinitionsKey)
        }
    }

    // MARK: Templates

    static func templates(defaults: UserDefaults = .standard) -> [WorkspaceTemplate] {
        guard let data = defaults.data(forKey: templatesKey),
              let templates = try? JSONDecoder().decode([WorkspaceTemplate].self, from: data) else {
            return []
        }
        return templates
    }

    static func setTemplates(_ templates: [WorkspaceTemplate], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(templates) {
            defaults.set(data, forKey: templatesKey)
        }
    }

    static func addTemplate(_ template: WorkspaceTemplate, defaults: UserDefaults = .standard) {
        var list = templates(defaults: defaults)
        list.append(template)
        setTemplates(list, defaults: defaults)
    }

    static func removeTemplate(id: UUID, defaults: UserDefaults = .standard) {
        var list = templates(defaults: defaults)
        list.removeAll { $0.id == id }
        setTemplates(list, defaults: defaults)
    }
}
