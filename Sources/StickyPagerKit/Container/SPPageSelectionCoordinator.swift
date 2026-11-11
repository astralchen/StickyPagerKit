import UIKit

/// 串行化选择与快照请求，配对 appearance，并在唯一提交点更新公开选中状态。
@MainActor
internal final class SPPageSelectionCoordinator {
    private weak var host: SPPageViewController?
    init(host: SPPageViewController) {
        self.host = host
    }

    var isVisible = false
    var parentAppearance: [UIViewController] = []
    var parentIsAppearing: Bool?
    /// 转场保存实际记录，避免回调重排快照后按旧索引结束另一页的 appearance。
    private final class PageTransition {
        let generation: UInt
        let outgoing: SPPageRecord?
        let incoming: SPPageRecord
        var outgoingBegan = false
        var incomingBegan = false
        var isSelectionAnimation = false
        init(generation: UInt, outgoing: SPPageRecord?, incoming: SPPageRecord) {
            self.generation = generation
            self.outgoing = outgoing
            self.incoming = incoming
        }
    }

    private var transition: PageTransition?
    var transitionTarget: Int? {
        transition.flatMap { host?.store.snapshot.index(of: $0.incoming.identifier) }
    }

    private var snapshotGeneration: UInt = 0
    private var selectionGeneration: UInt = 0
    var loadingIdentifiers: Set<AnyHashable> = []
    var finishingIdentifiers: Set<AnyHashable> = []
    var operationDepth = 0
    private var appearanceDepth = 0
    private var isDrainingRequests = false
    private enum Request {
        case snapshot(SPPageSnapshot, generation: UInt)
        case selection(AnyHashable, animated: Bool, source: SelectionSource, generation: UInt)
    }

    private enum SelectionSource {
        case programmatic
        case tab(SPTabBarItem)
        var item: SPTabBarItem? {
            if case let .tab(item) = self { item } else { nil }
        }
    }

    private var pendingRequests: [Request] = []

    func endOperation() {
        operationDepth -= 1
        drainRequests()
    }

    private func drainRequests() {
        guard operationDepth == 0, appearanceDepth == 0, !isReloading,
              loadingIdentifiers.isEmpty, !isDrainingRequests else {
            return
        }
        isDrainingRequests = true
        defer { isDrainingRequests = false }
        while !pendingRequests.isEmpty {
            let request = pendingRequests.removeFirst()
            switch request {
            case let .snapshot(snapshot, generation): applySnapshot(snapshot, generation: generation)
            case let .selection(id, animated, source, generation):
                performSelection(id, animated: animated, userItem: source.item, generation: generation)
            }
        }
    }

    func withAppearanceUpdates(_ updates: () -> Void) {
        operationDepth += 1
        appearanceDepth += 1
        defer { appearanceDepth -= 1; endOperation() }
        updates()
    }

    // 横向手势开始即保护纵向历史，覆盖候选页尚未建立及取消回原页的阶段。
    private(set) var isPaging = false {
        didSet {
            guard oldValue != isPaging else {
                return
            }
            updateScrollIndicatorVisibility()
        }
    }

    func updateScrollIndicatorVisibility() {
        guard let host else {
            return
        }
        for record in host.records.values {
            // 显隐写入可触发业务回调并改变策略，后续页面必须读取最新状态。
            record.binding?.indicatorsHiddenForPaging = isPaging && host
                .scrollIndicatorVisibilityPolicy == .hideDuringPaging
        }
    }

