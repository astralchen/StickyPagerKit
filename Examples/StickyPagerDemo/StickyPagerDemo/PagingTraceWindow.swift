import UIKit

/// 仅供分页 UI 回归观测，不安装识别器或替换滚动代理。
/// --coalesced-pan-regression／--coalesced-vertical-pan-regression 注入停顿；
/// --cancel-pan-regression 在真实拖动中取消 pan。
@MainActor
final class PagingTraceWindow: UIWindow {
    private weak var observedPan: UIPanGestureRecognizer?
    private var cancelledSequence = -1
    private var cancelledOffsets: [CGFloat] = []
    private var selectionEvents: [Int] = []

    func recordSelection(_ index: Int) {
        selectionEvents.append(index)
    }

    @objc private func observePan(_ pan: UIPanGestureRecognizer) {
        if pan.state == .cancelled, let scroll = pan.view as? UIScrollView {
            cancelledOffsets.append(scroll.contentOffset.x)
        }
    }

    private var stalledSequence = -1
    private var sequence = 0
    private var samples: [[String: Double]] = []
    private var hitView = ""
    private var release: [String: Double] = [:]
    private var verticalRelease: [String: Double] = [:]
    private weak var sourceScroll: UIScrollView?
    private var previousVertical: CGFloat = 0
    private var verticalChanges: [[String: Any]] = []
    private var sourceDeceleratingAtTouchBegan = false
    // 滚轮不一定带有 UITouch；单独计数，避免把输入干扰误判为菜单未响应。
    private var pointerScrollEvents = 0
    private var lastPointerScrollTimestamp: TimeInterval = 0

    func mark(_ stage: String) {
        guard let sourceScroll else {
            return
        }
        let value = sourceScroll.contentOffset.y + sourceScroll.adjustedContentInset.top
        if value != previousVertical {
            verticalChanges.append(["stage": stage, "before": previousVertical, "after": value])
            previousVertical = value
        }
    }

    func recordRelease(_ scrollView: UIScrollView, velocity: CGPoint, target: CGPoint) {
        release = ["offset": scrollView.contentOffset.x, "velocity": velocity.x, "target": target.x]
    }

    func recordVerticalRelease(_ scrollView: UIScrollView, velocity: CGPoint, target: CGPoint) {
        verticalRelease = [
            "offset": scrollView.contentOffset.y,
            "velocity": velocity.y,
            "target": target.y,
            "position": scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        ]
    }

    private func pagingView(in view: UIView) -> UIScrollView? {
        if view.accessibilityIdentifier == "sp.pages" {
            return view as? UIScrollView
        }
        for child in view.subviews {
            if let result = pagingView(in: child) {
                return result
            }
        }
        return nil
    }

