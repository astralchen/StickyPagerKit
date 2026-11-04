import XCTest
import UIKit
@testable import StickyPagerKit

/// 测试侧记录真实滚动动画与 RunLoop 时序，不改变分页滚动视图的 delegate。
@MainActor
final class SPSelectionTimingTrace: SPPageViewControllerDelegate, SPTabBarDelegate {
    private weak var pager: SPPageViewController?
    private let pageDelegate: SPPageViewControllerDelegate
    private let tabDelegate: SPTabBarDelegate
    private let start = CACurrentMediaTime()
    private let origin: CGFloat
    private let direction: CGFloat
    private var events: [[String: Any]] = []
    private var observer: CFRunLoopObserver?
    private var offsetObservation: NSKeyValueObservation?
    private var delayedCallback: Timer?
    private var pageCommits = 0
    private var tabCallbacks = 0
    private(set) var completedDelayedCallbacks = 0

    init(
        pager: SPPageViewController,
        rtl: Bool,
        pageDelegate: SPPageViewControllerDelegate,
        tabDelegate: SPTabBarDelegate
    ) {
        self.pager = pager
        self.pageDelegate = pageDelegate
        self.tabDelegate = tabDelegate
        origin = pager.pagingView.contentOffset.x
        direction = rtl ? -1 : 1
        pager.delegate = self
        pager.tabBar.delegate = self
        offsetObservation = pager.pagingView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.record("offset") }
        }
        observer = CFRunLoopObserverCreateWithHandler(
            nil,
            CFRunLoopActivity.allActivities.rawValue,
            true,
            0
        ) { [weak self] _, activity in
            MainActor.assumeIsolated { self?.record("runLoop", extra: ["activity": activity.rawValue]) }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        record("traceStart")
    }

    func record(_ event: String, extra: [String: Any] = [:]) {
        guard let pager else {
            return
        }
        var value: [String: Any] = [
            "event": event,
            "elapsedMs": (CACurrentMediaTime() - start) * 1000,
            "offsetX": pager.pagingView.contentOffset.x,
            "progress": (pager.pagingView.contentOffset.x - origin) * direction / pager.pagingView.bounds.width,
            "selectedIndex": pager.selectedIndex.map { $0 as Any } ?? NSNull(),
            "transitionTarget": pager.selection.transitionTarget.map { $0 as Any } ?? NSNull(),
            "pageCommits": pageCommits,
            "tabCallbacks": tabCallbacks
        ]
        value.merge(extra) { _, new in new }
        events.append(value)
    }

    func run(for duration: TimeInterval, label: String) {
        record("waitBegin", extra: ["label": label, "requestedMs": duration * 1000])
        let before = CACurrentMediaTime()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
        let elapsed = (CACurrentMediaTime() - before) * 1000
        record("waitEnd", extra: ["label": label, "requestedMs": duration * 1000, "actualMs": elapsed])
    }

    /// 仅用于诊断：让下一次 RunLoop 等待遇到一个慢回调，保留原动画与原断言。
    func scheduleDelayedCallback(seconds: TimeInterval) {
        delayedCallback = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.record("slowCallbackBegin", extra: ["delayMs": seconds * 1000])
                Thread.sleep(forTimeInterval: seconds)
                self?.completedDelayedCallbacks += 1
                self?.record("slowCallbackEnd")
            }
        }
    }

    func finish(in test: XCTestCase, name: String) {
        record("traceEnd")
        delayedCallback?.invalidate()
        if let observer {
            CFRunLoopObserverInvalidate(observer)
        }
        offsetObservation?.invalidate()
        pager?.delegate = pageDelegate
        pager?.tabBar.delegate = tabDelegate
        do {
            let data = try JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name
            attachment.lifetime = .keepAlways
            test.add(attachment)
        } catch {
            XCTFail("无法保存选择时序：\(error)")
        }
    }

    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {
        pageCommits += 1
        pageDelegate.pageViewController(pageViewController, didSelectPageAt: index)
        record("pageCommit", extra: ["index": index])
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        didScrollFrom fromIndex: Int,
        to toIndex: Int,
        progress: CGFloat
    ) {
        pageDelegate.pageViewController(pageViewController, didScrollFrom: fromIndex, to: toIndex, progress: progress)
        record("pageProgress", extra: ["reportedProgress": progress])
    }

    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool {
        tabDelegate.tabBar(tabBar, shouldSelect: item)
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        tabCallbacks += 1
        tabDelegate.tabBar(tabBar, didSelect: item)
        record("tabCallback")
    }
}
