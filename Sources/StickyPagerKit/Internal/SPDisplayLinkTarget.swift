import UIKit

/// displayLink 不直接保留容器，避免动画期间形成循环引用。
@MainActor
internal final class SPDisplayLinkTarget {
    var tick: (@MainActor (CADisplayLink) -> Void)?
    @objc func step(_ link: CADisplayLink) {
        tick?(link)
    }
}
