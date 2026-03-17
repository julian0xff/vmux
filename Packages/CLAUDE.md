# Packages

Local Swift packages extracted from the monolithic app target. Dependency layers: VmuxCore (L0, shared types) → VmuxSession, VmuxSocket (L1) → VmuxTerminal, VmuxUpdate (L2). All packages are referenced as local SPM dependencies in GhosttyTabs.xcodeproj.
