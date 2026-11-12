import UIKit

/// 平移框架自己的呈现层，安全区域继续以容器的正常布局为基准。
@MainActor
internal final class SPBounceContentView: UIView {
    override func setNeedsLayout() {
        super.setNeedsLayout()
        // 标签栏内容测量会通知直接父视图；呈现层必须继续通知拥有布局的容器。
        superview?.setNeedsLayout()
    }

    override var safeAreaInsets: UIEdgeInsets {
        superview?.safeAreaInsets ?? super.safeAreaInsets
    }
}

/// 临时顶部越界不进入折叠量和页面历史。列表原生 pan 保留识别权和业务代理。
@MainActor
internal final class SPTopBounceCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var host: SPPageViewController?
    private weak var record: SPPageRecord?
    private weak var binding: SPScrollBinding?
    private var pan: UIPanGestureRecognizer!
    private var behavior: SPTopBounceBehavior = .page
    private var startPosition: CGFloat = 0
    private var startTranslation: CGFloat = 0
    private var rawPosition: CGFloat = 0
    private var controlsTop = false
    private var dragging = false
    private var headerDragging = false
    private var settlingForPaging = false
    private var generation: UInt = 0
    private var velocity: CGFloat = 0
    private let target = SPDisplayLinkTarget()
    private(set) var displacement: CGFloat = 0
    private(set) var rawDistance: CGFloat = 0

    init(host: SPPageViewController) {
        self.host = host
        super.init()
        target.tick = { [weak self] link in self?.step(link) }
    }

    nonisolated deinit {
        spPerformMainActorCleanup { [target] in target.invalidate() }
    }

    func install() {
        guard let host else {
            return
        }
        pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        host.pagingView.addGestureRecognizer(pan)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let host, let binding = host.currentRecord?.binding,
              host.effectiveTopBounceBehavior == .container,
              binding.scrollView.isScrollEnabled,
              binding.scrollView.panGestureRecognizer.isEnabled,
              !host.selection.isPaging, host.selection.transitionTarget == nil else {
            return false
        }
        let velocity = pan.velocity(in: host.view.window ?? host.view)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let scroll = host?.currentScrollView, let view = touch.view else {
            return false
        }
        return view === scroll || view.isDescendant(of: scroll)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === host?.currentScrollView?.panGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer === host?.returnGesture
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let host else {
            return
        }
        let coordinateView = host.view.window ?? host.view
        switch pan.state {
        case .began:
            guard let record = host.currentRecord, let binding = record.binding else {
                return
            }
            let continuation = rawDistance
            stopLink()
            self.record = record
            self.binding = binding
            behavior = host.effectiveTopBounceBehavior
            dragging = true
            settlingForPaging = false
            controlsTop = continuation > 0
            startTranslation = pan.translation(in: coordinateView).y
            startPosition = max(0, binding.position) - continuation
            rawPosition = startPosition
            if controlsTop {
                binding.setPosition(0)
            }
        case .changed:
            guard dragging, let binding, record === host.currentRecord,
                  record?.binding === binding, binding.scrollView.isScrollEnabled else {
                return
            }
            rawPosition = startPosition - (pan.translation(in: coordinateView).y - startTranslation)
            if rawPosition < 0 {
                controlsTop = true
            }
            coordinate(binding)
            if controlsTop, let record {
                host.vertical.consume(binding, for: record)
            }
        case .ended, .cancelled, .failed:
            guard dragging else {
                return
            }
            dragging = false
            if displacement > 0 {
                startReturn(velocity: pan.state == .ended ? pan.velocity(in: coordinateView).y : 0)
            } else if pan.state != .ended {
                cancel()
            }
        // 正常松手仍保留本次归属，原生减速稍后越过顶部时也必须由容器承接。
        default: break
        }
    }

    /// 原生 offset 通知可能先于我们的 pan target；按同一触摸坐标结算，避免一帧双重位移。
    func coordinate(_ binding: SPScrollBinding) {
        guard let host, self.binding === binding, record === host.currentRecord,
              record?.binding === binding, behavior == .container else {
            return
        }
        if dragging {
            rawPosition = startPosition - (pan.translation(in: host.view.window ?? host.view).y - startTranslation)
            if rawPosition < 0 {
                controlsTop = true
            }
            guard controlsTop else {
                return
            }
            let generation = generation
            binding.setPosition(min(binding.maximumPosition, max(0, rawPosition)))
            guard generation == self.generation, record === host.currentRecord,
                  record?.binding === binding else {
                return
            }
            present(raw: max(0, -rawPosition))
            if rawPosition >= 0 {
                // 反向越过顶部后交还原生范围与底部回弹，并重置下一次过顶的触摸基准。
                controlsTop = false
                startPosition = binding.position
                startTranslation = pan.translation(in: host.view.window ?? host.view).y
            }
        } else if displacement == 0, binding.scrollView.isDecelerating, binding.position < 0 {
            let distance = -binding.position
            let generation = generation
            binding.setPosition(0)
            guard generation == self.generation, record === host.currentRecord,
                  record?.binding === binding else {
                return
            }
            present(raw: distance / 0.55)
            startReturn(velocity: 0)
        } else if displacement > 0 {
            // 回位期间丢弃原生列表的第二份顶部越界；正常程序化定位优先。
            if binding.position <= 0 {
                binding.setPosition(0)
            } else {
                cancel()
            }
        }
    }

    func beginHeader(_ pan: UIPanGestureRecognizer, position: CGFloat) {
        guard let host else {
            return
        }
        stopLink()
        behavior = host.effectiveTopBounceBehavior
        headerDragging = true
        settlingForPaging = false
        record = host.currentRecord
        binding = record?.binding
        if behavior != .container {
            present(raw: 0)
        }
    }

    /// 返回是否保留真实越界拖动基准；页面模式继续沿用到边界立即停止的契约。
    func updateHeader(raw: CGFloat) -> Bool {
        guard headerDragging, behavior == .container else {
            return false
        }
        present(raw: max(0, -raw))
        return raw <= 0
    }

    /// Header／普通页面的惯性到顶后沿用该次手势的归属。
    func absorbHeaderInertia(overshoot: CGFloat, velocity: CGFloat) -> Bool {
        guard behavior == .container, overshoot > 0 else {
            return false
        }
        present(raw: overshoot)
        startReturn(velocity: velocity)
        return true
    }

    func endHeader(velocity: CGFloat) -> Bool {
        headerDragging = false
        guard displacement > 0 else {
            return false
        }
        startReturn(velocity: velocity)
        return true
    }

    func settleForPaging() {
        generation &+= 1
        guard displacement > 0 else {
            cancel(); return
        }
        dragging = false
        headerDragging = false
        controlsTop = false
        record = nil
        binding = nil
        if !settlingForPaging {
            settlingForPaging = true
            startReturn(velocity: 0)
        }
    }

    func cancel() {
        generation &+= 1
        stopLink()
        dragging = false
        headerDragging = false
        controlsTop = false
        settlingForPaging = false
        record = nil
        binding = nil
        present(raw: 0)
    }

    private func present(raw: CGFloat) {
        guard let host else {
            return
        }
        rawDistance = max(0, raw)
        let height = max(1, host.view.bounds.height)
        displacement = height * (1 - 1 / (1 + rawDistance * 0.55 / height))
        applyPresentation()
    }

    private func applyPresentation() {
        host?.bounceContentView.transform = CGAffineTransform(translationX: 0, y: displacement)
    }

    private func stopLink() {
        target.invalidate()
        velocity = 0
    }

    private func startReturn(velocity: CGFloat) {
        stopLink()
        // 映射至阻力后的显示速度，限制极端输入，避免短距离松手反而大幅跳动。
        self.velocity = min(1200, max(-1200, velocity * 0.3))
        target.start()
    }

    private func step(_ link: CADisplayLink) {
        guard let host, settlingForPaging || (record === host.currentRecord &&
            record?.binding === binding && binding?.scrollView.isScrollEnabled != false) else {
            cancel(); return
        }
        let dt = min(1.0 / 30, max(1.0 / 240, link.targetTimestamp - link.timestamp))
        let damping: CGFloat = UIAccessibility.isReduceMotionEnabled ? 34 : 26
        velocity += (-220 * displacement - damping * velocity) * dt
        displacement = max(0, displacement + velocity * dt)
        let height = max(1, host.view.bounds.height)
        rawDistance = displacement / (0.55 * max(0.001, 1 - displacement / height))
        applyPresentation()
        if displacement < 0.25 && abs(velocity) < 5 || displacement == 0 {
            cancel()
        }
    }
}
