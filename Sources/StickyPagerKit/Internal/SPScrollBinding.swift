import UIKit

/// 管理框架贡献的 inset 与显式启用的分页指示器隐藏，不占用业务 delegate。
@MainActor
internal final class SPScrollBinding {
    let scrollView: UIScrollView
    var onScroll: (@MainActor (SPScrollBinding) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var updating = false
    private var changingExternalInset = false
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
            scrollView.observe(\.contentInset, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else {
                        return
                    }
                    // UIKit 在 inset setter 完成前可能先通知 offset/adjustedInset，不能在此期间覆盖业务值。
                    self.changingExternalInset = change.isPrior
                    if !change.isPrior {
                        self.externalInsetsChanged()
                    }
                }
            },
            scrollView.observe(\.verticalScrollIndicatorInsets, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else {
                        return
                    }
                    self.baseIndicatorInset = self.scrollView.verticalScrollIndicatorInsets
                    self.updateIndicators()
                }
            },
            scrollView.observe(\.showsVerticalScrollIndicator, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.indicatorChanged(.vertical, change: change) }
            },
            scrollView.observe(\.showsHorizontalScrollIndicator, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated { self?.indicatorChanged(.horizontal, change: change) }
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
        // UIKit 的非动画定位会终止当前滚动动画，不更换识别器或 delegate。
        updating = true
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
        updating = false
    }

    func detach() {
        guard !detached else {
            return
        }
        detached = true
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        onScroll = nil
        let contentPosition = max(0, position - range)
        var restored = scrollView.contentInset
        restored.top -= topContribution
        restored.bottom -= bottomContribution
        scrollView.contentInset = restored
        if scrollView
            .verticalScrollIndicatorInsets !=
            baseIndicatorInset {
            scrollView.verticalScrollIndicatorInsets = baseIndicatorInset
        }
        indicatorVisibilityGeneration &+= 1
        updateIndicatorVisibility()
        scrollView.contentOffset.y = contentPosition - scrollView.adjustedContentInset.top
    }

    private func externalInsetsChanged() {
        guard !updating, !detached else {
            return
        }
        // 外部赋值视作新的业务基准；框架贡献随后重新叠加。
        baseInset = scrollView.contentInset
        updateGeometry()
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
        bottomContribution = SPScrollGeometry.shortContentInset(
            height: scrollView.bounds.height + pageDisplacement,
            contentHeight: scrollView.contentSize.height,
            baseTop: baseInset.top + adjustment + uncoveredTop,
            baseBottom: baseInset.bottom + bottomAdjustment
        )
        var inset = baseInset
        inset.top += topContribution
        inset.bottom += bottomContribution
        if scrollView.contentInset != inset {
            scrollView.contentInset = inset
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
        defer { updating = wasUpdating }
        updateIndicatorVisibility()
        guard !wasUpdating, !detached else {
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
                scrollView.verticalScrollIndicatorInsets = inset
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
