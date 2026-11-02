import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarRefreshTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window.rootViewController = nil
        window = nil
    }

    private func mount(count: Int = 3) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 320, height: 80))
        bar.items = (0 ..< count).map { SPTabBarItem(title: "标签 \($0)") }
        bar.setSelectedIndex(0, animated: false)
        window.rootViewController!.view.addSubview(bar)
        bar.layoutIfNeeded()
        collection(bar).layoutIfNeeded()
        return bar
    }

    private func collection(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func button(_ bar: SPTabBar, _ index: Int) -> UIButton {
        collection(bar).cellForItem(at: IndexPath(item: index, section: 0))!.contentView.subviews
            .compactMap { $0 as? UIButton }.first!
    }

    private func indicator(_ bar: SPTabBar) -> UIView {
        collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
    }

    private func settle(_ bar: SPTabBar) {
        bar.layoutIfNeeded()
        collection(bar).layoutIfNeeded()
    }

    func testStandardRefreshWorkIsLimitedToAffectedPresentation() {
        let bar = mount()
        bar.items[0].badgeValue = "3"
        settle(bar)
        let first = button(bar, 0)
        first.isHighlighted = true
        let frames = collection(bar).visibleCells.map(\.frame)
        let spy = SelectionSpy()
        bar.delegate = spy
        var before = bar.refreshStatistics
        bar.standardAppearance.backgroundColor = .systemOrange
        settle(bar)
        print("P3 decoration: \(before) -> \(bar.refreshStatistics)")
        XCTAssertEqual(bar.refreshStatistics, before)
        XCTAssertEqual(
            bar.subviews.compactMap { $0 as? UIVisualEffectView }.first?.contentView.backgroundColor,
            .systemOrange
        )

        before = bar.refreshStatistics
        bar.items[0].accessibilityLabel = "收件箱"
        settle(bar)
        print("P3 accessibility: \(before) -> \(bar.refreshStatistics)")
        XCTAssertEqual(bar.refreshStatistics.measurementPasses, before.measurementPasses)
        XCTAssertEqual(bar.refreshStatistics.cellConfigurations - before.cellConfigurations, 1)
        XCTAssertEqual(first.accessibilityLabel, "收件箱")

        before = bar.refreshStatistics
        bar.items[0].badgeColor = .systemGreen
        settle(bar)
        print("P3 badge color: \(before) -> \(bar.refreshStatistics)")
        XCTAssertEqual(bar.refreshStatistics.measurementPasses, before.measurementPasses)
        XCTAssertEqual(bar.refreshStatistics.cellConfigurations - before.cellConfigurations, 1)
        let badge = collection(bar).cellForItem(at: IndexPath(item: 0, section: 0))!.contentView.subviews
            .compactMap { $0 as? UILabel }.first!
        XCTAssertEqual(badge.backgroundColor, .systemGreen)
        XCTAssertTrue(first.isHighlighted)
        XCTAssertTrue(button(bar, 0) === first)
        XCTAssertEqual(collection(bar).visibleCells.map(\.frame), frames)
        XCTAssertEqual(bar.selectedIndex, 0)
        XCTAssertTrue(spy.selected.isEmpty)
    }

    func testRefreshPreservesAnimationPagingAndManualOffsetInBothDirections() {
        for rtl in [false, true] {
            let bar = mount(count: 12)
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            settle(bar)
            bar.setSelectedIndex(8, animated: true)
            bar.advanceSelectionAnimation(to: 0.3)
            let frame = indicator(bar).frame
            let offset = collection(bar).contentOffset
            let before = bar.refreshStatistics
            bar.standardAppearance.backgroundColor = .systemOrange
            bar.items[0].accessibilityHint = "打开频道"
            settle(bar)
            XCTAssertEqual(indicator(bar).frame, frame)
            XCTAssertEqual(collection(bar).contentOffset, offset)
            XCTAssertEqual(bar.refreshStatistics.measurementPasses, before.measurementPasses)
            bar.advanceSelectionAnimation(to: 0.8)
            XCTAssertNotEqual(collection(bar).contentOffset, offset, "轻量刷新不能结束正在进行的动画")

            bar.setTransitionProgress(from: 8, to: 7, progress: 0.4)
            let pagingFrame = indicator(bar).frame
            let pagingOffset = collection(bar).contentOffset
            bar.standardAppearance.shadowImage = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 4))
                .image { _ in }
            settle(bar)
            XCTAssertEqual(indicator(bar).frame, pagingFrame)
            XCTAssertEqual(collection(bar).contentOffset, pagingOffset)
            bar.setSelectedIndex(8, animated: false)
            collection(bar).contentOffset.x = 50
            bar.items[8].badgeColor = .systemRed
            settle(bar)
            XCTAssertEqual(collection(bar).contentOffset.x, 50, accuracy: 0.01)
            bar.removeFromSuperview()
        }
    }

    func testCustomContentUsesItemSnapshotsAndGlobalEnvironmentWithFallback() throws {
        let bar = mount()
        let source = RefreshContentSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        settle(bar)
        let mutations: [() -> Void] = [
            { bar.standardAppearance.backgroundColor = .systemOrange },
            { bar.items[0].accessibilityLabel = "更长的内容" },
            { bar.items[0].badgeColor = .systemGreen }
        ]
        for (index, mutation) in mutations.enumerated() {
            let before = bar.refreshStatistics
            let oldWidth = collection(bar).contentSize.width
            mutation()
            settle(bar)
            XCTAssertGreaterThan(bar.refreshStatistics.measurementPasses, before.measurementPasses)
            XCTAssertEqual(
                bar.refreshStatistics.contentRequests - before.contentRequests,
                index == 0 ? UInt(bar.items.count) : 1
            )
            XCTAssertGreaterThan(collection(bar).contentSize.width, oldWidth)
            collection(bar).scrollToItem(at: IndexPath(item: 2, section: 0), at: .right, animated: false)
            settle(bar)
            let cell = try XCTUnwrap(collection(bar).cellForItem(at: IndexPath(item: 2, section: 0)))
            let fallback = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
            XCTAssertEqual(fallback.configuration?.title, bar.items[2].title, "nil 项仍回退为内置内容")
        }
    }

    func testGeometryChangesStillInvalidateMeasurementAndReflow() {
        let bar = mount()
        for mutation in [
            { bar.items[0].title = String(repeating: "长标题", count: 12) },
            { bar.items[1].badgeValue = "99999" },
            { bar.standardAppearance.itemAppearance.normal.font = .systemFont(ofSize: 36) }
        ] {
            let before = bar.refreshStatistics
            let oldWidth = collection(bar).contentSize.width
            mutation()
            settle(bar)
            XCTAssertGreaterThan(bar.refreshStatistics.measurementPasses, before.measurementPasses)
            XCTAssertGreaterThan(collection(bar).contentSize.width, oldWidth)
        }
    }

    func testSharedItemUpdatesEachHostAndOffscreenContentAppearsCurrent() {
        let bar = mount(count: 12)
        let other = mount()
        let item = bar.items[11]
        other.items = [item]
        settle(other)
        let before = bar.refreshStatistics
        let otherBefore = other.refreshStatistics
        item.accessibilityHint = "共享提示"
        settle(bar)
        settle(other)
        XCTAssertEqual(bar.refreshStatistics, before, "屏幕外项不配置其他可见 Cell")
        XCTAssertEqual(other.refreshStatistics.measurementPasses, otherBefore.measurementPasses)
        XCTAssertEqual(button(other, 0).accessibilityHint, "共享提示")
        bar.setSelectedIndex(11, animated: false)
        settle(bar)
        XCTAssertEqual(button(bar, 11).accessibilityHint, "共享提示")
        other.items = []
        settle(other)
        let detached = other.refreshStatistics
        item.accessibilityHint = "再次更新"
        XCTAssertEqual(other.refreshStatistics, detached)
    }

    func testLightweightChangesKeepCandidateAndAppliedMeasurementIndependent() {
        let bar = mount()
        let frame = collection(bar).frame
        let frames = collection(bar).visibleCells.map(\.frame)
        _ = bar.sizeThatFits(CGSize(width: 150, height: 0))
        let before = bar.refreshStatistics
        bar.items[0].accessibilityLabel = "新描述"
        bar.standardAppearance.backgroundColor = .systemOrange
        settle(bar)
        _ = bar.sizeThatFits(CGSize(width: 150, height: 0))
        XCTAssertEqual(bar.refreshStatistics.measurementPasses, before.measurementPasses)
        XCTAssertEqual(collection(bar).frame, frame)
        XCTAssertEqual(collection(bar).visibleCells.map(\.frame), frames)
    }

    func testSelectedItemAppearanceRemainsBarWideAndCopied() {
        let bar = mount()
        let appearance = SPTabBarAppearance()
        bar.items[0].standardAppearance = appearance
        settle(bar)
        let before = bar.refreshStatistics
        appearance.backgroundColor = .systemOrange
        XCTAssertEqual(bar.refreshStatistics, before, "赋值时复制的源对象不应继续通知宿主")
        bar.items[0].standardAppearance!.backgroundColor = .systemGreen
        settle(bar)
        XCTAssertEqual(bar.refreshStatistics, before)
        XCTAssertEqual(
            bar.subviews.compactMap { $0 as? UIVisualEffectView }.first?.contentView.backgroundColor,
            .systemGreen
        )
        bar.items[0].standardAppearance!.itemAppearance.normal.font = .systemFont(ofSize: 40)
        settle(bar)
        XCTAssertGreaterThan(bar.refreshStatistics.measurementPasses, before.measurementPasses)
        XCTAssertGreaterThan(
            bar.refreshStatistics.cellConfigurations - before.cellConfigurations,
            1,
            "选中 Item 的字体影响整栏，不能仅更新该 Item"
        )
    }

    func testCustomIndicatorGeometryStillReactsToLightweightItemChange() {
        let bar = mount()
        let source = RefreshIndicatorSource()
        bar.indicatorLayoutDelegate = source
        bar.indicatorStyle = .custom
        settle(bar)
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.3)
        let before = bar.refreshStatistics
        bar.items[1].accessibilityLabel = "改变业务指示器宽度"
        settle(bar)
        XCTAssertEqual(bar.refreshStatistics.measurementPasses, before.measurementPasses)
        XCTAssertEqual(indicator(bar).frame.width, 50, accuracy: 0.01)
        let end = indicator(bar).frame
        bar.advanceSelectionAnimation(to: 0.8)
        XCTAssertEqual(indicator(bar).frame, end, "端点几何改变仍按现有规则收敛动画")
    }
}

@MainActor
private final class RefreshIndicatorSource: SPTabBarIndicatorLayoutDelegate {
    func tabBar(_ tabBar: SPTabBar, indicatorFrameFor context: SPTabBarIndicatorLayoutContext) -> CGRect? {
        CGRect(x: context.itemFrame.minX, y: 0, width: context.item.accessibilityLabel == nil ? 20 : 50, height: 3)
    }
}

@MainActor
private final class RefreshContentSource: SPTabBarContentDelegate {
    func content(
        for item: SPTabBarContentItem,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        let index = context.index
        guard index != 2 else {
            return nil
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        // 内容只依赖单项快照和显式环境；外部依赖变化由 reloadContent() 刷新。
        var width: CGFloat = 200
        if context.appearance.backgroundColor == .systemOrange {
            width += 40
        }
        if item.accessibilityLabel != nil {
            width += 40
        }
        if item.badgeColor == .systemGreen {
            width += 40
        }
        return SPTabBarContent(configuration: configuration, size: CGSize(width: width, height: 60))
    }
}
