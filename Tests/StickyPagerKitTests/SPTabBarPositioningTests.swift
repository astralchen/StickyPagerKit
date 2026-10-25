import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarPositioningTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.closeForTesting()
        window = nil
    }

    private func mount(count: Int = 3, width: CGFloat = 400, rtl: Bool = false) -> (SPTabBar, UICollectionView) {
        window?.closeForTesting()
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = UIViewController()
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: width, height: 80))
        // 此夹具显式验证 automatic 分配；频道型默认组合由专门用例覆盖。
        bar.layoutConfiguration.itemSizing = .balanced
        // 此夹具显式使用零留白，隔离 Item 宽度与间距算法；默认留白由附件布局测试覆盖。
        bar.layoutConfiguration.contentInsets = .zero
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        window.rootViewController!.view.addSubview(bar)
        bar.items = (0 ..< count).map { SPTabBarItem(title: "标签 \($0)") }
        bar.setSelectedIndex(count > 0 ? 0 : nil, animated: false)
        bar.layoutIfNeeded()
        return (bar, bar.subviews.compactMap { $0 as? UICollectionView }.first!)
    }

    private func frame(_ index: Int, in list: UICollectionView) -> CGRect {
        list.layoutIfNeeded()
        return list.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    func testModesDistributeWidthsAndRestoreAutomaticInBothDirections() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            let source = PositioningSource()
            bar.contentDelegate = source
            bar.contentStyle = .custom
            bar.layoutConfiguration.itemSpacing = 20
            XCTAssertEqual(bar.layoutConfiguration.itemSizing, .balanced)
            for (sizing, alignment, expected): (
                SPTabBarLayoutConfiguration.ItemSizing,
                SPTabBarLayoutConfiguration.Alignment,
                [CGFloat]
            ) in [
                (.balanced, .leading, [200, 80, 80]),
                (.equal, .leading, [120, 120, 120]),
                (.content, .center, [200, 44, 44]),
                (.content, .leading, [200, 44, 44]),
                (.balanced, .leading, [200, 80, 80])
            ] {
                var layout = bar.layoutConfiguration
                layout.itemSizing = sizing
                layout.alignment = alignment
                bar.layoutConfiguration = layout
                bar.layoutIfNeeded()
                for index in 0 ..< 3 {
                    XCTAssertEqual(frame(index, in: list).width, expected[index], accuracy: 0.01)
                }
                let frames = (0 ..< 3).map { frame($0, in: list) }.sorted { $0.minX < $1.minX }
                let leftMargin: CGFloat = alignment == .center ? 36 :
                    (sizing == .content && alignment == .leading && rtl ? 72 : 0)
                let rightMargin: CGFloat = alignment == .center ? 36 :
                    (sizing == .content && alignment == .leading && !rtl ? 72 : 0)
                XCTAssertEqual(frames[0].minX, leftMargin, accuracy: 0.01)
                XCTAssertEqual(400 - frames[2].maxX, rightMargin, accuracy: 0.01)
                XCTAssertEqual(frames[1].minX - frames[0].maxX, 20, accuracy: 0.01)
                XCTAssertEqual(frame(0, in: list).minX > frame(2, in: list).minX, rtl)
                XCTAssertEqual(list.contentSize.width, 400, accuracy: 0.01)
            }
        }
    }

    func testFillRespectsMinimumAndCenteredOverflowsWithoutStretching() {
        let (bar, list) = mount(width: 300)
        let source = PositioningSource()
        source.widths = [240, 80, 60]
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.layoutConfiguration.itemSpacing = 10
        bar.layoutConfiguration.itemSizing = .content
        bar.layoutConfiguration.alignment = .center
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentSize.width, 400, accuracy: 0.01)
        bar.layoutConfiguration.minimumItemWidth = 120
        bar.layoutConfiguration.itemSizing = .equal
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentSize.width, 380, accuracy: 0.01)
        for index in 0 ..< 3 {
            XCTAssertEqual(frame(index, in: list).width, 120, accuracy: 0.01)
        }
        list.contentOffset.x = 80
        bar.layoutConfiguration.minimumItemWidth = 0
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, in: list).width, 280 / 3, accuracy: 0.01)
        XCTAssertEqual(list.contentOffset.x, 0, accuracy: 0.01)
    }

    func testSafeAreaAccessoriesInsetsAndResizeUseRemainingViewport() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            let source = PositioningSource()
            source.widths = [50, 50, 50]
            bar.contentDelegate = source
            bar.contentStyle = .custom
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            let accessory = UIView()
            accessory.widthAnchor.constraint(equalToConstant: 40).isActive = true
            accessory.heightAnchor.constraint(equalToConstant: 30).isActive = true
            bar.leadingAccessoryView = accessory
            bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                top: 2,
                leading: 10,
                bottom: 4,
                trailing: 20
            )
            bar.layoutConfiguration.itemSpacing = 10
            window.rootViewController!.view.layoutIfNeeded()
            for width: CGFloat in [400, 300, 400] {
                bar.frame.size.width = width
                for (sizing, alignment): (
                    SPTabBarLayoutConfiguration.ItemSizing,
                    SPTabBarLayoutConfiguration.Alignment
                ) in [(.equal, .leading), (.content, .center), (.content, .leading)] {
                    var layout = bar.layoutConfiguration
                    layout.itemSizing = sizing
                    layout.alignment = alignment
                    bar.layoutConfiguration = layout
                    bar.layoutIfNeeded()
                    let viewport = width - bar.safeAreaInsets.left - bar.safeAreaInsets.right - 40
                    XCTAssertEqual(list.bounds.width, viewport, accuracy: 0.01)
                    let first = (0 ..< 3).map { frame($0, in: list) }.min { $0.minX < $1.minX }!
                    let remaining = max(0, viewport - 30 - 170)
                    let extra = alignment == .center ? remaining / 2 :
                        (sizing == .content && alignment == .leading && rtl ? remaining : 0)
                    XCTAssertEqual(first.minX, (rtl ? 20 : 10) + extra, accuracy: 0.01)
                    XCTAssertEqual(first.width, sizing == .equal ? (viewport - 50) / 3 : 50, accuracy: 0.01)
                }
            }
        }
    }

    func testEmptySingleAndDefaultOrFallbackContent() {
        for count in [0, 1, 3] {
            let (bar, list) = mount(count: count)
            let source = PositioningSource()
            source.fallbackIndex = 0
            bar.contentDelegate = source
            for style: SPTabBar.ContentStyle in [.default, .custom] {
                bar.contentStyle = style
                if count > 0 {
                    bar.items[0].title = String(repeating: "长标题", count: 15)
                }
                for (sizing, alignment): (
                    SPTabBarLayoutConfiguration.ItemSizing,
                    SPTabBarLayoutConfiguration.Alignment
                ) in [(.balanced, .leading), (.equal, .leading), (.content, .center), (.content, .leading)] {
                    var layout = bar.layoutConfiguration
                    layout.itemSizing = sizing
                    layout.alignment = alignment
                    bar.layoutConfiguration = layout
                    bar.layoutIfNeeded()
                    XCTAssertTrue(list.contentSize.width.isFinite)
                    if count == 0 {
                        XCTAssertEqual(list.contentSize.width, 400)
                    } else if sizing == .equal {
                        XCTAssertEqual(frame(0, in: list).width, 400 / CGFloat(count), accuracy: 0.01)
                    } else {
                        XCTAssertGreaterThan(frame(0, in: list).width, 400)
                    }
                }
            }
        }
    }

    func testAutomaticContentHeightUsesAllocatedWidthAndCandidateMeasurementIsPure() {
        let (bar, list) = mount(count: 2)
        let source = AutomaticTabSource()
        source.text = String(repeating: "可换行的标签内容", count: 8)
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.layoutConfiguration.itemSizing = .content
        bar.layoutConfiguration.alignment = .center
        let naturalHeight = bar.sizeThatFits(bar.bounds.size).height
        bar.layoutConfiguration.itemSizing = .equal
        let fillHeight = bar.sizeThatFits(bar.bounds.size).height
        XCTAssertGreaterThan(fillHeight, naturalHeight)
        bar.frame.size.height = fillHeight
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, in: list).width, 200, accuracy: 0.01)
        let before = frame(0, in: list)
        let offset = list.contentOffset
        let narrowHeight = bar.sizeThatFits(CGSize(width: 200, height: 0)).height
        XCTAssertGreaterThan(narrowHeight, fillHeight)
        XCTAssertEqual(frame(0, in: list), before)
        XCTAssertEqual(list.contentOffset, offset)
        let host = window.rootViewController!
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        child.view.addSubview(bar)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: child
        )
        child.view.layoutIfNeeded()
        XCTAssertEqual(bar.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(bar.sizeThatFits(bar.bounds.size).height, fillHeight)
    }

    func testSwitchPreservesSelectionAndPagingIndicatorWithoutCallbacks() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            let source = PositioningSource()
            let spy = PositioningSpy()
            bar.contentDelegate = source
            bar.contentStyle = .custom
            bar.delegate = spy
            bar.indicatorStyle = .underline
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.4)
            let selected = bar.selectedItem
            for (sizing, alignment): (
                SPTabBarLayoutConfiguration.ItemSizing,
                SPTabBarLayoutConfiguration.Alignment
            ) in [
                (.equal, .leading),
                (.content, .center),
                (.content, .leading),
                (.balanced, .leading)
            ] {
                var layout = bar.layoutConfiguration
                layout.itemSizing = sizing
                layout.alignment = alignment
                bar.layoutConfiguration = layout
                bar.layoutIfNeeded()
                let a = frame(0, in: list), b = frame(1, in: list)
                let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
                XCTAssertEqual(indicator.frame.midX, a.midX + (b.midX - a.midX) * 0.4, accuracy: 0.01)
                XCTAssertTrue(bar.selectedItem === selected)
                XCTAssertEqual(spy.selections, 0)
            }
        }
    }

    func testLeadingShortSingleItemAndEmptyContentKeepUnusedSpaceAtTrailing() {
        for rtl in [false, true] {
            for count in [0, 1] {
                let (bar, list) = mount(count: count, rtl: rtl)
                let source = PositioningSource()
                source.widths = [20]
                bar.contentDelegate = source
                bar.contentStyle = .custom
                bar.layoutConfiguration.itemSpacing = 80
                bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                    top: 0,
                    leading: 10,
                    bottom: 0,
                    trailing: 20
                )
                bar.layoutConfiguration.itemSizing = .content
                bar.layoutConfiguration.alignment = .leading
                bar.layoutIfNeeded()
                XCTAssertEqual(list.contentSize.width, 400, accuracy: 0.01)
                XCTAssertEqual(list.contentOffset.x, 0, accuracy: 0.01)
                if count == 1 {
                    XCTAssertEqual(frame(0, in: list).width, 44, accuracy: 0.01)
                    XCTAssertEqual(frame(0, in: list).minX, rtl ? 346 : 10, accuracy: 0.01)
                    bar.layoutConfiguration.minimumItemWidth = 0
                    bar.layoutIfNeeded()
                    XCTAssertEqual(frame(0, in: list).width, 20, accuracy: 0.01)
                    XCTAssertEqual(frame(0, in: list).minX, rtl ? 370 : 10, accuracy: 0.01)
                }
            }
        }
    }

    func testLeadingOverflowMatchesCenteredAndPreservesScrollingAndAnimation() {
        for rtl in [false, true] {
            let (bar, list) = mount(count: 8, width: 320, rtl: rtl)
            let source = PositioningSource()
            source.widths = [100]
            bar.contentDelegate = source
            bar.contentStyle = .custom
            bar.layoutConfiguration.itemSpacing = 12
            bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 10,
                bottom: 0,
                trailing: 20
            )
            bar.layoutConfiguration.itemSizing = .content
            bar.layoutConfiguration.alignment = .center
            bar.layoutIfNeeded()
            let frames = (0 ..< 8).map { frame($0, in: list) }
            XCTAssertEqual(list.contentSize.width, 914, accuracy: 0.01)
            list.contentOffset.x = 120
            bar.layoutConfiguration.itemSizing = .content
            bar.layoutConfiguration.alignment = .leading
            bar.layoutIfNeeded()
            XCTAssertEqual((0 ..< 8).map { frame($0, in: list) }, frames)
            XCTAssertEqual(list.contentOffset.x, 120, accuracy: 0.01)
            bar.setSelectedIndex(3, animated: false)
            XCTAssertEqual(list.contentOffset.x, frames[3].midX - 160, accuracy: 0.01)
            XCTAssertGreaterThan(frames[3].minX - list.contentOffset.x, 0)
            bar.setSelectedIndex(7, animated: true)
            bar.advanceSelectionAnimation(to: 0.4)
            let midway = list.contentOffset.x
            bar.layoutConfiguration.itemSizing = .content
            bar.layoutConfiguration.alignment = .center
            bar.layoutIfNeeded()
            XCTAssertEqual(list.contentOffset.x, midway, accuracy: 0.01)
            bar.layoutConfiguration.itemSizing = .content
            bar.layoutConfiguration.alignment = .leading
            bar.layoutIfNeeded()
            XCTAssertEqual(list.contentOffset.x, midway, accuracy: 0.01)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertGreaterThan(abs(list.contentOffset.x - midway), 1)
        }
    }

    func testLeadingUsesNaturalAutomaticContentWidthAndTracksDynamicType() {
        for rtl in [false, true] {
            let (bar, list) = mount(count: 1, rtl: rtl)
            let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: CGSize(
                width: 520,
                height: 28
            )))
            bar.contentDelegate = source
            bar.contentStyle = .custom
            bar.layoutConfiguration.itemSizing = .content
            bar.layoutConfiguration.alignment = .leading
            bar.layoutIfNeeded()
            XCTAssertEqual(frame(0, in: list).width, 520, accuracy: 0.01)
            XCTAssertEqual(list.contentSize.width, 520, accuracy: 0.01)
            let before = frame(0, in: list)
            let offset = list.contentOffset
            _ = bar.sizeThatFits(CGSize(width: 100, height: 0))
            XCTAssertEqual(frame(0, in: list), before)
            XCTAssertEqual(list.contentOffset, offset)

            let automatic = AutomaticTabSource()
            automatic.text = "标签"
            bar.contentDelegate = automatic
            bar.layoutIfNeeded()
            let normalWidth = frame(0, in: list).width
            let host = window.rootViewController!
            let child = UIViewController()
            host.addChild(child)
            host.view.addSubview(child.view)
            child.didMove(toParent: host)
            child.view.addSubview(bar)
            host.setOverrideTraitCollection(
                UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
                forChild: child
            )
            child.view.layoutIfNeeded()
            bar.layoutIfNeeded()
            XCTAssertEqual(bar.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge)
            let large = frame(0, in: list)
            XCTAssertGreaterThan(large.width, normalWidth)
            XCTAssertEqual(rtl ? large.maxX : large.minX, rtl ? 400 : 0, accuracy: 0.01)
        }
    }

    func testFillMeasuresMultilineSystemContentAtCellWidth() {
        let (bar, list) = mount(count: 2)
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.text = String(repeating: "系统内容需要换行", count: 10)
        configuration.textProperties.numberOfLines = 0
        let source = StaticAutomaticSource(configuration: configuration)
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.layoutConfiguration.itemSizing = .equal
        let height = bar.sizeThatFits(bar.bounds.size).height
        bar.frame.size.height = height
        bar.layoutIfNeeded()
        let cell = list.cellForItem(at: IndexPath(item: 0, section: 0))!
        cell.layoutIfNeeded()
        let content = cell.contentView.subviews.compactMap { $0 as? UIListContentView }.first!
        let fitted = content.systemLayoutSizeFitting(
            CGSize(width: frame(0, in: list).width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        XCTAssertEqual(height, ceil(fitted.height), accuracy: 1)
        XCTAssertGreaterThan(bar.sizeThatFits(CGSize(width: 200, height: 0)).height, height)
    }

    func testFillTruncatesDefaultLongTitle() {
        let (bar, list) = mount()
        bar.items[0].title = String(repeating: "长标题", count: 30)
        bar.layoutConfiguration.itemSizing = .equal
        bar.layoutIfNeeded()
        let cell = list.cellForItem(at: IndexPath(item: 0, section: 0))!
        func button(in view: UIView) -> UIButton? {
            if let button = view as? UIButton {
                return button
            }
            return view.subviews.lazy.compactMap { button(in: $0) }.first
        }
        XCTAssertEqual(button(in: cell)?.configuration?.titleLineBreakMode, .byTruncatingTail)
        XCTAssertEqual(frame(0, in: list).width, 400 / 3, accuracy: 0.01)
    }

    func testEquivalentModeAndRepeatedAssignmentPreserveSelectionAnimation() {
        let (bar, list) = mount(count: 8, width: 320)
        bar.layoutConfiguration.minimumItemWidth = 100
        bar.layoutIfNeeded()
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.4)
        let midway = list.contentOffset.x
        bar.layoutConfiguration.itemSizing = .equal
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentOffset.x, midway, accuracy: 0.01)
        bar.layoutConfiguration.itemSizing = .equal
        bar.layoutIfNeeded()
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertGreaterThan(list.contentOffset.x, midway)
    }
}

@MainActor
private final class PositioningSource: SPTabBarContentDelegate {
    var widths: [CGFloat] = [200, 40, 40]
    var fallbackIndex: Int?
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        guard index != fallbackIndex else {
            return nil
        }
        return SPTabBarContent(
            configuration: IntrinsicTabConfiguration(),
            size: CGSize(width: widths[index % widths.count], height: 28)
        )
    }
}

@MainActor
private final class PositioningSpy: SPTabBarDelegate {
    var selections = 0
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        selections += 1
    }
}
