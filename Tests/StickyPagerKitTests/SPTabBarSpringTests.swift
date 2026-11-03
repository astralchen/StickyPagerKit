import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarSpringTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window = nil
    }

    private func mount(rtl: Bool = false) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 70))
        bar.layoutConfiguration.itemSizing = .equal
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)") }
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.visualStyle = .scale
        bar.selectionAnimationStyle = .spring
        bar.layoutIfNeeded()
        return bar
    }

    private func list(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func scale(_ bar: SPTabBar, _ index: Int) throws -> CGFloat {
        let cell = try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: index, section: 0)))
        return try XCTUnwrap(cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" })
            .transform.a
    }

    private func indicator(_ bar: SPTabBar) -> CGRect {
        list(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!.frame
    }

    private func animation(from a: CGRect, to b: CGRect, target: Int = 1) -> SPTabBarPresentationCoordinator.Animation {
        .init(
            fromIndex: 0,
            toIndex: target,
            fromIndicator: a,
            toIndicator: b,
            fromGeometry: a,
            fromOffset: 0,
            toOffset: 100,
            startTime: CACurrentMediaTime()
        )
    }

    func testSpringBoundsCompletionAndVelocityAreDeterministic() {
        let initial = SPTabSpringValue(position: 0.3, velocity: -2)
        XCTAssertEqual(initial.value(toward: 1, time: 0).position, 0.3, accuracy: 0.00001)
        XCTAssertEqual(initial.value(toward: 1, time: 0).velocity, -2, accuracy: 0.00001)
        let epsilon: CGFloat = 0.00001
        XCTAssertEqual((initial.value(toward: 1, time: epsilon).position - 0.3) / epsilon, -2, accuracy: 0.01)
        for step in 0 ... 100 {
            let sample = initial.value(toward: 1, time: CGFloat(step) / 200, limits: -0.15 ... 1.15)
            XCTAssertTrue(sample.position.isFinite && sample.velocity.isFinite)
            XCTAssertTrue((-0.15 ... 1.15).contains(sample.position))
        }
        XCTAssertEqual(initial.value(toward: 1, time: 0.5).position, 1)
        XCTAssertEqual(initial.value(toward: 1, time: 0.5).velocity, 0)
    }

    func testSpringRetargetPreservesPositionAndVelocityWhilePublicProgressIsBounded() throws {
        let coordinator = SPTabBarPresentationCoordinator()
        let a = CGRect(x: 10, y: 0, width: 20, height: 3), b = CGRect(x: 110, y: 0, width: 20, height: 3)
        var frame: SPTabBarPresentationCoordinator.Frame!
        coordinator.onFrame = { frame = $0 }
        coordinator.startAnimation(animation(from: a, to: b), contentOrigin: [0: 1], style: .spring)
        coordinator.advance(to: 0.45)
        let snapshot = try XCTUnwrap(coordinator.springSnapshot)
        XCTAssertGreaterThan(frame.indicator.midX, b.midX)
        XCTAssertTrue((0 ... 1).contains(frame.progress))
        XCTAssertTrue((0 ... 100).contains(frame.offset))
        XCTAssertTrue(coordinator.contentWeights(selectedIndex: 1).values.allSatisfy { (0 ... 1).contains($0) })
        let oldFrame = frame.indicator
        coordinator.startAnimation(
            animation(from: oldFrame, to: a, target: 0),
            contentOrigin: coordinator.contentWeights(selectedIndex: 1),
            style: .spring,
            spring: snapshot
        )
        XCTAssertEqual(frame.indicator, oldFrame)
        XCTAssertEqual(
            try XCTUnwrap(coordinator.springSnapshot).centerX.velocity,
            snapshot.centerX.velocity,
            accuracy: 0.00001
        )
        XCTAssertEqual(
            try XCTUnwrap(coordinator.springSnapshot?.weights[1]).velocity,
            snapshot.weights[1]!.velocity,
            accuracy: 0.00001
        )
        coordinator.advance(to: 1)
        XCTAssertEqual(frame.indicator, a)
        XCTAssertNil(coordinator.animation)
        XCTAssertNil(coordinator.springSnapshot)
    }

    func testActualScaleOvershootRetargetPagingAndCancelInBothDirections() throws {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            bar.setSelectedIndex(2, animated: true)
            bar.advanceSelectionAnimation(to: 0.45)
            XCTAssertGreaterThan(try scale(bar, 2), 1)
            XCTAssertLessThanOrEqual(try scale(bar, 2), 1.0091)
            let before = indicator(bar), previousScale = try scale(bar, 2)
            bar.setSelectedIndex(1, animated: true)
            XCTAssertEqual(indicator(bar), before)
            XCTAssertEqual(try scale(bar, 2), previousScale, accuracy: 0.00001)
            bar.advanceSelectionAnimation(to: 0.2)
            let takeover = indicator(bar), takeoverScale = try scale(bar, 1)
            bar.setTransitionProgress(from: 1, to: 0, progress: 0)
            XCTAssertEqual(indicator(bar), takeover)
            XCTAssertEqual(try scale(bar, 1), takeoverScale, accuracy: 0.00001)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(indicator(bar), takeover)
            bar.setTransitionProgress(from: 1, to: 0, progress: 0.4)
            let paging = indicator(bar)
            bar.setSelectedIndex(2, animated: true)
            XCTAssertEqual(indicator(bar), paging, "从分页转程序动画不跳到零坐标")
            bar.setSelectedIndex(1, animated: false)
            XCTAssertEqual(try scale(bar, 1), 1)
            XCTAssertEqual(try scale(bar, 0), 0.94, accuracy: 0.00001)
            bar.removeFromSuperview()
        }
    }

    func testContentOnlySpringKeepsAlphaAndCustomProgressBounded() throws {
        let bar = mount()
        bar.indicatorStyle = .none
        bar.visualStyle.unselectedAlpha = 0.55
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.45)
        XCTAssertGreaterThan(try scale(bar, 1), 1)
        for cell in list(bar).visibleCells {
            XCTAssertTrue((0.55 ... 1).contains(cell.contentView.alpha))
        }
        bar.advanceSelectionAnimation(to: 0.5)
        let target = try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: 1, section: 0)))
        XCTAssertEqual(target.contentView.alpha, 1)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(try scale(bar, 1), 1)
    }

    func testStyleChangeResizeReorderAndAccessibilityNotificationSettle() throws {
        let bar = mount()
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.45)
        bar.selectionAnimationStyle = .standard
        XCTAssertEqual(try scale(bar, 2), 1)
        bar.selectionAnimationStyle = .spring
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.3)
        bar.frame.size.width = 420
        bar.layoutIfNeeded()
        XCTAssertEqual(try scale(bar, 1), 1)
        let selected = bar.selectedItem
        bar.items = Array(bar.items.reversed())
        bar.layoutIfNeeded()
        XCTAssertTrue(bar.selectedItem === selected)
        bar.setSelectedIndex(0, animated: true)
        bar.advanceSelectionAnimation(to: 0.4)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        bar.layoutIfNeeded()
        XCTAssertEqual(try scale(bar, 0), 1)
        bar.advanceSelectionAnimation(to: 0.7)
        XCTAssertEqual(try scale(bar, 0), 1)
    }
}
