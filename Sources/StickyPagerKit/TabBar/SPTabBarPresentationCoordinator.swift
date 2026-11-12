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

    struct SpringSnapshot {
        var weights: [Int: SPTabSpringValue]
        var centerX: SPTabSpringValue
        var centerY: SPTabSpringValue
    }

    private(set) var springSnapshot: SpringSnapshot?
    private var springOrigin: SpringSnapshot?
    private var pagingSpringWeights: [Int: SPTabSpringValue]?
    private var animationStyle = SPTabBarAnimationStyle.standard

    func scaleWeight(at index: Int, fallback: CGFloat) -> CGFloat {
        springSnapshot?.weights[index]?.position ?? fallback
    }

    private enum Motion {
        case idle
        case selection(Animation)
        case paging(Transition, Origin?)
    }

    // 稀疏权重只保存呈现，不保存 Item，也不改变已提交选择。
    private var contentProgress: [Int: CGFloat]?
    private var animationContentOrigin: [Int: CGFloat] = [:]
    private var animationIndicatorMotion = SPTabBarVisualStyle.IndicatorMotion.linear
    private var pagingContentOrigin: [Int: CGFloat]?

    func contentWeights(selectedIndex: Int?) -> [Int: CGFloat] {
        contentProgress ?? selectedIndex.map { [$0: 1] } ?? [:]
    }

    func prepareContentProgress(_ origin: [Int: CGFloat]?, spring: SpringSnapshot? = nil) {
        contentProgress = origin
        springSnapshot = spring
    }

    private func interpolateContent(from origin: [Int: CGFloat], to index: Int?, progress: CGFloat) {
        var weights = origin.mapValues { $0 * (1 - progress) }
        if let index {
            weights[index, default: 0] += progress
        }
        contentProgress = weights.filter { $0.value > 0 }
    }

    private var motion: Motion = .idle
    private var generation: UInt = 0
    private let displayTarget = SPDisplayLinkTarget()
    private(set) var pendingSelection: SPTabBarItem?
    private(set) var requestGeneration: UInt = 0
    var renderedTransition: (from: Int?, to: Int?, progress: CGFloat)?
    var onFrame: ((Frame) -> Void)?

    init() {
        displayTarget.tick = { [weak self] link in
            guard let self, link === self.displayTarget.current, let animation = self.animation else {
                return
            }
            self
                .advance(to: CGFloat((link.timestamp - animation.startTime) /
                        (self.animationStyle == .spring ? 0.5 : 0.25)))
        }
    }

    nonisolated deinit {
        spPerformMainActorCleanup { [displayTarget] in displayTarget.invalidate() }
    }

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
        contentProgress = nil
        pagingContentOrigin = nil
        springSnapshot = nil
        springOrigin = nil
        pagingSpringWeights = nil
        generation &+= 1
    }

    func discardOrigin() {
        if let transition {
            motion = .paging(transition, nil)
            pagingContentOrigin = nil
            pagingSpringWeights = nil
            springSnapshot = nil
            interpolateContent(from: [transition.from: 1], to: transition.to, progress: transition.progress)
        }
    }

    func setTransition(from: Int, to: Int, progress: CGFloat, takeoverOrigin: Origin?) {
        let sameTransition = transition?.from == from && transition?.to == to
        let retainedOrigin = sameTransition ? origin : takeoverOrigin
        let retainedContent = sameTransition ? pagingContentOrigin : (animation == nil ? nil : contentProgress)
        let retainedSpring = sameTransition ? pagingSpringWeights : (animation == nil ? nil : springSnapshot?.weights)
        stopAnimation()
        pagingSpringWeights = retainedSpring
        springSnapshot = nil
        if let retainedSpring {
            let p = min(1, max(0, progress))
            var weights = retainedSpring.mapValues { SPTabSpringValue(position: $0.position * (1 - p)) }
            weights[to, default: SPTabSpringValue(position: 0)].position += p
            springSnapshot = SpringSnapshot(weights: weights, centerX: .init(position: 0), centerY: .init(position: 0))
        }
        pagingContentOrigin = retainedContent
        interpolateContent(from: retainedContent ?? [from: 1], to: to, progress: min(1, max(0, progress)))
        motion = .paging(Transition(from: from, to: to, progress: min(1, max(0, progress))), retainedOrigin)
        generation &+= 1
    }

    func startAnimation(
        _ animation: Animation,
        contentOrigin: [Int: CGFloat] = [:],
        indicatorMotion: SPTabBarVisualStyle.IndicatorMotion = .linear,
        style: SPTabBarAnimationStyle = .standard,
        spring: SpringSnapshot? = nil
    ) {
        resetMotion()
        animationStyle = style
        springOrigin = style == .spring ? (spring ?? SpringSnapshot(
            weights: contentOrigin.mapValues { SPTabSpringValue(position: $0) },
            centerX: .init(position: animation.fromIndicator.midX),
            centerY: .init(position: animation.fromIndicator.midY)
        )) : nil
        // 几何可能在接管前重算；位置以实际 frame 为准，速度只在程序动画之间延续。
        springOrigin?.centerX.position = animation.fromIndicator.midX
        springOrigin?.centerY.position = animation.fromIndicator.midY
        animationContentOrigin = contentOrigin
        animationIndicatorMotion = indicatorMotion
        motion = .selection(animation)
        let current = generation
        advance(to: 0)
        // 应用帧可能同步进入宿主；旧动画不能再安装时钟覆盖新请求。
        guard current == generation, self.animation != nil else {
            return
        }
        displayTarget.start()
    }

    func stopAnimation() {
        displayTarget.invalidate()
        if animation != nil {
            contentProgress = nil
            springSnapshot = nil
            springOrigin = nil
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
        let bounded = animationStyle == .spring ? min(1, p * 2) : p
        let eased = bounded * bounded * (3 - 2 * bounded)
        interpolateContent(from: animationContentOrigin, to: animation.toIndex, progress: eased)
        var frame = Self.frame(
            from: animation.fromIndex,
            to: animation.toIndex,
            progress: eased,
            fromIndicator: animation.fromIndicator,
            toIndicator: animation.toIndicator,
            fromOffset: animation.fromOffset,
            toOffset: animation.toOffset,
            indicatorMotion: animationIndicatorMotion
        )
        if let origin = springOrigin {
            var weights: [Int: SPTabSpringValue] = [:]
            let indices = Set(origin.weights.keys).union(animation.toIndex.map { [$0] } ?? [])
            for index in indices {
                let target: CGFloat = index == animation.toIndex ? 1 : 0
                weights[index] = p == 1 ? .init(position: target) :
                    (origin.weights[index] ?? .init(position: 0)).value(
                        toward: target,
                        time: p * 0.5,
                        limits: -0.15 ... 1.15
                    )
            }
            let x = p == 1 ? SPTabSpringValue(position: animation.toIndicator.midX) :
                origin.centerX.value(toward: animation.toIndicator.midX, time: p * 0.5)
            let y = p == 1 ? SPTabSpringValue(position: animation.toIndicator.midY) :
                origin.centerY.value(toward: animation.toIndicator.midY, time: p * 0.5)
            springSnapshot = SpringSnapshot(weights: weights, centerX: x, centerY: y)
            if !animation.fromIndicator.isEmpty, !animation.toIndicator.isEmpty {
                frame = Frame(
                    indicator: p == 0 ? animation.fromIndicator : (p == 1 ? animation.toIndicator : CGRect(
                        x: x.position - frame.indicator.width / 2,
                        y: y.position - frame.indicator.height / 2,
                        width: frame.indicator.width,
                        height: frame.indicator.height
                    )),
                    offset: frame.offset,
                    from: frame.from,
                    to: frame.to,
                    progress: frame.progress
                )
            }
        }
        onFrame?(frame)
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
        toOffset: CGFloat,
        indicatorMotion: SPTabBarVisualStyle.IndicatorMotion = .linear
    ) -> Frame {
        let a = fromIndicator, b = toIndicator, p = progress
        return Frame(
            indicator: SPTabBarVisualStyle.indicatorFrame(from: a, to: b, progress: p, motion: indicatorMotion),
            offset: fromOffset + (toOffset - fromOffset) * p,
            from: from,
            to: to,
            progress: p
        )
    }
}
