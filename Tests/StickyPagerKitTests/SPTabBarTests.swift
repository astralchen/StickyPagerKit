import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() async throws {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private func mount(count: Int = 12, width: CGFloat = 320, rtl: Bool = false) -> (SPTabBar, UICollectionView) {
        let controller = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: width, height: 44))
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        controller.view.addSubview(bar)
        bar.setItems((0..<count).map { SPTabBarItem(title: "标签 \($0)") })
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        self.window = window
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        return (bar, bar.subviews.compactMap { $0 as? UICollectionView }.first!)
    }

    private func frame(_ index: Int, in collection: UICollectionView) -> CGRect {
        collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    private func button(_ index: Int, in collection: UICollectionView) -> UIButton? {
        collection.layoutIfNeeded()
        return collection.cellForItem(at: IndexPath(item: index, section: 0))?.contentView.subviews.compactMap { $0 as? UIButton }.first
    }

    func testOverflowSelectionCentersAndClampsAtEdgesInBothDirections() {
        for rtl in [false, true] {
            let (bar, collection) = mount(rtl: rtl)
            XCTAssertTrue(collection.collectionViewLayout is SPTabBarLayout)
            XCTAssertTrue(bar.window === window)
            for index in [6, 0, 11, 3] {
                bar.setSelectedIndex(index, animated: false)
                let item = frame(index, in: collection)
                let expected = min(collection.contentSize.width - collection.bounds.width, max(0, item.midX - collection.bounds.width / 2))
                XCTAssertEqual(collection.contentOffset.x, expected, accuracy: 0.01)
                XCTAssertEqual(collection.contentOffset.y, 0)
            }
            XCTAssertEqual(frame(0, in: collection).minX > frame(11, in: collection).minX, rtl)
        }
    }

    func testShortContentFillsWidthWithoutScrolling() {
        let (bar, collection) = mount(count: 3, width: 600)
        for index in 0..<3 {
            bar.setSelectedIndex(index, animated: false)
            XCTAssertEqual(frame(index, in: collection).width, 200, accuracy: 0.01)
            XCTAssertEqual(collection.contentSize.width, 600, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset, .zero)
        }
    }

    func testResizeRecentersButOrdinaryLayoutPreservesManualScroll() {
        let (bar, collection) = mount()
        bar.setSelectedIndex(6, animated: false)
        collection.contentOffset.x = 50
        bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 50, accuracy: 0.01)
        bar.frame.size.width = 400
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, frame(6, in: collection).midX - 200, accuracy: 0.01)
        bar.semanticContentAttribute = .forceRightToLeft
        bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, frame(6, in: collection).midX - 200, accuracy: 0.01)
    }

    func testReusedButtonsKeepSelectionAccessibilityAndCurrentCallback() {
        let (bar, collection) = mount(count: 100)
        var callbacks: [Int] = []
        bar.onSelect = { callbacks.append($0) }
        for index in [50, 99, 0, 42] {
            bar.setSelectedIndex(index, animated: false)
            let selected = button(index, in: collection)
            XCTAssertNotNil(selected)
            XCTAssertEqual(selected?.accessibilityIdentifier, "sp.tab.\(index)")
            XCTAssertTrue(selected?.accessibilityTraits.contains(.selected) == true)
            selected?.sendActions(for: .touchUpInside)
            let neighbor = index == 99 ? 98 : index + 1
            XCTAssertFalse(button(neighbor, in: collection)?.accessibilityTraits.contains(.selected) ?? true)
            XCTAssertLessThan(collection.visibleCells.count, 10)
        }
        XCTAssertEqual(callbacks, [50, 99, 0, 42])
        XCTAssertEqual(bar.selectedIndex, 42)
    }

    func testWillDisplayRefreshesPreparedCellState() {
        let (bar, collection) = mount()
        bar.setSelectedIndex(1, animated: false)
        var tapped: Int?
        bar.onSelect = { tapped = $0 }
        for index in [0, 1] {
            let path = IndexPath(item: index, section: 0)
            let cell = collection.cellForItem(at: path)!
            let button = button(index, in: collection)!
            // 确定性模拟提前准备的 Cell：进入屏幕前仍保留旧选中态、字体和标题。
            button.accessibilityTraits = index == 0 ? [.button, .selected] : .button
            button.tintColor = index == 0 ? .label : .secondaryLabel
            button.titleLabel?.font = .systemFont(ofSize: 8)
            button.setTitle("旧标题", for: .normal)
            button.accessibilityIdentifier = "旧标识"
            collection.delegate?.collectionView?(collection, willDisplay: cell, forItemAt: path)
            XCTAssertEqual(button.accessibilityTraits.contains(.selected), index == 1)
            XCTAssertEqual(button.tintColor, index == 1 ? .label : .secondaryLabel)
            XCTAssertEqual(button.titleLabel?.font, UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: bar.traitCollection))
            XCTAssertEqual(button.title(for: .normal), bar.items[index].title)
            XCTAssertEqual(button.accessibilityIdentifier, "sp.tab.\(index)")
            button.sendActions(for: .touchUpInside)
            XCTAssertEqual(tapped, index)
        }
    }

    func testTransitionUsesOffscreenGeometryAndSurvivesRelayout() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.layer.zPosition == 1 }!
        XCTAssertNil(collection.cellForItem(at: IndexPath(item: 10, section: 0)))
        bar.setTransitionProgress(from: 0, to: 10, progress: 0.4)
        let expected = frame(0, in: collection).minX + (frame(10, in: collection).minX - frame(0, in: collection).minX) * 0.4 + 12
        XCTAssertEqual(indicator.frame.minX, expected, accuracy: 0.01)
        bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.minX, expected, accuracy: 0.01)
        bar.setTransitionProgress(from: 0, to: 10, progress: .nan)
        XCTAssertEqual(indicator.frame.minX, expected, accuracy: 0.01)
        bar.setSelectedIndex(0, animated: false)
        XCTAssertEqual(indicator.frame.minX, frame(0, in: collection).minX + 12, accuracy: 0.01)
    }

    func testReloadShrinkEmptyAndInvalidSelectionClearStaleState() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.layer.zPosition == 1 }!
        bar.setSelectedIndex(11, animated: true)
        bar.setItems([SPTabBarItem(title: "新标签")])
        bar.layoutIfNeeded()
        XCTAssertNil(bar.selectedIndex)
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 1)
        XCTAssertEqual(collection.contentOffset, .zero)
        XCTAssertEqual(indicator.frame, .zero)
        bar.setSelectedIndex(0, animated: false)
        XCTAssertTrue(button(0, in: collection)?.accessibilityTraits.contains(.selected) == true)
        bar.setSelectedIndex(99, animated: false)
        XCTAssertNil(bar.selectedIndex)
        XCTAssertEqual(indicator.frame, .zero)
        bar.setItems([]); bar.layoutIfNeeded()
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 0)
        XCTAssertEqual(collection.contentOffset, .zero)
        XCTAssertEqual(indicator.frame, .zero)
    }

    func testSelectionBeforeFirstLayoutAndInterruptingAnimatedRequests() {
        let (bar, collection) = mount()
        bar.frame.size = .zero
        bar.layoutIfNeeded()
        bar.setSelectedIndex(8, animated: true)
        bar.frame.size = CGSize(width: 320, height: 44)
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, frame(8, in: collection).midX - 160, accuracy: 0.01)
        bar.setSelectedIndex(2, animated: true)
        bar.setSelectedIndex(9, animated: true)
        // 无应用宿主的 Package 测试不推进系统滚动动画；动画落点另由 Demo UI 测试验证。
        bar.setSelectedIndex(5, animated: false)
        XCTAssertEqual(collection.contentOffset.x, frame(5, in: collection).midX - 160, accuracy: 0.5)
        XCTAssertTrue(button(5, in: collection)?.accessibilityTraits.contains(.selected) == true)
    }

    func testDynamicTypeUpdatesWidthsAndCentering() {
        let (bar, collection) = mount()
        bar.setItems((0..<12).map { SPTabBarItem(title: "较长的标签标题 \($0)") })
        bar.setSelectedIndex(6, animated: false)
        let originalWidth = frame(6, in: collection).width
        let host = window!.rootViewController!
        let child = UIViewController()
        host.addChild(child); host.view.addSubview(child.view); child.didMove(toParent: host)
        child.view.addSubview(bar)
        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge), forChild: child)
        child.view.layoutIfNeeded(); bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertGreaterThan(frame(6, in: collection).width, originalWidth)
        // UIScrollView 会把偏移对齐到屏幕像素。
        XCTAssertEqual(collection.contentOffset.x, frame(6, in: collection).midX - 160, accuracy: 1 / bar.traitCollection.displayScale)
    }
}
