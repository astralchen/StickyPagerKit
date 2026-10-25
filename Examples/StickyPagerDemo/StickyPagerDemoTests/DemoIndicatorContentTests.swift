import XCTest
import UIKit
import StickyPagerKit
@testable import StickyPagerDemo

@MainActor
final class DemoIndicatorContentTests: XCTestCase {
    func testAutomaticCardStyleAndExplicitUnderlineRestoreInBothDirections() throws {
        try withBar { bar, contents, indicators, list in
            for rtl in [false, true] {
                bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                indicators.useAutomaticStyle(on: bar)
                bar.contentStyle = .custom
                for height: CGFloat? in [nil, 32, 60, nil] {
                    contents.fixedHeight = height
                    contents.usesCompactContent = false
                    bar.reloadContent()
                    indicators.updateContentStyle(on: bar)
                    bar.frame.size.height = height ?? bar.sizeThatFits(bar.bounds.size).height
                    bar.setSelectedIndex(0, animated: false)
                    bar.layoutIfNeeded()
                    let line = try indicator(list)
                    XCTAssertEqual(bar.indicatorStyle, .none)
                    XCTAssertTrue(line.isHidden)
                    indicators.selectStyle(.underline, on: bar)
                    bar.layoutIfNeeded()
                    let frame = try XCTUnwrap(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))).frame
                    XCTAssertFalse(line.isHidden)
                    XCTAssertEqual(line.frame.width, frame.width - (height == nil ? 8 : 0), accuracy: 1)
                    XCTAssertEqual(line.frame.midX, frame.midX, accuracy: 1)
                    XCTAssertEqual(line.frame.maxY, frame.maxY, accuracy: 1)
                    bar.reloadContent()
                    indicators.updateContentStyle(on: bar)
                    XCTAssertFalse(line.isHidden, "显式选择不能被后续布局刷新覆盖")
                    indicators.useAutomaticStyle(on: bar)
                    XCTAssertTrue(line.isHidden)
                }
                bar.contentStyle = .default
                indicators.updateContentStyle(on: bar)
                bar.layoutIfNeeded()
                XCTAssertEqual(bar.indicatorStyle, .underline)
                XCTAssertFalse(try indicator(list).isHidden)
                indicators.selectStyle(.capsule, on: bar)
                bar.contentStyle = .custom
                indicators.updateContentStyle(on: bar)
                XCTAssertEqual(bar.indicatorStyle, .capsule, "保留显式选择的组合样式")
                XCTAssertEqual(bar.selectedIndex, 0)
            }
        }
    }

    func testCompactTextUnderlineExcludesPaddingAcrossWidthModesAndLargeText() throws {
        try withBar { bar, contents, indicators, list in
            contents.usesCompactContent = true
            contents.showCustomContent(on: bar)
            indicators.useAutomaticStyle(on: bar)
            let host = try XCTUnwrap(bar.superview?.next as? UIViewController)
            for rtl in [false, true] {
                bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                    host.parent?.setOverrideTraitCollection(
                        UITraitCollection(preferredContentSizeCategory: category),
                        forChild: host
                    )
                    bar.window?.layoutIfNeeded()
                    XCTAssertEqual(bar.traitCollection.preferredContentSizeCategory, category)
                    for sizing: SPTabBarLayoutConfiguration.ItemSizing in [.content, .equal, .fixed(180)] {
                        bar.layoutConfiguration.itemSizing = sizing
                        bar.layoutConfiguration.minimumItemWidth = 120
                        bar.reloadContent()
                        bar.frame.size.height = bar.sizeThatFits(bar.bounds.size).height
                        indicators.updateContentStyle(on: bar)
                        bar.setSelectedIndex(0, animated: false)
                        bar.layoutIfNeeded(); list.layoutIfNeeded()
                        let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 0, section: 0)))
                        cell.layoutIfNeeded()
                        let label = try XCTUnwrap(labels(in: cell)
                            .first { $0.accessibilityIdentifier == "demo.compactTabTitle" })
                        let line = try indicator(list)
                        let textWidth = min(
                            ceil(label.sizeThatFits(CGSize(width: 10000, height: 10000)).width),
                            label.bounds.width
                        )
                        let rect = label.convert(label.bounds, to: list)
                        XCTAssertEqual(line.frame.width, textWidth, accuracy: 1)
                        XCTAssertEqual(line.frame.midX, rect.midX, accuracy: 1)
                        XCTAssertLessThanOrEqual(line.frame.width, cell.bounds.width - 24 + 1)
                        let original = line.frame
                        bar.setTransitionProgress(from: 0, to: 1, progress: 0.7)
                        bar.setTransitionProgress(from: 0, to: 1, progress: 0)
                        XCTAssertEqual(line.frame, original)
                        XCTAssertEqual(bar.selectedIndex, 0)
                    }
                }
            }
        }
    }

    private func withBar(_ body: (SPTabBar, DemoTabContentProvider, DemoIndicatorProvider, UICollectionView) throws
        -> Void) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = IndicatorContentTestHost()
        let child = IndicatorContentTestHost()
        window.rootViewController = root
        // 先完成 containment，再让 UIKit 一次性转发显示生命周期。
        root.addChild(child); root.view.addSubview(child.view); child.didMove(toParent: root)
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 390, height: 80))
        child.view.addSubview(bar)
        bar.items = [SPTabBarItem(title: "推荐"), SPTabBarItem(title: "更多专题")]
        let contents = DemoTabContentProvider()
        let indicators = DemoIndicatorProvider()
        indicators.contentProvider = contents
        bar.contentDelegate = contents
        bar.setSelectedIndex(0, animated: false)
        let rootAppeared = expectation(description: "指示器宿主完成显示")
        let childAppeared = expectation(description: "指示器子控制器完成显示")
        root.onAppear = { rootAppeared.fulfill() }
        child.onAppear = { childAppeared.fulfill() }
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        wait(for: [rootAppeared, childAppeared], timeout: 5)
        defer {
            let rootDisappeared = expectation(description: "指示器宿主完成消失")
            let childDisappeared = expectation(description: "指示器子控制器完成消失")
            root.onDisappear = { rootDisappeared.fulfill() }
            child.onDisappear = { childDisappeared.fulfill() }
            window.rootViewController = nil
            wait(for: [rootDisappeared, childDisappeared], timeout: 5)
            window.isHidden = true
            previous?.makeKey()
            let expected = ["willAppear", "didAppear", "willDisappear", "didDisappear"]
            XCTAssertEqual(root.appearanceEvents, expected)
            XCTAssertEqual(child.appearanceEvents, expected)
        }
        let list = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        try body(bar, contents, indicators, list)
    }

    private func indicator(_ list: UICollectionView) throws -> UIView {
        try XCTUnwrap(list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" })
    }

    private func labels(in view: UIView) -> [UILabel] {
        (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }
}

/// 只观测 UIKit 自动转发，不手动补 begin/end 来掩盖夹具生命周期错误。
@MainActor
private final class IndicatorContentTestHost: UIViewController {
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?
    private(set) var appearanceEvents: [String] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearanceEvents.append("willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearanceEvents.append("didAppear")
        onAppear?()
        onAppear = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appearanceEvents.append("willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appearanceEvents.append("didDisappear")
        onDisappear?()
        onDisappear = nil
    }
}
