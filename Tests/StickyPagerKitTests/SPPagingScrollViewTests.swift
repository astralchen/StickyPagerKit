import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPPagingScrollViewTests: XCTestCase {
    func testNestedHorizontalScrollUsesDirectionalEdgesAndInsets() {
        let root = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let pager = SPPagingScrollView(frame: root.view.bounds)
        pager.contentInsetAdjustmentBehavior = .never
        root.view.addSubview(pager)
        pager.contentSize = CGSize(width: 1170, height: 844)
        pager.contentOffset.x = 390
        let inner = UIScrollView(frame: CGRect(x: 390, y: 100, width: 390, height: 140))
        inner.contentInsetAdjustmentBehavior = .never
        inner.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 24)
        inner.contentSize = CGSize(width: 1000, height: 140)
        pager.addSubview(inner)
        let point = CGPoint(x: 585, y: 160)
        let right = CGPoint(x: 300, y: 0), left = CGPoint(x: -300, y: 0)
        for direction: UISemanticContentAttribute in [.forceLeftToRight, .forceRightToLeft] {
            pager.semanticContentAttribute = direction
            inner.contentOffset.x = -16
            XCTAssertTrue(pager.shouldPage(at: point, velocity: right))
            XCTAssertFalse(pager.shouldPage(at: point, velocity: left))
            inner.contentOffset.x = 250
            XCTAssertFalse(pager.shouldPage(at: point, velocity: right))
            XCTAssertFalse(pager.shouldPage(at: point, velocity: left))
            inner.contentOffset.x = 634
            XCTAssertFalse(pager.shouldPage(at: point, velocity: right))
            XCTAssertTrue(pager.shouldPage(at: point, velocity: left))
            XCTAssertFalse(pager.shouldPage(at: point, velocity: CGPoint(x: 10, y: 300)))
            XCTAssertTrue(pager.gestureRecognizer(
                pager.panGestureRecognizer,
                shouldBeRequiredToFailBy: inner.panGestureRecognizer
            ))
        }
        // 内容外区域保留普通分页；容器本身已到边界时，不抢走内部弹性拖动。
        XCTAssertTrue(pager.shouldPage(at: CGPoint(x: 585, y: 300), velocity: right))
        inner.contentOffset.x = -16
        pager.contentOffset.x = 0
        inner.frame.origin.x = 0
        XCTAssertFalse(pager.shouldPage(at: CGPoint(x: 195, y: 160), velocity: right))
        pager.contentOffset.x = 390
        inner.frame.origin.x = 390
        inner.contentOffset.x = -30
        XCTAssertFalse(pager.shouldPage(at: point, velocity: left), "回弹越界后向内拖动仍由内部接收")
        inner.isScrollEnabled = false
        XCTAssertTrue(pager.shouldPage(at: point, velocity: left))
    }

    func testVerticalAndUnrelatedScrollViewsDoNotGainHorizontalPriority() {
        let pager = SPPagingScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let vertical = UIScrollView(frame: pager.bounds)
        vertical.contentSize = CGSize(width: 390, height: 2000)
        pager.addSubview(vertical)
        XCTAssertFalse(pager.gestureRecognizer(
            pager.panGestureRecognizer,
            shouldBeRequiredToFailBy: vertical.panGestureRecognizer
        ))
        let unrelated = UIScrollView(frame: pager.bounds)
        unrelated.contentSize.width = 2000
        XCTAssertFalse(pager.gestureRecognizer(
            pager.panGestureRecognizer,
            shouldBeRequiredToFailBy: unrelated.panGestureRecognizer
        ))
    }
}
