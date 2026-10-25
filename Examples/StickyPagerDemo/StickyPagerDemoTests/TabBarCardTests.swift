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
                "mode=\(bar.layoutConfiguration.itemSizing), width=\(frame.width), text=\(label.text ?? "")"
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
                    for (sizing, alignment): (
                        SPTabBarLayoutConfiguration.ItemSizing,
                        SPTabBarLayoutConfiguration.Alignment
                    ) in [
                        (.balanced, .leading),
                        (.equal, .leading),
                        (.content, .center),
                        (.content, .leading),
                        (.equal, .leading),
                        (.balanced, .leading)
                    ] {
                        var layout = bar.layoutConfiguration
                        layout.itemSizing = sizing
                        layout.alignment = alignment
                        bar.layoutConfiguration = layout
                        try checkCard(bar, list: list, compact: sizing == .equal)
                        if sizing == .equal {
                            XCTAssertEqual(
                                list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.size.width,
                                44,
                                accuracy: 0.01
                            )
                        }
                    }
                    bar.layoutConfiguration.itemSizing = .equal
                    for minimum: CGFloat in [24, 600, 44] {
                        bar.layoutConfiguration.minimumItemWidth = minimum
                        // 扣除间距后均分宽度小于 24，确保覆盖 Demo 最小宽度选项。
                        bar.layoutConfiguration.itemSpacing = 16
                        try checkCard(bar, list: list, compact: minimum < 600)
                    }
                }
            }
        }
    }

    func testFillCardRestoresNumberWhenViewportExpands() throws {
        try withBar(count: 1, rtl: false, largeText: false) { bar, list in
            bar.layoutConfiguration.itemSizing = .equal
            for width: CGFloat in [80, 320, 80] {
                bar.frame.size.width = width
                try checkCard(bar, list: list, compact: width == 80)
            }
        }
    }

    func testCardsKeepMeasuredHeightWhenBarIsClippedAndRestore() throws {
        for rtl in [false, true] {
            for largeText in [false, true] {
                try withBar(count: 3, rtl: rtl, largeText: largeText) { bar, list in
                    try checkCard(bar, list: list, compact: false)
                    let idealHeight = bar.sizeThatFits(bar.bounds.size).height
                    let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 0, section: 0)))
                    let content = try XCTUnwrap(cell.contentView.subviews.first { $0 is any UIContentView })
                    let control = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
                    for height in [32, 60, idealHeight + 20, 32, idealHeight] {
                        bar.frame.size.height = height
                        bar.layoutIfNeeded()
                        cell.layoutIfNeeded()
                        content.layoutIfNeeded()
                        XCTAssertEqual(content.bounds.height, max(height, idealHeight), accuracy: 1)
                        XCTAssertEqual(control.bounds.height, height, accuracy: 1)
                        XCTAssertTrue(cell.contentView.clipsToBounds)
                        XCTAssertFalse(bar.point(inside: CGPoint(x: 20, y: height + 1), with: nil))
                        XCTAssertEqual(bar.selectedIndex, 0)
                        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, idealHeight, accuracy: 1)
                    }
                    try checkCard(bar, list: list, compact: false)
                }
            }
        }
    }

    func testPagerAdaptsCardsToFixedHeightAndRestoresFullContent() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let pager = DemoPager()
        let navigation = UINavigationController(rootViewController: pager)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        settle(window)
        pager.tabBar.contentStyle = .custom
        defer {
            window.rootViewController = nil
            settle(window)
            window.isHidden = true
            previous?.makeKey()
        }
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        let list = try XCTUnwrap(pager.tabBar.subviews.compactMap { $0 as? UICollectionView }.first)
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                navigation.setOverrideTraitCollection(
                    UITraitCollection(preferredContentSizeCategory: category),
                    forChild: pager
                )
                pager.tabBar.layoutConfiguration.contentInsets = .zero
                pager.layout.tabBarSizing = .content(minimum: 44)
                settle(window)
                let originalHeight = pager.tabBar.bounds.height
                for sizing: SPTabBarSizing in [
                    .fixed(32),
                    .fixed(60),
                    .hidden,
                    .fixed(32),
                    .content(minimum: 44)
                ] {
                    // 同一固定高度下直接切换留白，检查配置刷新；最后清除留白验证可逆性。
                    for insets in [
                        NSDirectionalEdgeInsets.zero,
                        NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16),
                        NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 10, trailing: 32),
                        .zero
                    ] {
                        pager.layout.tabBarSizing = sizing
                        pager.tabBar.layoutConfiguration.contentInsets = insets
                        settle(window)
                        XCTAssertEqual(pager.selectedIndex, 0)
                        if sizing == .hidden {
                            XCTAssertEqual(pager.tabBar.bounds.height, 0)
                            continue
                        }
                        // 内容切换保留物理偏移；RTL／大字号下先将待检查的逻辑首项带回视口。
                        list.layoutIfNeeded()
                        let path = IndexPath(item: 0, section: 0)
                        let frame = try XCTUnwrap(list.layoutAttributesForItem(at: path)).frame
                        list.contentOffset.x = min(
                            max(0, frame.minX),
                            max(0, list.contentSize.width - list.bounds.width)
                        )
                        list.layoutIfNeeded()
                        let cell = try XCTUnwrap(
                            list.cellForItem(at: path),
                            "rtl=\(rtl), category=\(category), sizing=\(sizing), insets=\(insets)"
                        )
                        cell.layoutIfNeeded()
                        let content = try XCTUnwrap(cell.contentView.subviews.first { $0 is any UIContentView })
                        let text = labels(in: content)
                        if case let .fixed(height) = sizing {
                            XCTAssertEqual(pager.tabBar.bounds.height, height, accuracy: 1)
                            XCTAssertEqual(cell.bounds.height, height - insets.top - insets.bottom, accuracy: 1)
                            XCTAssertEqual(content.bounds.height, cell.bounds.height, accuracy: 1, "紧凑内容不应依赖裁切")
                            let title = try XCTUnwrap(text
                                .first { $0.accessibilityIdentifier == "demo.compactTabTitle" })
                            XCTAssertEqual(text.count, 1, "紧凑卡片收起编号和副标题")
                            let rect = title.convert(title.bounds, to: cell)
                            XCTAssertGreaterThanOrEqual(rect.minY, 0)
                            XCTAssertLessThanOrEqual(rect.maxY, cell.bounds.height)
                            XCTAssertGreaterThanOrEqual(title.bounds.height, ceil(title.font.lineHeight))
                            XCTAssertFalse(title.hasAmbiguousLayout)
                        } else {
                            XCTAssertEqual(
                                pager.tabBar.bounds.height,
                                originalHeight + insets.top + insets.bottom,
                                accuracy: 1
                            )
                            XCTAssertTrue(text.contains { $0.text == "1" })
                            XCTAssertTrue(text.contains { $0.text == "浏览专题" })
                            XCTAssertFalse(text.contains { $0.accessibilityIdentifier == "demo.compactTabTitle" })
                        }
                        for label in text {
                            let rect = label.convert(label.bounds, to: cell)
                            XCTAssertGreaterThanOrEqual(rect.minY, -0.5)
                            XCTAssertLessThanOrEqual(rect.maxY, cell.bounds.height + 0.5)
                        }
                    }
                }
            }
        }
    }
}