    override func sendEvent(_ event: UIEvent) {
        if event.type == .scroll {
            pointerScrollEvents += 1
            lastPointerScrollTimestamp = event.timestamp
        }
        // hover／scroll 的 allTouches 可能包含区域事件，不能覆盖上一次真实触摸。
        let touch = event.type == .touches ? event.allTouches?.first : nil
        if touch?.phase == .began {
            sequence += 1
            samples.removeAll(keepingCapacity: true)
            cancelledOffsets = []
            selectionEvents = []
            if let paging = pagingView(in: self), observedPan !== paging.panGestureRecognizer {
                observedPan?.removeTarget(self, action: #selector(observePan(_:)))
                observedPan = paging.panGestureRecognizer
                observedPan?.addTarget(self, action: #selector(observePan(_:)))
            }
            release = [:]
            verticalRelease = [:]
            verticalChanges = []
            var ancestor = touch?.view
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            sourceScroll = ancestor as? UIScrollView
            sourceDeceleratingAtTouchBegan = sourceScroll?.isDecelerating == true
            previousVertical = sourceScroll.map { $0.contentOffset.y + $0.adjustedContentInset.top } ?? 0
            hitView = touch?.view.map { String(describing: type(of: $0)) } ?? "nil"
        }
        super.sendEvent(event)
        guard let touch, let paging = pagingView(in: self), samples.count < 256 else {
            return
        }
        let point = touch.location(in: self)
        let pan = paging.panGestureRecognizer
        mark("touch-\(touch.phase.rawValue)")
        samples.append([
            "time": touch.timestamp,
            "deliveryTime": CACurrentMediaTime(),
            "previousX": touch.previousLocation(in: self).x,
            "coalescedCount": Double(event.coalescedTouches(for: touch)?.count ?? 0),
            "phase": Double(touch.phase.rawValue),
            "x": point.x,
            "y": point.y,
            "offset": paging.contentOffset.x,
            "pan": Double(pan.state.rawValue),
            "velocity": pan.velocity(in: self).x,
            "translation": pan.translation(in: self).x,
            "sourceOffsetX": sourceScroll?.contentOffset.x ?? 0,
            "sourceVelocityY": sourceScroll?.panGestureRecognizer.velocity(in: self).y ?? 0,
            "sourcePan": Double(sourceScroll?.panGestureRecognizer.state.rawValue ?? 0),
            "verticalPosition": sourceScroll.map { $0.contentOffset.y + $0.adjustedContentInset.top } ?? 0
        ])
        if ProcessInfo.processInfo.arguments.contains("--cancel-pan-regression"),
           pan.state == .changed, cancelledSequence != sequence,
           let first = samples.first,
           abs(paging.contentOffset.x - (first["offset"] ?? paging.contentOffset.x)) > paging.bounds.width * 0.6 {
            cancelledSequence = sequence
            // 真实触摸期间禁用识别器，让 UIKit 产生 .cancelled；不手动提交或恢复页码。
            pan.isEnabled = false
            DispatchQueue.main.async { pan.isEnabled = true }
        }
        if ProcessInfo.processInfo.arguments.contains("--coalesced-pan-regression"),
           pan.state == .began, stalledSequence != sequence {
            stalledSequence = sequence
            // 回归夹具：在方向已获接受后模拟一次主线程停顿，促使 UIKit 合并后续移动事件。
            // 甩动路径较短，使用短停顿合并中间事件，并让后续移动自然形成松手速度。
            let duration = ProcessInfo.processInfo.arguments.contains("--momentum-pan-regression") ? 0.06 : 0.65
            Thread.sleep(forTimeInterval: duration)
        }
        if ProcessInfo.processInfo.arguments.contains("--coalesced-vertical-pan-regression"),
           sourceScroll?.panGestureRecognizer.state == .began, stalledSequence != sequence {
            stalledSequence = sequence
            Thread.sleep(forTimeInterval: 0.3)
        }
        if touch.phase == .ended || touch.phase == .cancelled {
            NSLog("PAGING_EVENT %@", pagingTrace)
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("sp-pan-\(ProcessInfo.processInfo.processIdentifier)-\(sequence).json")
            if let data = try? JSONSerialization.data(withJSONObject: samples, options: [.sortedKeys]) {
                try? data.write(to: url)
            }
        }
    }

    private var touchReversals: Int {
        var direction: Double = 0
        var reversals = 0
        for (a, b) in zip(samples, samples.dropFirst()) {
            let delta = (b["x"] ?? 0) - (a["x"] ?? 0)
            guard abs(delta) > 0.5 else {
                continue
            }
            let next: Double = delta > 0 ? 1 : -1
            if direction != 0, next != direction {
                reversals += 1
            }
            direction = next
        }
        return reversals
    }

    var pagingTrace: String {
        guard let paging = pagingView(in: self) else {
            return ""
        }
        let value: [String: Any] = [
            "sequence": sequence,
            "cancelledOffsets": cancelledOffsets,
            "selectionEvents": selectionEvents,
            "touchReversals": touchReversals,
            "pointerScrollEvents": pointerScrollEvents,
            "lastPointerScrollTimestamp": lastPointerScrollTimestamp,
            "hitView": hitView,
            "release": release,
            "verticalRelease": verticalRelease,
            "sourceDeceleratingAtTouchBegan": sourceDeceleratingAtTouchBegan,
            "verticalChanges": verticalChanges,
            "samples": [samples.first, samples.last].compactMap { $0 },
            "sampleCount": samples.count,
            "firstPan": samples.first { ($0["pan"] ?? 0) > 0 } ?? [:],
            "beganSamples": samples.filter { $0["pan"] == 1 },
            "firstMoved": samples.first { $0["phase"] == 1 } ?? [:],
            "maxTouchGap": zip(samples, samples.dropFirst()).map { ($1["time"] ?? 0) - ($0["time"] ?? 0) }.max() ?? 0,

            "minOffset": samples.compactMap { $0["offset"] }.min() ?? paging.contentOffset.x,
            "maxOffset": samples.compactMap { $0["offset"] }.max() ?? paging.contentOffset.x,
            "offset": paging.contentOffset.x,
            "width": paging.bounds.width,
            "dragging": paging.isDragging,
            "decelerating": paging.isDecelerating
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return ""
        }
        return data.base64EncodedString()
    }
}
