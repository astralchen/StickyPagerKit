import UIKit

/// 协调共享折叠、绑定及纵向交互；位置历史通过 store 写入，不接管业务 delegate。
@MainActor
internal final class SPVerticalScrollCoordinator {
    private weak var host: SPPageViewController?
    init(host: SPPageViewController) {
        self.host = host
    }

    internal private(set) var collapseOffset: CGFloat = 0
    private var interactionGeneration: UInt = 0
    var headerPan: UIPanGestureRecognizer!
    var tabPan: UIPanGestureRecognizer!
    var plainPagePan: UIPanGestureRecognizer!
    private weak var dragRecord: SPPageRecord?
    private weak var dragBinding: SPScrollBinding?
    private weak var dragPan: UIPanGestureRecognizer?
    private var dragStart: CGFloat = 0
    private var animationVelocity: CGFloat = 0
    private let displayTarget = SPDisplayLinkTarget()
    func configureAnimation() {
        displayTarget.tick = { [weak self] link in self?.stepAnimation(link) }
    }

    func updateCollapseRange(_ range: CGFloat, preservingCollapsed: Bool) {
        collapseOffset = preservingCollapsed ? range : min(collapseOffset, range)
    }

    func publishHeader(currentPageOnly: Bool = false) {
        guard let host else {
            return
        }
        host.pageLayout.layoutHeader(currentPageOnly: currentPageOnly)
        let range = host.pageLayout.effectiveLayout.collapseRange
        let progress = range == 0 ? 0 : collapseOffset / range
        let state: SPHeaderState = progress <= 0 ? .expanded : (progress >= 1 ? .collapsed : .collapsing)
        host.delegate?.pageViewController(host, didChangeHeaderState: state, progress: progress)
    }

    func bind(_ record: SPPageRecord) {
        guard let host else {
            return
        }
        // inset 还原和布局可同步回调业务。等待当前解绑完成后再应用最新选择，
        // 避免新绑定读取旧贡献，或旧操作覆盖回调中设置的选择。
        record.needsBinding = true
        guard !record.isPreparingBinding, !record.isBinding else {
            return
        }
        record.isBinding = true
        defer { record.isBinding = false }
        while record.needsBinding, host.records[record.identifier] === record {
            record.needsBinding = false
            applyBinding(record)
        }
    }

    private func applyBinding(_ record: SPPageRecord) {
        guard let host else {
            return
        }
        let root = record.controller.view!
        let scroll: UIScrollView?
        switch record.scrollViewSelection.mode {
        case .automatic:
            scroll = SPScrollViewDiscovery.find(in: root)
        case .unbound:
            scroll = nil
        case .explicit:
            scroll = record.scrollViewSelection.scrollView.flatMap {
                $0 === root || $0.isDescendant(of: root) ? $0 : nil
            }
        }
        if scroll === record.binding?.scrollView {
            return
        }
        if record === host.currentRecord {
            stopAnimation()
        }
        let previous = record.binding
        record.binding = nil
        previous?.detach()
        guard !record.needsBinding, host.records[record.identifier] === record else {
            return
        }
        if host.store.position(for: record.identifier) == nil, let scroll {
            // 尚未叠加框架滚动 inset：此时归一化位移就是业务正文位置。
            // 已有记录（包括 0）继续按页面标识恢复，不被替换列表的初始值覆盖。
            host.store.setPosition(
                max(0, scroll.contentOffset.y + scroll.adjustedContentInset.top),
                for: record.identifier
            )
        }
        record.binding = scroll.map(SPScrollBinding.init)
        record.binding?.onScrollDisabled = { [weak self, weak host, weak record] binding in
            guard let self, let host, let record, record === host.currentRecord, record.binding === binding else {
                return
            }
            // 关闭后立即废弃旧交互，即使同一帧重新开启也不续接原来的拖动或惯性。
            self.stopAnimation()
        }
        record.binding?.onScroll = { [weak self, weak host, weak record] binding in
            guard let self, let host, let record, !host.pageLayout.isLayingOutPages,
                  !host.pageLayout.isTransitioningSize, !host.selection.isPaging,
                  record === host.currentRecord, host.selection.transitionTarget == nil else {
                return
            }
            // 系统尺寸变化可能先发送旧绑定的偏移回调；新几何完成布局前不能改写历史位置。
            guard host.pageLayout.previousBoundsSize == host.view.bounds.size,
                  host.pageLayout.previousCollapseRange == host.pageLayout.effectiveLayout.collapseRange else {
                return
            }
            if #available(iOS 26.0, *),
               host.view.window?.windowScene?.effectiveGeometry.isInteractivelyResizing == true {
                // 持续拖动窗口时，单次尺寸转换会在帧间结束；原生状态仍需保护保存位移。
                self.align(record)
                return
            }
            self.stopAnimation(preservingTopBounce: true)
            self.host?.topBounce.coordinate(binding)
            self.consume(binding, for: record)
        }
        record.binding?.indicatorsHiddenForPaging = host.selection.isPaging && host
            .scrollIndicatorVisibilityPolicy == .hideDuringPaging
        record.binding?.setRange(host.pageLayout.effectiveLayout.collapseRange)
        guard !record.needsBinding, host.records[record.identifier] === record else {
            return
        }
        host.pageLayout.layoutPage(record)
        guard !record.needsBinding, host.records[record.identifier] === record else {
            return
        }
        align(record)
        host.view.setNeedsLayout()
    }

