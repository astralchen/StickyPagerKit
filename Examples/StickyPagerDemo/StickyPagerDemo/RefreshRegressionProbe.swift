import UIKit
import StickyPagerKit

/// 仅供刷新 UI 回归使用，按实际显示帧记录 Header，避免只断言手势终态。
@MainActor
final class RefreshRegressionProbe {
    static var enabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--refresh-regression")
    }

    private weak var page: DemoList?
    private var displayLink: CADisplayLink?
    private let target = RefreshFrameTarget()
    private var baselineTabY: CGFloat?
    private var minimumDragTabY: CGFloat?
    private(set) var metrics: [String: Double] = [:]

    var currentHeaderY: CGFloat? {
        (page?.parent as? SPPageViewController)?.tabBar.frame.minY
    }

    init(page: DemoList) {
        self.page = page; target.owner = self
        page.tableView.panGestureRecognizer.addTarget(target, action: #selector(RefreshFrameTarget.panChanged(_:)))
    }

    isolated deinit {
        displayLink?.invalidate()
        page?.tableView.panGestureRecognizer.removeTarget(target, action: #selector(RefreshFrameTarget.panChanged(_:)))
    }

    func beginRefreshing() {
        displayLink?.invalidate()
        displayLink = nil
        baselineTabY = nil
        minimumDragTabY = nil
        metrics = ["refreshStarted": 1]
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, let page = self.page, let pager = page.parent as? SPPageViewController,
                  let index = pager.selectedIndex else {
                return
            }
            pager.setSelectedIndex(0, animated: false)
            if let grid = pager.children.compactMap({ $0 as? DemoGrid }).first {
                grid.collectionView.contentOffset.y = 500 - grid.collectionView.adjustedContentInset.top
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            pager.setSelectedIndex(index, animated: false)
            self.metrics["returnedRefreshing"] = page.refreshControl?.isRefreshing == true ? 1 : 0
        }
    }

    func willEndRefreshing() {
        guard let page, let pager = page.parent as? SPPageViewController else {
            return
        }
        baselineTabY = pager.tabBar.frame.minY
        metrics["beforeEndPosition"] = Double(page.tableView.contentOffset.y + page.tableView.adjustedContentInset.top)
        metrics["maxReverseHeaderMovement"] = 0
        metrics["dragFrames"] = 0
    }

    func didEndRefreshing() {
        // 在原生刷新回调及框架的几何收尾完成后、下一次真实触摸前检查状态。
        DispatchQueue.main.async { [weak self] in self?.recordEndedGeometry() }
    }

    private func recordEndedGeometry() {
        guard let page, let pager = page.parent as? SPPageViewController else {
            return
        }
        metrics["refreshEnded"] = 1
        metrics["afterEndHeaderDelta"] = Double(pager.tabBar.frame.minY - (baselineTabY ?? pager.tabBar.frame.minY))
        metrics["afterEndPosition"] = Double(page.tableView.contentOffset.y + page.tableView.adjustedContentInset.top)
        metrics["afterEndContentHeight"] = Double(page.tableView.contentSize.height)
        metrics["afterEndGap"] = Double(page.tableView.convert(.zero, to: page.view.window).y
            - pager.tabBar.convert(pager.tabBar.bounds, to: page.view.window).maxY)
    }

    // 仅在真实 pan 期间采样，避免让测试辅助 display link 持续影响 XCTest 的空闲等待。
    fileprivate func panChanged(_ pan: UIPanGestureRecognizer) {
        guard metrics["refreshEnded"] == 1 else {
            return
        }
        switch pan.state {
        case .began, .changed:
            guard displayLink == nil else {
                return
            }
            guard let page, let pager = page.parent as? SPPageViewController else {
                return
            }
            // reloadData 的原生行高结算可能发生在刷新结束与触摸之间；拖动方向从真实 pan 开始计量。
            minimumDragTabY = pager.tabBar.frame.minY
            metrics["dragStartHeaderDelta"] = Double(pager.tabBar.frame
                .minY - (baselineTabY ?? pager.tabBar.frame.minY))
            metrics["dragStartPosition"] = Double(page.tableView.contentOffset.y + page.tableView.adjustedContentInset
                .top)
            metrics["dragStartContentHeight"] = Double(page.tableView.contentSize.height)
            let link = CADisplayLink(target: target, selector: #selector(RefreshFrameTarget.tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        case .ended, .cancelled, .failed:
            displayLink?.invalidate()
            displayLink = nil
        default: break
        }
    }

    fileprivate func sample() {
        guard metrics["refreshEnded"] == 1, let page, let pager = page.parent as? SPPageViewController,
              let minimumDragTabY, page.tableView.panGestureRecognizer.state == .changed else {
            return
        }
        metrics["dragFrames", default: 0] += 1
        let tabY = Double(pager.tabBar.frame.minY)
        metrics["maxDragTabY"] = max(metrics["maxDragTabY"] ?? tabY, tabY)
        metrics["maxReverseHeaderMovement"] = max(
            metrics["maxReverseHeaderMovement", default: 0],
            Double(pager.tabBar.frame.minY - minimumDragTabY)
        )
        self.minimumDragTabY = min(minimumDragTabY, pager.tabBar.frame.minY)
    }
}

@MainActor
private final class RefreshFrameTarget: NSObject {
    weak var owner: RefreshRegressionProbe?
    @objc func panChanged(_ pan: UIPanGestureRecognizer) {
        owner?.panChanged(pan)
    }

    @objc func tick() {
        owner?.sample()
    }
}
