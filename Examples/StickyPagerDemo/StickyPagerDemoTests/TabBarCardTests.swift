import XCTest
import UIKit
import StickyPagerKit
@testable import StickyPagerDemo

/// 通过真实窗口、最终 Cell 宽度验证卡片的测量与内部内容，避免只检查外层 frame。
@MainActor
final class TabBarCardTests: XCTestCase {
    private func withBar(
        count: Int,
        rtl: Bool,
        largeText: Bool,
        body: (SPTabBar, UICollectionView) throws -> Void
    ) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let child = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        settle(window)
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        root.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory:
            largeText ? .accessibilityExtraExtraExtraLarge : .large), forChild: child)
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 390, height: 80))
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        child.view.addSubview(bar)
        bar.items = (0 ..< count).map { SPTabBarItem(title: "长标题专题频道 \($0)") }
        bar.setSelectedIndex(0, animated: false)
        let provider = DemoTabContentProvider()
        bar.contentDelegate = provider
        provider.showCustomContent(on: bar)
        settle(window)
        XCTAssertEqual(
            bar.traitCollection.preferredContentSizeCategory,
            largeText ? .accessibilityExtraExtraExtraLarge : .large
        )
        defer {
            settle(window)
            window.rootViewController = nil
            settle(window)
            window.isHidden = true
            previous?.makeKey()
        }
        let list = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        try body(bar, list)
        withExtendedLifetime(provider) {}
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        window.layoutIfNeeded()
    }

    private func checkCard(_ bar: SPTabBar, list: UICollectionView, compact: Bool) throws {
        let height = bar.sizeThatFits(bar.bounds.size).height
        bar.frame.size.height = height
        bar.layoutIfNeeded()
        let frame = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))).frame
        list.contentOffset.x = min(max(0, frame.minX), max(0, list.contentSize.width - list.bounds.width))
        list.layoutIfNeeded()
        let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 0, section: 0)))
        cell.layoutIfNeeded()
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        let allLabels = labels(in: cell)
        let title = try XCTUnwrap(allLabels.first { $0.text == "长标题专题频道 0" })
        let subtitle = try XCTUnwrap(allLabels.first { $0.text == "浏览专题" })
        XCTAssertEqual(allLabels.contains { $0.text == "1" }, !compact)
        for label in [title, subtitle] {
            let rect = label.convert(label.bounds, to: cell)
            XCTAssertGreaterThan(rect.width, 0)
            XCTAssertGreaterThanOrEqual(rect.minX, -0.5)
            XCTAssertLessThanOrEqual(rect.maxX, cell.bounds.width + 0.5)
            XCTAssertGreaterThanOrEqual(rect.minY, -0.5)
            XCTAssertLessThanOrEqual(rect.maxY, cell.bounds.height + 0.5)
            XCTAssertFalse(
                label.hasAmbiguousLayout,
                "mode=\(bar.itemPositioning), width=\(frame.width), text=\(label.text ?? "")"
            )
        }
        XCTAssertEqual(
            title.textAlignment,
            compact ? .center : (bar.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left)
        )
        XCTAssertEqual(cell.bounds.height, height, accuracy: 1)
        XCTAssertEqual(bar.selectedIndex, 0)
    }

    func testCardsSwitchAllModesInBothDirectionsAndLargeText() throws {
        for rtl in [false, true] {
            for largeText in [false, true] {
                try withBar(count: 13, rtl: rtl, largeText: largeText) { bar, list in
                    for mode: SPTabBar.ItemPositioning in [.automatic, .fill, .centered, .leading, .fill, .automatic] {
                        bar.itemPositioning = mode
                        try checkCard(bar, list: list, compact: mode == .fill)
                        if mode == .fill {
                            XCTAssertEqual(
                                list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.size.width,
                                44,
                                accuracy: 0.01
                            )
                        }
                    }
                    bar.itemPositioning = .fill
                    for minimum: CGFloat in [24, 600, 44] {
                        bar.minimumItemWidth = minimum
                        // 扣除间距后均分宽度小于 24，确保覆盖 Demo 最小宽度选项。
                        bar.itemSpacing = 16
                        try checkCard(bar, list: list, compact: minimum < 600)
                    }
                }
            }
        }
    }

    func testFillCardRestoresNumberWhenViewportExpands() throws {
        try withBar(count: 1, rtl: false, largeText: false) { bar, list in
            bar.itemPositioning = .fill
            for width: CGFloat in [80, 320, 80] {
                bar.frame.size.width = width
                try checkCard(bar, list: list, compact: width == 80)
            }
        }
    }
}
