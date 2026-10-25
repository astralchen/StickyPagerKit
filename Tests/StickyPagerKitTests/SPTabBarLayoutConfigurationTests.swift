import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarLayoutConfigurationTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.closeForTesting()
        window = nil
    }

    private func mount(rtl: Bool = false) -> (SPTabBar, UICollectionView) {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = UIViewController()
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 400, height: 80))
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        window.rootViewController!.view.addSubview(bar)
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)") }
        bar.selectedItem = bar.items[0]
        bar.layoutIfNeeded()
        return (bar, bar.subviews.compactMap { $0 as? UICollectionView }.first!)
    }

    private func frame(_ index: Int, _ list: UICollectionView) -> CGRect {
        list.layoutIfNeeded()
        return list.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    func testFixedWidthsAndIndependentAlignmentRespectSafeAreaAccessoriesAndRTL() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            let accessory = UIView()
            NSLayoutConstraint.activate([
                accessory.widthAnchor.constraint(equalToConstant: 40),
                accessory.heightAnchor.constraint(equalToConstant: 30)
            ])
            bar.leadingAccessoryView = accessory
            var layout = bar.layoutConfiguration
            layout.itemSizing = .fixed(60)
            layout.itemSpacing = 10
            layout.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 4, trailing: 12)
            for alignment: SPTabBarLayoutConfiguration.Alignment in [.leading, .center, .trailing] {
                layout.alignment = alignment
                bar.layoutConfiguration = layout
                window.layoutIfNeeded()
                bar.layoutIfNeeded()
                XCTAssertEqual(list.bounds.width, 310, accuracy: 0.01)
                let slack: CGFloat = 90
                let extra: CGFloat = alignment == .center ? slack / 2 : ((alignment == .leading) == rtl ? slack : 0)
                let physicalFirst = frame(rtl ? 2 : 0, list)
                XCTAssertEqual(physicalFirst.minX, (rtl ? 12 : 8) + extra, accuracy: 0.01)
                for index in 0 ..< 3 {
                    XCTAssertEqual(frame(index, list).width, 60, accuracy: 0.01)
                    XCTAssertEqual(frame(index, list).height, 74, accuracy: 0.01)
                }
                XCTAssertEqual(bar.selectedIndex, 0)
            }
            window.closeForTesting()
        }
    }

    func testContentWidthLimitReflowsAutomaticContentWithoutCommittingCandidateMeasurement() {
        let (bar, list) = mount()
        let provider = AutomaticTabSource()
        provider.text = String(repeating: "根据实际分配宽度换行。", count: 8)
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.layoutConfiguration.maximumItemWidth = 120
        let height = bar.sizeThatFits(bar.bounds.size).height
        bar.frame.size.height = height
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, list).width, 120, accuracy: 0.01)
        let original = frame(0, list)
        let offset = list.contentOffset
        _ = bar.sizeThatFits(CGSize(width: 200, height: 0))
        XCTAssertEqual(frame(0, list), original)
        XCTAssertEqual(list.contentOffset, offset)
        bar.layoutConfiguration.maximumItemWidth = 80
        XCTAssertGreaterThan(bar.sizeThatFits(bar.bounds.size).height, height)
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, list).width, 80, accuracy: 0.01)
        bar.layoutConfiguration.minimumItemWidth = 100
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, list).width, 100, accuracy: 0.01)
    }

    func testNormalizedEqualConfigurationPreservesAnimationAndInvalidIndexDoesNotCancelIt() {
        let (bar, list) = mount()
        bar.layoutConfiguration.itemSizing = .fixed(180)
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.4)
        let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
        let midway = indicator.frame
        let offset = list.contentOffset
        var layout = bar.layoutConfiguration
        layout.itemSpacing = -10
        layout.contentInsets.top = .nan
        bar.layoutConfiguration = layout
        bar.setSelectedIndex(-1, animated: true)
        bar.setSelectedIndex(99, animated: false)
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.selectedIndex, 2)
        XCTAssertEqual(indicator.frame, midway)
        XCTAssertEqual(list.contentOffset, offset)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertNotEqual(indicator.frame, midway)
        bar.setTransitionProgress(from: 2, to: 1, progress: 0.3)
        let pagingFrame = indicator.frame
        bar.setSelectedIndex(99, animated: true)
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, pagingFrame)
        bar.setSelectedIndex(nil, animated: false)
        XCTAssertNil(bar.selectedIndex)
        XCTAssertEqual(indicator.frame, .zero)
    }

    func testDefaultDimensionsDriveMeasurementRenderingAndRestore() throws {
        let (bar, list) = mount()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        bar.items = [SPTabBarItem(title: nil, image: image)]
        bar.layoutConfiguration.minimumItemWidth = 0
        let originalHeight = bar.sizeThatFits(bar.bounds.size).height
        var content = bar.defaultContentLayout
        content.imagePlacement = .inline
        content.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 6, bottom: 7, trailing: 10)
        content.iconSize = CGSize(width: 20, height: 20)
        content.minimumHeight = 0
        content.imageTitleSpacing = 8
        bar.defaultContentLayout = content
        bar.frame.size.height = bar.sizeThatFits(bar.bounds.size).height
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.bounds.height, 30, accuracy: 0.01)
        XCTAssertEqual(frame(0, list).width, 36, accuracy: 0.01)
        let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 0, section: 0)))
        func button(in view: UIView) -> UIButton? {
            (view as? UIButton) ?? view.subviews.lazy.compactMap { button(in: $0) }.first
        }
        let control = try XCTUnwrap(button(in: cell))
        XCTAssertEqual(control.configuration?.contentInsets, content.contentInsets)
        XCTAssertEqual(control.configuration?.image?.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(control.configuration?.imagePadding, 8)
        control.layoutIfNeeded()
        let icon = try XCTUnwrap(control.imageView)
        XCTAssertGreaterThanOrEqual(icon.frame.minY, 3 - 0.5)
        XCTAssertLessThanOrEqual(icon.frame.maxY, bar.bounds.height - 7 + 0.5)
        bar.defaultContentLayout = SPTabBarDefaultContentLayout()
        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, originalHeight)
    }

    func testLargeIconKeepsLogicalSizeWithBoundedRasterAllocation() throws {
        let (bar, list) = mount()
        bar.layoutConfiguration.itemSizing = .fixed(80)
        let original = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        bar.items = [SPTabBarItem(title: nil, image: original)]
        bar.defaultContentLayout.iconSize = CGSize(width: 1_000_000, height: 1_000_000)
        bar.layoutIfNeeded()
        let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 0, section: 0)))
        func button(in view: UIView) -> UIButton? {
            (view as? UIButton) ?? view.subviews.lazy.compactMap { button(in: $0) }.first
        }
        let image = try XCTUnwrap(button(in: cell)?.configuration?.image)
        XCTAssertEqual(image.size.width, 1_000_000, accuracy: 1)
        XCTAssertEqual(image.size.height, 1_000_000, accuracy: 1)
        let raster = try XCTUnwrap(image.cgImage)
        XCTAssertLessThanOrEqual(raster.width, 1024)
        XCTAssertLessThanOrEqual(raster.height, 1024)
        XCTAssertEqual(frame(0, list).width, 80, accuracy: 0.01)
    }

    func testDefaultDimensionsDoNotResizeCustomContentAndFallbackUsesNewDimensions() {
        let (bar, list) = mount()
        let provider = LayoutContentSource()
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.defaultContentLayout.minimumHeight = 120
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, 28)
        XCTAssertEqual(frame(0, list).width, 60)
        provider.fallback = true
        bar.reloadContent()
        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, 120)
        provider.fallback = false
        bar.reloadContent()
        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, 28)
    }

    func testInvalidDimensionsNormalizeAndZeroIconRemainsValid() {
        let (bar, _) = mount()
        var layout = bar.layoutConfiguration
        layout.minimumItemWidth = .nan
        layout.maximumItemWidth = .infinity
        layout.itemSizing = .fixed(-1)
        layout.itemSpacing = .infinity
        bar.layoutConfiguration = layout
        XCTAssertEqual(bar.layoutConfiguration.minimumItemWidth, 44)
        XCTAssertNil(bar.layoutConfiguration.maximumItemWidth)
        XCTAssertEqual(bar.layoutConfiguration.itemSizing, .fixed(0))
        XCTAssertEqual(bar.layoutConfiguration.itemSpacing, 0)
        var content = bar.defaultContentLayout
        content.iconSize = CGSize(width: -1, height: CGFloat.nan)
        content.minimumHeight = .nan
        content.imageTitleSpacing = .infinity
        content.contentInsets.leading = 2_000_000
        bar.defaultContentLayout = content
        XCTAssertEqual(bar.defaultContentLayout.iconSize, CGSize(width: 0, height: 24))
        XCTAssertEqual(bar.defaultContentLayout.minimumHeight, 44)
        XCTAssertEqual(bar.defaultContentLayout.imageTitleSpacing, 4)
        XCTAssertEqual(bar.defaultContentLayout.contentInsets.leading, 1_000_000)
        XCTAssertTrue(bar.sizeThatFits(bar.bounds.size).height.isFinite)
    }
}

@MainActor
private final class LayoutContentSource: SPTabBarContentDelegate {
    var fallback = false
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        guard !fallback || index != 0 else {
            return nil
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(configuration: configuration, size: CGSize(width: 60, height: 28))
    }
}