    func align(_ record: SPPageRecord?) {
        guard let host else {
            return
        }
        guard let record, let binding = record.binding else {
            return
        }
        let position = SPScrollGeometry.position(
            collapse: collapseOffset,
            content: host.store.position(for: record.identifier) ?? 0,
            range: host.pageLayout.effectiveLayout.collapseRange
        )
        binding.setPosition(min(binding.maximumPosition, position))
    }

    func consume(_ binding: SPScrollBinding, for record: SPPageRecord) {
        guard let host else {
            return
        }
        guard record === host.currentRecord, record.binding === binding,
              host.records[record.identifier] === record else {
            return
        }
        let range = host.pageLayout.effectiveLayout.collapseRange
        collapseOffset = SPScrollGeometry.collapse(binding.position, range: range)
        host.store.setPosition(SPScrollGeometry.content(binding.position, range: range), for: record.identifier)
        publishHeader(currentPageOnly: true)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let host else {
            return false
        }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let record = host.currentRecord,
              host.selection.transitionTarget == nil else {
            return false
        }
        if record.binding?.scrollView.isScrollEnabled == false {
            return false
        }
        if let dragPan, dragPan !== pan {
            return false
        }
        if gestureRecognizer === plainPagePan &&
            (record.binding != nil || record.scrollViewSelection.mode != .automatic) {
            return false
        }
        if record.binding == nil && host.pageLayout.effectiveLayout.collapseRange <= 0,
           host.effectiveTopBounceBehavior != .container {
            return false
        }
        let v = pan.velocity(in: host.view)
        return abs(v.y) > abs(v.x)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let candidate = target, candidate !== gestureRecognizer.view {
            // 默认标签按钮允许父级纵向拖动，其他 Header 控件保留自身交互。
            if gestureRecognizer === headerPan || gestureRecognizer === plainPagePan {
                if candidate is UIControl || candidate is UITextView {
                    return false
                }
                if candidate.gestureRecognizers?
                    .contains(where: { $0.isEnabled && $0 !== gestureRecognizer && !($0 is UITapGestureRecognizer) }) ==
                    true {
                    return false
                }
            }
            target = candidate.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let host else {
            return false
        }
        return gestureRecognizer === tabPan && otherGestureRecognizer.view?.isDescendant(of: host.storedTabBar) == true
    }

    func handleHeaderPan(_ pan: UIPanGestureRecognizer) {
        guard let host else {
            return
        }
        guard let record = host.currentRecord, host.selection.transitionTarget == nil else {
            return
        }
        let binding = record.binding
        // 业务禁用列表滚动时暂停整次纵向联动；保留布局及切页使用的程序化协调。
        guard binding?.scrollView.isScrollEnabled != false else {
            stopAnimation()
            return
        }
        // 切页、重新绑定或布局变化后，旧触摸不能继续驱动新的滚动状态。
        if pan.state == .began {
            if let dragPan, dragPan !== pan {
                return
            }
        } else if dragPan !== pan || dragRecord !== record || dragBinding !== binding {
            return
        }
        switch pan.state {
        case .began:
            stopAnimation(preservingTopBounce: true)
            dragRecord = record; dragBinding = binding; dragPan = pan
            // 先登记交互，让停止原生减速时的同步业务回调也能取消本次拖动。
            binding?.stopDeceleration()
            guard dragPan === pan, dragRecord === record, dragBinding === binding else {
                return
            }
            dragStart = binding?.position ?? collapseOffset
            host.topBounce.beginHeader(pan, position: dragStart)
            dragStart -= host.topBounce.rawDistance
        case .changed:
            let translation = pan.translation(in: host.view).y
            let raw = dragStart - translation
            let maximum = binding?.maximumPosition ?? host.pageLayout.effectiveLayout.collapseRange
            let bound = min(max(0, raw), maximum)
            // 丢弃越界距离并同步手势基准，反向拖动立即生效，不积累边界外的空行程。
            if !host.topBounce.updateHeader(raw: raw) {
                dragStart = bound + translation
            }
            if let binding {
                // 框架拖动仅协调合法范围，列表原生回弹由业务配置和 UIKit 管理。
                let generation = interactionGeneration
                binding.setPosition(bound)
                guard generation == interactionGeneration, dragPan === pan,
                      dragRecord === record, dragBinding === binding else {
                    return
                }
                consume(binding, for: record)
            } else {
                // 普通页面只消耗 Header 范围，不生成内容位移或越界回弹。
                collapseOffset = bound
                publishHeader(currentPageOnly: true)
            }
        case .ended:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = -pan.velocity(in: host.view).y
            if !host.topBounce.endHeader(velocity: -animationVelocity) {
                startAnimation()
            }
        case .cancelled, .failed:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = 0
            if host.topBounce.endHeader(velocity: 0) {
                return
            } else if binding != nil {
                startAnimation()
            } else {
                stopAnimation()
            }
        default: break
        }
    }

    private func startAnimation() {
        displayTarget.start()
    }

    func stopAnimation(preservingTopBounce: Bool = false, settlingTopBounce: Bool = false) {
        if settlingTopBounce {
            host?.topBounce.settleForPaging()
        } else if !preservingTopBounce {
            host?.topBounce.cancel()
        }
        interactionGeneration &+= 1
        displayTarget.invalidate()
        dragRecord = nil; dragBinding = nil; dragPan = nil
    }

    private func stepAnimation(_ link: CADisplayLink) {
        guard let host else {
            return
        }
        guard let record = host.currentRecord, host.selection.transitionTarget == nil else {
            stopAnimation(); return
        }
        let dt = min(1.0 / 30, max(1.0 / 240, link.targetTimestamp - link.timestamp))
        guard let binding = record.binding else {
            animationVelocity *= pow(UIScrollView.DecelerationRate.normal.rawValue, dt * 1000)
            let raw = collapseOffset + animationVelocity * dt
            collapseOffset = SPScrollGeometry.collapse(raw, range: host.pageLayout.effectiveLayout.collapseRange)
            publishHeader(currentPageOnly: true)
            if raw < 0, host.topBounce.absorbHeaderInertia(overshoot: -raw, velocity: -animationVelocity) {
                stopAnimation(preservingTopBounce: true)
                return
            }
            if abs(animationVelocity) < 2 || collapseOffset <= 0 || collapseOffset >= host.pageLayout.effectiveLayout
                .collapseRange {
                stopAnimation()
            }
            return
        }
        guard binding.scrollView.isScrollEnabled else {
            stopAnimation()
            return
        }
        animationVelocity *= pow(binding.scrollView.decelerationRate.rawValue, dt * 1000)
        let raw = binding.position + animationVelocity * dt
        let position = min(max(0, raw), binding.maximumPosition)
        let generation = interactionGeneration
        binding.setPosition(position)
        guard generation == interactionGeneration, displayTarget.current === link,
              record === host.currentRecord, record.binding === binding else {
            return
        }
        consume(binding, for: record)
        guard generation == interactionGeneration, displayTarget.current === link else {
            return
        }
        if raw < 0, host.topBounce.absorbHeaderInertia(overshoot: -raw, velocity: -animationVelocity) {
            stopAnimation(preservingTopBounce: true)
            return
        }
        // 页面策略保持到边界停止；容器策略的顶部惯性由独立回弹协调器承接。
        if abs(animationVelocity) < 2 || position <= 0 || position >= binding.maximumPosition {
            stopAnimation()
        }
    }
}
