import UIKit

/// 仅管理框架贡献的 inset，不占用内容滚动视图的 delegate。
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
    private var requestedVerticalIndicator: Bool
    private var requestedHorizontalIndicator: Bool
    var indicatorsHiddenForPaging = false {
        didSet {
            if oldValue != indicatorsHiddenForPaging { updateIndicators() }
        }
    }
    private let originalBounce: Bool
    private var range: CGFloat = 0
    private var pageDisplacement: CGFloat = 0

    var position: CGFloat { scrollView.contentOffset.y + scrollView.adjustedContentInset.top }
    var maximumPosition: CGFloat {
        max(range, scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
    }
    var isRefreshing: Bool { scrollView.refreshControl?.isRefreshing == true }

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        baseInset = scrollView.contentInset
        baseIndicatorInset = scrollView.verticalScrollIndicatorInsets
        requestedVerticalIndicator = scrollView.showsVerticalScrollIndicator
        requestedHorizontalIndicator = scrollView.showsHorizontalScrollIndicator
        originalBounce = scrollView.alwaysBounceVertical
        scrollView.alwaysBounceVertical = true
        observations = [
            scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.changingExternalInset, !self.detached else { return }
                    self.updateIndicators()
                    self.onScroll?(self)
                }
            },
            scrollView.observe(\.contentInset, options: [.prior, .new]) { [weak self] _, change in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else { return }
                    // UIKit 在 inset setter 完成前可能先通知 offset/adjustedInset，不能在此期间覆盖业务值。
                    self.changingExternalInset = change.isPrior
                    if !change.isPrior { self.externalInsetsChanged() }
                }
            },
            scrollView.observe(\.verticalScrollIndicatorInsets, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else { return }
                    self.baseIndicatorInset = self.scrollView.verticalScrollIndicatorInsets
                    self.updateIndicators()
                }
            },
            scrollView.observe(\.showsVerticalScrollIndicator, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else { return }
                    self.requestedVerticalIndicator = self.scrollView.showsVerticalScrollIndicator
                    self.updateIndicators()
                }
            },
            scrollView.observe(\.showsHorizontalScrollIndicator, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else { return }
                    self.requestedHorizontalIndicator = self.scrollView.showsHorizontalScrollIndicator
                    self.updateIndicators()
                }
            },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateGeometry() }
            },
            scrollView.observe(\.bounds, options: [.old, .new]) { [weak self] _, change in
                guard change.oldValue?.size != change.newValue?.size else { return }
                MainActor.assumeIsolated { self?.updateGeometry() }
            },
            scrollView.observe(\.adjustedContentInset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.updateGeometry() }
            }
        ]
    }

    isolated deinit { detach() }

    func setRange(_ newRange: CGFloat) {
        range = max(0, newRange)
        updateGeometry()
    }

    /// 将页面尺寸与折叠 inset 作为一次几何更新，避免 UIKit 的中间偏移反向驱动 Header。
    func layoutPage(range newRange: CGFloat, collapse: CGFloat, updates: () -> Void) {
        guard !updating, !changingExternalInset, !detached else { return }
        let oldPosition = position
        updating = true
        range = max(0, newRange)
        pageDisplacement = max(0, range - collapse)
        updates()
        updating = false
        updateGeometry(preserving: oldPosition)
    }

    func setPosition(_ position: CGFloat) {
        guard !detached else { return }
        let y = position - scrollView.adjustedContentInset.top
        guard abs(y - scrollView.contentOffset.y) > 0.001 else { return }
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
        guard !detached else { return }
        detached = true
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        onScroll = nil
        let contentPosition = max(0, position - range)
        var restored = scrollView.contentInset
        restored.top -= topContribution
        restored.bottom -= bottomContribution
        scrollView.contentInset = restored
        if scrollView.verticalScrollIndicatorInsets != baseIndicatorInset { scrollView.verticalScrollIndicatorInsets = baseIndicatorInset }
        if scrollView.showsVerticalScrollIndicator != requestedVerticalIndicator { scrollView.showsVerticalScrollIndicator = requestedVerticalIndicator }
        if scrollView.showsHorizontalScrollIndicator != requestedHorizontalIndicator { scrollView.showsHorizontalScrollIndicator = requestedHorizontalIndicator }
        scrollView.alwaysBounceVertical = originalBounce
        scrollView.contentOffset.y = contentPosition - scrollView.adjustedContentInset.top
    }

    private func externalInsetsChanged() {
        guard !updating, !detached else { return }
        // 外部赋值视作新的业务基准；框架贡献随后重新叠加。
        baseInset = scrollView.contentInset
        updateGeometry()
    }

    private func updateGeometry(preserving savedPosition: CGFloat? = nil) {
        guard !updating, !changingExternalInset, !detached else { return }
        updating = true
        let oldPosition = savedPosition ?? position
        let adjustment = scrollView.adjustedContentInset.top - scrollView.contentInset.top
        let bottomAdjustment = scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom
        // 尚未折叠的距离由页面根视图的下移承担，inset 只承担已经折叠的距离。
        topContribution = max(0, range - pageDisplacement)
        bottomContribution = SPScrollGeometry.shortContentInset(
            height: scrollView.bounds.height + pageDisplacement, contentHeight: scrollView.contentSize.height,
            baseTop: baseInset.top + adjustment, baseBottom: baseInset.bottom + bottomAdjustment)
        var inset = baseInset
        inset.top += topContribution
        inset.bottom += bottomContribution
        if scrollView.contentInset != inset { scrollView.contentInset = inset }
        let desired = oldPosition - scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - desired) > 0.001 { scrollView.contentOffset.y = desired }
        updating = false
        updateIndicators()
    }

    private func updateIndicators() {
        guard !updating, !detached else { return }
        updating = true
        defer { updating = false }
        // 仅有 Header 折叠距离的页面没有正文滚动进度；合成 inset 不应产生一条长指示器。
        let visible = !indicatorsHiddenForPaging && requestedVerticalIndicator && maximumPosition > range + 0.001
        if visible {
            // 仅在需要显示时更新轨道；隐藏期间不处理指示器几何。
            var inset = baseIndicatorInset
            // 页面本身已位于标签栏下方，不再重复缩短指示器轨道。
            inset.top += max(0, range - SPScrollGeometry.collapse(position, range: range) - pageDisplacement)
            if scrollView.verticalScrollIndicatorInsets != inset { scrollView.verticalScrollIndicatorInsets = inset }
        }
        if scrollView.showsVerticalScrollIndicator != visible { scrollView.showsVerticalScrollIndicator = visible }
        let horizontalVisible = !indicatorsHiddenForPaging && requestedHorizontalIndicator
        if scrollView.showsHorizontalScrollIndicator != horizontalVisible { scrollView.showsHorizontalScrollIndicator = horizontalVisible }
    }
}
