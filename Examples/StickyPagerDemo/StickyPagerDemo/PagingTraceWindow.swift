import UIKit

/// 仅供分页 UI 回归观测；不安装识别器、不改变事件分发或滚动代理。
@MainActor
final class PagingTraceWindow: UIWindow {
    private var sequence = 0
    private var samples: [[String: Double]] = []
    private var hitView = ""
    private var release: [String: Double] = [:]
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
            release = [:]
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
            "phase": Double(touch.phase.rawValue),
            "x": point.x,
            "y": point.y,
            "offset": paging.contentOffset.x,
            "pan": Double(pan.state.rawValue),
            "velocity": pan.velocity(in: self).x,
            "translation": pan.translation(in: self).x,
            "sourceOffsetX": sourceScroll?.contentOffset.x ?? 0,
            "verticalPosition": sourceScroll.map { $0.contentOffset.y + $0.adjustedContentInset.top } ?? 0
        ])
        if touch.phase == .ended || touch.phase == .cancelled {
            NSLog("PAGING_EVENT %@", pagingTrace)
        }
    }

    var pagingTrace: String {
        guard let paging = pagingView(in: self) else {
            return ""
        }
        let value: [String: Any] = [
            "sequence": sequence,
            "pointerScrollEvents": pointerScrollEvents,
            "lastPointerScrollTimestamp": lastPointerScrollTimestamp,
            "hitView": hitView,
            "release": release,
            "sourceDeceleratingAtTouchBegan": sourceDeceleratingAtTouchBegan,
            "verticalChanges": verticalChanges,
            "samples": [samples.first, samples.last].compactMap { $0 },
            "sampleCount": samples.count,
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
