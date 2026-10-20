import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarSpacingTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private func mount(count: Int = 3, width: CGFloat = 400, rtl: Bool = false) -> (SPTabBar, UICollectionView) {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: width, height: 60))
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        window.rootViewController!.view.addSubview(bar)
        bar.items = (0 ..< count).map { SPTabBarItem(title: "标签 \($0)") }
        bar.setSelectedIndex(count > 0 ? 0 : nil, animated: false)
        bar.layoutIfNeeded()
        return (bar, bar.subviews.compactMap { $0 as? UICollectionView }.first!)
    }

    private func frame(_ index: Int, in collection: UICollectionView) -> CGRect {
        collection.layoutIfNeeded()
        return collection.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    private func assertGaps(_ bar: SPTabBar, _ collection: UICollectionView, spacing: CGFloat) {
        let frames = bar.items.indices.map { frame($0, in: collection) }.sorted { $0.minX < $1.minX }
        XCTAssertEqual(frames.first?.minX ?? 0, 0, accuracy: 0.01)
        for pair in zip(frames, frames.dropFirst()) {
            XCTAssertEqual(pair.1.minX - pair.0.maxX, spacing, accuracy: 0.01)
        }
        if let last = frames.last {
            XCTAssertEqual(last.maxX, collection.contentSize.width, accuracy: 0.01)
        }
    }

    func testSpacingDefaultsNormalizationAndEmptyOrSingleItem() {
        for count in [0, 1] {
            let (bar, collection) = mount(count: count)
            XCTAssertEqual(bar.itemSpacing, 0)
            for (input, expected): (CGFloat, CGFloat) in [
                (20, 20),
                (-2, 0),
                (.nan, 0),
                (.infinity, 0),
                (-.infinity, 0),
                (2_000_000, 1_000_000)
            ] {
                bar.itemSpacing = input
                bar.layoutIfNeeded()
                XCTAssertEqual(bar.itemSpacing, expected)
                XCTAssertEqual(collection.contentSize.width, collection.bounds.width)
                XCTAssertEqual(collection.contentOffset.x, 0)
                if count == 1 {
                    XCTAssertEqual(frame(0, in: collection).width, collection.bounds.width)
                }
            }
        }
    }

    func testBalancedWidthsOverflowAndGapsDoNotBecomeItemHitAreas() {
        let (bar, collection) = mount()
        let source = SpacingContentSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.itemSpacing = 20
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, in: collection).width, 200)
        XCTAssertEqual(frame(1, in: collection).width, 80)
        XCTAssertEqual(frame(2, in: collection).width, 80)
        assertGaps(bar, collection, spacing: 20)
        let gap = CGPoint(x: frame(0, in: collection).maxX + 10, y: 30)
        XCTAssertNil(collection.indexPathForItem(at: gap))
        var hit = collection.hitTest(gap, with: nil)
        while let view = hit, view !== collection {
            XCTAssertFalse(view is UIButton)
            hit = view.superview
        }
        bar.minimumItemWidth = 200
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentSize.width, 640)
        assertGaps(bar, collection, spacing: 20)
        XCTAssertEqual(source.widths, [200, 40, 40], "间距不能写入业务理想尺寸")
    }

    func testDefaultCustomAndFallbackShareSpacingIncludingRTLAndSafeArea() {
        for rtl in [false, true] {
            let (bar, collection) = mount(width: 320, rtl: rtl)
            let source = SpacingContentSource()
            bar.contentDelegate = source
            bar.minimumItemWidth = 180
            bar.itemSpacing = 24
            window.frame.size.width = bar.bounds.width
            window.rootViewController!.view.frame = window.bounds
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            window.rootViewController!.view.layoutIfNeeded()
            for style: SPTabBar.ContentStyle in [.default, .custom] {
                source.fallbackIndex = 1
                bar.contentStyle = style
                bar.setNeedsLayout()
                bar.layoutIfNeeded()
                XCTAssertEqual(bar.safeAreaInsets.left, 20, accuracy: 0.01)
                XCTAssertEqual(bar.safeAreaInsets.right, 30, accuracy: 0.01)
                assertGaps(bar, collection, spacing: 24)
                XCTAssertEqual(collection.frame.minX, bar.safeAreaInsets.left, accuracy: 0.01)
                XCTAssertEqual(collection.frame.maxX, bar.bounds.width - bar.safeAreaInsets.right, accuracy: 0.01)
                XCTAssertEqual(frame(0, in: collection).minX > frame(2, in: collection).minX, rtl)
                bar.setSelectedIndex(2, animated: false)
                let item = frame(2, in: collection)
                let expected = min(
                    collection.contentSize.width - collection.bounds.width,
                    max(0, item.midX - collection.bounds.width / 2)
                )
                XCTAssertEqual(collection.contentOffset.x, expected, accuracy: 1)
                XCTAssertNotNil(collection.layer.mask)
            }
        }
    }

    func testSpacingRefreshPreservesPagingProgressSelectionAndManualOffset() {
        for rtl in [false, true] {
            let (bar, collection) = mount(count: 8, width: 320, rtl: rtl)
            let spy = SpacingSelectionSpy()
            bar.delegate = spy
            bar.minimumItemWidth = 100
            bar.indicatorStyle = .underline
            bar.layoutIfNeeded()
            let items = bar.items
            collection.contentOffset.x = 120
            bar.itemSpacing = 16
            bar.layoutIfNeeded()
            XCTAssertEqual(collection.contentOffset.x, 120, accuracy: 1)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.4)
            bar.itemSpacing = 32
            bar.layoutIfNeeded()
            let a = frame(0, in: collection), b = frame(1, in: collection)
            let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
            XCTAssertEqual(indicator.frame.midX, a.midX + (b.midX - a.midX) * 0.4, accuracy: 0.01)
            XCTAssertEqual(indicator.frame.width, a.width - 24, accuracy: 0.01)
            let maximum = collection.contentSize.width - collection.bounds.width
            let from = min(maximum, max(0, a.midX - collection.bounds.width / 2))
            let to = min(maximum, max(0, b.midX - collection.bounds.width / 2))
            XCTAssertEqual(collection.contentOffset.x, from + (to - from) * 0.4, accuracy: 1)
            XCTAssertEqual(bar.selectedIndex, 0)
            XCTAssertTrue(zip(items, bar.items).allSatisfy { $0.0 === $0.1 })
            XCTAssertEqual(spy.selections, 0)
            bar.setSelectedIndex(0, animated: false)
            collection.contentOffset.x = maximum
            bar.itemSpacing = 0
            bar.layoutIfNeeded()
            XCTAssertEqual(
                collection.contentOffset.x,
                collection.contentSize.width - collection.bounds.width,
                accuracy: 1
            )
        }
    }

    func testUnchangedSpacingPreservesAnimationAndChangedSpacingSettlesItWithNone() {
        let (bar, collection) = mount(count: 8, width: 320)
        let source = SpacingContentSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.minimumItemWidth = 100
        bar.itemSpacing = 16
        bar.indicatorStyle = .none
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let midway = collection.contentOffset.x
        let calls = source.calls
        bar.itemSpacing = 16
        bar.layoutIfNeeded()
        XCTAssertEqual(source.calls, calls)
        XCTAssertEqual(collection.contentOffset.x, midway, accuracy: 1)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertGreaterThan(collection.contentOffset.x, midway)
        bar.setSelectedIndex(0, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        bar.itemSpacing = 32
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 1)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(collection.contentOffset.x, 0, accuracy: 1)
        XCTAssertEqual(bar.selectedIndex, 0)
        XCTAssertTrue(collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!.isHidden)
    }
}

@MainActor
private final class SpacingContentSource: SPTabBarContentDelegate {
    let widths: [CGFloat] = [200, 40, 40]
    var fallbackIndex: Int?
    var calls = 0
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        calls += 1
        guard index != fallbackIndex else {
            return nil
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(
            configuration: configuration,
            size: CGSize(width: widths[index % widths.count], height: 40)
        )
    }
}

@MainActor
private final class SpacingSelectionSpy: SPTabBarDelegate {
    var selections = 0
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        selections += 1
    }
}
