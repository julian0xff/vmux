import AppKit
import SwiftUI

enum SidebarDragLifecycleNotification {
    static let stateDidChange = Notification.Name("vmux.sidebarDragStateDidChange")
    static let requestClear = Notification.Name("vmux.sidebarDragRequestClear")
    static let tabIdKey = "tabId"
    static let reasonKey = "reason"

    static func postStateDidChange(tabId: UUID?, reason: String) {
        var userInfo: [AnyHashable: Any] = [reasonKey: reason]
        if let tabId {
            userInfo[tabIdKey] = tabId
        }
        NotificationCenter.default.post(
            name: stateDidChange,
            object: nil,
            userInfo: userInfo
        )
    }

    static func postClearRequest(reason: String) {
        NotificationCenter.default.post(
            name: requestClear,
            object: nil,
            userInfo: [reasonKey: reason]
        )
    }

    static func tabId(from notification: Notification) -> UUID? {
        notification.userInfo?[tabIdKey] as? UUID
    }

    static func reason(from notification: Notification) -> String {
        notification.userInfo?[reasonKey] as? String ?? "unknown"
    }
}

enum SidebarOutsideDropResetPolicy {
    static func shouldResetDrag(draggedTabId: UUID?, hasSidebarDragPayload: Bool) -> Bool {
        draggedTabId != nil && hasSidebarDragPayload
    }
}

enum SidebarDragFailsafePolicy {
    static let pollInterval: TimeInterval = 0.05
    static let clearDelay: TimeInterval = 0.15

    static func shouldRequestClear(isDragActive: Bool, isLeftMouseButtonDown: Bool) -> Bool {
        isDragActive && !isLeftMouseButtonDown
    }
}

enum SidebarDropEdge {
    case top
    case bottom
}

struct SidebarDropIndicator {
    let tabId: UUID?
    let edge: SidebarDropEdge
    var isIntoFolder: Bool = false
}

enum SidebarDropPlanner {
    static func indicator(
        draggedTabId: UUID?,
        targetTabId: UUID?,
        tabIds: [UUID],
        pointerY: CGFloat? = nil,
        targetHeight: CGFloat? = nil
    ) -> SidebarDropIndicator? {
        guard tabIds.count > 1, let draggedTabId else { return nil }
        guard let fromIndex = tabIds.firstIndex(of: draggedTabId) else { return nil }

        let insertionPosition: Int
        if let targetTabId {
            guard let targetTabIndex = tabIds.firstIndex(of: targetTabId) else { return nil }
            let edge: SidebarDropEdge
            if let pointerY, let targetHeight {
                edge = edgeForPointer(locationY: pointerY, targetHeight: targetHeight)
            } else {
                edge = preferredEdge(fromIndex: fromIndex, targetTabId: targetTabId, tabIds: tabIds)
            }
            insertionPosition = (edge == .bottom) ? targetTabIndex + 1 : targetTabIndex
        } else {
            insertionPosition = tabIds.count
        }

        let targetIndex = resolvedTargetIndex(from: fromIndex, insertionPosition: insertionPosition, totalCount: tabIds.count)
        guard targetIndex != fromIndex else { return nil }
        return indicatorForInsertionPosition(insertionPosition, tabIds: tabIds)
    }

    static func targetIndex(
        draggedTabId: UUID,
        targetTabId: UUID?,
        indicator: SidebarDropIndicator?,
        tabIds: [UUID]
    ) -> Int? {
        guard let fromIndex = tabIds.firstIndex(of: draggedTabId) else { return nil }

        let insertionPosition: Int
        if let indicator, let indicatorInsertion = insertionPositionForIndicator(indicator, tabIds: tabIds) {
            insertionPosition = indicatorInsertion
        } else if let targetTabId {
            guard let targetTabIndex = tabIds.firstIndex(of: targetTabId) else { return nil }
            let edge = (indicator?.tabId == targetTabId)
                ? (indicator?.edge ?? preferredEdge(fromIndex: fromIndex, targetTabId: targetTabId, tabIds: tabIds))
                : preferredEdge(fromIndex: fromIndex, targetTabId: targetTabId, tabIds: tabIds)
            insertionPosition = (edge == .bottom) ? targetTabIndex + 1 : targetTabIndex
        } else {
            insertionPosition = tabIds.count
        }

        return resolvedTargetIndex(from: fromIndex, insertionPosition: insertionPosition, totalCount: tabIds.count)
    }

