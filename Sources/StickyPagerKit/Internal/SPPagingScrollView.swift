import UIKit

@MainActor
internal final class SPPagingScrollView: UIScrollView, UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            guard shouldPage(at: panGestureRecognizer.location(in: self), velocity: velocity) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// 内部横向列表先等待容器判定；容器仅在内部无法沿拖动方向继续滚动时开始分页。
    /// 保留 UIScrollView 自身作为 pan 的 delegate，不更换业务或 UIKit 内部代理。
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer,
              let scroll = otherGestureRecognizer.view as? UIScrollView,
              otherGestureRecognizer === scroll.panGestureRecognizer,
              scroll !== self, scroll.isDescendant(of: self) else { return false }
        return horizontalRange(of: scroll).count > 0.5
    }

    internal func shouldPage(at point: CGPoint, velocity: CGPoint) -> Bool {
        guard abs(velocity.x) > abs(velocity.y), canScroll(self, velocityX: velocity.x) else { return false }
        var candidate = hitTest(point, with: nil)
        while let view = candidate, view !== self {
            if let scroll = view as? UIScrollView, scroll.isScrollEnabled, scroll.panGestureRecognizer.isEnabled {
                if canScroll(scroll, velocityX: velocity.x) { return false }
            }
            candidate = view.superview
        }
        return true
    }

    private func horizontalRange(of scroll: UIScrollView) -> (lower: CGFloat, upper: CGFloat, count: CGFloat) {
        let lower = -scroll.adjustedContentInset.left
        let upper = max(lower, scroll.contentSize.width - scroll.bounds.width + scroll.adjustedContentInset.right)
        return (lower, upper, upper - lower)
    }

    private func canScroll(_ scroll: UIScrollView, velocityX: CGFloat) -> Bool {
        let range = horizontalRange(of: scroll)
        guard range.count > 0.5 else { return false }
        // 使用物理方向和实际边界，RTL 无需反转；弹性越界时仍允许向内容内部拖回。
        return velocityX > 0 ? scroll.contentOffset.x > range.lower + 0.5
            : scroll.contentOffset.x < range.upper - 0.5
    }
}

/// displayLink 不直接保留容器，避免动画期间形成循环引用。
@MainActor
internal final class SPDisplayLinkTarget {
    var tick: (@MainActor (CADisplayLink) -> Void)?
    @objc func step(_ link: CADisplayLink) { tick?(link) }
}

@MainActor
internal final class SPPageRecord {
    let identifier: AnyHashable
    let controller: UIViewController
    var binding: SPScrollBinding?
    weak var explicitScrollView: UIScrollView?
    var access: UInt = 0
    init(identifier: AnyHashable, controller: UIViewController) {
        self.identifier = identifier
        self.controller = controller
    }
}
