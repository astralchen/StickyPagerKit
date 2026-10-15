import UIKit

@MainActor
internal final class SPPagingScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            guard abs(velocity.x) > abs(velocity.y) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
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
