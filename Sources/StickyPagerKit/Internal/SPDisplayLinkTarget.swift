import UIKit

/// displayLink 不直接保留容器，避免动画期间形成循环引用。
@MainActor
internal final class SPDisplayLinkTarget {
    var tick: (@MainActor (CADisplayLink) -> Void)?
    // 注册期间由 RunLoop 持有 displayLink，target 只保留弱引用。
    private(set) weak var current: CADisplayLink?

    func start() {
        invalidate()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        current = link
        link.add(to: .main, forMode: .common)
    }

    func invalidate() {
        current?.invalidate()
        current = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        tick?(link)
    }
}
