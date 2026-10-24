import UIKit

/// 管理框架贡献的 inset 与显式启用的分页指示器隐藏，不占用业务 delegate。
@MainActor
internal final class SPScrollBinding {
    let scrollView: UIScrollView
    var onScroll: (@MainActor (SPScrollBinding) -> Void)?
    var onScrollDisabled: (@MainActor (SPScrollBinding) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var updating = false
    private enum InsetKind { case content, indicator }
    private final class InsetObservation {
        var depth = 0
        var internalDepth: Int?
        var externalDepth = 0
        var externalStart: UIEdgeInsets?
    }

    private let contentInsetObservation = InsetObservation()
    private let indicatorInsetObservation = InsetObservation()
    private var changingExternalInset: Bool {
        contentInsetObservation.externalDepth > 0 || indicatorInsetObservation.externalDepth > 0
    }

    private var pendingGeometryUpdate = false
    private var pendingIndicatorUpdate = false
    private var flushingInsetUpdates = false
    private var detached = false
    private var topContribution: CGFloat = 0
    private var bottomContribution: CGFloat = 0
    private var baseInset: UIEdgeInsets
    private var baseIndicatorInset: UIEdgeInsets
    // 仅在临时隐藏期间保存业务意图；默认模式没有显隐恢复状态。
    private var hiddenIndicatorPreferences: (vertical: Bool, horizontal: Bool)?
    private enum IndicatorAxis { case vertical, horizontal }
    private var indicatorNotificationDepth: [IndicatorAxis: Int] = [:]
    private var internalIndicatorWriteDepth: [IndicatorAxis: Int] = [:]
    private var updatingIndicatorVisibility = false
    private var indicatorVisibilityGeneration: UInt = 0
    var indicatorsHiddenForPaging = false {
        didSet {
            guard oldValue != indicatorsHiddenForPaging, !detached else {
                return
            }
            indicatorVisibilityGeneration &+= 1
            if indicatorsHiddenForPaging, hiddenIndicatorPreferences == nil {
                hiddenIndicatorPreferences = (
                    scrollView.showsVerticalScrollIndicator,
                    scrollView.showsHorizontalScrollIndicator
                )
            }
            updateIndicators()
        }
    }

    private var range: CGFloat = 0
    private var pageDisplacement: CGFloat = 0
    private weak var pageRoot: UIView?
    private var topOcclusion: CGFloat = 0

    private var overlappingTop: CGFloat {
        guard let pageRoot else {
            return 0
        }
        let frame = scrollView.convert(scrollView.bounds, to: pageRoot)
        return min(scrollView.bounds.height, max(0, topOcclusion - (frame.minY - pageRoot.bounds.minY)))
    }

    var position: CGFloat {
        scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    var maximumPosition: CGFloat {
        max(
            range,
            scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset
                .bottom - scrollView.bounds.height
        )
    }

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        baseInset = scrollView.contentInset
        baseIndicatorInset = scrollView.verticalScrollIndicatorInsets
        observations = [
            scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.changingExternalInset, !self.detached else {
                        return
                    }
                    self.updateIndicators()
                    // 布局回写仍需刷新指示器，但相同偏移或浮点尾差不能接管 Header 拖动。
                    guard let old = change.oldValue, let new = change.newValue, abs(new.y - old.y) > 0.001 else {
                        return
                    }
                    self.onScroll?(self)
                }
            },
            scrollView.observe(\.contentInset, options: [.prior, .old, .new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.insetChanged(.content, change: change) }
            },
            scrollView.observe(\.verticalScrollIndicatorInsets, options: [
                .prior,
                .old,
                .new
            ]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.insetChanged(.indicator, change: change) }
            },
            scrollView.observe(\.showsVerticalScrollIndicator, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.indicatorChanged(.vertical, change: change) }
            },
            scrollView.observe(\.showsHorizontalScrollIndicator, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.indicatorChanged(.horizontal, change: change) }
            },
            scrollView.observe(\.isScrollEnabled, options: [.new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.detached, change.newValue == false else {
                        return
                    }
                    self.onScrollDisabled?(self)
                }
            },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateGeometry() }
            },
            scrollView.observe(\.bounds, options: [.old, .new]) { [weak self] _, change in
                guard change.oldValue?.size != change.newValue?.size else {
                    return
                }
                MainActor.assumeIsolated { self?.updateGeometry() }
            },
            scrollView.observe(\.adjustedContentInset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateGeometry() }
            },
            scrollView.observe(\.automaticallyAdjustsScrollIndicatorInsets, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateIndicators() }
            }
        ]
    }

    isolated deinit { detach() }

    func setRange(_ newRange: CGFloat) {
        range = max(0, newRange)
        updateGeometry()
    }

    /// 将页面尺寸与折叠 inset 作为一次几何更新，避免 UIKit 的中间偏移反向驱动 Header。
    func layoutPage(
        range newRange: CGFloat,
        collapse: CGFloat,
        root: UIView? = nil,
        topOcclusion: CGFloat = 0,
        updates: () -> Void
    ) {
        guard !updating, !changingExternalInset, !detached else {
            return
        }
        let oldPosition = position
        updating = true
        range = max(0, newRange)
        pageDisplacement = max(0, range - collapse)
        pageRoot = root
        self.topOcclusion = max(0, topOcclusion)
        updates()
        updating = false
        updateGeometry(preserving: oldPosition)
    }

    func setPosition(_ position: CGFloat) {
        guard !detached else {
            return
        }
        let y = position - scrollView.adjustedContentInset.top
        guard abs(y - scrollView.contentOffset.y) > 0.001 else {
            return
        }
        updating = true
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
        updating = false
        updateIndicators()
    }

    func stopDeceleration() {
        guard !detached, scrollView.isDecelerating else {
            return
        }
        // 仅交接正在进行的原生减速；静止或业务程序化动画不发送额外的停止定位。
        updating = true
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        updating = false
        flushInsetUpdates()
    }

    func detach() {
        guard !detached else {
            return
        }
        detached = true
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        onScroll = nil
        onScrollDisabled = nil
        let oldPosition = position
        let contentPosition = oldPosition - SPScrollGeometry.collapse(oldPosition, range: range)
        var restored = scrollView.contentInset
        restored.top -= topContribution
        restored.bottom -= bottomContribution
        if scrollView.contentInset != restored {
            scrollView.contentInset = restored
        }
        if scrollView
            .verticalScrollIndicatorInsets !=
            baseIndicatorInset {
            scrollView.verticalScrollIndicatorInsets = baseIndicatorInset
        }
        indicatorVisibilityGeneration &+= 1
        updateIndicatorVisibility()
        let desired = contentPosition - scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - desired) > 0.001 {
            scrollView.contentOffset.y = desired
        }
    }

    private func insetObservation(_ kind: InsetKind) -> InsetObservation {
        kind == .content ? contentInsetObservation : indicatorInsetObservation
    }

    private func insetChanged(_ kind: InsetKind, change: NSKeyValueObservedChange<UIEdgeInsets>) {
        guard !detached else {
            return
        }
        let observation = insetObservation(kind)
        if change.isPrior {
            observation.depth += 1
            guard observation.depth != observation.internalDepth else {
                return
            }
            if observation.externalDepth == 0 {
                observation.externalStart = change.oldValue
            }
            observation.externalDepth += 1
            return
        }
        defer { observation.depth -= 1 }
        guard observation.depth != observation.internalDepth else {
            // 后续 KVO 观察者还可同步赋值；本次框架通知结束后不能继续占用该层级。
            observation.internalDepth = nil
            return
        }
        observation.externalDepth -= 1
        guard observation.externalDepth == 0 else {
            return
        }
        // 外部 setter 的嵌套赋值完成后再叠加贡献，避免中间回写污染外层通知。
        switch kind {
        case .content:
            baseInset = Self.updatedBase(baseInset, from: observation.externalStart, to: scrollView.contentInset)
            pendingGeometryUpdate = true
        case .indicator:
            baseIndicatorInset = Self.updatedBase(
                baseIndicatorInset,
                from: observation.externalStart,
                to: scrollView.verticalScrollIndicatorInsets
            )
            pendingIndicatorUpdate = true
        }
        observation.externalStart = nil
        flushInsetUpdates()
    }

    private func writeInset(_ inset: UIEdgeInsets, kind: InsetKind) {
        let observation = insetObservation(kind)
        let previous = observation.internalDepth
        // 只屏蔽框架 setter 本身；其回调中的业务写入有独立通知层级。
        observation.internalDepth = observation.depth + 1
        defer { observation.internalDepth = previous }
        switch kind {
        case .content: scrollView.contentInset = inset
        case .indicator: scrollView.verticalScrollIndicatorInsets = inset
        }
    }

    private func flushInsetUpdates() {
        guard !updating, !changingExternalInset, !detached, !flushingInsetUpdates else {
            return
        }
        flushingInsetUpdates = true
        defer { flushingInsetUpdates = false }
        while !detached, pendingGeometryUpdate || pendingIndicatorUpdate {
            if pendingGeometryUpdate {
                pendingGeometryUpdate = false
                updateGeometry()
            } else {
                pendingIndicatorUpdate = false
                updateIndicators()
            }
        }
    }

    /// 仅变化的方向提供新业务基准；未变化方向不能把 getter 中的框架贡献再次计入。
    private static func updatedBase(
        _ base: UIEdgeInsets,
        from oldValue: UIEdgeInsets?,
        to newValue: UIEdgeInsets
    ) -> UIEdgeInsets {
        UIEdgeInsets(
            top: oldValue?.top == newValue.top ? base.top : newValue.top,
            left: oldValue?.left == newValue.left ? base.left : newValue.left,
            bottom: oldValue?.bottom == newValue.bottom ? base.bottom : newValue.bottom,
            right: oldValue?.right == newValue.right ? base.right : newValue.right
        )
    }

    private func updateGeometry(preserving savedPosition: CGFloat? = nil) {
        guard !updating, !changingExternalInset, !detached else {
            return
        }
        updating = true
        let oldPosition = savedPosition ?? position
        let adjustment = scrollView.adjustedContentInset.top - scrollView.contentInset.top
        let bottomAdjustment = scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom
        // 尚未折叠的距离由页面根视图的下移承担，inset 只承担已经折叠的距离。
        // 自动 inset 已通过子页面 Safe Area 避让标签栏；仅补足 .never 等策略留下的遮挡。
        let uncoveredTop = max(0, overlappingTop - adjustment)
        topContribution = max(0, range - pageDisplacement) + uncoveredTop
        bottomContribution = range > 0 ? SPScrollGeometry.shortContentInset(
            height: scrollView.bounds.height + pageDisplacement,
            contentHeight: scrollView.contentSize.height,
            baseTop: baseInset.top + adjustment + uncoveredTop,
            baseBottom: baseInset.bottom + bottomAdjustment
        ) : 0
        var inset = baseInset
        inset.top += topContribution
        inset.bottom += bottomContribution
        if scrollView.contentInset != inset {
            writeInset(inset, kind: .content)
        }
        // 业务可在 inset 回调里解绑；旧更新不能覆盖解绑已还原的正文坐标。
        guard !detached else {
            updating = false
            return
        }
        let desired = oldPosition - scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - desired) > 0.001 {
            scrollView.contentOffset.y = desired
        }
        updating = false
        updateIndicators()
    }

    private func updateIndicators() {
        let wasUpdating = updating
        updating = true
        defer {
            updating = wasUpdating
            flushInsetUpdates()
        }
        updateIndicatorVisibility()
        guard !wasUpdating, !changingExternalInset, !detached else {
            return
        }
        if scrollView.showsVerticalScrollIndicator {
            // 仅在需要显示时更新轨道；隐藏期间不处理指示器几何。
            var inset = baseIndicatorInset
            // 自动指示器已避让 Safe Area，手动模式仅补上仍被标签栏遮挡的轨道。
            let automaticTop = scrollView.automaticallyAdjustsScrollIndicatorInsets ? scrollView.safeAreaInsets.top : 0
            inset.top += max(0, overlappingTop - automaticTop)
            inset.top += max(0, range - SPScrollGeometry.collapse(position, range: range) - pageDisplacement)
            if scrollView.verticalScrollIndicatorInsets != inset {
                writeInset(inset, kind: .indicator)
            }
        }
    }

    private func indicatorChanged(_ axis: IndicatorAxis, change: NSKeyValueObservedChange<Bool>) {
        if change.isPrior {
            indicatorNotificationDepth[axis, default: 0] += 1
            return
        }
        let depth = indicatorNotificationDepth[axis, default: 0]
        defer { indicatorNotificationDepth[axis] = depth - 1 }
        if internalIndicatorWriteDepth[axis] == depth {
            internalIndicatorWriteDepth[axis] = nil
            return
        }
        guard !detached, let value = change.newValue else {
            return
        }
        if hiddenIndicatorPreferences != nil {
            switch axis {
            case .vertical: hiddenIndicatorPreferences?.vertical = value
            case .horizontal: hiddenIndicatorPreferences?.horizontal = value
            }
            indicatorVisibilityGeneration &+= 1
        }
        if axis == .vertical || hiddenIndicatorPreferences != nil {
            updateIndicators()
        }
    }

    private func writeIndicator(_ visible: Bool, axis: IndicatorAxis) {
        let current = axis == .vertical ? scrollView.showsVerticalScrollIndicator : scrollView
            .showsHorizontalScrollIndicator
        guard current != visible else {
            return
        }
        // 只忽略本次框架 setter 的成对通知；回调中业务嵌套赋值（包括同值）有自己的层级。
        let previous = internalIndicatorWriteDepth[axis]
        internalIndicatorWriteDepth[axis] = indicatorNotificationDepth[axis, default: 0] + 1
        defer { internalIndicatorWriteDepth[axis] = previous }
        switch axis {
        case .vertical: scrollView.showsVerticalScrollIndicator = visible
        case .horizontal: scrollView.showsHorizontalScrollIndicator = visible
        }
    }

    private func updateIndicatorVisibility() {
        // 业务属性回调可能切换策略或解绑；串行收敛到最新状态，旧操作不再写入下一轴。
        guard !updatingIndicatorVisibility else {
            return
        }
        updatingIndicatorVisibility = true
        defer { updatingIndicatorVisibility = false }
        while let preferences = hiddenIndicatorPreferences {
            let generation = indicatorVisibilityGeneration
            let hidden = indicatorsHiddenForPaging && !detached
            let vertical = hidden ? false : preferences.vertical
            let horizontal = hidden ? false : preferences.horizontal
            writeIndicator(vertical, axis: .vertical)
            if generation != indicatorVisibilityGeneration {
                continue
            }
            writeIndicator(horizontal, axis: .horizontal)
            if generation != indicatorVisibilityGeneration {
                continue
            }
            // 两个方向均恢复后才清除意图，避免恢复中重新隐藏时采集到一半恢复的值。
            if !hidden {
                hiddenIndicatorPreferences = nil
            }
            break
        }
    }
}
