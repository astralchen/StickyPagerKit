import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarScaleTests: XCTestCase {
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
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        bar.items[1].badgeValue = "12"
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func list(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func content(_ bar: SPTabBar, _ index: Int) throws -> UIView {
        try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: index, section: 0))?.contentView)
    }

    private func host(_ bar: SPTabBar, _ index: Int) throws -> UIView {
        try XCTUnwrap(try content(bar, index).subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" })
    }

    private func button(_ bar: SPTabBar, _ index: Int) throws -> UIButton {
        try XCTUnwrap(try content(bar, index).subviews.compactMap { $0 as? UIButton }.first)
    }

    func testScalePreservesHitAreaAccessibilityAndUnscaledIndicatorGeometry() throws {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            let root = try content(bar, 1)
            let geometry = try XCTUnwrap(root as? SPTabIndicatorContentGeometry)
            let title = geometry.indicatorTitleRect, rect = geometry.indicatorContentRect
            let size = bar.sizeThatFits(bar.bounds.size)
            bar.visualStyle = .scale
            bar.layoutIfNeeded()
            let visual = try host(bar, 1), control = try button(bar, 1)
            XCTAssertEqual(visual.transform.a, 0.94, accuracy: 0.001)
            XCTAssertEqual(control.frame, root.bounds)
            XCTAssertEqual(control.transform, .identity)
            XCTAssertTrue(visual.accessibilityElementsHidden)
            XCTAssertEqual(control.accessibilityValue, "12")
            XCTAssertEqual(control.accessibilityIdentifier, "sp.tab.1")
            XCTAssertEqual(geometry.indicatorTitleRect, title)
            XCTAssertEqual(geometry.indicatorContentRect, rect)
            XCTAssertEqual(bar.sizeThatFits(bar.bounds.size), size)
            let hit = window.hitTest(control.convert(CGPoint(x: 1, y: 1), to: window), with: nil)
            XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
            XCTAssertTrue(control.accessibilityActivate())
            XCTAssertEqual(bar.selectedIndex, 1)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertTrue(control.accessibilityTraits.contains(.selected))
            XCTAssertEqual(visual.transform, .identity)
            let selectedTitle = geometry.indicatorTitleRect
            bar.visualStyle = .standard
            XCTAssertFalse(root.subviews.contains { $0 === visual })
            XCTAssertEqual(geometry.indicatorTitleRect, selectedTitle)
            bar.removeFromSuperview()
        }
    }

    func testContentOnlyAnimationRetargetingPagingAndCancellation() throws {
        let bar = mount()
        bar.indicatorStyle = .none
        bar.visualStyle = .scale
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertEqual(try host(bar, 0).transform.a, 0.97, accuracy: 0.001)
        XCTAssertEqual(try host(bar, 2).transform.a, 0.97, accuracy: 0.001)
        bar.setSelectedIndex(1, animated: true)
        XCTAssertEqual(try host(bar, 2).transform.a, 0.97, accuracy: 0.001)
        bar.advanceSelectionAnimation(to: 0.5)
        let before = try host(bar, 1).transform
        bar.setTransitionProgress(from: 1, to: 0, progress: 0)
        XCTAssertEqual(try host(bar, 1).transform, before)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(try host(bar, 1).transform, before)
        bar.setSelectedIndex(1, animated: false)
        XCTAssertEqual(try host(bar, 1).transform, .identity)
        XCTAssertEqual(try host(bar, 0).transform.a, 0.94, accuracy: 0.001)
    }

    func testCustomTransformClippingHighlightAndCacheRemainOwnedByContent() throws {
        let bar = mount()
        let source = ScaleSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.visualStyle = .scale
        bar.layoutIfNeeded()
        let visual = try host(bar, 1)
        let custom = try XCTUnwrap(visual.subviews.compactMap { $0 as? ScaleContentView }.first)
        let transform = custom.transform
        XCTAssertEqual(custom.bounds.height, 100)
        XCTAssertTrue(visual.clipsToBounds)
        let stats = bar.refreshStatistics, requests = source.requests
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        XCTAssertEqual(custom.transform, transform)
        XCTAssertEqual(bar.refreshStatistics, stats)
        XCTAssertEqual(source.requests, requests)
        let control = try button(bar, 1)
        control.isHighlighted = true
        XCTAssertTrue(custom.value.highlighted)
        control.isHighlighted = false
        XCTAssertFalse(custom.value.highlighted)
        bar.frame.size = CGSize(width: 420, height: 40)
        bar.layoutIfNeeded()
        XCTAssertEqual(custom.transform, transform)
        XCTAssertEqual(custom.bounds.height, 100)
        XCTAssertEqual(control.frame, try content(bar, 1).bounds)
        bar.visualStyle = .standard
        XCTAssertTrue(custom.superview === (try content(bar, 1)))
        XCTAssertEqual(custom.transform, transform)
        withExtendedLifetime(source) {}
    }

    func testDisabledModeChangesAndReorderResetPresentation() throws {
        let bar = mount()
        bar.visualStyle = .scale
        bar.visualStyle.interpolatesDefaultColors = true
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
        XCTAssertEqual(try host(bar, 1).transform.a, 0.955, accuracy: 0.001)
        bar.items[1].isEnabled = false
        bar.layoutIfNeeded()
        XCTAssertNil(try content(bar, 1).subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" })
        XCTAssertFalse(try button(bar, 1).isEnabled)
        bar.items[1].isEnabled = true
        bar.layoutIfNeeded()
        let selected = bar.selectedItem
        bar.items = Array(bar.items.reversed())
        bar.layoutIfNeeded()
        XCTAssertTrue(bar.selectedItem === selected)
        XCTAssertEqual(try host(bar, 2).transform, .identity)
        let source = ScaleSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.layoutIfNeeded()
        bar.contentStyle = .standard
        bar.layoutIfNeeded()
        XCTAssertEqual(try host(bar, 1).transform.a, 0.94, accuracy: 0.001)
        bar.visualStyle = .standard
        for index in 0 ..< 3 {
            XCTAssertNil(try content(bar, index).subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" })
            XCTAssertEqual(try button(bar, index).transform, .identity)
        }
        withExtendedLifetime(source) {}
    }

    func testScrollingReusePreservesManualOffsetAndRestoresFullSize() throws {
        let bar = mount()
        bar.items = (0 ..< 12).map { SPTabBarItem(title: "频道 \($0)") }
        bar.layoutConfiguration.itemSizing = .fixed(120)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        let collection = list(bar)
        collection.contentOffset.x = 170
        collection.layoutIfNeeded()
        bar.layoutIfNeeded()
        let stats = bar.refreshStatistics
        bar.visualStyle = .scale
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 170, accuracy: 0.001)
        XCTAssertEqual(bar.refreshStatistics, stats)
        collection.contentOffset.x = 1000
        collection.layoutIfNeeded()
        bar.layoutIfNeeded()
        for path in collection.indexPathsForVisibleItems {
            XCTAssertEqual(try host(bar, path.item).transform.a, 0.94, accuracy: 0.001)
            XCTAssertEqual(try button(bar, path.item).accessibilityIdentifier, "sp.tab.\(path.item)")
        }
        bar.visualStyle = .standard
        for cell in collection.visibleCells {
            XCTAssertFalse(cell.contentView.subviews.contains { $0.accessibilityIdentifier == "sp.tab.visualHost" })
        }
    }

    func testNormalizationAndReduceMotionFallback() {
        let bar = mount()
        bar.visualStyle.unselectedScale = -1
        XCTAssertEqual(bar.visualStyle.unselectedScale, 0.8)
        bar.visualStyle.unselectedScale = .nan
        XCTAssertEqual(bar.visualStyle, .standard)
        bar.visualStyle.unselectedScale = 2
        XCTAssertEqual(bar.visualStyle, .standard)
        XCTAssertEqual(SPTabBarVisualStyle.scale.scale(progress: 0, enabled: true, reduceMotion: true), 1)
        XCTAssertEqual(SPTabBarVisualStyle.scale.scale(progress: 0, enabled: false, reduceMotion: false), 1)
    }
}

@MainActor
private final class ScaleSource: SPTabBarContentDelegate {
    var requests = 0
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        requests += 1
        return SPTabBarContent(configuration: ScaleConfiguration(), size: CGSize(width: 100, height: 100))
    }
}

private struct ScaleConfiguration: UIContentConfiguration {
    var highlighted = false
    func makeContentView() -> UIView & UIContentView {
        ScaleContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        var result = self
        result.highlighted = (state as? UICellConfigurationState)?.isHighlighted ?? false
        return result
    }
}

@MainActor
private final class ScaleContentView: UIView, UIContentView {
    var value: ScaleConfiguration
    var configuration: UIContentConfiguration {
        get { value }
        set { value = newValue as! ScaleConfiguration }
    }

    init(configuration: ScaleConfiguration) {
        value = configuration
        super.init(frame: .zero)
        transform = CGAffineTransform(rotationAngle: 0.04)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
