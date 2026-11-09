import UIKit
import StickyPagerKit

/// 只在专用验收参数下安装。通过公开 API 发起有限输入，记录真实生命周期，不推进框架时钟。
@MainActor
final class DemoTabStateProbe: NSObject {
    private weak var bar: SPTabBar?
    private var timer: Timer?
    private var pending: Task<Void, Never>?
    private var requests = 0
    private var lastRequest: CFTimeInterval = 0
    private var resignCount = 0
    private var resignSelected = -1
    private var resignInFlight = false
    private var mutation = "none"
    private var mutationScheduled = false

    init(bar: SPTabBar) {
        self.bar = bar
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resign(_:)),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
    }

    isolated deinit {
        timer?.invalidate()
        pending?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    var snapshot: String {
        guard let bar else {
            return ""
        }
        return "requests=\(requests);resigns=\(resignCount);resignSelected=\(resignSelected);"
            + "resignInFlight=\(resignInFlight ? 1 : 0);mutation=\(mutation);itemCount=\(bar.items.count);"
            + "selectedTitle=\(bar.selectedItem?.title ?? "none");selectedScale=\(selectedScale);"
    }

    private var selectedScale: CGFloat {
        guard let bar, let index = bar.selectedIndex,
              let list = bar.subviews.compactMap({ $0 as? UICollectionView }).first,
              let cell = list.cellForItem(at: IndexPath(item: index, section: 0)),
              let host = cell.contentView.subviews.first(where: { $0.accessibilityIdentifier == "sp.tab.visualHost" }) else {
            return 1
        }
        return host.transform.a
    }

    func startSequence() {
        guard timer == nil else {
            return
        }
        requests = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestNext() }
        }
        print("TAB_STATE_SEQUENCE_START time=\(CACurrentMediaTime())")
    }

    private func requestNext() {
        guard let bar, requests < 60 else {
            timer?.invalidate(); timer = nil; return
        }
        requests += 1
        lastRequest = CACurrentMediaTime()
        bar.setSelectedIndex(requests % 3, animated: true)
    }

    @objc private func resign(_ notification: Notification) {
        guard let bar, let scene = notification.object as? UIScene, scene === bar.window?.windowScene,
              requests > 0 else {
            return
        }
        resignCount += 1
        resignSelected = bar.selectedIndex ?? -1
        // 既检查请求时序，也检查实际视觉层未到终态；不能把稳态离开前台算作动画中断。
        resignInFlight = CACurrentMediaTime() - lastRequest < 0.5 && abs(selectedScale - 1) > 0.0001
        print("TAB_STATE_RESIGN time=\(CACurrentMediaTime()) gap=\(CACurrentMediaTime() - lastRequest) \(snapshot)")
        // 只结束夹具继续发起的请求，不停止、推进或补偿框架已有动画。
        timer?.invalidate()
        timer = nil
    }

    func didSelect(_ item: SPTabBarItem) {
        guard !mutationScheduled,
              let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tab-mutation=") }) else {
            return
        }
        mutationScheduled = true
        let action = String(argument.dropFirst("--tab-mutation=".count))
        pending = Task { @MainActor [weak self, weak item] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self, let item, let bar = self.bar else {
                return
            }
            switch action {
            case "rename":
                item.title = "更新后的收藏"
                item.accessibilityLabel = "更新后的收藏"
                item.badgeValue = "23"
            case "disable": item.isEnabled = false
            case "remove": bar.items.removeAll { $0 === item }
            case "reorder": bar.items.reverse()
            case "scale": bar.visualStyle = .standard
            default: return
            }
            self.mutation = action
            print("TAB_STATE_MUTATION time=\(CACurrentMediaTime()) \(self.snapshot)")
        }
    }
}