    private static func indicatorForInsertionPosition(_ insertionPosition: Int, tabIds: [UUID]) -> SidebarDropIndicator {
        let clampedInsertion = max(0, min(insertionPosition, tabIds.count))
        if clampedInsertion >= tabIds.count {
            return SidebarDropIndicator(tabId: nil, edge: .bottom)
        }
        return SidebarDropIndicator(tabId: tabIds[clampedInsertion], edge: .top)
    }

    private static func insertionPositionForIndicator(_ indicator: SidebarDropIndicator, tabIds: [UUID]) -> Int? {
        if let tabId = indicator.tabId {
            guard let targetTabIndex = tabIds.firstIndex(of: tabId) else { return nil }
            return indicator.edge == .bottom ? targetTabIndex + 1 : targetTabIndex
        }
        return tabIds.count
    }

    private static func preferredEdge(fromIndex: Int, targetTabId: UUID, tabIds: [UUID]) -> SidebarDropEdge {
        guard let targetIndex = tabIds.firstIndex(of: targetTabId) else { return .top }
        return fromIndex < targetIndex ? .bottom : .top
    }

    static func edgeForPointer(locationY: CGFloat, targetHeight: CGFloat) -> SidebarDropEdge {
        guard targetHeight > 0 else { return .top }
        let clampedY = min(max(locationY, 0), targetHeight)
        return clampedY < (targetHeight / 2) ? .top : .bottom
    }

    private static func resolvedTargetIndex(from sourceIndex: Int, insertionPosition: Int, totalCount: Int) -> Int {
        let clampedInsertion = max(0, min(insertionPosition, totalCount))
        let adjusted = clampedInsertion > sourceIndex ? clampedInsertion - 1 : clampedInsertion
        return max(0, min(adjusted, max(0, totalCount - 1)))
    }
}

enum SidebarAutoScrollDirection: Equatable {
    case up
    case down
}

struct SidebarAutoScrollPlan: Equatable {
    let direction: SidebarAutoScrollDirection
    let pointsPerTick: CGFloat
}

enum SidebarDragAutoScrollPlanner {
    static let edgeInset: CGFloat = 44
    static let minStep: CGFloat = 2
    static let maxStep: CGFloat = 12

    static func plan(
        distanceToTop: CGFloat,
        distanceToBottom: CGFloat,
        edgeInset: CGFloat = SidebarDragAutoScrollPlanner.edgeInset,
        minStep: CGFloat = SidebarDragAutoScrollPlanner.minStep,
        maxStep: CGFloat = SidebarDragAutoScrollPlanner.maxStep
    ) -> SidebarAutoScrollPlan? {
        guard edgeInset > 0, maxStep >= minStep else { return nil }
        if distanceToTop <= edgeInset {
            let normalized = max(0, min(1, (edgeInset - distanceToTop) / edgeInset))
            let step = minStep + ((maxStep - minStep) * normalized)
            return SidebarAutoScrollPlan(direction: .up, pointsPerTick: step)
        }
        if distanceToBottom <= edgeInset {
            let normalized = max(0, min(1, (edgeInset - distanceToBottom) / edgeInset))
            let step = minStep + ((maxStep - minStep) * normalized)
            return SidebarAutoScrollPlan(direction: .down, pointsPerTick: step)
        }
        return nil
    }
}

