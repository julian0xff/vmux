import Foundation

enum WorkspaceShortcutMapper {
    /// Maps Cmd+digit workspace shortcuts to a zero-based workspace index.
    /// Cmd+1...Cmd+8 target fixed indices; Cmd+9 always targets the last workspace.
    static func workspaceIndex(forCommandDigit digit: Int, workspaceCount: Int) -> Int? {
        guard workspaceCount > 0 else { return nil }
        guard (1...9).contains(digit) else { return nil }

        if digit == 9 {
            return workspaceCount - 1
        }

        let index = digit - 1
        return index < workspaceCount ? index : nil
    }

    /// Returns the primary Cmd+digit badge to display for a workspace row.
    /// Picks the lowest digit that maps to that row index.
    static func commandDigitForWorkspace(at index: Int, workspaceCount: Int) -> Int? {
        guard index >= 0 && index < workspaceCount else { return nil }
        for digit in 1...9 {
            if workspaceIndex(forCommandDigit: digit, workspaceCount: workspaceCount) == index {
                return digit
            }
        }
        return nil
    }
}
