import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarVisualStyleTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window = nil
    }

    private func mount(rtl: Bool = false, source: VisualContentSource? = nil) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 60))
        bar.layoutConfiguration.contentInsets = .zero
        bar.layoutConfiguration.itemSpacing = 0
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)") }
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.contentDelegate = source
        if source != nil {
            bar.contentStyle = .custom
        }
        var layout = SPTabBarIndicatorLayout.underline(width: .fixed(20))
        layout.reference = .item
        bar.standardAppearance.indicatorLayout = layout
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func list(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func cell(_ bar: SPTabBar, _ index: Int) throws -> UICollectionViewCell {
        try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: index, section: 0)))
    }

    private func indicator(_ bar: SPTabBar) -> UIView {
        list(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
    }

    private func endpoint(_ bar: SPTabBar, _ index: Int) -> CGRect {
        let rect = list(bar).layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
        return CGRect(x: rect.midX - 10, y: rect.maxY - 3, width: 20, height: 3)
    }

    func testStandardAndNormalizedStylesPreserveLayoutAndRemainHittable() throws {
        let bar = mount()
        XCTAssertEqual(bar.visualStyle, .standard)
        let before = try cell(bar, 1).frame
        bar.visualStyle = SPTabBarVisualStyle(unselectedAlpha: -5)
        XCTAssertEqual(bar.visualStyle.unselectedAlpha, 0.2)
        let content = try cell(bar, 1).contentView
        XCTAssertEqual(content.alpha, 0.2, accuracy: 0.001)
        let button = try XCTUnwrap(content.subviews.compactMap { $0 as? UIButton }.first)
        let hit = window.hitTest(
            button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window),
            with: nil
        )
        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(bar.selectedIndex, 1)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertTrue(button.accessibilityTraits.contains(.selected))
        XCTAssertEqual(try cell(bar, 1).frame, before)
        bar.visualStyle.unselectedAlpha = .nan
        XCTAssertEqual(bar.visualStyle, .standard)
        for index in 0 ..< 3 {
            XCTAssertEqual(try cell(bar, index).contentView.alpha, 1)
        }
        bar.visualStyle.unselectedAlpha = .infinity
        XCTAssertEqual(bar.visualStyle, .standard)
    }

    func testFadeUsesContinuousProgressWithoutReconfigurationOrMeasurement() throws {
        for rtl in [false, true] {
            let source = VisualContentSource()
            let bar = mount(rtl: rtl, source: source)
            bar.visualStyle = .fadeAndStretch
            let stats = bar.refreshStatistics
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
            XCTAssertEqual(try cell(bar, 0).contentView.alpha, 0.91, accuracy: 0.001)
            XCTAssertEqual(try cell(bar, 1).contentView.alpha, 0.64, accuracy: 0.001)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
            XCTAssertEqual(bar.refreshStatistics, stats)
            XCTAssertEqual(bar.selectedIndex, 0)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.8)
            XCTAssertEqual(try cell(bar, 1).contentView.alpha, 0.91, accuracy: 0.001)
            bar.setSelectedIndex(0, animated: false)
            XCTAssertEqual(try cell(bar, 0).contentView.alpha, 1)
            XCTAssertEqual(try cell(bar, 1).contentView.alpha, 0.55, accuracy: 0.001)
            bar.items[1].isEnabled = false
            XCTAssertEqual(try cell(bar, 1).contentView.alpha, 1, "禁用外观不叠加淡化")
            bar.contentStyle = .standard
            XCTAssertEqual(try cell(bar, 2).contentView.alpha, 0.55, accuracy: 0.001)
            bar.visualStyle = .standard
            XCTAssertEqual(try cell(bar, 2).contentView.alpha, 1)
            bar.removeFromSuperview()
        }
    }

    func testStretchKeepsEndpointsAndMirrorsForwardAndReverseInRTL() {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            let a = endpoint(bar, 0), b = endpoint(bar, 1)
            bar.visualStyle = .stretch
            bar.setTransitionProgress(from: 0, to: 1, progress: 0)
            XCTAssertEqual(indicator(bar).frame, a)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.5)
            let middle = indicator(bar).frame
            XCTAssertEqual(middle.midX, (a.midX + b.midX) / 2, accuracy: 0.001)
            XCTAssertEqual(middle.width, 80, accuracy: 0.001)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
            let quarter = indicator(bar).frame
            XCTAssertEqual(quarter.width, 65, accuracy: 0.001)
            bar.setNeedsLayout(); bar.layoutIfNeeded()
            XCTAssertEqual(indicator(bar).frame, quarter, "布局回调也须使用相同拉伸曲线")
            bar.setTransitionProgress(from: 1, to: 0, progress: 0.75)
            XCTAssertEqual(indicator(bar).frame, quarter)
            bar.setTransitionProgress(from: 0, to: 1, progress: 1)
            XCTAssertEqual(indicator(bar).frame, b)
            bar.setSelectedIndex(0, animated: false)
            XCTAssertEqual(indicator(bar).frame, a)
            bar.removeFromSuperview()
        }
    }

    func testProgramAnimationAndPagingTakeoverContinueFromPresentedGeometry() throws {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            bar.visualStyle = .fadeAndStretch
            bar.setSelectedIndex(1, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            XCTAssertEqual(indicator(bar).frame.width, 80, accuracy: 0.001)
            let before = indicator(bar).frame
            bar.setSelectedIndex(2, animated: true)
            XCTAssertEqual(indicator(bar).frame, before)
            XCTAssertEqual(try cell(bar, 0).contentView.alpha, 0.775, accuracy: 0.001)
            bar.advanceSelectionAnimation(to: 0.5)
            let interrupted = indicator(bar).frame
            bar.setTransitionProgress(from: 1, to: 2, progress: 0)
            XCTAssertEqual(indicator(bar).frame, interrupted)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(indicator(bar).frame, interrupted)
            bar.setTransitionProgress(from: 1, to: 2, progress: 0.5)
            bar.frame.size.width = 420
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator(bar).frame.width, 90, accuracy: 0.001)
            XCTAssertEqual(
                indicator(bar).frame.midX,
                (endpoint(bar, 1).midX + endpoint(bar, 2).midX) / 2,
                accuracy: 0.001
            )
            bar.setSelectedIndex(2, animated: false)
            XCTAssertEqual(indicator(bar).frame, endpoint(bar, 2))
            bar.removeFromSuperview()
        }
    }

    func testContentOnlyAnimationAndEquivalentAssignmentDoNotLoseContinuity() throws {
        let bar = mount()
        bar.indicatorStyle = .none
        bar.visualStyle = .fade
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertEqual(try cell(bar, 0).contentView.alpha, 0.775, accuracy: 0.001)
        bar.visualStyle = .fade
        bar.advanceSelectionAnimation(to: 0.8)
        XCTAssertGreaterThan(try cell(bar, 1).contentView.alpha, 0.9)
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(try cell(bar, 2).contentView.alpha, 1)
        bar.visualStyle = .standard
        XCTAssertEqual(try cell(bar, 0).contentView.alpha, 1)
    }

    func testRuntimeStyleChangeDoesNotReloadContentOrMoveManualOffsetAndReusedCellsResetAlpha() throws {
        let source = VisualContentSource()
        let bar = mount(source: source)
        bar.items = (0 ..< 12).map { SPTabBarItem(title: "标签 \($0)") }
        bar.layoutConfiguration.itemSizing = .fixed(120)
        bar.setSelectedIndex(5, animated: false)
        bar.layoutIfNeeded()
        let collection = list(bar)
        collection.contentOffset.x = 170
        // 先完成手动滚动引起的 Cell 复用，再单独计量预设赋值的工作量。
        collection.layoutIfNeeded()
        bar.layoutIfNeeded()
        let stats = bar.refreshStatistics
        bar.visualStyle = .fadeAndStretch
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 170, accuracy: 0.001)
        XCTAssertEqual(bar.refreshStatistics, stats)
        collection.contentOffset.x = 1000
        collection.layoutIfNeeded()
        for path in collection.indexPathsForVisibleItems {
            XCTAssertEqual(try cell(bar, path.item).contentView.alpha, path.item == 5 ? 1 : 0.55, accuracy: 0.001)
        }
        bar.items = Array(bar.items.reversed())
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.selectedIndex, 6)
        XCTAssertEqual(try cell(bar, 6).contentView.alpha, 1)
        bar.visualStyle = .standard
        for visible in collection.visibleCells {
            XCTAssertEqual(visible.contentView.alpha, 1)
        }
    }

    func testCustomIndicatorReceivesStretchedFrameAndUnchangedLogicalProgress() {
        let bar = mount()
        let view = VisualIndicatorView()
        bar.indicatorStyle = .custom
        bar.indicatorView = view
        bar.visualStyle = .stretch
        bar.setTransitionProgress(from: 0, to: 2, progress: 0.5)
        XCTAssertEqual(view.state?.progress, 0.5)
        XCTAssertEqual(view.state?.fromIndex, 0)
        XCTAssertEqual(view.state?.toIndex, 2)
        XCTAssertEqual(view.state?.frame.width ?? 0, 140, accuracy: 0.001)
        XCTAssertEqual(view.frame, indicator(bar).bounds)
        bar.setSelectedIndex(0, animated: false)
        XCTAssertEqual(indicator(bar).frame, endpoint(bar, 0))
    }

    func testAccessibilityFallbacksAndNotificationFinishCurrentAnimation() throws {
        let style = SPTabBarVisualStyle.fadeAndStretch
        XCTAssertEqual(style.alpha(progress: 0, enabled: true, reduceTransparency: true), 1)
        XCTAssertEqual(style.motion(reduceMotion: true), .linear)
        let bar = mount()
        bar.visualStyle = style
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator(bar).frame, endpoint(bar, 1))
        XCTAssertEqual(try cell(bar, 1).contentView.alpha, 1)
        bar.advanceSelectionAnimation(to: 0.7)
        XCTAssertEqual(indicator(bar).frame, endpoint(bar, 1))
    }
}

@MainActor
private final class VisualContentSource: SPTabBarContentDelegate {
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        guard context.index != 2 else {
            return nil
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(configuration: configuration, size: CGSize(width: 100, height: 50))
    }
}

@MainActor
private final class VisualIndicatorView: SPTabBarIndicatorView {
    var state: SPTabBarIndicatorState?
    override func update(_ state: SPTabBarIndicatorState) {
        self.state = state
        super.update(state)
    }
}