    var suppressPaging = false
    private var isReloading = false
    func reloadData() {
        guard let host else {
            return
        }
        guard !isReloading else {
            return
        }
        isReloading = true
        operationDepth += 1
        defer { isReloading = false; endOperation() }
        host.loadViewIfNeeded()
        let count = max(0, host.dataSource?.numberOfPages(in: host) ?? 0)
        var newIDs: [AnyHashable] = [], newItems: [SPTabBarItem] = []
        for index in 0 ..< count {
            guard let source = host.dataSource else {
                return
            }
            newIDs.append(source.pageViewController(host, identifierForPageAt: index))
            newItems.append(source.pageViewController(host, tabBarItemAt: index))
        }
        guard var snapshot = SPPageSnapshot(identifiers: newIDs, items: newItems) else {
            return
        }
        for (index, identifier) in newIDs.enumerated() {
            snapshot.topBounceBehaviors[identifier] = host.dataSource?
                .pageViewController(host, topBounceBehaviorForPageAt: index)
        }
        // 只有完整且合法的快照才使旧选择失效；拒绝更新不触碰已有转场。
        snapshotGeneration &+= 1
        selectionGeneration &+= 1
        let generation = snapshotGeneration
        if appearanceDepth > 0 {
            pendingRequests.append(.snapshot(snapshot, generation: generation))
        } else {
            applySnapshot(snapshot, generation: generation)
        }
    }

