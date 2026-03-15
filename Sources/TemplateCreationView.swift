import SwiftUI
import AppKit

// MARK: - Window Controller

final class TemplateCreationWindowController: NSWindowController, NSWindowDelegate {
    private var onCreateWorkspace: ((WorkspaceTemplate) -> Void)?

    init(onCreateWorkspace: @escaping (WorkspaceTemplate) -> Void) {
        self.onCreateWorkspace = onCreateWorkspace
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "templateCreation.windowTitle", defaultValue: "New Workspace from Template")
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("cmux.templateCreation")
        window.minSize = NSSize(width: 480, height: 500)
        window.center()

        super.init(window: window)
        window.delegate = self

        let view = TemplateCreationView(
            onCreate: { [weak self] template in
                self?.onCreateWorkspace?(template)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        window.contentView = NSHostingView(rootView: view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        onCreateWorkspace = nil
    }
}

// MARK: - Template Creation View

private struct TemplateCreationView: View {
    let onCreate: (WorkspaceTemplate) -> Void
    let onCancel: () -> Void

    @State private var currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var shellInput = ""
    @State private var shellOutput = ""
    @State private var selectedLayout: TemplateLayout = .twoVertical
    @State private var agentDefinitions: [AgentDefinition] = []
    @State private var processAssignments: [ProcessAssignment] = []

    private var totalPanes: Int { selectedLayout.paneCount }
    private var assignedPanes: Int { processAssignments.reduce(0) { $0 + $1.count } }
    private var remainingPanes: Int { max(0, totalPanes - assignedPanes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Working Directory
                sectionHeader(String(localized: "templateCreation.directory", defaultValue: "Working Directory"))
                MiniShellView(
                    currentDirectory: $currentDirectory,
                    shellInput: $shellInput,
                    shellOutput: $shellOutput,
                    onBrowse: chooseDirectory
                )

                // Layout
                sectionHeader(String(localized: "templateCreation.layout", defaultValue: "Layout"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(TemplateLayout.allCases) { layout in
                        LayoutThumbnail(layout: layout, isSelected: selectedLayout == layout)
                            .onTapGesture {
                                selectedLayout = layout
                                clampProcessCounts()
                            }
                    }
                }

                // Processes
                sectionHeader(String(localized: "templateCreation.processes", defaultValue: "Processes"))
                Text(String(localized: "templateCreation.processesHint",
                    defaultValue: "\(assignedPanes) of \(totalPanes) panes assigned — \(remainingPanes) will be plain shell"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    // Table header
                    HStack(spacing: 8) {
                        Text(String(localized: "templateCreation.headerCommand", defaultValue: "Command"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(localized: "templateCreation.headerCount", defaultValue: "Count"))
                            .frame(width: 80, alignment: .center)
                        Spacer().frame(width: 24)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                    // Rows
                    ForEach(Array(processAssignments.enumerated()), id: \.element.id) { index, assignment in
                        if let agentIndex = agentDefinitions.firstIndex(where: { $0.id == assignment.agentDefinitionId }) {
                            ProcessRow(
                                command: $agentDefinitions[agentIndex].command,
                                count: assignment.count,
                                maxCount: assignment.count + remainingPanes,
                                onIncrement: {
                                    if assignedPanes < totalPanes {
                                        processAssignments[index].count += 1
                                    }
                                },
                                onDecrement: {
                                    if processAssignments[index].count > 0 {
                                        processAssignments[index].count -= 1
                                    }
                                },
                                onRemove: {
                                    if let agentIndex = agentDefinitions.firstIndex(where: { $0.id == assignment.agentDefinitionId }) {
                                        agentDefinitions.remove(at: agentIndex)
                                    }
                                    processAssignments.remove(at: index)
                                    saveAgents()
                                },
                                onSave: saveAgents
                            )
                        }
                    }

                    // Add row button
                    Button {
                        let newAgent = AgentDefinition(name: "", command: "")
                        agentDefinitions.append(newAgent)
                        processAssignments.append(ProcessAssignment(agentDefinitionId: newAgent.id, count: 0))
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text(String(localized: "templateCreation.addRow", defaultValue: "Add"))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        // Action Buttons pinned to bottom
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Button(String(localized: "templateCreation.cancel", defaultValue: "Cancel")) {
                        onCancel()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(String(localized: "templateCreation.create", defaultValue: "Create")) {
                        let normalizedState = normalizedAgentState()
                        agentDefinitions = normalizedState.definitions
                        processAssignments = normalizedState.assignments
                        WorkspaceTemplateSettings.setAgentDefinitions(normalizedState.definitions)
                        onCreate(buildTemplate(processAssignments: normalizedState.assignments))
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .frame(minWidth: 480, minHeight: 500)
        .onAppear {
            agentDefinitions = WorkspaceTemplateSettings.agentDefinitions()
            processAssignments = agentDefinitions.map { ProcessAssignment(agentDefinitionId: $0.id, count: 0) }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: currentDirectory)
        panel.prompt = String(localized: "templateCreation.chooseFolder", defaultValue: "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            currentDirectory = url.path
        }
    }

    private func clampProcessCounts() {
        var remaining = totalPanes
        for i in processAssignments.indices {
            processAssignments[i].count = min(processAssignments[i].count, remaining)
            remaining -= processAssignments[i].count
        }
    }

    private func saveAgents() {
        WorkspaceTemplateSettings.setAgentDefinitions(agentDefinitions)
    }

    private var derivedName: String {
        let last = (currentDirectory as NSString).lastPathComponent
        return last.isEmpty ? "Workspace" : last
    }

    private func normalizedAgentState() -> (definitions: [AgentDefinition], assignments: [ProcessAssignment]) {
        let countByAgentId = processAssignments.reduce(into: [UUID: Int]()) { partialResult, assignment in
            partialResult[assignment.agentDefinitionId, default: 0] += assignment.count
        }

        var seenKeys: [String: UUID] = [:]
        var definitions: [AgentDefinition] = []
        var mergedCountByAgentId: [UUID: Int] = [:]

        for definition in agentDefinitions {
            guard let commandKey = WorkspaceTemplateSettings.normalizedAgentCommandKey(definition.command) else { continue }

            if let existingId = seenKeys[commandKey] {
                mergedCountByAgentId[existingId, default: 0] += countByAgentId[definition.id] ?? 0
                continue
            }

            var normalized = definition
            normalized.command = WorkspaceTemplateSettings.normalizedAgentCommand(definition.command)
            let trimmedName = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty || trimmedName == "New Process" {
                normalized.name = normalized.command.components(separatedBy: .whitespaces).first ?? normalized.command
            } else {
                normalized.name = trimmedName
            }

            seenKeys[commandKey] = normalized.id
            definitions.append(normalized)
            mergedCountByAgentId[normalized.id, default: 0] += countByAgentId[definition.id] ?? 0
        }

        let assignments = definitions.map {
            ProcessAssignment(agentDefinitionId: $0.id, count: mergedCountByAgentId[$0.id] ?? 0)
        }

        return (definitions, assignments)
    }

    private func buildTemplate(processAssignments: [ProcessAssignment]? = nil) -> WorkspaceTemplate {
        WorkspaceTemplate(
            name: derivedName,
            workingDirectory: currentDirectory,
            layout: selectedLayout,
            processAssignments: (processAssignments ?? self.processAssignments).filter { $0.count > 0 }
        )
    }
}

// MARK: - Shell Text Field (intercepts Tab for completion)

private struct ShellTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onTab: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = TabInterceptingTextField()
        field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.onTab = onTab
        field.cell?.lineBreakMode = .byTruncatingTail
        // Focus automatically
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        (nsView as? TabInterceptingTextField)?.onTab = onTab
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: ShellTextField

        init(parent: ShellTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return true // eat Shift+Tab too
            }
            return false
        }
    }
}

private final class TabInterceptingTextField: NSTextField {
    var onTab: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab key
            onTab?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Mini Shell View

private struct MiniShellView: View {
    @Binding var currentDirectory: String
    @Binding var shellInput: String
    @Binding var shellOutput: String
    let onBrowse: () -> Void
    @State private var history: [String] = []

    private var shortDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if currentDirectory == home { return "~" }
        if currentDirectory.hasPrefix(home + "/") {
            return "~" + currentDirectory.dropFirst(home.count)
        }
        return currentDirectory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Output area
            if !history.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(history.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(line.hasPrefix("error:") ? Color.red : .primary)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    }
                    .frame(maxHeight: 100)
                    .onChange(of: history.count) { _ in
                        if let last = history.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            // Prompt + input
            HStack(spacing: 4) {
                Text(shortDirectory)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("❯")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.green)
                ShellTextField(
                    text: $shellInput,
                    onSubmit: executeCommand,
                    onTab: { tabComplete() }
                )
                Button(String(localized: "templateCreation.browse", defaultValue: "Browse…")) {
                    onBrowse()
                }
                .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private func tabComplete() {
        let input = shellInput.trimmingCharacters(in: .whitespaces)
        // Extract the path portion to complete
        let parts = input.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let pathPart: String
        let prefix: String
        if parts.count >= 2 {
            prefix = parts.dropLast().joined(separator: " ") + " "
            pathPart = parts.last!
        } else if parts.count == 1 && (input.first == "c" || input.first == "m" || input.first == "l" || input.first == "p") {
            // Could be typing a command name — don't complete
            let cmds = ["cd", "mkdir", "ls", "pwd"]
            if let match = cmds.first(where: { $0.hasPrefix(input) }), match != input {
                shellInput = match + " "
                return
            }
            prefix = input + " "
            pathPart = ""
            return
        } else {
            prefix = ""
            pathPart = input
        }

        guard !pathPart.isEmpty else { return }

        // Resolve the path relative to currentDirectory
        let expanded: String
        if pathPart.hasPrefix("~") {
            expanded = NSString(string: pathPart).expandingTildeInPath
        } else if pathPart.hasPrefix("/") {
            expanded = pathPart
        } else {
            expanded = (currentDirectory as NSString).appendingPathComponent(pathPart)
        }

        let dir = (expanded as NSString).deletingLastPathComponent
        let partial = (expanded as NSString).lastPathComponent

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        let matches = contents.filter { $0.lowercased().hasPrefix(partial.lowercased()) }.sorted()

        if matches.count == 1 {
            let match = matches[0]
            let fullPath = (dir as NSString).appendingPathComponent(match)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)

            // Reconstruct the input with the completed name
            let originalDir = (pathPart as NSString).deletingLastPathComponent
            let completed: String
            if originalDir.isEmpty || originalDir == "." {
                completed = match + (isDir.boolValue ? "/" : "")
            } else {
                completed = (originalDir as NSString).appendingPathComponent(match) + (isDir.boolValue ? "/" : "")
            }
            shellInput = prefix + completed
        } else if matches.count > 1 {
            var common = matches[0]
            for m in matches.dropFirst() {
                var endIdx = common.startIndex
                for (a, b) in zip(common, m) {
                    if a != b { break }
                    endIdx = common.index(after: endIdx)
                }
                common = String(common[..<endIdx])
            }
            if common.count > partial.count {
                let originalDir = (pathPart as NSString).deletingLastPathComponent
                let completed: String
                if originalDir.isEmpty || originalDir == "." {
                    completed = common
                } else {
                    completed = (originalDir as NSString).appendingPathComponent(common)
                }
                shellInput = prefix + completed
            }
            // Show matches in history
            history.append(matches.joined(separator: "  "))
        }
    }

    private func executeCommand() {
        let input = shellInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        shellInput = ""

        history.append("\(shortDirectory) ❯ \(input)")

        let parts = input.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let command = parts.first else { return }

        switch command {
        case "cd":
            let target = parts.dropFirst().joined(separator: " ")
            executeCd(target.isEmpty ? "~" : target)
        case "mkdir":
            let args = Array(parts.dropFirst())
            executeMkdir(args)
        case "ls":
            executeLs()
        case "pwd":
            history.append(currentDirectory)
        default:
            history.append("error: only cd, mkdir, ls, and pwd are allowed")
        }
    }

    private func executeCd(_ target: String) {
        let resolved: String
        if target == "~" || target == "" {
            resolved = FileManager.default.homeDirectoryForCurrentUser.path
        } else if target.hasPrefix("~") {
            resolved = NSString(string: target).expandingTildeInPath
        } else if target.hasPrefix("/") {
            resolved = target
        } else if target == ".." {
            resolved = (currentDirectory as NSString).deletingLastPathComponent
        } else if target.hasPrefix("../") {
            let parent = (currentDirectory as NSString).deletingLastPathComponent
            let rest = String(target.dropFirst(3))
            resolved = (parent as NSString).appendingPathComponent(rest)
        } else {
            resolved = (currentDirectory as NSString).appendingPathComponent(target)
        }

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue {
            // Resolve to the real on-disk path (correct casing + symlinks)
            let realPath = (resolved as NSString).resolvingSymlinksInPath
            currentDirectory = realPath
        } else {
            history.append("error: no such directory: \(target)")
        }
    }

    private func executeMkdir(_ args: [String]) {
        guard let name = args.last, !name.isEmpty else {
            history.append("error: mkdir requires a directory name")
            return
        }
        let createParents = args.contains("-p")
        let path: String
        if name.hasPrefix("/") {
            path = name
        } else if name.hasPrefix("~") {
            path = NSString(string: name).expandingTildeInPath
        } else {
            path = (currentDirectory as NSString).appendingPathComponent(name)
        }
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: createParents,
                attributes: nil
            )
            history.append("created: \(name)")
        } catch {
            history.append("error: \(error.localizedDescription)")
        }
    }

    private func executeLs() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: currentDirectory)
            let sorted = contents.sorted()
            if sorted.isEmpty {
                history.append("(empty)")
            } else {
                history.append(sorted.joined(separator: "  "))
            }
        } catch {
            history.append("error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Process Row

private struct ProcessRow: View {
    @Binding var command: String
    let count: Int
    let maxCount: Int
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "templateCreation.processCommand", defaultValue: "e.g. claude, codex"), text: $command)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 100)
                .onChange(of: command) { _ in onSave() }

            // Counter: - [N] +
            Button(action: onDecrement) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .disabled(count <= 0)

            Text("\(count)")
                .monospacedDigit()
                .frame(width: 24, alignment: .center)

            Button(action: onIncrement) {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .disabled(count >= maxCount)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Layout Thumbnail

private struct LayoutThumbnail: View {
    let layout: TemplateLayout
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            layoutShape
                .frame(width: 60, height: 44)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                )
            Text(layout.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var layoutShape: some View {
        let gap: CGFloat = 2
        let color = Color.primary.opacity(0.4)

        switch layout {
        case .single:
            RoundedRectangle(cornerRadius: 2).fill(color)
        case .twoVertical:
            HStack(spacing: gap) {
                RoundedRectangle(cornerRadius: 2).fill(color)
                RoundedRectangle(cornerRadius: 2).fill(color)
            }
        case .twoHorizontal:
            VStack(spacing: gap) {
                RoundedRectangle(cornerRadius: 2).fill(color)
                RoundedRectangle(cornerRadius: 2).fill(color)
            }
        case .threeLeftWide:
            HStack(spacing: gap) {
                RoundedRectangle(cornerRadius: 2).fill(color)
                VStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                }
            }
        case .threeTopWide:
            VStack(spacing: gap) {
                RoundedRectangle(cornerRadius: 2).fill(color)
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                }
            }
        case .fourGrid:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                }
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                }
            }
        }
    }
}
