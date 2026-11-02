import UIKit

/// 统一驱动指示器与横向偏移；只保存呈现状态，提交索引仍由 SPTabBar 持有。
@MainActor
internal final class SPTabBarPresentationCoordinator {
    struct Transition {
        let from: Int
        let to: Int
        let progress: CGFloat
    }

    struct Origin {
        let indicator: CGRect
        let offset: CGFloat
        let fromGeometry: CGRect
        let toGeometry: CGRect
    }

    struct Animation {
        let fromIndex: Int?
        let toIndex: Int?
        let fromIndicator: CGRect
        let toIndicator: CGRect
        let fromGeometry: CGRect
        let fromOffset: CGFloat
        let toOffset: CGFloat
        let startTime: CFTimeInterval
    }

    struct Frame {
        let indicator: CGRect
        let offset: CGFloat
        let from: Int?
        let to: Int?
        let progress: CGFloat
    }

    private enum Motion {
        case idle
        case selection(Animation)
        case paging(Transition, Origin?)
    }

    private var motion: Motion = .idle
    private var generation: UInt = 0
    private var displayLink: CADisplayLink?
    private let displayTarget = SPDisplayLinkTarget()
    private(set) var pendingSelection: SPTabBarItem?
    private(set) var requestGeneration: UInt = 0
    var renderedTransition: (from: Int?, to: Int?, progress: CGFloat)?
    var onFrame: ((Frame) -> Void)?

    init() {
        displayTarget.tick = { [weak self] link in
            guard let self, link === self.displayLink, let animation = self.animation else {
                return
            }
            self.advance(to: CGFloat((link.timestamp - animation.startTime) / 0.25))
        }
    }

    isolated deinit { displayLink?.invalidate() }

    var animation: Animation? {
        guard case let .selection(value) = motion else {
            return nil
        }
        return value
    }

    var transition: Transition? {
        guard case let .paging(value, _) = motion else {
            return nil
        }
        return value
    }

    var origin: Origin? {
        guard case let .paging(_, value) = motion else {
            return nil
        }
        return value
    }

    func presentationIndex(items: [SPTabBarItem], selectedIndex: Int?) -> Int? {
        if let pendingSelection, let index = items.firstIndex(where: { $0 === pendingSelection }) {
            return index
        }
        if let transition {
            return transition.progress >= 0.5 ? transition.to : transition.from
        }
        return selectedIndex
    }

    func beginRequest() -> UInt {
        requestGeneration &+= 1
        return requestGeneration
    }

    func setPendingSelection(_ item: SPTabBarItem?) {
        pendingSelection = item
    }

    func cancelRequest() {
        pendingSelection = nil
        requestGeneration &+= 1
    }

    func takePendingSelection() -> SPTabBarItem? {
        let item = pendingSelection
        pendingSelection = nil
        return item
    }

    func resetMotion() {
        stopAnimation()
        motion = .idle
        generation &+= 1
    }

    func discardOrigin() {
        if let transition {
            motion = .paging(transition, nil)
        }
    }

    func setTransition(from: Int, to: Int, progress: CGFloat, takeoverOrigin: Origin?) {
        let retainedOrigin = transition?.from == from && transition?.to == to ? origin : takeoverOrigin
        stopAnimation()
        motion = .paging(Transition(from: from, to: to, progress: min(1, max(0, progress))), retainedOrigin)
        generation &+= 1
    }

    func startAnimation(_ animation: Animation) {
        resetMotion()
        motion = .selection(animation)
        let current = generation
        advance(to: 0)
        // 应用帧可能同步进入宿主；旧动画不能再安装时钟覆盖新请求。
        guard current == generation, self.animation != nil else {
            return
        }
        let link = CADisplayLink(target: displayTarget, selector: #selector(SPDisplayLinkTarget.step(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        if animation != nil {
            motion = .idle
            generation &+= 1
        }
    }

    func advance(to progress: CGFloat) {
        guard let animation, progress.isFinite else {
            return
        }
        let current = generation
        let p = min(1, max(0, progress))
        let eased = p * p * (3 - 2 * p)
        onFrame?(Self.frame(
            from: animation.fromIndex,
            to: animation.toIndex,
            progress: eased,
            fromIndicator: animation.fromIndicator,
            toIndicator: animation.toIndicator,
            fromOffset: animation.fromOffset,
            toOffset: animation.toOffset
        ))
        if p == 1, current == generation {
            stopAnimation()
        }
    }

    /// 同一归一化进度同时决定几何、滚动偏移和自定义指示器状态。
    static func frame(
        from: Int?,
        to: Int?,
        progress: CGFloat,
        fromIndicator: CGRect,
        toIndicator: CGRect,
        fromOffset: CGFloat,
        toOffset: CGFloat
    ) -> Frame {
        let a = fromIndicator, b = toIndicator, p = progress
        return Frame(
            indicator: CGRect(
                x: a.minX + (b.minX - a.minX) * p,
                y: a.minY + (b.minY - a.minY) * p,
                width: a.width + (b.width - a.width) * p,
                height: a.height + (b.height - a.height) * p
            ),
            offset: fromOffset + (toOffset - fromOffset) * p,
            from: from,
            to: to,
            progress: p
        )
    }
}