    private func applySnapshot(_ snapshot: SPPageSnapshot, generation: UInt) {
        guard let host else {
            return
        }
        let newIDs = snapshot.identifiers
        guard generation == snapshotGeneration else {
            return
        }
        operationDepth += 1
        // 应用快照期间的选择在完整状态建立后执行；沿用嵌套 reload 忽略的既有约定。
        let wasReloading = isReloading
        isReloading = true
        defer { isReloading = wasReloading; endOperation() }
        cancelPaging(invalidatingRequest: false)
        host.vertical.stopAnimation()
        let oldIndex = host.selectedIndex
        let oldID = oldIndex.flatMap { host.identifiers.indices.contains($0) ? host.identifiers[$0] : nil }
        let next = SPScrollGeometry.selectedIndex(oldID: oldID, oldIndex: oldIndex, identifiers: newIDs)
        let nextID = next.map { newIDs[$0] }
        if oldID != nextID, let old = host.currentRecord {
            appear(old.controller, false)
        }
        for id in Array(host.records.keys) where !newIDs.contains(id) {
            host.removeRecord(id)
        }
        host.store.apply(snapshot)
        host.commitSelection(next)
        host.storedTabBar.setItems(host.items)
        if let next {
            let record = host.loadPage(next)
            host.vertical.align(record)
            if oldID != nextID, let record {
                appear(record.controller, true)
            }
        }
        host.storedTabBar.setSelectedItem(
            host.selectedIndex.flatMap { host.items.indices.contains($0) ? host.items[$0] : nil },
            animated: false
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        host.evictPages()
        if let next, oldID != nextID || oldIndex != next {
            host.delegate?.pageViewController(host, didSelectPageAt: next)
        }
    }

    /// 越界请求不改变状态。新请求取消尚未完成的旧转场。
    func selectPage(at index: Int, animated: Bool, userItem: SPTabBarItem?) {
        guard let host else {
            return
        }
        guard host.identifiers.indices.contains(index) else {
            return
        }
        let id = host.identifiers[index]
        // 同目标点击沿用正在运行的选择动画；必须先于 generation 更新和取消转场。
        // 手势候选页及程序化请求仍按原有接管规则处理。
        if let userItem, let transition, transition.isSelectionAnimation,
           !host.pagingView.isDragging, !host.pagingView.isDecelerating,
           transition.generation == selectionGeneration, transition.incoming.identifier == id {
            withAppearanceUpdates { host.storedTabBar.beginUserSelection(userItem) }
            return
        }
        selectionGeneration &+= 1
        let generation = selectionGeneration
        if appearanceDepth > 0 || isReloading || loadingIdentifiers.contains(id) {
            pendingRequests.append(.selection(
                id,
                animated: animated,
                source: userItem.map(SelectionSource.tab) ?? .programmatic,
                generation: generation
            ))
            return
        }
        performSelection(id, animated: animated, userItem: userItem, generation: generation)
    }

    private func performSelection(_ id: AnyHashable, animated: Bool, userItem: SPTabBarItem?, generation: UInt) {
        guard let host else {
            return
        }
        guard generation == selectionGeneration, host.identifiers.contains(id) else {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        host.loadViewIfNeeded()
        cancelPaging(invalidatingRequest: false)
        guard generation == selectionGeneration, let index = host.store.snapshot.index(of: id) else {
            return
        }
        if let userItem {
            host.storedTabBar.beginUserSelection(userItem)
        }
        guard generation == selectionGeneration else {
            return
        }
        guard index != host.selectedIndex else {
            withAppearanceUpdates { host.storedTabBar.completeUserSelection() }
            return
        }
        host.vertical.stopAnimation(settlingTopBounce: true)
        host.view.layoutIfNeeded()
        guard generation == selectionGeneration, let index = host.store.snapshot.index(of: id) else {
            return
        }
        let isAdjacent = host.selectedIndex.map { abs(index - $0) == 1 } ?? false
        let animatePage = animated && isVisible && isAdjacent && host.pagingView.bounds.width > 0
        beginTransition(to: index, animated: animatePage)
        guard generation == selectionGeneration, transition?.incoming.identifier == id,
              let index = host.store.snapshot.index(of: id) else {
            return
        }
        let point = CGPoint(x: host.pageLayout.physicalIndex(index) * host.pagingView.bounds.width, y: 0)
        if animatePage {
            transition?.isSelectionAnimation = true
            host.pagingView.setContentOffset(point, animated: true)
        } else {
            let wasSuppressing = suppressPaging
            suppressPaging = true
            host.pagingView.setContentOffset(point, animated: false)
            suppressPaging = wasSuppressing
            guard generation == selectionGeneration else {
                return
            }
            finishTransition(commit: true, animated: animated && isVisible)
        }
    }

    func logicalPosition() -> CGFloat {
        guard let host else {
            return 0
        }
        guard host.pagingView.bounds.width > 0 else {
            return CGFloat(host.selectedIndex ?? 0)
        }
        let physical = host.pagingView.contentOffset.x / host.pagingView.bounds.width
        return host.isRTL ? CGFloat(host.identifiers.count - 1) - physical : physical
    }

    func alignPaging() {
        guard let host else {
            return
        }
        host.pagingView.contentOffset = CGPoint(
            x: host.selectedIndex.map { host.pageLayout.physicalIndex($0) * host.pagingView.bounds.width } ?? 0,
            y: 0
        )
    }

    func endParentAppearance() {
        let controllers = parentAppearance
        parentAppearance.removeAll()
        parentIsAppearing = nil
        withAppearanceUpdates { controllers.forEach { $0.endAppearanceTransition() } }
    }

    func appear(_ controller: UIViewController, _ appearing: Bool) {
        withAppearanceUpdates {
            if let index = parentAppearance.firstIndex(where: { $0 === controller }) {
                parentAppearance.remove(at: index)
                let wasAppearing = parentIsAppearing == true
                controller.endAppearanceTransition()
                if !appearing && wasAppearing {
                    controller.beginAppearanceTransition(false, animated: false)
                    controller.endAppearanceTransition()
                }
                return
            }
            if isVisible {
                controller.beginAppearanceTransition(appearing, animated: false)
                controller.endAppearanceTransition()
            } else if appearing && parentIsAppearing == true {
                parentAppearance.append(controller)
                controller.beginAppearanceTransition(true, animated: false)
            }
        }
    }

    private func beginTransition(to index: Int, animated: Bool = true) {
        guard let host else {
            return
        }
        guard index != host.selectedIndex, host.identifiers.indices.contains(index) else {
            return
        }
        let id = host.identifiers[index]
        if transition?.incoming.identifier == id {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        let generation = selectionGeneration
        if transition != nil {
            finishTransition(commit: false, continuingPaging: true)
        }
        guard generation == selectionGeneration, let currentIndex = host.store.snapshot.index(of: id),
              let incoming = host.loadPage(currentIndex), generation == selectionGeneration,
              host.records[id] === incoming else {
            return
        }
        beginPaging()
        guard generation == selectionGeneration, host.records[id] === incoming else {
            return
        }
        host.vertical.align(incoming)
        guard generation == selectionGeneration, host.records[id] === incoming else {
            return
        }
        let context = PageTransition(generation: generation, outgoing: host.currentRecord, incoming: incoming)
        transition = context
        withAppearanceUpdates {
            if isVisible {
                context.outgoingBegan = context.outgoing != nil
                context.outgoing?.controller.beginAppearanceTransition(false, animated: animated)
                context.incomingBegan = true
                incoming.controller.beginAppearanceTransition(true, animated: animated)
            }
            if generation != selectionGeneration, transition === context {
                finishTransition(commit: false)
            }
        }
    }

    private func finishTransition(commit: Bool, animated: Bool = true, continuingPaging: Bool = false) {
        guard let host else {
            return
        }
        guard let context = transition else {
            if !continuingPaging {
                if isPaging {
                    host.vertical.align(host.currentRecord)
                }
                isPaging = false
            }
            return
        }
        operationDepth += 1
        defer { endOperation() }
        // 先移走活动上下文，再调用 UIKit；回调不能递归结束同一转场。
        transition = nil
        let previousFinishing = finishingIdentifiers
        finishingIdentifiers.formUnion([context.outgoing?.identifier, context.incoming.identifier].compactMap { $0 })
        defer { finishingIdentifiers = previousFinishing; host.evictPages() }
        withAppearanceUpdates {
            let hadAppearance = context.outgoingBegan || context.incomingBegan
            if context.outgoingBegan {
                context.outgoingBegan = false
                context.outgoing?.controller.endAppearanceTransition()
            }
            if context.incomingBegan {
                context.incomingBegan = false
                context.incoming.controller.endAppearanceTransition()
            }
            let canCommit = commit && context.generation == selectionGeneration
                && host.records[context.incoming.identifier] === context.incoming
                && host.identifiers.contains(context.incoming.identifier)
            if !canCommit, hadAppearance {
                context.outgoing?.controller.beginAppearanceTransition(true, animated: false)
                context.outgoing?.controller.endAppearanceTransition()
                context.incoming.controller.beginAppearanceTransition(false, animated: false)
                context.incoming.controller.endAppearanceTransition()
            }
            if canCommit && !hadAppearance && parentIsAppearing == true {
                if let old = context.outgoing {
                    appear(old.controller, false)
                }
                if context.generation == selectionGeneration {
                    appear(context.incoming.controller, true)
                }
                if context.generation != selectionGeneration {
                    // 父级仍在出现时，撤销候选页并恢复旧页的待完成 appearance。
                    // 后续请求必须从完整的旧状态接管，不能留下两张待出现页面。
                    if parentAppearance.contains(where: { $0 === context.incoming.controller }) {
                        appear(context.incoming.controller, false)
                    }
                    if let old = context.outgoing {
                        appear(old.controller, true)
                    }
                }
            }
            let didCommit = canCommit && context.generation == selectionGeneration
            if didCommit {
                host.commitSelection(host.store.snapshot.index(of: context.incoming.identifier))
                host.vertical.align(host.currentRecord)
            } else if !continuingPaging {
                host.vertical.align(host.currentRecord)
            }
            host.storedTabBar.synchronizeSelection(
                host.selectedIndex.flatMap { host.items.indices.contains($0) ? host.items[$0] : nil },
                animated: didCommit && animated
            )
            if !continuingPaging {
                isPaging = false
            }
            if didCommit, let target = host.selectedIndex {
                // 已提交事件在队列中的下一次选择之前发送，保持提交顺序。
                host.storedTabBar.completeUserSelection()
                host.delegate?.pageViewController(host, didSelectPageAt: target)
            } else {
                host.storedTabBar.cancelUserSelection()
            }
        }
    }

    func cancelPaging(invalidatingRequest: Bool = true) {
        guard let host else {
            return
        }
        if invalidatingRequest {
            selectionGeneration &+= 1
        }
        operationDepth += 1
        defer { endOperation() }
        host.storedTabBar.cancelUserSelection()
        guard host.isViewLoaded else {
            return
        }
        let wasSuppressing = suppressPaging
        suppressPaging = true
        defer { suppressPaging = wasSuppressing }
        host.pagingView.setContentOffset(host.pagingView.contentOffset, animated: false)
        finishTransition(commit: false)
        alignPaging()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let host else {
            return
        }
        host.storedTabBar.cancelUserSelection()
        // 每次真实分页输入都取消框架旧交互；只对业务原生减速交接去重。
        host.vertical.stopAnimation(settlingTopBounce: true)
        beginPaging()
        host.pagingView.preserveAcceptedPanDisplacement()
    }

    private func beginPaging() {
        guard let host else {
            return
        }
        guard !isPaging else {
            return
        }
        // 手势开始、候选页建立及候选页变化共用一次交接。
        isPaging = true
        host.vertical.stopAnimation(settlingTopBounce: true)
        host.currentRecord?.binding?.stopDeceleration()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let host else {
            return
        }
        guard !suppressPaging, let selectedIndex = host.selectedIndex, !host.identifiers.isEmpty else {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        let snapshot = snapshotGeneration
        let selection = selectionGeneration
        let position = min(CGFloat(host.identifiers.count - 1), max(0, logicalPosition()))
        // 手势或相邻切页期间按需准备可见页；非相邻选择直接定位，不进入此路径。
        // 只保留当前、目标及最多两个可见页。
        let visibleIndices = Set([Int(floor(position)), Int(ceil(position))])
        for index in visibleIndices {
            if host.records[host.identifiers[index]] == nil {
                host.loadPage(index)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
        }
        // 页面加载可能更新标签内容；准备完成后只测量一次，两张可见页共用当前布局。
        let pageLayout = host.pageLayout.effectiveLayout
        for index in visibleIndices {
            // 页面横向进入视口时，UIKit 才会更新其自动安全区域 inset。
            // 同步撤销离屏时的标签栏补偿，避免首次切页期间重复避让、结束时正文上跳。
            if let record = host.records[host.identifiers[index]] {
                host.pageLayout.layoutPage(record, at: index, layout: pageLayout)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
        }
        host.evictPages()
        guard snapshot == snapshotGeneration, selection == selectionGeneration else {
            return
        }
        let delta = position - CGFloat(selectedIndex)
        if abs(delta) > 0.001 {
            let target = delta > 0 ? Int(ceil(position)) : Int(floor(position))
            if host.pagingView.isDragging || host.pagingView.isDecelerating {
                beginTransition(to: target)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
            let end = transitionTarget ?? target
            let denominator = abs(CGFloat(end - selectedIndex))
            let progress = denominator == 0 ? 0 : min(1, abs(delta) / denominator)
            publishProgress(SPPagingProgress(
                fromID: host.identifiers[selectedIndex],
                toID: host.identifiers[end],
                fromIndex: selectedIndex,
                toIndex: end,
                fraction: progress,
                snapshotGeneration: snapshot,
                selectionGeneration: selection
            ))
        }
    }

    private func publishProgress(_ progress: SPPagingProgress) {
        guard let host, progress.isCurrent(
            snapshot: host.store.snapshot,
            snapshotGeneration: snapshotGeneration,
            selectionGeneration: selectionGeneration
        ) else {
            return
        }
        // 指示器先更新、代理随后收到同一份进度；提交仍只发生于 finishTransition。
        host.storedTabBar.setTransitionProgress(
            from: progress.fromIndex,
            to: progress.toIndex,
            progress: progress.fraction
        )
        host.delegate?.pageViewController(
            host,
            didScrollFrom: progress.fromIndex,
            to: progress.toIndex,
            progress: progress.fraction
        )
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settlePaging()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 原生 pan 取消不是松手选页；即便已越过半页，也恢复原页和未提交的 appearance。
        if scrollView.panGestureRecognizer.state == .cancelled {
            cancelPaging()
            return
        }
        if !decelerate {
            settlePaging()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settlePaging()
    }

    private func settlePaging() {
        guard let host else {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        let index = Int(logicalPosition().rounded())
        if index == host.selectedIndex {
            finishTransition(commit: false)
        } else {
            beginTransition(to: index); finishTransition(commit: true)
        }
        let wasSuppressing = suppressPaging
        suppressPaging = true; alignPaging(); suppressPaging = wasSuppressing
    }
}
