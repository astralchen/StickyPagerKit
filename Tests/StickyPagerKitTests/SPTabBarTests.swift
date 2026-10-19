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

    private func mount(count: Int = 12, width: CGFloat = 320, rtl: Bool = false, titles: [String]? = nil) -> (SPTabBar, UICollectionView) {
        let controller = UIViewController()
        // 宽度算法用例会放大标签栏；安全区域由容器集成测试单独验证。
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: max(2048, width), height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: width, height: 44))
        bar.standardAppearance.selectionStyle = .underline
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        controller.view.addSubview(bar)
        bar.setItems((titles ?? (0..<count).map { "标签 \($0)" }).map { SPTabBarItem(title: $0) })
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

    private let variedTitles = ["热", "推荐内容", "关注", "本周热门精选", "收藏", "更多专题与活动",
                                "新", "附近的人", "视频", "开发者讨论专区", "图", "全部"]

    func testScrollingEdgeFadePreservesEndpointsAndTracksViewport() throws {
        for rtl in [false, true] {
            let (bar, collection) = mount(rtl: rtl, titles: variedTitles)
            let maximum = collection.contentSize.width - collection.bounds.width
            // 选中项对齐和手动滚动共用物理边界；包括临近端点与回弹。
            for (offset, leftAlpha, rightAlpha): (CGFloat, CGFloat, CGFloat) in [
                (-20, 1, 0), (0, 1, 0), (8, 0.5, 0), (maximum / 2, 0, 0),
                (maximum - 8, 0, 0.5), (maximum, 0, 1), (maximum + 20, 0, 1)
            ] {
                collection.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
                let mask = try XCTUnwrap(collection.layer.mask as? CAGradientLayer)
                let colors = try XCTUnwrap(mask.colors as? [CGColor])
                XCTAssertEqual(mask.frame, collection.bounds, "遮罩必须跟随视口，不随内容滚走")
                XCTAssertEqual(colors.first!.alpha, leftAlpha, accuracy: 0.01)
                XCTAssertEqual(colors.last!.alpha, rightAlpha, accuracy: 0.01)
            }
            for index in [0, variedTitles.count - 1] {
                bar.setSelectedIndex(index, animated: false)
                let tab = try XCTUnwrap(button(index, in: collection))
                tab.layoutIfNeeded()
                let label = try XCTUnwrap(tab.titleLabel)
                let titleFrame = label.convert(label.bounds, to: collection)
                XCTAssertGreaterThanOrEqual(titleFrame.minX, collection.bounds.minX + 15)
                XCTAssertLessThanOrEqual(titleFrame.maxX, collection.bounds.maxX - 15)
            }
            bar.frame.size.width = collection.contentSize.width + 100
            bar.layoutIfNeeded()
            XCTAssertNil(collection.layer.mask, "内容无需滚动时不应遮挡首尾")
            bar.frame.size.width = 320
            bar.layoutIfNeeded()
            XCTAssertNotNil(collection.layer.mask)
        }
    }

    func testTabButtonTrackingCanYieldToScrolling() throws {
        let (bar, collection) = mount()
        let tab = try XCTUnwrap(button(1, in: collection))
        XCTAssertTrue(collection.canCancelContentTouches)
        XCTAssertTrue(collection.touchesShouldCancel(in: tab), "按住标签后移动，滚动视图必须能取消按钮跟踪")
        XCTAssertFalse(collection.touchesShouldCancel(in: UISlider()), "其他控件保持 UIKit 默认行为")
        var selected: [Int] = []
        let observer = TabSelectionObserver { selected.append($0) }; bar.delegate = observer
        tab.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, [1])
    }

    func testUnspecifiedDirectionFollowsContainerAndExplicitOverrideWins() {
        let (bar, collection) = mount(titles: variedTitles)
        let host = window!.rootViewController!.view!
        bar.semanticContentAttribute = .unspecified
        for direction in [UISemanticContentAttribute.forceRightToLeft, .forceLeftToRight] {
            host.semanticContentAttribute = direction
            bar.setNeedsLayout(); bar.layoutIfNeeded()
            XCTAssertEqual(frame(0, in: collection).minX > frame(11, in: collection).minX,
                           direction == .forceRightToLeft)
            let expected = direction == .forceRightToLeft ? collection.contentSize.width - collection.bounds.width : 0
            XCTAssertEqual(collection.contentOffset.x, expected, accuracy: 0.5)
        }
        host.semanticContentAttribute = .forceRightToLeft
        bar.semanticContentAttribute = .forceLeftToRight
        bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertLessThan(frame(0, in: collection).minX, frame(11, in: collection).minX)
    }

    func testVariableWidthsAndVisibleQueriesUseActualGeometryInBothDirections() {
        for rtl in [false, true] {
            let (bar, collection) = mount(rtl: rtl, titles: variedTitles)
            let font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: bar.traitCollection)
            let widths = variedTitles.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) + 32 }
            let total = widths.reduce(0, +)
            XCTAssertEqual(collection.contentSize.width, total, accuracy: 0.01)
            var x: CGFloat = 0
            for index in variedTitles.indices {
                let item = frame(index, in: collection)
                XCTAssertEqual(item.width, widths[index], accuracy: 0.01)
                XCTAssertEqual(item.minX, rtl ? total - x - widths[index] : x, accuracy: 0.01)
                x += widths[index]
                bar.setSelectedIndex(index, animated: false)
                let expected = min(total - collection.bounds.width, max(0, item.midX - collection.bounds.width / 2))
                XCTAssertEqual(collection.contentOffset.x, expected, accuracy: 0.5)
            }
            let allFrames = variedTitles.indices.map { frame($0, in: collection) }
            // 包括恰好位于项边缘的查询，验证可见项检索既不遗漏也不返回不相交的项。
            for item in allFrames {
                for rect in [item, CGRect(x: item.maxX, y: 0, width: 1, height: 44)] {
                    let expected = Set(allFrames.indices.filter { allFrames[$0].intersects(rect) })
                    let actual = Set(collection.collectionViewLayout.layoutAttributesForElements(in: rect)!.map { $0.indexPath.item })
                    XCTAssertEqual(actual, expected)
                }
            }
        }
    }

    func testResizeSwitchesBetweenIntrinsicWidthsAndEqualDistribution() {
        for rtl in [false, true] {
            let (bar, collection) = mount(width: 200, rtl: rtl, titles: ["热", "本周热门精选", "关注"])
            let widths = (0..<3).map { frame($0, in: collection).width }
            let total = widths.reduce(0, +)
            XCTAssertGreaterThan(total, 200)
            bar.setSelectedIndex(1, animated: false)
            for width in [total, total + 30, widths.max()! * 3, 200] {
                bar.frame.size.width = width
                bar.layoutIfNeeded()
                for index in 0..<3 {
                    let item = frame(index, in: collection)
                    XCTAssertGreaterThanOrEqual(item.width, widths[index], "可用总宽度足够时不能挤压长标题")
                    if width >= widths.max()! * 3 {
                        XCTAssertEqual(item.width, width / 3, accuracy: 0.01)
                    }
                    if width < total { XCTAssertEqual(item.width, widths[index], accuracy: 0.01) }
                }
                let target = frame(1, in: collection)
                let offset = min(max(0, total - width), max(0, target.midX - width / 2))
                XCTAssertEqual(collection.contentOffset.x, offset, accuracy: 0.5)
            }
        }
    }

    func testVariableWidthIndicatorAndOffsetStaySynchronizedDuringAnimationAndGestureTakeover() {
        for rtl in [false, true] {
            let (bar, collection) = mount(rtl: rtl, titles: variedTitles)
            let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
            let start = indicator.frame
            let startOffset = collection.contentOffset.x
            bar.setSelectedIndex(5, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            let target = frame(5, in: collection)
            XCTAssertEqual(indicator.frame.minX, (start.minX + target.minX + 12) / 2, accuracy: 0.01)
            XCTAssertEqual(indicator.frame.width, (start.width + target.width - 24) / 2, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset.x, (startOffset + target.midX - 160) / 2, accuracy: 0.5)

            let halfway = indicator.frame
            let halfwayOffset = collection.contentOffset.x
            bar.setTransitionProgress(from: 5, to: 6, progress: 0)
            XCTAssertEqual(indicator.frame, halfway)
            XCTAssertEqual(collection.contentOffset.x, halfwayOffset, accuracy: 0.5)
            bar.setTransitionProgress(from: 5, to: 6, progress: 0.5)
            let neighbor = frame(6, in: collection)
            XCTAssertEqual(indicator.frame.minX, (halfway.minX + neighbor.minX + 12) / 2, accuracy: 0.01)
            XCTAssertEqual(indicator.frame.width, (halfway.width + neighbor.width - 24) / 2, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset.x, (halfwayOffset + neighbor.midX - 160) / 2, accuracy: 0.5)
            bar.setSelectedIndex(5, animated: false)
            XCTAssertEqual(indicator.frame.width, target.width - 24, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset.x, target.midX - 160, accuracy: 0.5)

            bar.setSelectedIndex(9, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            collection.delegate?.scrollViewWillBeginDragging?(collection)
            collection.contentOffset.x = 30
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(collection.contentOffset.x, 30, accuracy: 0.01)
            XCTAssertEqual(bar.selectedIndex, 9)
        }
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
                // 标题宽度不同可能产生半点中心，UIScrollView 会将偏移对齐到屏幕像素。
                XCTAssertEqual(collection.contentOffset.x, expected, accuracy: 1 / bar.traitCollection.displayScale)
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
        let observer = TabSelectionObserver { callbacks.append($0) }; bar.delegate = observer
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
        let observer = TabSelectionObserver { tapped = $0 }; bar.delegate = observer
        for index in [0, 1] {
            bar.setSelectedIndex(1, animated: false)
            let path = IndexPath(item: index, section: 0)
            let cell = collection.cellForItem(at: path)!
            let button = button(index, in: collection)!
            // 确定性模拟提前准备的 Cell：进入屏幕前仍保留旧选中态、字体和标题。
            button.accessibilityTraits = index == 0 ? [.button, .selected] : .button
            button.tintColor = index == 0 ? .label : .secondaryLabel
            button.titleLabel?.font = .systemFont(ofSize: 8)
            button.configuration?.title = "旧标题"
            button.accessibilityIdentifier = "旧标识"
            collection.delegate?.collectionView?(collection, willDisplay: cell, forItemAt: path)
            XCTAssertEqual(button.accessibilityTraits.contains(.selected), index == 1)
            XCTAssertEqual(button.tintColor, index == 1 ? bar.tintColor : .secondaryLabel)
            XCTAssertEqual(button.titleLabel?.font, UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: bar.traitCollection))
            XCTAssertEqual(button.configuration?.title, bar.items[index].title)
            XCTAssertEqual(button.accessibilityIdentifier, "sp.tab.\(index)")
            button.sendActions(for: .touchUpInside)
            XCTAssertEqual(tapped, index)
        }
    }

    func testTransitionUsesOffscreenGeometryAndSurvivesRelayout() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
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
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
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

    func testIndicatorAndCenteringShareAnimationProgressAndRetargetFromCurrentPosition() {
        for rtl in [false, true] {
            let (bar, collection) = mount(rtl: rtl)
            let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
            let startFrame = indicator.frame
            let startOffset = collection.contentOffset.x
            bar.setSelectedIndex(6, animated: true)
            XCTAssertEqual(indicator.frame, startFrame)
            XCTAssertEqual(collection.contentOffset.x, startOffset)
            bar.advanceSelectionAnimation(to: 0.5)
            let targetX = frame(6, in: collection).minX + 12
            let targetOffset = frame(6, in: collection).midX - 160
            XCTAssertEqual(indicator.frame.minX, (startFrame.minX + targetX) / 2, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset.x, (startOffset + targetOffset) / 2, accuracy: 0.5)
            let halfway = indicator.frame
            let offset = collection.contentOffset.x
            bar.setNeedsLayout(); bar.layoutIfNeeded()
            XCTAssertEqual(indicator.frame, halfway)
            bar.setSelectedIndex(3, animated: true)
            XCTAssertEqual(indicator.frame, halfway)
            XCTAssertEqual(collection.contentOffset.x, offset)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(indicator.frame.minX, frame(3, in: collection).minX + 12, accuracy: 0.01)
            XCTAssertEqual(collection.contentOffset.x, frame(3, in: collection).midX - 160, accuracy: 0.5)
        }
    }

    func testPagingProgressSynchronizesTabOffsetAndCancellation() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
        bar.setSelectedIndex(4, animated: false)
        let startOffset = collection.contentOffset.x
        let startX = indicator.frame.minX
        bar.setTransitionProgress(from: 4, to: 5, progress: 0.5)
        XCTAssertEqual(indicator.frame.minX, (startX + frame(5, in: collection).minX + 12) / 2, accuracy: 0.01)
        XCTAssertEqual(collection.contentOffset.x, (startOffset + frame(5, in: collection).midX - 160) / 2, accuracy: 0.5)
        bar.setSelectedIndex(4, animated: false)
        XCTAssertEqual(indicator.frame.minX, startX, accuracy: 0.01)
        XCTAssertEqual(collection.contentOffset.x, startOffset, accuracy: 0.5)
    }

    func testPagingTakesOverAnUnfinishedTabAnimationWithoutJumping() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
        bar.setSelectedIndex(6, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let startFrame = indicator.frame
        let startOffset = collection.contentOffset.x
        bar.setTransitionProgress(from: 6, to: 7, progress: 0)
        XCTAssertEqual(indicator.frame, startFrame)
        XCTAssertEqual(collection.contentOffset.x, startOffset, accuracy: 0.5)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, startFrame)
        bar.setTransitionProgress(from: 6, to: 7, progress: 0.5)
        XCTAssertEqual(indicator.frame.minX, (startFrame.minX + frame(7, in: collection).minX + 12) / 2, accuracy: 0.01)
        XCTAssertEqual(collection.contentOffset.x, (startOffset + frame(7, in: collection).midX - 160) / 2, accuracy: 0.5)
        bar.setTransitionProgress(from: 6, to: 7, progress: 1)
        let endFrame = indicator.frame
        let endOffset = collection.contentOffset.x
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertEqual(indicator.frame, endFrame)
        XCTAssertEqual(collection.contentOffset.x, endOffset, accuracy: 0.5)
    }

    func testManualDragResizeAndReloadStopSelectionAnimation() {
        let (bar, collection) = mount()
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
        bar.setSelectedIndex(6, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        collection.delegate?.scrollViewWillBeginDragging?(collection)
        collection.contentOffset.x = 30
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(collection.contentOffset.x, 30, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.minX, frame(6, in: collection).minX + 12, accuracy: 0.01)
        bar.setSelectedIndex(3, animated: true)
        bar.frame.size.width = 400
        bar.layoutIfNeeded()
        let resized = indicator.frame
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, resized)
        XCTAssertEqual(collection.contentOffset.x, frame(3, in: collection).midX - 200, accuracy: 0.5)
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        bar.removeFromSuperview()
        window!.rootViewController!.view.addSubview(bar)
        bar.layoutIfNeeded()
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(collection.contentOffset.x, frame(7, in: collection).midX - 200, accuracy: 0.5)
        XCTAssertEqual(indicator.frame.minX, frame(7, in: collection).minX + 12, accuracy: 0.01)
        bar.setSelectedIndex(9, animated: true)
        bar.setItems([]); bar.layoutIfNeeded()
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, .zero)
        XCTAssertEqual(collection.contentOffset, .zero)
    }

    func testAnimatedTabBarCanBeReleased() {
        weak var reference: SPTabBar?
        autoreleasepool {
            let (bar, _) = mount()
            reference = bar
            bar.setSelectedIndex(7, animated: true)
            bar.removeFromSuperview()
        }
        XCTAssertNil(reference)
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

@MainActor
private final class TabSelectionObserver: SPTabBarDelegate {
    let action: (Int) -> Void
    init(_ action: @escaping (Int) -> Void) { self.action = action }
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        if let index = tabBar.items.firstIndex(where: { $0 === item }) { action(index) }
    }
}
