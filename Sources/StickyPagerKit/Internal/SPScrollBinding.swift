import UIKit

/// 仅管理框架贡献的 inset，不占用内容滚动视图的 delegate。
@MainActor
internal final class SPScrollBinding {
    let scrollView: UIScrollView
    var onScroll: (@MainActor (SPScrollBinding) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var updating = false
    private var detached = false
    private var topContribution: CGFloat = 0
    private var bottomContribution: CGFloat = 0
    private var baseInset: UIEdgeInsets
    private let originalBounce: Bool
    private var range: CGFloat = 0

    var position: CGFloat { scrollView.contentOffset.y + scrollView.adjustedContentInset.top }
    var maximumPosition: CGFloat {
        max(range, scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom - scrollView.bounds.height)
    }
    var isRefreshing: Bool { scrollView.refreshControl?.isRefreshing == true }

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        baseInset = scrollView.contentInset
        originalBounce = scrollView.alwaysBounceVertical
        scrollView.alwaysBounceVertical = true
        observations = [
            scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.updating, !self.detached else { return }
                    self.onScroll?(self)
                }
            },
            scrollView.observe(\.contentInset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.externalInsetsChanged() }
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

    func setPosition(_ position: CGFloat) {
        guard !detached else { return }
        let y = position - scrollView.adjustedContentInset.top
        guard abs(y - scrollView.contentOffset.y) > 0.001 else { return }
        updating = true
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: false)
        updating = false
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
        scrollView.alwaysBounceVertical = originalBounce
        scrollView.contentOffset.y = contentPosition - scrollView.adjustedContentInset.top
    }

    private func externalInsetsChanged() {
        guard !updating, !detached else { return }
        // 外部赋值视作新的业务基准；框架贡献随后重新叠加。
        baseInset = scrollView.contentInset
        updateGeometry()
    }

    private func updateGeometry() {
        guard !updating, !detached else { return }
        updating = true
        let oldPosition = position
        let adjustment = scrollView.adjustedContentInset.top - scrollView.contentInset.top
        let bottomAdjustment = scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom
        topContribution = range
        bottomContribution = SPScrollGeometry.shortContentInset(
            height: scrollView.bounds.height, contentHeight: scrollView.contentSize.height,
            baseTop: baseInset.top + adjustment, baseBottom: baseInset.bottom + bottomAdjustment)
        var inset = baseInset
        inset.top += topContribution
        inset.bottom += bottomContribution
        if scrollView.contentInset != inset { scrollView.contentInset = inset }
        let desired = oldPosition - scrollView.adjustedContentInset.top
        if abs(scrollView.contentOffset.y - desired) > 0.001 { scrollView.contentOffset.y = desired }
        updating = false
    }
}