@MainActor
final class SidebarDragAutoScrollController: ObservableObject {
    private weak var scrollView: NSScrollView?
    private var timer: Timer?
    private var activePlan: SidebarAutoScrollPlan?

    func attach(scrollView: NSScrollView?) {
        self.scrollView = scrollView
    }

    func updateFromDragLocation() {
        guard let scrollView else {
            stop()
            return
        }
        guard let plan = plan(for: scrollView) else {
            stop()
            return
        }
        activePlan = plan
        startTimerIfNeeded()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        activePlan = nil
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .eventTracking)
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons != 0 else {
            stop()
            return
        }
        guard let scrollView else {
            stop()
            return
        }

        // AppKit drag/drop autoscroll guidance recommends autoscroll(with:)
        // when periodic drag updates are available; use it first.
        if applyNativeAutoscroll(to: scrollView) {
            activePlan = plan(for: scrollView)
            if activePlan == nil {
                stop()
            }
            return
        }

        activePlan = self.plan(for: scrollView)
        guard let plan = activePlan else {
            stop()
            return
        }
        _ = apply(plan: plan, to: scrollView)
    }

    private func applyNativeAutoscroll(to scrollView: NSScrollView) -> Bool {
        guard let event = NSApp.currentEvent else { return false }
        switch event.type {
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            break
        default:
            return false
        }

        let clipView = scrollView.contentView
        let didScroll = clipView.autoscroll(with: event)
        if didScroll {
            scrollView.reflectScrolledClipView(clipView)
        }
        return didScroll
    }

    private func distancesToEdges(mousePoint: CGPoint, viewportHeight: CGFloat, isFlipped: Bool) -> (top: CGFloat, bottom: CGFloat) {
        if isFlipped {
            return (top: mousePoint.y, bottom: viewportHeight - mousePoint.y)
        }
        return (top: viewportHeight - mousePoint.y, bottom: mousePoint.y)
    }

    private func planForMousePoint(_ mousePoint: CGPoint, in clipView: NSClipView) -> SidebarAutoScrollPlan? {
        let viewportHeight = clipView.bounds.height
        guard viewportHeight > 0 else { return nil }

        let distances = distancesToEdges(mousePoint: mousePoint, viewportHeight: viewportHeight, isFlipped: clipView.isFlipped)
        return SidebarDragAutoScrollPlanner.plan(distanceToTop: distances.top, distanceToBottom: distances.bottom)
    }

    private func mousePoint(in clipView: NSClipView) -> CGPoint {
        let mouseInWindow = clipView.window?.convertPoint(fromScreen: NSEvent.mouseLocation) ?? .zero
        return clipView.convert(mouseInWindow, from: nil)
    }

    private func currentPlan(for scrollView: NSScrollView) -> SidebarAutoScrollPlan? {
        let clipView = scrollView.contentView
        let mouse = mousePoint(in: clipView)
        return planForMousePoint(mouse, in: clipView)
    }

    private func plan(for scrollView: NSScrollView) -> SidebarAutoScrollPlan? {
        currentPlan(for: scrollView)
    }

    private func apply(plan: SidebarAutoScrollPlan, to scrollView: NSScrollView) -> Bool {
        guard let documentView = scrollView.documentView else { return false }
        let clipView = scrollView.contentView
        let maxOriginY = max(0, documentView.bounds.height - clipView.bounds.height)
        guard maxOriginY > 0 else { return false }

        let directionMultiplier: CGFloat = (plan.direction == .down) ? 1 : -1
        let flippedMultiplier: CGFloat = documentView.isFlipped ? 1 : -1
        let delta = directionMultiplier * flippedMultiplier * plan.pointsPerTick
        let currentY = clipView.bounds.origin.y
        let targetY = min(max(currentY + delta, 0), maxOriginY)
        guard abs(targetY - currentY) > 0.01 else { return false }

        clipView.scroll(to: CGPoint(x: clipView.bounds.origin.x, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
        return true
    }
}
