import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPRefreshInsetTests: XCTestCase {
    func testInsetRetractionWithoutOffsetChangePreservesPosition() {
        for position: CGFloat in [80, 200, 350] {
            withBinding { scroll, binding in
                binding.setPosition(position)
                var callbacks = 0
                binding.onScroll = { _ in callbacks += 1 }
                scroll.retractInset()
                XCTAssertEqual(binding.position, position, accuracy: 0.01)
                XCTAssertEqual(callbacks, 0, "几何补偿不应被当作业务滚动")
                scroll.contentOffset.y += 1
                XCTAssertEqual(binding.position, position + 1, accuracy: 0.01)
                XCTAssertEqual(callbacks, 1)
            }
        }
    }

    func testRepeatedOffsetNotificationDoesNotApplyRetractionTwice() {
        withBinding { scroll, binding in
            binding.setPosition(200)
            scroll.retractInset()
            for _ in 0 ..< 3 {
                scroll.contentOffset = scroll.contentOffset
            }
            XCTAssertEqual(binding.position, 200, accuracy: 0.01)
        }
    }

    func testNativeOverscrollKeepsItsOffsetWhenInsetRetracts() {
        for position: CGFloat in [-40, 0] {
            withBinding { scroll, binding in
                binding.setPosition(position)
                let offset = scroll.contentOffset.y
                scroll.retractInset()
                XCTAssertEqual(scroll.contentOffset.y, offset, accuracy: 0.01)
                XCTAssertEqual(binding.position, position - 60, accuracy: 0.01)
            }
        }
    }

    func testUIKitOffsetCompensationIsNotAppliedAgain() {
        withBinding { scroll, binding in
            binding.setPosition(200)
            scroll.transientTop = 0
            scroll.contentOffset = scroll.contentOffset
            scroll.contentOffset.y += 60
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertEqual(binding.position, 200, accuracy: 0.01)
        }
    }

    func testGeometryNotificationCanDiscoverRetractionBeforeOffsetNotification() {
        withBinding { scroll, binding in
            binding.setPosition(350)
            scroll.transientTop = 0
            scroll.contentSize.height += 10
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertEqual(binding.position, 350, accuracy: 0.01)
            scroll.contentOffset = scroll.contentOffset
            XCTAssertEqual(binding.position, 350, accuracy: 0.01)
        }
    }

    func testDetachedBindingDoesNotCorrectLaterInsetRetraction() {
        withBinding { scroll, binding in
            binding.setPosition(350)
            binding.detach()
            let offset = scroll.contentOffset.y
            scroll.retractInset()
            XCTAssertEqual(scroll.contentOffset.y, offset, accuracy: 0.01)
        }
    }

    func testRetractionCorrectionCanDetachSynchronously() {
        withBinding { scroll, binding in
            binding.setPosition(350)
            var detached = false
            let observation = scroll.observe(\.contentOffset, options: [.old, .new]) { _, change in
                MainActor.assumeIsolated {
                    guard !detached, change.oldValue != change.newValue else {
                        return
                    }
                    detached = true
                    binding.detach()
                }
            }
            scroll.retractInset()
            XCTAssertTrue(detached)
            XCTAssertEqual(scroll.contentInset.top, 0, accuracy: 0.01)
            XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 150, accuracy: 0.01)
            withExtendedLifetime(observation) {}
        }
    }

    func testInactiveRetractionDoesNotChangeCurrentHeaderOrSavedContent() {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
            let pager = SPPageViewController()
            let source = RefreshInsetSource()
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            window.rootViewController = pager
            window.showForTesting()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.reloadData()
            pager.view.layoutIfNeeded()
            let range = pager.layout.headerHeight - pager.view.safeAreaInsets.top - pager.layout.minimumHeaderHeight
            let first = source.scrolls[0]
            first.contentOffset.y = range + 130 - first.adjustedContentInset.top
            pager.setSelectedIndex(1, animated: false)
            let second = source.scrolls[1]
            second.contentOffset.y = 80 - second.adjustedContentInset.top
            first.retractInset()
            XCTAssertEqual(pager.collapseOffset, 80, accuracy: 0.01)
            second.contentOffset.y = range - second.adjustedContentInset.top
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(pager.records[0]!.binding!.position, range + 130, accuracy: 0.01)
            window.closeForTesting()
        }
    }

    func testNewPositionSupersedesDeferredRetraction() {
        withBinding { scroll, binding in
            binding.setPosition(350)
            scroll.retractInset(settle: false)
            binding.setPosition(80)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertEqual(binding.position, 80, accuracy: 0.01)
        }
    }

    func testDetachBeforeDeferredRetractionPreservesContentAndCancelsCallback() {
        withBinding { scroll, binding in
            binding.setPosition(350)
            scroll.retractInset(settle: false)
            binding.detach()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 150, accuracy: 0.01)
            XCTAssertEqual(scroll.contentInset.top, 0, accuracy: 0.01)
        }
    }

    private func withBinding(_ body: (TransientInsetScrollView, SPScrollBinding) -> Void) {
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        let controller = UIViewController()
        window.rootViewController = controller
        window.showForTesting()
        let scroll = TransientInsetScrollView(frame: controller.view.bounds)
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(width: 440, height: 2400)
        controller.view.addSubview(scroll)
        controller.view.layoutIfNeeded()
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        body(scroll, binding)
        binding.detach()
        window.closeForTesting()
    }
}

/// 模拟 UIKit 的临时 adjusted inset：getter 变化不发送 KVO，随后发送相同 offset 通知。
@MainActor
private final class TransientInsetScrollView: UIScrollView {
    var transientTop: CGFloat = 60
    override var adjustedContentInset: UIEdgeInsets {
        var inset = super.adjustedContentInset
        inset.top += transientTop
        return inset
    }

    func retractInset(settle: Bool = true) {
        let original = contentOffset
        transientTop = 0
        contentOffset = original
        // 原生刷新 setter 尚未返回，后续仍可能再次写入进入时的 offset。
        contentOffset = original
        if settle {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }
}

@MainActor
private final class RefreshInsetSource: SPPageViewControllerDataSource {
    let scrolls = [TransientInsetScrollView(), TransientInsetScrollView()]
    lazy var pages: [UIViewController] = scrolls.map { scroll in
        let page = UIViewController()
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(width: 440, height: 2400)
        page.view = scroll
        return page
    }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        pages.count
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        identifierForPageAt index: Int
    ) -> AnyHashable {
        index
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        pages[index]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        tabBarItemAt index: Int
    ) -> SPTabBarItem {
        SPTabBarItem(title: "列表 \(index)")
    }
}
