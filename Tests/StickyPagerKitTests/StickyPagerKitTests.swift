import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class StickyPagerKitTests: XCTestCase {
    private var window: UIWindow?
    private var source: FixtureSource?
    private var pager: SPPageViewController?

    override func tearDown() async throws {
        window?.closeForTesting()
        window?.rootViewController = nil
        window = nil; pager = nil; source = nil
    }

    private func mount(
        ids: [Int] = [0, 1, 2, 3],
        plain: Set<Int> = [],
        height: CGFloat = 1800,
        inNavigation: Bool = false,
        mixedLayout: Bool? = nil,
        rootScroll: Bool = false
    ) -> SPPageViewController {
        window?.closeForTesting()
        let source = FixtureSource(ids: ids, plain: plain, contentHeight: height)
        source.mixedLayout = mixedLayout
        source.rootScroll = rootScroll
        let pager = SPPageViewController()
        pager.dataSource = source
        pager.headerView = UIView()
        pager.layout = SPPageLayout(headerHeight: 240, minimumHeaderHeight: 40)
        pager.reloadData()
        let window: UIWindow
        if inNavigation {
            // 系统导航栏的安全区域依赖真实场景，不能用无场景窗口替代。
            let application: UIApplication? = UIApplication.shared
            let scene = application?.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            XCTAssertNotNil(scene, "请通过 Scripts/validate.sh 的 UIKit application host 运行库测试")
            window = scene.map(UIWindow.init(windowScene:)) ?? SPTestWindow(frame: .zero)
        } else {
            window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.rootViewController = inNavigation ? UINavigationController(rootViewController: pager) : pager
        window.showForTesting()
        pager.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        // 通用交互夹具保留 200 pt 折叠距离；总高度现在包含顶部安全区域。
        pager.layout.headerHeight = 240 + pager.view.safeAreaInsets.top
        self.window = window; self.source = source; self.pager = pager
        return pager
    }

    func testPageRootTopAlignsWithTabBarAndSafeContentStaysBelowIt() throws {
        let pager = mount(plain: [1])
        for position: CGFloat in [0, 80, 200, 350, 0] {
            pager.setSelectedIndex(0, animated: false)
            let scroll = try XCTUnwrap(pager.currentScrollView)
            scroll.contentOffset.y = position - scroll.adjustedContentInset.top
            for index in [0, 1] {
                pager.setSelectedIndex(index, animated: false)
                pager.view.layoutIfNeeded()
                let root = try XCTUnwrap(pager.records[index]?.controller.view)
                XCTAssertEqual(root.convert(root.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
                XCTAssertEqual(root.convert(root.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
                XCTAssertEqual(
                    root.convert(root.safeAreaLayoutGuide.layoutFrame, to: pager.view).minY,
                    pager.tabBar.frame.maxY,
                    accuracy: 0.01
                )
            }
        }
    }

    func testTabOcclusionIsCompensatedOnceForEveryInsetStrategyAndRootKind() throws {
        for rootScroll in [false, true] {
            for height: CGFloat in [0, 100, 1800] {
                let pager = mount(height: height, rootScroll: rootScroll)
                let scroll = try XCTUnwrap(pager.currentScrollView)
                let binding = try XCTUnwrap(pager.records[0]?.binding)
                let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
                for behavior: UIScrollView.ContentInsetAdjustmentBehavior in [
                    .automatic,
                    .always,
                    .scrollableAxes,
                    .never
                ] {
                    scroll.contentInsetAdjustmentBehavior = behavior
                    scroll.contentInset = base
                    for position: CGFloat in [0, 40, 200, 350, 200, 50, 0, -25, 0] {
                        if height < 200, position > 200 {
                            continue
                        }
                        scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                        pager.view.layoutIfNeeded()
                        let root = pager.records[0]!.controller.view!
                        XCTAssertEqual(
                            root.convert(root.bounds, to: pager.view).minY,
                            pager.tabBar.frame.minY,
                            accuracy: 0.01
                        )
                        XCTAssertEqual(binding.position, position, accuracy: 0.01)
                        XCTAssertEqual(pager.collapseOffset, min(200, max(0, position)), accuracy: 0.01)
                        XCTAssertEqual(
                            scroll.convert(.zero, to: pager.view).y,
                            pager.tabBar.frame.maxY + base.top - max(0, position - 200) - min(0, position),
                            accuracy: 0.01
                        )
                        if height < 200 {
                            let physicalRange = scroll.contentSize.height + scroll.adjustedContentInset.top + scroll
                                .adjustedContentInset.bottom - scroll.bounds.height
                            XCTAssertEqual(physicalRange, 200, accuracy: 0.01)
                            XCTAssertTrue(scroll.showsVerticalScrollIndicator)
                        }
                    }
                }
                scroll.contentOffset.y = (height > 200 ? 350 : 200) - scroll.adjustedContentInset.top
                source!.ids.removeFirst()
                pager.reloadData()
                XCTAssertEqual(scroll.contentInset, base)
                XCTAssertEqual(
                    scroll.contentOffset.y + scroll.adjustedContentInset.top,
                    height > 200 ? 150 : 0,
                    accuracy: 0.01
                )
            }
        }
    }

    func testPageSafeAreaPreservesBusinessInsetsAndRestoresOnRemoval() throws {
        let pager = mount(plain: [1])
        for index in [0, 1] {
            pager.setSelectedIndex(try XCTUnwrap(source!.ids.firstIndex(of: index)), animated: false)
            let controller = try XCTUnwrap(pager.records[index]?.controller)
            let business = UIEdgeInsets(top: 11, left: 7, bottom: 17, right: 9)
            controller.additionalSafeAreaInsets = business
            controller.additionalSafeAreaInsets.bottom = business.bottom + 4
            XCTAssertEqual(controller.additionalSafeAreaInsets.top, business.top + pager.tabBar.frame.height)
            controller.additionalSafeAreaInsets.bottom = business.bottom
            for height: CGFloat in [80, 0, 48, 100, 48] {
                pager.layout.tabBarHeight = height
                pager.view.layoutIfNeeded()
                XCTAssertEqual(
                    controller.additionalSafeAreaInsets.top,
                    business.top + pager.tabBar.frame.height,
                    accuracy: 0.01
                )
                XCTAssertEqual(controller.additionalSafeAreaInsets.left, business.left)
                XCTAssertEqual(controller.additionalSafeAreaInsets.bottom, business.bottom)
                XCTAssertEqual(controller.additionalSafeAreaInsets.right, business.right)
                let safeFrame = controller.view.convert(controller.view.safeAreaLayoutGuide.layoutFrame, to: pager.view)
                XCTAssertEqual(safeFrame.minY, pager.tabBar.frame.maxY + business.top, accuracy: 0.01)
            }
            let latest = UIEdgeInsets(top: 5, left: 3, bottom: 21, right: 13)
            controller.additionalSafeAreaInsets = latest
            source!.ids.removeAll { $0 == index }
            pager.reloadData()
            XCTAssertNil(controller.parent)
            XCTAssertEqual(controller.additionalSafeAreaInsets, latest)
        }
    }

    func testSafeAreaContributionRestoresOnCacheEviction() throws {
        let pager = mount()
        let first = try XCTUnwrap(pager.records[0]?.controller)
        first.additionalSafeAreaInsets = UIEdgeInsets(top: 9, left: 0, bottom: 4, right: 0)
        pager.maximumCachedPageCount = 1
        pager.setSelectedIndex(1, animated: false)
        XCTAssertNil(first.parent)
        XCTAssertEqual(first.additionalSafeAreaInsets.top, 9)
    }

    func testTabBarOwnsTouchesAboveOverlappingPage() throws {
        let pager = mount()
        for position: CGFloat in [0, 100, 200, 350] {
            let scroll = try XCTUnwrap(pager.currentScrollView)
            scroll.contentOffset.y = position - scroll.adjustedContentInset.top
            pager.view.layoutIfNeeded()
            let bar = pager.tabBar
            let point = CGPoint(x: bar.frame.midX, y: bar.frame.midY)
            let hit = try XCTUnwrap(pager.view.hitTest(point, with: nil))
            XCTAssertTrue(hit === bar || hit.isDescendant(of: bar))
            let below = try XCTUnwrap(pager.view.hitTest(CGPoint(x: point.x, y: bar.frame.maxY + 10), with: nil))
            XCTAssertTrue(below === scroll || below.isDescendant(of: scroll))
        }
    }

    func testManualIndicatorInsetsAvoidTabBarAndRestoreLatestBusinessValues() throws {
        let pager = mount()
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
        scroll.verticalScrollIndicatorInsets = base
        for automatic in [false, true, false] {
            scroll.automaticallyAdjustsScrollIndicatorInsets = automatic
            for position: CGFloat in [0, 70, 200, 350] {
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                pager.view.layoutIfNeeded()
                let automaticTop = automatic ? scroll.safeAreaInsets.top : 0
                let trackTop = scroll.convert(scroll.bounds, to: pager.view).minY + scroll.verticalScrollIndicatorInsets
                    .top + automaticTop
                XCTAssertEqual(trackTop, pager.tabBar.frame.maxY + base.top, accuracy: 0.01)
            }
        }
        let latest = UIEdgeInsets(top: 9, left: 2, bottom: 13, right: 4)
        scroll.verticalScrollIndicatorInsets = latest
        source!.ids.removeFirst()
        pager.reloadData()
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, latest)
        XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets)
    }

    func testTabHeightChangePreservesContentOriginAndClampsNewBottom() throws {
        let pager = mount()
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let binding = try XCTUnwrap(pager.records[0]?.binding)
        for behavior: UIScrollView.ContentInsetAdjustmentBehavior in [.automatic, .never] {
            scroll.contentInsetAdjustmentBehavior = behavior
            for position: CGFloat in [0, 80, 200, 350] {
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                for height: CGFloat in [100, 0, 44] {
                    pager.layout.tabBarHeight = height
                    pager.view.layoutIfNeeded()
                    XCTAssertEqual(binding.position, position, accuracy: 0.01)
                    XCTAssertEqual(
                        scroll.convert(.zero, to: pager.view).y,
                        pager.tabBar.frame.maxY - max(0, position - 200),
                        accuracy: 0.01
                    )
                }
            }
        }
        pager.layout.tabBarHeight = 150
        scroll.contentOffset.y = binding.maximumPosition - scroll.adjustedContentInset.top
        pager.layout.tabBarHeight = 44
        XCTAssertEqual(binding.position, binding.maximumPosition, accuracy: 0.01)
        pager.setSelectedIndex(1, animated: false)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(binding.position, binding.maximumPosition, accuracy: 0.01)
    }

    func testTabUserSelectionCommitsOnceAndCancelsOnReplacementOrReload() {
        let pager = mount()
        let spy = SelectionSpy()
        pager.tabBar.delegate = spy
        let tabs = pager.tabBar
        tabs.requestSelection(of: tabs.items[1])
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertTrue(spy.selected.isEmpty)
        pager.setSelectedIndex(2, animated: false)
        XCTAssertTrue(spy.selected.isEmpty)
        tabs.requestSelection(of: tabs.items[0])
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertEqual(spy.selected.count, 1)
        tabs.requestSelection(of: tabs.items[1])
        pager.reloadData()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        XCTAssertEqual(spy.selected.count, 1)
        tabs.requestSelection(of: tabs.items[1])
        pager.tabBar = SPTabBar()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
        XCTAssertEqual(spy.selected.count, 1)
        tabs.requestSelection(of: tabs.items[0])
        XCTAssertEqual(spy.selected.count, 2, "旧标签栏恢复独立选择")
    }

    func testDisabledTabAllowsProgrammaticAndGesturePaging() {
        let pager = mount()
        let spy = SelectionSpy()
        pager.tabBar.delegate = spy
        let item = pager.tabBar.items[1]
        item.isEnabled = false
        pager.tabBar.requestSelection(of: item)
        XCTAssertEqual(pager.selectedIndex, 0)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertTrue(pager.tabBar.selectedItem === item)
        pager.setSelectedIndex(0, animated: false)
        pager.scrollViewWillBeginDragging(pager.pagingView)
        pager.pagingView.contentOffset.x = pager.pagingView.bounds.width
        pager.scrollViewDidEndDecelerating(pager.pagingView)
        XCTAssertEqual(pager.selectedIndex, 1)
        XCTAssertTrue(spy.selected.isEmpty)
    }

    func testCompactTabHeightUsesContainerMinimumAndRestoresCachedPages() {
        let pager = mount()
        let provider = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: CGSize(
            width: 12,
            height: 28
        )))
        pager.tabBar.contentDelegate = provider
        pager.tabBar.contentStyle = .custom
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 310 - scroll.adjustedContentInset.top
        let position = pager.records[0]!.binding!.position
        XCTAssertEqual(SPPageLayout().tabBarHeight, 44)
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for explicit in [false, true] {
                for contentHeight: CGFloat in [28, 80] {
                    let size = CGSize(width: 12, height: contentHeight)
                    provider.configuration = IntrinsicTabConfiguration(size: size)
                    provider.explicitSize = explicit ? size : nil
                    pager.tabBar.reloadContent()
                    for minimum: CGFloat in [44, 32, 60, 0, 32, 44] {
                        pager.setSelectedIndex(1, animated: false)
                        pager.layout.tabBarHeight = minimum
                        pager.view.layoutIfNeeded()
                        let expected = minimum == 0 ? 0 : max(minimum, contentHeight)
                        XCTAssertEqual(pager.tabBar.bounds.height, expected, accuracy: 0.01)
                        pager.setSelectedIndex(0, animated: false)
                        pager.view.layoutIfNeeded()
                        XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
                        for index in [0, 1] {
                            let root = pager.records[index]!.controller.view!
                            let frame = root.convert(root.bounds, to: pager.view)
                            XCTAssertEqual(frame.minY, pager.tabBar.frame.minY, accuracy: 0.01)
                            XCTAssertEqual(frame.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                        }
                        if minimum > 0 {
                            let list = pager.tabBar.subviews.compactMap { $0 as? UICollectionView }.first!
                            let frame = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(
                                item: 0,
                                section: 0
                            ))!.frame
                            XCTAssertEqual(frame.height, expected, accuracy: 0.01)
                            XCTAssertGreaterThanOrEqual(frame.width, 44)
                        }
                    }
                }
            }
        }
    }

    func testAccessoryHeightInsetsPreserveContainerScrollAndHiddenBar() {
        for short in [false, true] {
            let pager = mount(height: short ? 40 : 1800)
            pager.view.layoutIfNeeded()
            let scroll = pager.currentScrollView!
            scroll.contentOffset.y = (short ? 100 : 310) - scroll.adjustedContentInset.top
            let position = pager.records[0]!.binding!.position
            let accessory = UIView()
            let height = accessory.heightAnchor.constraint(equalToConstant: 100)
            NSLayoutConstraint.activate([accessory.widthAnchor.constraint(equalToConstant: 60), height])
            pager.tabBar.trailingAccessoryView = accessory
            pager.tabBar.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16)
            for expected: CGFloat in [100, 130, 0, 130] {
                pager.layout.tabBarHeight = expected == 0 ? 0 : 44
                if expected > 0 {
                    height.constant = expected
                }
                pager.tabBar.invalidateAccessoryLayout()
                pager.view.layoutIfNeeded()
                XCTAssertEqual(pager.tabBar.bounds.height, expected, accuracy: 0.01)
                XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
                pager.setSelectedIndex(1, animated: false)
                pager.setSelectedIndex(0, animated: false)
                pager.view.layoutIfNeeded()
                for index in [0, 1] {
                    let root = pager.records[index]!.controller.view!
                    let frame = root.convert(root.bounds, to: pager.view)
                    XCTAssertEqual(frame.minY, pager.tabBar.frame.minY, accuracy: 0.01)
                    XCTAssertEqual(frame.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                }
            }
            pager.tabBar.trailingAccessoryView = nil
            pager.tabBar.contentInsets = .zero
            pager.view.layoutIfNeeded()
            XCTAssertEqual(pager.tabBar.bounds.height, 44, accuracy: 0.01)
            XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
        }
    }

    func testAutomaticTabHeightUpdatesContainerAndCachedPages() {
        let pager = mount()
        let provider = AutomaticTabSource()
        pager.tabBar.contentDelegate = provider
        pager.tabBar.contentStyle = .custom
        pager.view.layoutIfNeeded()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 310 - scroll.adjustedContentInset.top
        let position = pager.records[0]!.binding!.position
        let oldHeight = pager.tabBar.bounds.height
        pager.setSelectedIndex(1, animated: false)
        provider.text = String(repeating: "自动布局的多行标签内容", count: 20)
        pager.tabBar.reloadContent()
        pager.view.layoutIfNeeded()
        XCTAssertGreaterThan(pager.tabBar.bounds.height, oldHeight)
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.setSelectedIndex(0, animated: false)
            pager.view.layoutIfNeeded()
            XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
            let root = pager.records[0]!.controller.view!
            XCTAssertEqual(root.convert(root.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
            XCTAssertEqual(root.convert(root.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
        }
        provider.text = "短标签"
        pager.tabBar.reloadContent()
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.tabBar.bounds.height, oldHeight, accuracy: 1)
        XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
    }

    func testCustomTabHeightAndModeSwitchPreserveCachedPageGeometry() {
        let pager = mount()
        let provider = CustomContentSource()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 310 - scroll.adjustedContentInset.top
        let position = pager.records[0]!.binding!.position
        pager.tabBar.contentDelegate = provider
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for style: SPTabBar.ContentStyle in [.custom, .default, .custom] {
                pager.tabBar.contentStyle = style
                pager.view.layoutIfNeeded()
                XCTAssertEqual(pager.tabBar.bounds.height, style == .custom ? 80 : 44, accuracy: 0.01)
                XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
                let root = pager.records[0]!.controller.view!
                XCTAssertEqual(root.convert(root.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
                XCTAssertEqual(root.convert(root.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            }
        }
        pager.setSelectedIndex(1, animated: false)
        provider.size.height = 110
        pager.tabBar.reloadContent()
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.tabBar.bounds.height, 110, accuracy: 0.01)
        pager.setSelectedIndex(0, animated: false)
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
        XCTAssertEqual(
            pager.records[0]!.controller.view.convert(.zero, to: pager.view).y,
            pager.tabBar.frame.minY,
            accuracy: 0.01
        )
    }

    func testLiveTabHeightPreservesPageGeometryAndScrollPosition() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 310 - scroll.adjustedContentInset.top
        let position = pager.records[0]!.binding!.position
        let oldHeight = pager.tabBar.bounds.height
        pager.tabBar.standardAppearance.itemAppearance.layout = .stacked
        pager.tabBar.items[0].image = UIImage(systemName: "star")
        pager.view.layoutIfNeeded()
        XCTAssertGreaterThan(pager.tabBar.bounds.height, oldHeight)
        XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
        let root = pager.records[0]!.controller.view!
        XCTAssertEqual(root.convert(root.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
    }

    func testSiblingLabelAndScrollStayBelowTabBar() throws {
        for belowLabel in [true, false] {
            let pager = mount(inNavigation: true, mixedLayout: belowLabel)
            let page = try XCTUnwrap(pager.records[0]?.controller as? MixedFixturePage)
            let scroll = page.scroll
            for behavior: UIScrollView.ContentInsetAdjustmentBehavior in [.automatic, .never] {
                scroll.contentInsetAdjustmentBehavior = behavior
                for position: CGFloat in [0, 40, 120, 200, 350, 200, 50, 0, -25, 0] {
                    scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                    pager.view.layoutIfNeeded()
                    page.view.layoutIfNeeded()
                    let root = page.view.convert(page.view.bounds, to: pager.view)
                    let label = page.label.convert(page.label.bounds, to: pager.view)
                    let scrollFrame = scroll.convert(scroll.bounds, to: pager.view)
                    XCTAssertEqual(root.minY, pager.tabBar.frame.minY, accuracy: 0.01)
                    XCTAssertEqual(root.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                    XCTAssertEqual(label.minY, pager.tabBar.frame.maxY + 12, accuracy: 0.01)
                    XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
                    let contentTop = scroll.convert(.zero, to: pager.view).y
                    XCTAssertEqual(
                        contentTop,
                        max(scrollFrame.minY, pager.tabBar.frame.maxY) - max(0, position - 200) - min(0, position),
                        accuracy: 0.01
                    )
                    if belowLabel {
                        XCTAssertEqual(scrollFrame.minY, label.maxY + 8, accuracy: 0.01)
                    }
                }
            }
        }
    }

    func testMixedPageResizeSafeAreaAndPagingPreserveGeometry() throws {
        let pager = mount(mixedLayout: true)
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)] {
                window!.frame.size = size
                pager.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 21, bottom: 25, right: 13)
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                for position: CGFloat in [0, 80, 200, 350] {
                    let page = try XCTUnwrap(pager.records[0]?.controller as? MixedFixturePage)
                    page.scroll.contentOffset.y = position - page.scroll.adjustedContentInset.top
                    pager.setSelectedIndex(1, animated: false)
                    pager.view.layoutIfNeeded()
                    for record in pager.records.values {
                        let child = try XCTUnwrap(record.controller as? MixedFixturePage)
                        let root = child.view.convert(child.view.bounds, to: pager.view)
                        let label = child.label.convert(child.label.bounds, to: pager.view)
                        XCTAssertEqual(root.minY, pager.tabBar.frame.minY, accuracy: 0.01)
                        XCTAssertEqual(root.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                        XCTAssertEqual(label.minY, pager.tabBar.frame.maxY + 12, accuracy: 0.01)
                        XCTAssertEqual(
                            label.width,
                            root.width - child.view.safeAreaInsets.left - child.view.safeAreaInsets.right - 32,
                            accuracy: 0.01
                        )
                    }
                    pager.setSelectedIndex(0, animated: false)
                    XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
                }
            }
        }
    }

    func testMixedShortPageHasPhysicalCollapseRangeAndRestoresBusinessInsets() throws {
        for height: CGFloat in [0, 100] {
            let pager = mount(height: height, mixedLayout: true)
            let page = try XCTUnwrap(pager.records[0]?.controller as? MixedFixturePage)
            let scroll = page.scroll
            let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
            scroll.contentInset = base
            for position: CGFloat in [0, 40, 150, 200, 50, 0] {
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                XCTAssertEqual(pager.collapseOffset, position, accuracy: 0.01)
                XCTAssertEqual(scroll.contentInset.top, base.top + position, accuracy: 0.01)
                // 直接检查 UIKit 的实际可滚动范围，不能只依赖 maximumPosition 的下限钳制。
                let physicalRange = scroll.contentSize.height + scroll.adjustedContentInset.top + scroll
                    .adjustedContentInset.bottom - scroll.bounds.height
                XCTAssertEqual(physicalRange, 200, accuracy: 0.01)
                XCTAssertTrue(scroll.showsVerticalScrollIndicator)
                XCTAssertEqual(
                    scroll.convert(.zero, to: pager.view).y,
                    page.label.convert(page.label.bounds, to: pager.view).maxY + 8 + base.top,
                    accuracy: 0.01
                )
            }
            source!.ids.removeFirst()
            pager.reloadData()
            XCTAssertEqual(scroll.contentInset, base)
            XCTAssertNil(page.parent)
        }
    }

    func testShortAndEmptyContentPreserveBusinessIndicatorVisibility() {
        let pager = mount(height: 216, inNavigation: true)
        let scroll = pager.currentScrollView!
        let binding = pager.records[0]!.binding!
        XCTAssertEqual(pager.scrollIndicatorVisibilityPolicy, .preserve)
        for visible in [true, false] {
            scroll.showsVerticalScrollIndicator = visible
            scroll.showsHorizontalScrollIndicator = !visible
            for height: CGFloat in [216, 0, 1800, 216] {
                scroll.contentSize.height = height
                for position: CGFloat in [0, 100, 200] {
                    binding.setPosition(position)
                    XCTAssertEqual(scroll.showsVerticalScrollIndicator, visible)
                    XCTAssertEqual(scroll.showsHorizontalScrollIndicator, !visible)
                }
            }
            scroll.frame.size.height = 2000
            XCTAssertEqual(scroll.showsVerticalScrollIndicator, visible)
            scroll.frame.size.height = 500
            XCTAssertEqual(scroll.showsVerticalScrollIndicator, visible)
        }
    }

    func testIndicatorTrackFollowsVisibleHeaderAndKeepsBusinessInsets() {
        let pager = mount(inNavigation: true)
        let scroll = pager.currentScrollView!
        let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
        scroll.verticalScrollIndicatorInsets = base
        let horizontal = scroll.horizontalScrollIndicatorInsets
        for position: CGFloat in [-30, 0, 100, 200, 350, 50] {
            scroll.contentOffset.y = position - scroll.adjustedContentInset.top
            let trackTop = scroll.convert(scroll.bounds.origin, to: pager.view).y + scroll.verticalScrollIndicatorInsets
                .top + scroll.safeAreaInsets.top
            XCTAssertEqual(trackTop, pager.tabBar.frame.maxY + base.top, accuracy: 0.01)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.bottom, base.bottom)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.left, base.left)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.right, base.right)
            XCTAssertEqual(scroll.horizontalScrollIndicatorInsets, horizontal)
        }
        pager.setSelectedIndex(1, animated: false)
        let next = pager.currentScrollView!
        XCTAssertEqual(
            next.verticalScrollIndicatorInsets.top + next.safeAreaInsets.top,
            pager.tabBar.bounds.height,
            accuracy: 0.01
        )
        pager.layout.headerHeight += 40
        XCTAssertEqual(
            next.verticalScrollIndicatorInsets.top + next.safeAreaInsets.top,
            pager.tabBar.bounds.height,
            accuracy: 0.01
        )
    }

    func testBindingRestoresLatestIndicatorPreferencesOnlyAfterTemporaryHiding() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let initial = UIEdgeInsets(top: 11, left: 2, bottom: 17, right: 4)
        scroll.verticalScrollIndicatorInsets = initial
        scroll.automaticallyAdjustsScrollIndicatorInsets = false
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        binding.indicatorsHiddenForPaging = true
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        let updated = UIEdgeInsets(top: 9, left: 6, bottom: 23, right: 8)
        scroll.verticalScrollIndicatorInsets = updated
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, updated)
        // false 与临时隐藏后的实际值相同，也必须记为新的业务意图。
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize.height = 1800
        binding.indicatorsHiddenForPaging = false
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        scroll.showsVerticalScrollIndicator = true
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets.top, 209)
        scroll.contentSize.height = 0
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        binding.indicatorsHiddenForPaging = true
        scroll.showsHorizontalScrollIndicator = true
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        binding.detach()
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, updated)
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
        XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets)
    }

    func testDefaultPolicyNeverWritesVisibilityDuringPagingRebindingOrDetach() {
        for vertical in [false, true] {
            for horizontal in [false, true] {
                let pager = mount(height: 0)
                let root = pager.records[0]!.controller.view!
                let scroll = IndicatorWriteTrackingScrollView(frame: root.bounds)
                scroll.showsVerticalScrollIndicator = vertical
                scroll.showsHorizontalScrollIndicator = horizontal
                scroll.visibilityWrites = 0
                root.addSubview(scroll)
                pager.setScrollView(scroll, forPageAt: 0)
                pager.view.layoutIfNeeded()
                scroll.contentSize.height = 1800
                scroll.contentSize.height = 0
                pager.scrollViewWillBeginDragging(pager.pagingView)
                pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
                pager.setSelectedIndex(1, animated: true)
                pager.setSelectedIndex(0, animated: false)
                pager.scrollViewWillBeginDragging(pager.pagingView)
                let replacement = UIScrollView(frame: root.bounds)
                root.addSubview(replacement)
                pager.setScrollView(replacement, forPageAt: 0)
                XCTAssertEqual(scroll.visibilityWrites, 0)
                XCTAssertEqual(scroll.showsVerticalScrollIndicator, vertical)
                XCTAssertEqual(scroll.showsHorizontalScrollIndicator, horizontal)
                XCTAssertTrue(replacement.showsVerticalScrollIndicator)
                XCTAssertTrue(replacement.showsHorizontalScrollIndicator)
            }
        }
    }

    func testChangingIndicatorPolicyDuringPagingRestoresAndRecapturesLatestIntent() {
        let pager = mount(height: 0)
        let scroll = pager.currentScrollView!
        scroll.showsHorizontalScrollIndicator = false
        pager.scrollViewWillBeginDragging(pager.pagingView)
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = true
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        pager.scrollIndicatorVisibilityPolicy = .preserve
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
        // 重复赋值不应再次拍摄已经隐藏的 false，覆盖业务 true。
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
        scroll.showsVerticalScrollIndicator = true
        scroll.contentSize.height = 0
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertEqual(pager.collapseOffset, 0, accuracy: 0.01)
    }

    func testIndicatorPolicyChangeInsideVisibilityCallbackAppliesToAllCachedPages() {
        let pager = mount()
        var scrolls: [IndicatorWriteTrackingScrollView] = []
        for index in 0 ..< 3 {
            pager.setSelectedIndex(index, animated: false)
            let root = pager.records[index]!.controller.view!
            let scroll = IndicatorWriteTrackingScrollView(frame: root.bounds)
            root.addSubview(scroll)
            pager.setScrollView(scroll, forPageAt: index)
            scrolls.append(scroll)
        }
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        for scroll in scrolls {
            scroll.onVisibilityChange = { [weak pager, weak scroll] in
                guard scroll?.showsVerticalScrollIndicator == false else {
                    return
                }
                scroll?.onVisibilityChange = nil
                pager?.scrollIndicatorVisibilityPolicy = .preserve
            }
        }
        pager.scrollViewWillBeginDragging(pager.pagingView)
        XCTAssertEqual(pager.scrollIndicatorVisibilityPolicy, .preserve)
        for scroll in scrolls {
            scroll.onVisibilityChange = nil
            XCTAssertTrue(scroll.showsVerticalScrollIndicator)
            XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
        }
        pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
    }

    func testReenteringIndicatorHidingDuringRestorationPreservesBothPreferences() {
        let scroll = IndicatorWriteTrackingScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let binding = SPScrollBinding(scrollView: scroll)
        binding.indicatorsHiddenForPaging = true
        scroll.onVisibilityChange = { [weak binding, weak scroll] in
            guard scroll?.showsVerticalScrollIndicator == true else {
                return
            }
            scroll?.onVisibilityChange = nil
            binding?.indicatorsHiddenForPaging = true
        }
        binding.indicatorsHiddenForPaging = false
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        binding.indicatorsHiddenForPaging = false
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
    }

    func testDetachInsideIndicatorVisibilityCallbackDoesNotLeaveHiddenFlags() {
        let scroll = IndicatorWriteTrackingScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let binding = SPScrollBinding(scrollView: scroll)
        scroll.onVisibilityChange = { [weak binding, weak scroll] in
            guard scroll?.showsVerticalScrollIndicator == false else {
                return
            }
            scroll?.onVisibilityChange = nil
            binding?.detach()
        }
        binding.indicatorsHiddenForPaging = true
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
        scroll.showsVerticalScrollIndicator = false
        binding.setRange(200)
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
    }

    func testBusinessIndicatorWritesInsideFrameworkVisibilityCallbacksArePreserved() {
        for writesVertical in [false, true] {
            let scroll = IndicatorWriteTrackingScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
            let binding = SPScrollBinding(scrollView: scroll)
            scroll.onVisibilityChange = { [weak scroll] in
                guard let scroll, !scroll.showsVerticalScrollIndicator else {
                    return
                }
                scroll.onVisibilityChange = nil
                if writesVertical {
                    // 同轴同值赋值仍是业务意图，不能与外层框架写入一起忽略。
                    scroll.showsVerticalScrollIndicator = false
                } else {
                    scroll.showsHorizontalScrollIndicator = false
                }
            }
            binding.indicatorsHiddenForPaging = true
            binding.indicatorsHiddenForPaging = false
            XCTAssertEqual(scroll.showsVerticalScrollIndicator, !writesVertical)
            XCTAssertEqual(scroll.showsHorizontalScrollIndicator, writesVertical)
        }
        let scroll = IndicatorWriteTrackingScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let binding = SPScrollBinding(scrollView: scroll)
        binding.indicatorsHiddenForPaging = true
        scroll.onVisibilityChange = { [weak scroll] in
            guard let scroll, scroll.showsVerticalScrollIndicator else {
                return
            }
            scroll.onVisibilityChange = nil
            scroll.showsHorizontalScrollIndicator = false
        }
        binding.indicatorsHiddenForPaging = false
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
    }

    func testTemporaryIndicatorHidingRestoresOnBindingRelease() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        var binding: SPScrollBinding? = SPScrollBinding(scrollView: scroll)
        binding?.indicatorsHiddenForPaging = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = true
        XCTAssertFalse(scroll.showsHorizontalScrollIndicator)
        binding = nil
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertTrue(scroll.showsHorizontalScrollIndicator)
    }

    func testCancelledPagingRestoresOutgoingPositionAfterNativeLayoutAdjustment() {
        for rtl in [false, true] {
            let pager = mount()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.view.layoutIfNeeded()
            let binding = pager.records[0]!.binding!
            let scroll = binding.scrollView
            scroll.contentOffset.y = 650 - scroll.adjustedContentInset.top
            let top = scroll.convert(.zero, to: pager.view).y
            let start = pager.pagingView.contentOffset.x
            pager.scrollViewWillBeginDragging(pager.pagingView)
            // 横向拖动已开始、候选页尚未建立时，UIKit 自适应列表会发送临时纵向偏移。
            scroll.contentOffset.y -= 10.5
            pager.pagingView.contentOffset.x = start + (rtl ? -1 : 1) * pager.pagingView.bounds.width * 0.4
            pager.pagingView.contentOffset.x = start
            pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
            XCTAssertEqual(pager.selectedIndex, 0)
            XCTAssertEqual(binding.position, 650, accuracy: 0.01)
            XCTAssertEqual(scroll.convert(.zero, to: pager.view).y, top, accuracy: 0.01)
            // 后续真实纵向位置变化仍须正常保存。
            scroll.contentOffset.y = 700 - scroll.adjustedContentInset.top
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(binding.position, 700, accuracy: 0.01)
        }
    }

    func testCommittedPagingDoesNotSaveOutgoingNativeLayoutAdjustment() {
        for rtl in [false, true] {
            let pager = mount()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.view.layoutIfNeeded()
            let binding = pager.records[0]!.binding!
            binding.scrollView.contentOffset.y = 650 - binding.scrollView.adjustedContentInset.top
            let start = pager.pagingView.contentOffset.x
            pager.scrollViewWillBeginDragging(pager.pagingView)
            binding.scrollView.contentOffset.y -= 10.5
            pager.pagingView.contentOffset.x = start + (rtl ? -1 : 1) * pager.pagingView.bounds.width
            pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
            XCTAssertEqual(pager.selectedIndex, 1)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(binding.position, 650, accuracy: 0.01)
        }
    }

    func testPagingHidesIndicatorsForOutgoingAndNewPagesUntilSettled() {
        let pager = mount()
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        let outgoing = pager.currentScrollView!
        pager.scrollViewWillBeginDragging(pager.pagingView)
        XCTAssertFalse(outgoing.showsVerticalScrollIndicator)
        XCTAssertFalse(outgoing.showsHorizontalScrollIndicator)
        pager.pagingView.contentOffset.x = pager.pagingView.bounds.width * 0.5
        let incoming = pager.records[1]!.binding!.scrollView
        XCTAssertFalse(incoming.showsVerticalScrollIndicator)
        XCTAssertFalse(incoming.showsHorizontalScrollIndicator)
        pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: true)
        XCTAssertFalse(outgoing.showsVerticalScrollIndicator)
        pager.pagingView.contentOffset.x = pager.pagingView.bounds.width
        pager.scrollViewDidEndDecelerating(pager.pagingView)
        XCTAssertEqual(pager.selectedIndex, 1)
        XCTAssertTrue(incoming.showsVerticalScrollIndicator)
        XCTAssertTrue(incoming.showsHorizontalScrollIndicator)
        XCTAssertTrue(outgoing.showsVerticalScrollIndicator)
    }

    func testPagingCancellationAndAnimatedSelectionRestoreIndicatorPreferences() {
        let pager = mount()
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        let outgoing = pager.currentScrollView!
        outgoing.showsHorizontalScrollIndicator = false
        pager.scrollViewWillBeginDragging(pager.pagingView)
        outgoing.showsVerticalScrollIndicator = false
        pager.scrollViewDidEndDragging(pager.pagingView, willDecelerate: false)
        XCTAssertFalse(outgoing.showsVerticalScrollIndicator)
        XCTAssertFalse(outgoing.showsHorizontalScrollIndicator)
        outgoing.showsVerticalScrollIndicator = true
        pager.setSelectedIndex(1, animated: true)
        XCTAssertFalse(outgoing.showsVerticalScrollIndicator)
        XCTAssertFalse(pager.records[1]!.binding!.scrollView.showsVerticalScrollIndicator)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertTrue(outgoing.showsVerticalScrollIndicator)
        XCTAssertFalse(outgoing.showsHorizontalScrollIndicator)
        pager.setSelectedIndex(1, animated: true)
        // 库夹具驱动动画终态回调，真实动画由 Demo UI 回归验证。
        pager.pagingView.setContentOffset(CGPoint(x: pager.pagingView.bounds.width, y: 0), animated: false)
        pager.scrollViewDidEndScrollingAnimation(pager.pagingView)
        XCTAssertEqual(pager.selectedIndex, 1)
        XCTAssertTrue(pager.currentScrollView!.showsVerticalScrollIndicator)
    }

    func testReplacingBindingDuringPagingKeepsIndicatorsHiddenAndRestoresOnReload() {
        let pager = mount()
        pager.scrollIndicatorVisibilityPolicy = .hideDuringPaging
        let old = pager.currentScrollView!
        pager.scrollViewWillBeginDragging(pager.pagingView)
        let replacement = UIScrollView(frame: old.frame)
        replacement.contentSize.height = 1800
        pager.records[0]!.controller.view.addSubview(replacement)
        pager.setScrollView(replacement, forPageAt: 0)
        XCTAssertTrue(old.showsVerticalScrollIndicator)
        XCTAssertTrue(old.showsHorizontalScrollIndicator)
        XCTAssertFalse(replacement.showsVerticalScrollIndicator)
        XCTAssertFalse(replacement.showsHorizontalScrollIndicator)
        pager.reloadData()
        XCTAssertTrue(replacement.showsVerticalScrollIndicator)
        XCTAssertTrue(replacement.showsHorizontalScrollIndicator)
    }

    func testAlreadyHiddenIndicatorsReceiveNoPropertyWrites() {
        let scroll = IndicatorWriteTrackingScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        scroll.contentSize.height = 1800
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.verticalScrollIndicatorInsets = UIEdgeInsets(top: 9, left: 2, bottom: 17, right: 4)
        scroll.indicatorWrites = 0
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        binding.indicatorsHiddenForPaging = true
        binding.setPosition(100)
        scroll.contentSize.height = 2000
        binding.indicatorsHiddenForPaging = false
        binding.detach()
        XCTAssertEqual(scroll.indicatorWrites, 0)
    }

    func testGeometryOrdersHeaderAndContent() {
        XCTAssertEqual(SPScrollGeometry.collapse(120, range: 200), 120)
        XCTAssertEqual(SPScrollGeometry.content(120, range: 200), 0)
        XCTAssertEqual(SPScrollGeometry.collapse(340, range: 200), 200)
        XCTAssertEqual(SPScrollGeometry.content(340, range: 200), 140)
        XCTAssertEqual(SPScrollGeometry.collapse(-50, range: 200), 0)
        XCTAssertEqual(SPScrollGeometry.position(collapse: 100, content: 900, range: 200), 100)
    }

    func testLayoutNormalizesInvalidHeights() {
        XCTAssertEqual(SPPageLayout(headerHeight: -2, minimumHeaderHeight: 50).normalized.headerHeight, 0)
        XCTAssertEqual(SPPageLayout(headerHeight: 30, minimumHeaderHeight: 50).normalized.minimumHeaderHeight, 30)
        XCTAssertEqual(SPPageLayout(headerHeight: .infinity, tabBarHeight: .nan).normalized.tabBarHeight, 44)
    }

    func testSnapshotSelection() {
        XCTAssertEqual(SPScrollGeometry.selectedIndex(oldID: 2, oldIndex: 1, identifiers: [2, 0, 1]), 0)
        XCTAssertEqual(SPScrollGeometry.selectedIndex(oldID: 3, oldIndex: 3, identifiers: [0, 1]), 1)
        XCTAssertNil(SPScrollGeometry.selectedIndex(oldID: 0, oldIndex: 0, identifiers: []))
    }

    func testDiscoveryRootAndEmptyList() {
        let list = UITableView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        XCTAssertTrue(SPScrollViewDiscovery.find(in: list) === list)
    }

    func testDiscoveryExcludesHiddenAndHorizontalAndUsesArea() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let hidden = UIScrollView(frame: root.bounds); hidden.isHidden = true; hidden.alwaysBounceVertical = true
        let horizontal = UIScrollView(frame: root.bounds); horizontal.contentSize.width = 900
        let small = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)); small.alwaysBounceVertical = true
        let large = UIScrollView(frame: root.bounds); large.alwaysBounceVertical = true
        [hidden, horizontal, small, large].forEach(root.addSubview)
        XCTAssertTrue(SPScrollViewDiscovery.find(in: root) === large)
        large.isUserInteractionEnabled = false
        XCTAssertTrue(SPScrollViewDiscovery.find(in: root) === small)
    }

    func testDiscoveryStableTieAndHiddenAncestor() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let first = UIScrollView(frame: root.bounds), second = UIScrollView(frame: root.bounds)
        root.addSubview(first); root.addSubview(second)
        XCTAssertTrue(SPScrollViewDiscovery.find(in: root) === first)
        root.isHidden = true
        XCTAssertNil(SPScrollViewDiscovery.find(in: root))
    }

    func testBindingPreservesDelegateAndRestoresInsets() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        scroll.contentSize.height = 1000
        let owner = ScrollDelegate(); scroll.delegate = owner
        scroll.contentInset = UIEdgeInsets(top: 13, left: 3, bottom: 19, right: 5)
        let original = scroll.contentInset
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        XCTAssertEqual(scroll.contentInset.top, 213)
        binding.setPosition(350)
        XCTAssertEqual(binding.position, 350, accuracy: 0.01)
        XCTAssertTrue(scroll.delegate === owner)
        binding.detach()
        XCTAssertEqual(scroll.contentInset, original)
        XCTAssertFalse(scroll.alwaysBounceVertical)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 150, accuracy: 0.01)
    }

    func testBindingNeverOwnsBusinessBounceConfiguration() {
        for enabled in [false, true] {
            let pager = mount(height: 0)
            let scroll = UIScrollView(frame: pager.records[0]!.controller.view.bounds)
            scroll.bounces = enabled
            scroll.alwaysBounceVertical = enabled
            scroll.alwaysBounceHorizontal = enabled
            pager.records[0]!.controller.view.addSubview(scroll)
            pager.setScrollView(scroll, forPageAt: 0)
            pager.view.layoutIfNeeded()
            XCTAssertEqual(scroll.bounces, enabled)
            XCTAssertEqual(scroll.alwaysBounceVertical, enabled)
            XCTAssertEqual(scroll.alwaysBounceHorizontal, enabled)
            let binding = pager.records[0]!.binding!
            XCTAssertEqual(binding.maximumPosition, 200, accuracy: 0.01)
            scroll.bounces = !enabled
            scroll.alwaysBounceVertical = !enabled
            scroll.alwaysBounceHorizontal = !enabled
            binding.detach()
            XCTAssertEqual(scroll.bounces, !enabled)
            XCTAssertEqual(scroll.alwaysBounceVertical, !enabled)
            XCTAssertEqual(scroll.alwaysBounceHorizontal, !enabled)
        }
    }

    func testDisabledBusinessScrollRejectsHeaderInputButKeepsPageCoordination() {
        for position: CGFloat in [80, 650] {
            let pager = mount()
            let binding = pager.records[0]!.binding!
            let scroll = binding.scrollView
            scroll.contentInsetAdjustmentBehavior = .never
            pager.view.layoutIfNeeded()
            scroll.contentOffset.y = position - scroll.adjustedContentInset.top
            scroll.isScrollEnabled = false
            let pan = FixturePan()
            XCTAssertFalse(pager.gestureRecognizerShouldBegin(pan))
            let offset = scroll.contentOffset
            let collapse = pager.collapseOffset
            pan.send(to: pager, state: .began)
            pan.send(to: pager, state: .changed, y: -300)
            pan.testVelocity.y = -1000
            pan.send(to: pager, state: .ended)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            XCTAssertEqual(scroll.contentOffset, offset)
            XCTAssertEqual(pager.collapseOffset, collapse)
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(binding.position, position, accuracy: 0.01)
            XCTAssertFalse(scroll.isScrollEnabled)
            // 程序化位置和布局仍按正常契约协调；不把禁用用户滚动当成坐标冻结。
            scroll.contentOffset.y = 100 - scroll.adjustedContentInset.top
            XCTAssertEqual(pager.collapseOffset, 100, accuracy: 0.01)
            pager.layout.headerHeight += 20
            pager.view.layoutIfNeeded()
            XCTAssertFalse(scroll.isScrollEnabled)
            scroll.isScrollEnabled = true
            XCTAssertTrue(pager.gestureRecognizerShouldBegin(pan))
            pan.send(to: pager, state: .began)
            let start = binding.position
            pan.send(to: pager, state: .changed, y: -20)
            XCTAssertEqual(binding.position, start + 20, accuracy: 0.01)
            pan.send(to: pager, state: .cancelled)
        }
    }

    func testDisablingBusinessScrollStopsActiveHeaderDragAndInertia() {
        let pager = mount()
        let binding = pager.records[0]!.binding!
        let scroll = binding.scrollView
        scroll.contentInsetAdjustmentBehavior = .never
        pager.view.layoutIfNeeded()
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -260)
        XCTAssertEqual(binding.position, 260, accuracy: 0.01)
        scroll.isScrollEnabled = false
        scroll.isScrollEnabled = true
        pan.send(to: pager, state: .changed, y: -400)
        XCTAssertEqual(binding.position, 260, accuracy: 0.01)
        pan.send(to: pager, state: .changed, y: -500)
        XCTAssertEqual(binding.position, 260, accuracy: 0.01, "恢复开关后旧触摸不能继续驱动")
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -20)
        pan.testVelocity.y = -500
        pan.send(to: pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        XCTAssertGreaterThan(binding.position, 280)
        scroll.isScrollEnabled = false
        let stopped = binding.position
        scroll.isScrollEnabled = true
        for _ in 0 ..< 5 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertEqual(binding.position, stopped, accuracy: 0.01)
        }
        scroll.isScrollEnabled = true
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        XCTAssertEqual(binding.position, stopped, accuracy: 0.01, "恢复开关后旧惯性不能重启")
    }

    func testDisablingScrollDuringHeaderDragStartDoesNotReviveCancelledGesture() {
        let pager = mount()
        let root = pager.records[0]!.controller.view!
        let scroll = OffsetCallbackScrollView(frame: root.bounds)
        scroll.contentSize.height = 1800
        scroll.contentInsetAdjustmentBehavior = .never
        root.addSubview(scroll)
        pager.setScrollView(scroll, forPageAt: 0)
        pager.view.layoutIfNeeded()
        let binding = pager.records[0]!.binding!
        var didDisable = false
        // 业务滚动视图可在非动画定位的同步回调里更新交互开关。
        scroll.onSetContentOffset = { [weak scroll] in
            guard !didDisable else {
                return
            }
            didDisable = true
            scroll?.isScrollEnabled = false
            scroll?.isScrollEnabled = true
        }
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        XCTAssertTrue(didDisable)
        let stopped = binding.position
        pan.send(to: pager, state: .changed, y: -100)
        XCTAssertEqual(binding.position, stopped, accuracy: 0.01)
        pan.testVelocity.y = -500
        pan.send(to: pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        XCTAssertEqual(binding.position, stopped, accuracy: 0.01)
        scroll.onSetContentOffset = nil
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -20)
        XCTAssertEqual(binding.position, stopped + 20, accuracy: 0.01)
        pan.send(to: pager, state: .cancelled)
    }

    func testBackgroundAndDetachedScrollDisableDoNotCancelCurrentHeaderDrag() {
        let pager = mount()
        let old = pager.currentScrollView!
        pager.setSelectedIndex(1, animated: false)
        let binding = pager.records[1]!.binding!
        binding.scrollView.contentInsetAdjustmentBehavior = .never
        pager.view.layoutIfNeeded()
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        let start = binding.position
        old.isScrollEnabled = false
        pan.send(to: pager, state: .changed, y: -20)
        XCTAssertEqual(binding.position, start + 20, accuracy: 0.01)
        pan.send(to: pager, state: .cancelled)
        source!.ids.removeFirst()
        pager.reloadData()
        pan.send(to: pager, state: .began)
        let reloadedStart = binding.position
        old.isScrollEnabled = true
        old.isScrollEnabled = false
        pan.send(to: pager, state: .changed, y: -20)
        XCTAssertEqual(binding.position, reloadedStart + 20, accuracy: 0.01)
        pan.send(to: pager, state: .cancelled)
    }

    func testExplicitDisabledScrollBindingKeepsLayoutAndProgrammaticPosition() {
        let pager = mount()
        let root = pager.records[0]!.controller.view!
        let scroll = UIScrollView(frame: root.bounds)
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize.height = 1800
        scroll.isScrollEnabled = false
        root.addSubview(scroll)
        pager.setScrollView(scroll, forPageAt: 0)
        pager.view.layoutIfNeeded()
        XCTAssertTrue(pager.currentScrollView === scroll)
        scroll.contentOffset.y = 300 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
        let pan = FixturePan()
        XCTAssertFalse(pager.gestureRecognizerShouldBegin(pan))
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: 200)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 300, accuracy: 0.01)
        pager.setSelectedIndex(1, animated: false)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 300, accuracy: 0.01)
        XCTAssertFalse(scroll.isScrollEnabled)
    }

    func testHeaderDragAndInertiaStayWithinScrollBounds() {
        for height: CGFloat in [0, 100, 1800] {
            for bounces in [false, true] {
                let pager = mount(height: height)
                let binding = pager.records[0]!.binding!
                binding.scrollView.bounces = bounces
                let pan = FixturePan()
                pan.send(to: pager, state: .began)
                pan.send(to: pager, state: .changed, y: 300)
                XCTAssertEqual(binding.position, 0, accuracy: 0.01)
                pan.testVelocity.y = 5000
                pan.send(to: pager, state: .ended)
                // 检查真实 display link 推进期间的每个采样点，不能只检查最终归位。
                for _ in 0 ..< 12 {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
                    XCTAssertEqual(binding.position, 0, accuracy: 0.01)
                }
                pan.send(to: pager, state: .began)
                pan.send(to: pager, state: .changed, y: -5000)
                XCTAssertEqual(binding.position, binding.maximumPosition, accuracy: 0.01)
                pan.testVelocity.y = -5000
                pan.send(to: pager, state: .ended)
                for _ in 0 ..< 12 {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
                    XCTAssertEqual(binding.position, binding.maximumPosition, accuracy: 0.01)
                }
                XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
                XCTAssertEqual(binding.scrollView.bounces, bounces)
            }
        }
    }

    func testHeaderDragReversesImmediatelyAfterReachingEitherBoundary() {
        for plain in [false, true] {
            for height: CGFloat in [0, 100, 1800] {
                for direction: UISemanticContentAttribute in [.forceLeftToRight, .forceRightToLeft] {
                    let pager = mount(plain: plain ? [0] : [], height: height)
                    pager.view.semanticContentAttribute = direction
                    pager.view.layoutIfNeeded()
                    let binding = pager.records[0]!.binding
                    let maximum = binding?.maximumPosition ?? 200
                    let pan = FixturePan()
                    pan.send(to: pager, state: .began)
                    pan.send(to: pager, state: .changed, y: 300)
                    XCTAssertEqual(binding?.position ?? pager.collapseOffset, 0, accuracy: 0.01)
                    // 已丢弃的越界距离不能变成反向拖动时需要先抵消的空行程。
                    pan.send(to: pager, state: .changed, y: 290)
                    XCTAssertEqual(binding?.position ?? pager.collapseOffset, 10, accuracy: 0.01)
                    pan.send(to: pager, state: .changed, y: -5000)
                    XCTAssertEqual(binding?.position ?? pager.collapseOffset, maximum, accuracy: 0.01)
                    pan.send(to: pager, state: .changed, y: -4990)
                    XCTAssertEqual(binding?.position ?? pager.collapseOffset, maximum - 10, accuracy: 0.01)
                    pan.send(to: pager, state: .cancelled)
                }
            }
        }
    }

    func testHeaderInertiaContinuesInsideBoundsAndStopsAtBoundary() {
        let pager = mount(height: 0)
        let binding = pager.records[0]!.binding!
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -80)
        pan.testVelocity.y = -1000
        pan.send(to: pager, state: .ended)
        var furthest: CGFloat = 80
        for _ in 0 ..< 30 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            XCTAssertGreaterThanOrEqual(binding.position, 80 - 0.01)
            XCTAssertLessThanOrEqual(binding.position, 200 + 0.01)
            furthest = max(furthest, binding.position)
        }
        XCTAssertGreaterThan(furthest, 80)
        XCTAssertEqual(binding.position, 200, accuracy: 0.01)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
    }

    func testZeroCollapseRangeKeepsBusinessBottomInsetAcrossGeometryChanges() {
        for removesHeader in [false, true] {
            for behavior: UIScrollView
                .ContentInsetAdjustmentBehavior in [.automatic, .always, .scrollableAxes, .never] {
                let pager = mount(inNavigation: true)
                let scroll = pager.currentScrollView!
                let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
                scroll.contentInsetAdjustmentBehavior = behavior
                scroll.contentInset = base
                let originalHeader = pager.headerView
                let originalLayout = pager.layout
                if removesHeader {
                    pager.headerView = nil
                } else {
                    pager.layout.headerHeight = 0
                    pager.layout.minimumHeaderHeight = 0
                }
                pager.view.layoutIfNeeded()
                for height: CGFloat in [0, 100, 1800, 0] {
                    scroll.contentSize.height = height
                    pager.view.layoutIfNeeded()
                    XCTAssertEqual(scroll.contentInset.bottom, base.bottom, accuracy: 0.01)
                    XCTAssertEqual(scroll.contentInset.left, base.left)
                    XCTAssertEqual(scroll.contentInset.right, base.right)
                    XCTAssertEqual(pager.collapseOffset, 0)
                    // 零折叠范围仍需避让标签栏，不能连同必要的顶部贡献一起移除。
                    XCTAssertGreaterThanOrEqual(
                        scroll.adjustedContentInset.top,
                        pager.tabBar.bounds.height + base.top - 0.01
                    )
                }
                window?.frame.size.height = 700
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                XCTAssertEqual(scroll.contentInset.bottom, base.bottom, accuracy: 0.01)
                pager.headerView = originalHeader
                pager.layout = originalLayout
                pager.view.layoutIfNeeded()
                XCTAssertGreaterThan(scroll.contentInset.bottom, base.bottom)
                pager.headerView = nil
                pager.view.layoutIfNeeded()
                XCTAssertEqual(scroll.contentInset.bottom, base.bottom, accuracy: 0.01)
            }
        }
    }

    func testZeroRangeCachedBindingPreservesUpdatedBusinessInsetOnRestoreAndDetach() {
        let pager = mount(height: 0)
        let scroll = pager.currentScrollView!
        scroll.contentInsetAdjustmentBehavior = .never
        pager.setSelectedIndex(1, animated: false)
        let originalLayout = pager.layout
        // 保留有高度的固定 Header，同样属于零折叠范围。
        pager.layout.minimumHeaderHeight = pager.layout.headerHeight
        let base = UIEdgeInsets(top: 11, left: 3, bottom: 37, right: 5)
        scroll.contentInset = base
        pager.view.layoutIfNeeded()
        XCTAssertEqual(scroll.contentInset.bottom, base.bottom)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(scroll.contentInset.bottom, base.bottom)
        pager.layout = originalLayout
        pager.view.layoutIfNeeded()
        XCTAssertGreaterThan(scroll.contentInset.bottom, base.bottom)
        pager.layout.minimumHeaderHeight = pager.layout.headerHeight
        pager.view.layoutIfNeeded()
        XCTAssertEqual(scroll.contentInset.bottom, base.bottom)
        source!.ids.removeFirst()
        pager.reloadData()
        XCTAssertEqual(scroll.contentInset, base)
    }

    func testBindingExternalInsetAndShortContentResize() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        XCTAssertEqual(binding.maximumPosition, 200, accuracy: 0.01)
        scroll.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 8, right: 0)
        XCTAssertEqual(scroll.contentInset.top, 212)
        scroll.bounds.size.height = 600
        XCTAssertEqual(binding.maximumPosition, 200, accuracy: 0.01)
        binding.detach()
        XCTAssertEqual(scroll.contentInset.top, 12)
        XCTAssertEqual(scroll.contentInset.bottom, 8)
    }

    func testWindowFramesAndHeaderCollapse() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 120 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 120, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top + 120, accuracy: 0.01)
        scroll.contentOffset.y = 350 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.pagingView.frame.minY, accuracy: 0.01)
        scroll.contentOffset.y = 50 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 50, accuracy: 0.01)
    }

    func testFullBleedHeaderAndContentGeometryInNavigation() throws {
        let pager = mount(plain: [1], inNavigation: true)
        let header = try XCTUnwrap(pager.headerView)
        let headerScroll = try XCTUnwrap(header.superview as? UIScrollView)
        XCTAssertTrue(pager.contentScrollView(for: .top) === headerScroll)
        XCTAssertFalse(headerScroll.isScrollEnabled)
        let scroll = try XCTUnwrap(pager.currentScrollView)
        scroll.contentInset.top = 13
        let safeTop = pager.view.safeAreaInsets.top
        XCTAssertGreaterThan(safeTop, 0)
        for minimum: CGFloat in [0, 40] {
            pager.layout = SPPageLayout(headerHeight: 240, minimumHeaderHeight: minimum)
            let range = 240 - safeTop - minimum
            for position in [CGFloat(0), range / 2, range, range + 150] {
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                let collapse = min(position, range)
                XCTAssertEqual(headerScroll.convert(headerScroll.bounds, to: window).minY, 0, accuracy: 0.01)
                XCTAssertEqual(headerScroll.contentOffset.y, collapse, accuracy: 0.01)
                XCTAssertEqual(header.frame.height, 240, accuracy: 0.01)
                XCTAssertEqual(pager.tabBar.frame.minY, 240 - collapse, accuracy: 0.01)
                XCTAssertEqual(scroll.contentInset.top, collapse + 13, accuracy: 0.01)
                let contentTop = scroll.convert(CGPoint.zero, to: pager.view).y
                XCTAssertEqual(contentTop, pager.tabBar.frame.maxY + 13 - max(0, position - range), accuracy: 0.01)
                XCTAssertEqual(pager.pagingView.frame.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                pager.setSelectedIndex(1, animated: false)
                pager.view.layoutIfNeeded()
                let plain = try XCTUnwrap(pager.records[1]?.controller.view)
                XCTAssertEqual(plain.convert(.zero, to: pager.view).y, pager.tabBar.frame.minY, accuracy: 0.01)
                pager.setSelectedIndex(0, animated: false)
                XCTAssertEqual(pager.records[0]!.binding!.position, position, accuracy: 0.01)
            }
        }
    }

    func testTopSafeAreaChangesPreservePinnedContentAndExpandedOrigin() throws {
        let pager = mount(inNavigation: true)
        pager.layout = SPPageLayout(headerHeight: 300)
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let range = 300 - pager.view.safeAreaInsets.top
        scroll.contentOffset.y = range + 150 - scroll.adjustedContentInset.top
        let before = scroll.convert(CGPoint.zero, to: pager.view).y - pager.tabBar.frame.maxY
        for top: CGFloat in [40, 0] {
            pager.additionalSafeAreaInsets.top = top
            pager.view.setNeedsLayout()
            pager.view.layoutIfNeeded()
            XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top, accuracy: 0.01)
            XCTAssertEqual(
                scroll.convert(CGPoint.zero, to: pager.view).y - pager.tabBar.frame.maxY,
                before,
                accuracy: 0.01
            )
        }
        scroll.contentOffset.y = -scroll.adjustedContentInset.top
        pager.additionalSafeAreaInsets.top = 30
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertEqual(pager.headerView!.convert(.zero, to: window).y, 0, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, 300, accuracy: 0.01)
    }

    func testShortOrMissingHeaderKeepsTabBarBelowSafeArea() throws {
        let pager = mount(inNavigation: true)
        pager.layout = SPPageLayout(headerHeight: 10)
        let scroll = try XCTUnwrap(pager.currentScrollView)
        scroll.contentOffset.y = 100 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top, accuracy: 0.01)
        pager.headerView = nil
        XCTAssertEqual(scroll.contentInset.top, 0, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top, accuracy: 0.01)
    }

    func testPageWidthFillsContainerAndPreservesHorizontalSafeArea() {
        let pager = mount(ids: [0, 1], plain: [1])
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for size in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)] {
                pager.view.frame.size = size
                for inset in [CGFloat(32), 0, 48] {
                    pager.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset / 2)
                    pager.view.setNeedsLayout()
                    pager.view.layoutIfNeeded()
                    for index in [0, 1, 0] {
                        pager.setSelectedIndex(index, animated: false)
                        pager.view.layoutIfNeeded()
                        // 切页后 UIKit 会在下一轮布局中更新从屏幕外移入的子页面安全区域。
                        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                        let child = pager.records[index]!.controller.view!
                        child.layoutIfNeeded()
                        let frame = child.convert(child.bounds, to: pager.view)
                        XCTAssertTrue(child.window === window)
                        XCTAssertEqual(frame.minX, 0, accuracy: 0.01)
                        XCTAssertEqual(frame.maxX, pager.view.bounds.width, accuracy: 0.01)
                        XCTAssertEqual(child.bounds.width, pager.view.bounds.width, accuracy: 0.01)
                        let safeFrame = child.convert(child.safeAreaLayoutGuide.layoutFrame, to: pager.view)
                        XCTAssertEqual(
                            safeFrame.minX,
                            pager.view.safeAreaInsets.left,
                            accuracy: 0.01,
                            "index=\(index), rtl=\(rtl), size=\(size), inset=\(inset), childSafe=\(child.safeAreaInsets)"
                        )
                        XCTAssertEqual(
                            safeFrame.maxX,
                            pager.view.bounds.width - pager.view.safeAreaInsets.right,
                            accuracy: 0.01
                        )
                        XCTAssertEqual(pager.selectedIndex, index)
                    }
                }
            }
        }
    }

    func testPageBottomFillsContainerAndPreservesSafeAreaInsets() {
        let pager = mount(plain: [1])
        let scroll = pager.currentScrollView!
        scroll.contentInset.bottom = 17
        for bottom in [CGFloat(24), 80, 0] {
            pager.additionalSafeAreaInsets.bottom = bottom
            pager.view.setNeedsLayout()
            pager.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            for position in [CGFloat(0), 100, 350] {
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                let child = pager.records[0]!.controller.view!
                XCTAssertTrue(child.window === window)
                XCTAssertEqual(child.convert(child.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
                XCTAssertEqual(pager.pagingView.frame.maxY, pager.view.bounds.maxY, accuracy: 0.01)
            }
            // 页面铺到底边，内容仍由 UIKit 的自动 inset 避开底部安全区域。
            XCTAssertEqual(scroll.contentInset.bottom, 17, accuracy: 0.01)
            XCTAssertEqual(scroll.adjustedContentInset.bottom, 17 + pager.view.safeAreaInsets.bottom, accuracy: 0.01)
            let binding = pager.records[0]!.binding!
            binding.setPosition(binding.maximumPosition)
            let contentBottom = scroll.convert(CGPoint(x: 0, y: scroll.contentSize.height), to: pager.view).y
            XCTAssertEqual(
                contentBottom,
                pager.view.bounds.maxY - pager.view.safeAreaInsets.bottom - 17,
                accuracy: 0.01
            )
            pager.setSelectedIndex(1, animated: false)
            pager.view.layoutIfNeeded()
            let plain = pager.records[1]!.controller.view!
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            pager.setSelectedIndex(0, animated: false)
        }
    }

    func testShortAndEmptyContentCanFullyCollapse() {
        let pager = mount(height: 0)
        let binding = pager.records[0]!.binding!
        XCTAssertGreaterThanOrEqual(binding.maximumPosition, 200)
        binding.scrollView.contentOffset.y = 200 - binding.scrollView.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
    }

    func testSwitchPreservesSharedHeaderAndPagePosition() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 650 - scroll.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(pager.records[1]!.binding!.position, 200, accuracy: 0.01)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(pager.records[0]!.binding!.position, 650, accuracy: 0.01)
    }

    func testPartiallyExpandedHeaderAlignsDestination() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 95 - scroll.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(pager.records[1]!.binding!.position, 95, accuracy: 0.01)
        XCTAssertEqual(pager.collapseOffset, 95)
    }

    func testInactiveScrollCannotDriveHeader() {
        let pager = mount()
        let old = pager.currentScrollView!
        pager.setSelectedIndex(1, animated: false)
        old.contentOffset.y = 700
        XCTAssertEqual(pager.collapseOffset, 0)
    }

    func testPlainPageKeepsHeader() {
        let pager = mount(plain: [1])
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 90 - scroll.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        XCTAssertNil(pager.currentScrollView)
        XCTAssertEqual(pager.collapseOffset, 90)
    }

    func testPlainPageDragGeometryAndSharedPosition() throws {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        let plain = try XCTUnwrap(pager.records[1]?.controller.view)
        let pan = FixturePan()
        for minimum: CGFloat in [0, 40] {
            pager.layout = SPPageLayout(headerHeight: 240 + pager.view.safeAreaInsets.top, minimumHeaderHeight: minimum)
            pan.send(to: pager, state: .began)
            pan.send(to: pager, state: .changed, y: 1000)
            pan.send(to: pager, state: .cancelled)
            XCTAssertEqual(pager.collapseOffset, 0)
            pan.send(to: pager, state: .began)
            pan.send(to: pager, state: .changed, y: -90)
            XCTAssertEqual(pager.collapseOffset, 90)
            XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top + 150, accuracy: 0.01)
            pan.send(to: pager, state: .changed, y: -1000)
            XCTAssertEqual(pager.collapseOffset, 240 - minimum)
            XCTAssertEqual(pager.tabBar.frame.minY, pager.view.safeAreaInsets.top + minimum, accuracy: 0.01)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            pan.send(to: pager, state: .cancelled)
            pager.setSelectedIndex(0, animated: false)
            let scroll = try XCTUnwrap(pager.currentScrollView)
            XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 240 - minimum, accuracy: 0.01)
            pager.setSelectedIndex(1, animated: false)
            pan.send(to: pager, state: .began)
            pan.send(to: pager, state: .changed, y: 1000)
            XCTAssertEqual(pager.collapseOffset, 0)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            pan.send(to: pager, state: .cancelled)
        }
        XCTAssertNil(pager.currentScrollView)
    }

    func testNumericalOffsetWritebackDoesNotInterruptHeaderDrag() throws {
        let pager = mount()
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -45)
        // UITableView 的后续布局可能回写相同偏移，或产生浮点运算尾差。
        scroll.contentOffset = scroll.contentOffset
        scroll.contentOffset.y += 0.0000000001
        pan.send(to: pager, state: .changed, y: -150)
        XCTAssertEqual(pager.collapseOffset, 150, accuracy: 0.001)
        pan.send(to: pager, state: .changed, y: -260)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.001)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 260, accuracy: 0.001)
        // 真实的外部滚动仍接管位置，旧 Header 触摸不能覆盖它。
        scroll.contentOffset.y += 10
        pan.send(to: pager, state: .changed, y: -300)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 270, accuracy: 0.001)
    }

    func testPlainPageOldDragCannotAffectSelectedPageOrNewBinding() throws {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -80)
        pager.setSelectedIndex(0, animated: false)
        pan.send(to: pager, state: .changed, y: -190)
        XCTAssertEqual(pager.collapseOffset, 80)
        pager.setSelectedIndex(1, animated: false)
        pan.send(to: pager, state: .changed, y: -190)
        XCTAssertEqual(pager.collapseOffset, 80)
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: 30)
        XCTAssertEqual(pager.collapseOffset, 50)
        let plain = try XCTUnwrap(pager.records[1]?.controller.view)
        let scroll = UIScrollView(frame: plain.bounds)
        scroll.contentSize = CGSize(width: 1, height: 1600)
        plain.addSubview(scroll)
        pager.rediscoverScrollView(forPageAt: 1)
        let position = scroll.contentOffset.y + scroll.adjustedContentInset.top
        pan.send(to: pager, state: .changed, y: -190)
        XCTAssertEqual(pager.collapseOffset, 50)
        XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, position, accuracy: 0.01)
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -40)
        XCTAssertEqual(pager.collapseOffset, 90)
        pan.send(to: pager, state: .cancelled)
    }

    func testPlainPageLayoutChangeCancelsDragAndClampsHeader() {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -180)
        pager.layout = SPPageLayout(headerHeight: 100 + pager.view.safeAreaInsets.top, minimumHeaderHeight: 20)
        XCTAssertEqual(pager.collapseOffset, 80)
        pan.send(to: pager, state: .changed, y: 180)
        XCTAssertEqual(pager.collapseOffset, 80)
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: 40)
        XCTAssertEqual(pager.collapseOffset, 40)
        pan.send(to: pager, state: .cancelled)
        pager.headerView = nil
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertFalse(pager.gestureRecognizerShouldBegin(pan))
        source?.ids = []
        pager.reloadData()
        XCTAssertFalse(pager.gestureRecognizerShouldBegin(pan))
    }

    func testPlainPageGestureAdmissionUsesVerticalDirection() {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        let pan = FixturePan()
        pan.testVelocity = CGPoint(x: 10, y: -100)
        XCTAssertTrue(pager.gestureRecognizerShouldBegin(pan))
        pan.testVelocity = CGPoint(x: 100, y: 10)
        XCTAssertFalse(pager.gestureRecognizerShouldBegin(pan))
    }

    func testReloadReorderReusesControllerAndSelection() {
        let pager = mount()
        pager.setSelectedIndex(1, animated: false)
        let controller = pager.records[1]!.controller
        source!.ids = [3, 2, 0, 1]
        pager.reloadData()
        XCTAssertEqual(pager.selectedIndex, 3)
        XCTAssertTrue(pager.records[1]!.controller === controller)
    }

    func testDeletionZeroPagesAndInvalidSelection() {
        let pager = mount()
        pager.setSelectedIndex(3, animated: false)
        source!.ids = [0, 1]
        pager.reloadData()
        XCTAssertEqual(pager.selectedIndex, 1)
        pager.setSelectedIndex(99, animated: false)
        XCTAssertEqual(pager.selectedIndex, 1)
        source!.ids = []; pager.reloadData()
        XCTAssertNil(pager.selectedIndex)
        XCTAssertTrue(pager.children.isEmpty)
        XCTAssertTrue(pager.records.isEmpty)
    }

    func testDuplicateIdentifiersRejectEntireSnapshot() {
        let pager = mount()
        source!.ids = [7, 7]
        pager.reloadData()
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertEqual(pager.tabBar.items.count, 4)
        XCTAssertNotNil(pager.records[0])
    }

    func testCacheEvictionReleasesControllerAndRestoresPosition() {
        weak var old: UIViewController?
        var scroll: UIScrollView!
        autoreleasepool {
            let pager = mount()
            pager.maximumCachedPageCount = 1
            old = pager.records[0]!.controller
            scroll = pager.currentScrollView!
            scroll.contentOffset.y = 500 - scroll.adjustedContentInset.top
            pager.setSelectedIndex(1, animated: false)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(old)
        XCTAssertEqual(pager!.records.count, 1)
        XCTAssertEqual(scroll.contentInset.top, 0)
        pager!.setSelectedIndex(0, animated: false)
        XCTAssertEqual(pager!.records[0]!.binding!.position, 500, accuracy: 0.01)
    }

    func testHeaderReplacementContainment() {
        let pager = mount()
        let header = FixturePage(height: 0)
        pager.headerViewController = header
        XCTAssertNil(pager.headerView)
        XCTAssertTrue(header.parent === pager)
        XCTAssertEqual(header.appearCount, 1)
        pager.headerView = UIView()
        XCTAssertNil(pager.headerViewController)
        XCTAssertNil(header.parent)
        XCTAssertEqual(header.disappearCount, 1)
    }

    func testHeaderHeightChangesPreserveContentAndClampCollapse() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 500 - scroll.adjustedContentInset.top
        pager.layout = SPPageLayout(headerHeight: 180 + pager.view.safeAreaInsets.top, minimumHeaderHeight: 40)
        XCTAssertEqual(pager.collapseOffset, 140)
        XCTAssertEqual(pager.records[0]!.binding!.position, 440, accuracy: 0.01)
    }

    func testRediscoveryRestoresOldScrollAndBindsReplacement() {
        let pager = mount()
        let controller = pager.records[0]!.controller as! FixturePage
        let old = controller.scroll!
        old.removeFromSuperview()
        let replacement = UIScrollView(frame: controller.view.bounds)
        replacement.contentSize.height = 1500
        controller.view.addSubview(replacement)
        pager.rediscoverScrollView(forPageAt: 0)
        XCTAssertTrue(pager.currentScrollView === replacement)
        XCTAssertEqual(old.contentInset.top, 0)
        XCTAssertEqual(replacement.contentInset.top, 0)
    }

    func testExplicitScrollSelectionRejectsForeignView() {
        let pager = mount()
        let original = pager.currentScrollView
        pager.setScrollView(UIScrollView(), forPageAt: 0)
        XCTAssertTrue(pager.currentScrollView === original)
        let second = UIScrollView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        pager.records[0]!.controller.view.addSubview(second)
        pager.setScrollView(second, forPageAt: 0)
        XCTAssertTrue(pager.currentScrollView === second)
        pager.setScrollView(nil, forPageAt: 0)
        XCTAssertTrue(pager.currentScrollView === original)
    }

    func testLifecycleAndSelectionCallbackOnlyOnCommit() {
        let pager = mount()
        let delegate = PageDelegate(); pager.delegate = delegate
        let first = pager.records[0]!.controller as! FixturePage
        pager.setSelectedIndex(1, animated: false)
        let second = pager.records[1]!.controller as! FixturePage
        XCTAssertEqual(first.appearCount, 1)
        XCTAssertEqual(first.disappearCount, 1)
        XCTAssertEqual(second.appearCount, 1)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(delegate.selected, [1])
    }

    func testOverlappingSystemSizeTransitionsPreservePositionAndResumeScrolling() {
        let pager = mount()
        let binding = pager.records[0]!.binding!
        binding.scrollView.contentOffset.y = 650 - binding.scrollView.adjustedContentInset.top
        let first = SizeTransitionCoordinator()
        let second = SizeTransitionCoordinator()
        pager.viewWillTransition(to: CGSize(width: 535, height: 750), with: first)
        pager.view.frame.size = CGSize(width: 535, height: 750)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        binding.setPosition(628); binding.onScroll?(binding)
        pager.viewWillTransition(to: CGSize(width: 690, height: 866), with: second)
        pager.view.frame.size = CGSize(width: 690, height: 866)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        first.finish()
        binding.setPosition(618.5); binding.onScroll?(binding)
        second.finish()
        XCTAssertEqual(binding.position, 650, accuracy: 0.5)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.5)
        binding.scrollView.contentOffset.y = 700 - binding.scrollView.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(binding.position, 700, accuracy: 0.5)
    }

    func testPendingSafeAreaLayoutDoesNotOverwriteSavedContentDistance() {
        let pager = mount()
        let binding = pager.records[0]!.binding!
        binding.scrollView.contentOffset.y = 650 - binding.scrollView.adjustedContentInset.top
        pager.additionalSafeAreaInsets.top = 22
        // 重现 UIKit 在新 Safe Area 已生效、绑定尚未应用新折叠范围时发送的观察回调。
        binding.onScroll?(binding)
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.collapseOffset, 178, accuracy: 0.5)
        XCTAssertEqual(binding.position, 628, accuracy: 0.5)
        pager.setSelectedIndex(1, animated: false)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(binding.position, 628, accuracy: 0.5)
    }

    func testPendingViewportLayoutDoesNotRecordUIKitTemporaryOffset() {
        let pager = mount()
        let binding = pager.records[0]!.binding!
        binding.scrollView.contentOffset.y = 650 - binding.scrollView.adjustedContentInset.top
        pager.view.frame.size = CGSize(width: 535, height: 750)
        binding.setPosition(628)
        binding.onScroll?(binding)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        XCTAssertEqual(binding.position, 650, accuracy: 0.5)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.5)
    }

    func testSelfSizingTablePreservesContentDistanceAcrossViewportChanges() {
        let pager = mount()
        let root = pager.records[0]!.controller.view!
        pager.currentScrollView!.removeFromSuperview()
        let table = UITableView(frame: root.bounds)
        let data = SelfSizingTableSource()
        table.dataSource = data
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 84
        table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addSubview(table)
        table.reloadData(); table.layoutIfNeeded()
        pager.rediscoverScrollView(forPageAt: 0)
        table.contentOffset.y = 650 - table.adjustedContentInset.top
        table.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let initialPosition = pager.records[0]!.binding!.position
        XCTAssertGreaterThan(initialPosition, 400)
        print("SELF SIZING INITIAL POSITION", initialPosition)
        for size in [
            CGSize(width: 375, height: 630),
            CGSize(width: 690, height: 866),
            CGSize(width: 535, height: 750),
            CGSize(width: 834, height: 1210)
        ] {
            pager.view.frame.size = size
            pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertEqual(pager.records[0]!.binding!.position, initialPosition, accuracy: 0.5)
            XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.5)
            XCTAssertEqual(
                table.convert(.zero, to: pager.view).y - pager.tabBar.frame.maxY,
                -(initialPosition - 200),
                accuracy: 0.5
            )
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(pager.records[0]!.binding!.position, initialPosition, accuracy: 0.5)
        }
    }

    // 真实 UIWindow 内的尺寸矩阵；系统分屏与窗口手柄另由 UI 测试验证。
    func testContinuousResizePreservesHeaderAndSavedPositions() {
        let pager = mount(height: 4000)
        let sizes = [
            CGSize(width: 1194, height: 834),
            CGSize(width: 592, height: 834),
            CGSize(width: 375, height: 700),
            CGSize(width: 640, height: 480),
            CGSize(width: 834, height: 1194)
        ]
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.setSelectedIndex(1, animated: false)
            for position: CGFloat in [0, 100, 650] {
                let scroll = pager.currentScrollView!
                scroll.contentOffset.y = position - scroll.adjustedContentInset.top
                for size in sizes {
                    pager.view.frame.size = size
                    pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
                    let binding = pager.records[1]!.binding!
                    XCTAssertEqual(binding.position, position, accuracy: 0.5)
                    XCTAssertEqual(pager.collapseOffset, min(position, 200), accuracy: 0.5)
                    XCTAssertEqual(
                        pager.tabBar.frame.minY,
                        pager.layout.headerHeight - min(position, 200),
                        accuracy: 0.5
                    )
                    let width = pager.pagingView.bounds.width
                    XCTAssertEqual(pager.pagingView.contentOffset.x, (rtl ? 2 : 1) * width, accuracy: 0.5)
                    XCTAssertEqual(
                        scroll.convert(.zero, to: pager.view).y - pager.tabBar.frame.maxY,
                        -max(0, position - 200),
                        accuracy: 0.5
                    )
                    pager.setSelectedIndex(2, animated: false)
                    pager.setSelectedIndex(1, animated: false)
                    XCTAssertEqual(binding.position, position, accuracy: 0.5)
                }
            }
        }
    }

    func testGrowingViewportClampsBottomAndKeepsHeaderPinned() {
        let pager = mount(height: 1800)
        pager.view.frame.size = CGSize(width: 500, height: 500)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        let scroll = pager.currentScrollView!
        let binding = pager.records[0]!.binding!
        scroll.contentOffset.y = binding.maximumPosition - scroll.adjustedContentInset.top
        pager.view.frame.size = CGSize(width: 834, height: 1194)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        XCTAssertLessThanOrEqual(binding.position, binding.maximumPosition + 0.5)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.5)
        let position = binding.position
        pager.setSelectedIndex(1, animated: false)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(binding.position, position, accuracy: 0.5)
        XCTAssertLessThanOrEqual(binding.position, binding.maximumPosition + 0.5)
    }

    func testTabBarBackgroundAndHitRegionsRespectSafeArea() throws {
        let pager = mount()
        for rtl in [false, true] {
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            for insets in [
                UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 60),
                UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 24),
                .zero
            ] {
                pager.additionalSafeAreaInsets = insets
                pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
                let bar = pager.tabBar
                bar.setNeedsLayout(); bar.layoutIfNeeded()
                let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
                XCTAssertEqual(bar.frame.minX, 0, accuracy: 0.01)
                XCTAssertEqual(bar.frame.width, pager.view.bounds.width, accuracy: 0.01)
                XCTAssertEqual(collection.frame.minX, pager.view.safeAreaInsets.left, accuracy: 0.01)
                XCTAssertEqual(
                    collection.frame.maxX,
                    pager.view.bounds.width - pager.view.safeAreaInsets.right,
                    accuracy: 0.01
                )
                if insets.left > 0 {
                    XCTAssertNil(bar.hitTest(CGPoint(x: 1, y: bar.bounds.midY), with: nil))
                    XCTAssertNil(bar.hitTest(CGPoint(x: bar.bounds.maxX - 1, y: bar.bounds.midY), with: nil))
                }
                for index in [0, 3] {
                    bar.setSelectedIndex(index, animated: false)
                    collection.layoutIfNeeded()
                    let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
                    let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
                    let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: bar)
                    XCTAssertTrue(bar.hitTest(center, with: nil) === button)
                }
            }
        }
    }

    func testTabBarDynamicTypePreservesReadableTitlesAndPageBoundary() throws {
        let pager = mount(inNavigation: true)
        let navigation = try XCTUnwrap(pager.navigationController)
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
            navigation.setOverrideTraitCollection(
                UITraitCollection(preferredContentSizeCategory: category),
                forChild: pager
            )
            pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
            let bar = pager.tabBar
            bar.layoutIfNeeded()
            let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
            let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
            let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
            button.layoutIfNeeded()
            let label = try XCTUnwrap(button.titleLabel)
            XCTAssertGreaterThanOrEqual(label.frame.height + 1, label.font.lineHeight)
            XCTAssertGreaterThanOrEqual(label.frame.minY, 7)
            XCTAssertLessThanOrEqual(label.frame.maxY, bar.bounds.height - 10)
            XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
            XCTAssertEqual(bar.frame.height, category == .large ? 44 : bar.sizeThatFits(.zero).height, accuracy: 0.01)
            let scroll = try XCTUnwrap(pager.currentScrollView)
            XCTAssertEqual(scroll.convert(.zero, to: pager.view).y, bar.frame.maxY, accuracy: 0.5)
            XCTAssertEqual(pager.selectedIndex, 0)
        }
        pager.layout.tabBarHeight = 0
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.tabBar.bounds.height, 0)
    }

    func testResizeAndSafeAreaKeepsSelectionAndFrame() {
        let pager = mount()
        pager.setSelectedIndex(1, animated: false)
        pager.additionalSafeAreaInsets = UIEdgeInsets(top: 20, left: 14, bottom: 10, right: 24)
        pager.view.frame.size = CGSize(width: 700, height: 500)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.selectedIndex, 1)
        XCTAssertEqual(pager.pagingView.bounds.width, pager.view.bounds.width, accuracy: 0.01)
        XCTAssertEqual(pager.pagingView.contentOffset.x, pager.pagingView.bounds.width, accuracy: 0.01)
    }

    func testRTLPhysicalOrderKeepsLogicalIndex() {
        let pager = mount()
        pager.view.semanticContentAttribute = .forceRightToLeft
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(pager.selectedIndex, 1)
        XCTAssertEqual(pager.pagingView.contentOffset.x, pager.pagingView.bounds.width * 2, accuracy: 0.01)
    }

    func testInterruptedAdjacentAnimationAndImmediateSelectionsCommitOnceEach() {
        let pager = mount()
        let delegate = PageDelegate(); pager.delegate = delegate
        pager.setSelectedIndex(1, animated: true)
        pager.setSelectedIndex(2, animated: true)
        XCTAssertEqual(pager.selectedIndex, 2)
        XCTAssertEqual(delegate.selected, [2])
        pager.setSelectedIndex(3, animated: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(pager.selectedIndex, 3)
        XCTAssertEqual(delegate.selected, [2, 3])
        XCTAssertEqual(pager.pagingView.contentOffset.x, pager.pagingView.bounds.width * 3, accuracy: 0.01)
    }

    func testNonAdjacentSelectionSkipsIntermediatePagesAndCommitsOnce() {
        for rtl in [false, true] {
            let pager = mount(ids: Array(0 ..< 10))
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
            pager.maximumCachedPageCount = 2
            let delegate = PageDelegate(); pager.delegate = delegate
            let first = pager.records[0]!.controller as! FixturePage
            pager.currentScrollView!.contentOffset.y = 120 - pager.currentScrollView!.adjustedContentInset.top
            pager.setSelectedIndex(9, animated: true)
            XCTAssertEqual(pager.selectedIndex, 9)
            XCTAssertEqual(source!.createdIDs, [0, 9])
            XCTAssertEqual(delegate.progressEvents, 0)
            XCTAssertEqual(delegate.selected, [9])
            XCTAssertEqual(
                pager.pagingView.contentOffset.x,
                rtl ? 0 : pager.pagingView.bounds.width * 9,
                accuracy: 0.01
            )
            XCTAssertEqual(pager.collapseOffset, 120, accuracy: 0.01)
            XCTAssertEqual(first.disappearCount, 1)
            XCTAssertEqual((pager.records[9]!.controller as! FixturePage).appearCount, 1)
            XCTAssertLessThanOrEqual(pager.records.count, 2)
            pager.scrollViewDidEndScrollingAnimation(pager.pagingView)
            XCTAssertEqual(delegate.selected, [9])
            pager.setSelectedIndex(0, animated: true)
            XCTAssertEqual(pager.selectedIndex, 0)
            XCTAssertEqual(delegate.selected, [9, 0])
            XCTAssertEqual(source!.createdIDs, [0, 9])
        }
    }

    func testSelectionAnimationFlagIsForwardedToCustomTabBar() {
        let pager = mount()
        let tabs = RecordingTabBar()
        pager.tabBar = tabs
        pager.view.layoutIfNeeded()
        pager.setSelectedIndex(3, animated: false)
        XCTAssertEqual(tabs.lastAnimated, false)
        XCTAssertEqual(pager.selectedIndex, 3)
        pager.setSelectedIndex(0, animated: true)
        XCTAssertEqual(tabs.lastAnimated, true)
        XCTAssertEqual(pager.selectedIndex, 0)
    }

    func testResizeCancelsPendingTransitionWithoutSelectionEvent() {
        let pager = mount()
        let delegate = PageDelegate(); pager.delegate = delegate
        pager.setSelectedIndex(1, animated: true)
        pager.view.frame.size.width = 600
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertTrue(delegate.selected.isEmpty)
        XCTAssertEqual(pager.pagingView.contentOffset.x, 0, accuracy: 0.01)
    }

    func testPlainPageStartsAtVisibleTabBarTop() {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        let child = pager.records[1]!.controller.view!
        XCTAssertEqual(child.convert(child.bounds, to: pager.view).minY, pager.tabBar.frame.minY, accuracy: 0.01)
    }

    func testHeaderReplacedDuringParentAppearanceBalancesCallbacks() {
        let pager = mount()
        pager.beginAppearanceTransition(false, animated: false); pager.endAppearanceTransition()
        let old = FixturePage(height: 0)
        pager.headerViewController = old
        pager.beginAppearanceTransition(true, animated: false)
        let replacement = FixturePage(height: 0)
        pager.headerViewController = replacement
        pager.endAppearanceTransition()
        XCTAssertEqual(old.appearCount, 1)
        XCTAssertEqual(old.disappearCount, 1)
        XCTAssertEqual(replacement.appearCount, 1)
        XCTAssertNil(old.parent)
    }

    func testSelectionDuringParentAppearanceForwardsToNewPage() {
        let pager = mount()
        pager.beginAppearanceTransition(false, animated: false); pager.endAppearanceTransition()
        let old = pager.records[0]!.controller as! FixturePage
        pager.beginAppearanceTransition(true, animated: false)
        pager.setSelectedIndex(1, animated: false)
        let incoming = pager.records[1]!.controller as! FixturePage
        pager.endAppearanceTransition()
        XCTAssertEqual(old.appearCount, 2)
        XCTAssertEqual(old.disappearCount, 2)
        XCTAssertEqual(incoming.appearCount, 1)
        XCTAssertEqual(pager.selectedIndex, 1)
    }

    func testRefreshAllowsScrollAndHeaderDragWithoutEndingBusinessRefresh() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        let refresh = UIRefreshControl()
        scroll.refreshControl = refresh
        refresh.beginRefreshing()
        scroll.contentOffset.y = 300 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
        XCTAssertEqual(pager.records[0]!.binding!.position, 300, accuracy: 0.01)
        XCTAssertTrue(scroll.refreshControl === refresh)
        XCTAssertTrue(refresh.isRefreshing)
        let pan = FixturePan()
        XCTAssertTrue(pager.gestureRecognizerShouldBegin(pan))
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: 220)
        XCTAssertEqual(pager.collapseOffset, 80, accuracy: 0.01)
        pan.testVelocity.y = -1000
        pan.send(to: pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertGreaterThan(pager.records[0]!.binding!.position, 80)
        XCTAssertTrue(refresh.isRefreshing)
        // 业务结束刷新后仍正常跟随内容位置。
        refresh.endRefreshing()
        scroll.contentOffset.y = 120 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 120, accuracy: 0.01)
    }

    func testNativeOverscrollIsPreservedWithoutFrameworkDrag() {
        for refreshing in [false, true] {
            let pager = mount()
            let scroll = pager.currentScrollView!
            let binding = pager.records[0]!.binding!
            let refresh = UIRefreshControl()
            scroll.refreshControl = refresh
            if refreshing {
                refresh.beginRefreshing()
            }
            // 列表自身的负向位移不受 Header 手势边界钳制影响。
            scroll.contentOffset.y = -45 - scroll.adjustedContentInset.top
            pager.view.setNeedsLayout()
            pager.view.layoutIfNeeded()
            XCTAssertEqual(binding.position, -45, accuracy: 0.01)
            XCTAssertEqual(pager.collapseOffset, 0, accuracy: 0.01)
            XCTAssertEqual(refresh.isRefreshing, refreshing)
            XCTAssertTrue(scroll.refreshControl === refresh)
            refresh.endRefreshing()
        }
    }

    func testContainerReleaseRestoresOwnedInsets() {
        weak var weakPager: SPPageViewController?
        var scroll: UIScrollView!
        var child: UIViewController!
        autoreleasepool {
            let container = mount()
            scroll = container.currentScrollView!
            child = container.records[0]!.controller
            child.additionalSafeAreaInsets = UIEdgeInsets(top: 6, left: 3, bottom: 8, right: 2)
            weakPager = container
            window?.closeForTesting()
            window?.rootViewController = nil
            self.pager = nil
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(weakPager)
        XCTAssertEqual(scroll.contentInset.top, 0)
        XCTAssertEqual(child.additionalSafeAreaInsets, UIEdgeInsets(top: 6, left: 3, bottom: 8, right: 2))
    }

    func testInactivePositionSurvivesHeaderResizeAndEviction() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        scroll.contentOffset.y = 500 - scroll.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        pager.layout.headerHeight -= 60
        pager.maximumCachedPageCount = 1
        XCTAssertNil(pager.records[0])
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(pager.records[0]!.binding!.position, 440, accuracy: 0.01)
        XCTAssertEqual(
            pager.currentScrollView!.convert(.zero, to: pager.view).y,
            pager.tabBar.frame.maxY - 300,
            accuracy: 0.01
        )
    }

    func testInactiveRefreshingPageCannotExpandSharedHeaderDuringLayout() {
        let pager = mount()
        let first = pager.currentScrollView!
        first.refreshControl = UIRefreshControl()
        first.refreshControl!.beginRefreshing()
        pager.setSelectedIndex(1, animated: false)
        let current = pager.currentScrollView!
        current.contentOffset.y = 350 - current.adjustedContentInset.top
        pager.additionalSafeAreaInsets.top = 20
        pager.view.layoutIfNeeded()
        XCTAssertEqual(pager.collapseOffset, 180, accuracy: 0.01)
        XCTAssertEqual(pager.records[1]!.binding!.position, 330, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.pagingView.frame.minY, accuracy: 0.01)
    }

    func testInactiveHistorySurvivesTemporaryAlignmentAndRebinding() {
        let pager = mount()
        pager.currentScrollView!.contentOffset.y = 500 - pager.currentScrollView!.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: false)
        let current = pager.currentScrollView!
        current.contentOffset.y = -current.adjustedContentInset.top
        pager.layout.headerHeight -= 60
        XCTAssertEqual(pager.records[0]!.binding!.position, 0, accuracy: 0.01)
        let old = pager.records[0]!.binding!.scrollView
        old.removeFromSuperview()
        let root = pager.records[0]!.controller.view!
        let replacement = UIScrollView(frame: root.bounds)
        replacement.contentSize.height = 1800
        root.addSubview(replacement)
        pager.rediscoverScrollView(forPageAt: 0)
        XCTAssertEqual(old.contentInset.top, 0)
        XCTAssertEqual(pager.records[0]!.binding!.position, 0, accuracy: 0.01)
        // 展开时的临时对齐不应抹掉旧页 300 pt 的业务内容位置。
        current.contentOffset.y = 140 - current.adjustedContentInset.top
        pager.setSelectedIndex(0, animated: false)
        XCTAssertTrue(pager.currentScrollView === replacement)
        XCTAssertEqual(pager.records[0]!.binding!.position, 440, accuracy: 0.01)
        XCTAssertEqual(
            replacement.convert(.zero, to: pager.view).y,
            pager.tabBar.frame.maxY - 300,
            accuracy: 0.01
        )
    }

    func testCancelledPagingToRefreshingPagePreservesCurrentHeader() {
        let pager = mount()
        pager.setSelectedIndex(1, animated: false)
        let refresh = UIRefreshControl()
        pager.currentScrollView!.refreshControl = refresh
        refresh.beginRefreshing()
        pager.setSelectedIndex(0, animated: false)
        pager.currentScrollView!.contentOffset.y = 350 - pager.currentScrollView!.adjustedContentInset.top
        pager.setSelectedIndex(1, animated: true)
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(pager.selectedIndex, 0)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
        XCTAssertEqual(pager.records[0]!.binding!.position, 350, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.frame.minY, pager.pagingView.frame.minY, accuracy: 0.01)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.01)
        XCTAssertEqual(pager.records[1]!.binding!.position, 200, accuracy: 0.01)
        XCTAssertTrue(pager.currentScrollView!.refreshControl === refresh)
        XCTAssertTrue(refresh.isRefreshing)
    }

    func testOnlyOwningPanCanContinueOrEndHeaderDrag() {
        let pager = mount(plain: [0])
        let first = FixturePan(), second = FixturePan()
        first.send(to: pager, state: .began)
        first.send(to: pager, state: .changed, y: -60)
        second.send(to: pager, state: .began)
        second.send(to: pager, state: .changed, y: -100)
        second.send(to: pager, state: .cancelled)
        XCTAssertEqual(pager.collapseOffset, 60)
        first.send(to: pager, state: .changed, y: -90)
        XCTAssertEqual(pager.collapseOffset, 90)
        first.send(to: pager, state: .cancelled)
        second.send(to: pager, state: .began)
        second.send(to: pager, state: .changed, y: 40)
        XCTAssertEqual(pager.collapseOffset, 50)
        second.send(to: pager, state: .cancelled)
    }

    func testReplacingTabBarInvalidatesOldDragAndAllowsNewDrag() {
        let pager = mount(plain: [0])
        let pan = FixturePan()
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: -60)
        pager.tabBar = SPTabBar()
        pager.view.layoutIfNeeded()
        pan.send(to: pager, state: .changed, y: -140)
        XCTAssertEqual(pager.collapseOffset, 60)
        pan.send(to: pager, state: .began)
        pan.send(to: pager, state: .changed, y: 20)
        XCTAssertEqual(pager.collapseOffset, 40)
        pan.send(to: pager, state: .cancelled)
    }

    func testEvictionDuringParentDisappearanceFinishesBeforeDetaching() {
        let pager = mount()
        pager.maximumCachedPageCount = 1
        let old = pager.records[0]!.controller as! FixturePage
        var parentsAtDisappearance: [UIViewController?] = []
        old.onDisappear = { [weak old] in parentsAtDisappearance.append(old?.parent) }
        pager.beginAppearanceTransition(false, animated: true)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertNil(old.parent)
        XCTAssertEqual(old.disappearCount, 1)
        XCTAssertEqual(parentsAtDisappearance.count, 1)
        XCTAssertTrue(parentsAtDisappearance.contains { $0 === pager })
        pager.endAppearanceTransition()
        XCTAssertEqual(old.disappearCount, 1)
        let incoming = pager.records[1]!.controller as! FixturePage
        XCTAssertEqual(incoming.appearCount, 0)
        pager.beginAppearanceTransition(true, animated: false)
        pager.endAppearanceTransition()
        XCTAssertEqual(incoming.appearCount, 1)
        XCTAssertTrue(incoming.view.window === window)
    }
}

@MainActor
private final class FixtureSource: SPPageViewControllerDataSource {
    var mixedLayout: Bool?
    var rootScroll = false
    var ids: [Int]
    var createdIDs: [Int] = []
    let plain: Set<Int>
    let contentHeight: CGFloat
    init(ids: [Int], plain: Set<Int>, contentHeight: CGFloat) {
        self.ids = ids; self.plain = plain; self.contentHeight = contentHeight
    }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        ids.count
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        identifierForPageAt index: Int
    ) -> AnyHashable {
        ids[index]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        createdIDs.append(ids[index])
        if let mixedLayout {
            return MixedFixturePage(height: contentHeight, belowLabel: mixedLayout)
        }
        let page = FixturePage(height: contentHeight, plain: plain.contains(ids[index]))
        if rootScroll {
            let scroll = UIScrollView()
            scroll.contentSize = CGSize(width: 1, height: contentHeight)
            page.view = scroll
            page.scroll = scroll
        }
        return page
    }
}

@MainActor
private final class MixedFixturePage: UIViewController {
    let label = UILabel()
    let scroll = UIScrollView()
    let height: CGFloat
    let belowLabel: Bool
    init(height: CGFloat, belowLabel: Bool) {
        self.height = height; self.belowLabel = belowLabel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = "标签栏下方的固定说明"
        label.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.contentSize = CGSize(width: 1, height: height)
        view.addSubview(scroll)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            label.heightAnchor.constraint(equalToConstant: 28),
            scroll.topAnchor.constraint(
                equalTo: belowLabel ? label.bottomAnchor : view.topAnchor,
                constant: belowLabel ? 8 : 0
            ),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

@MainActor
private final class FixturePage: UIViewController {
    let height: CGFloat
    let plain: Bool
    var scroll: UIScrollView?
    var appearCount = 0, disappearCount = 0
    var onDisappear: (() -> Void)?
    init(height: CGFloat, plain: Bool = false) {
        self.height = height; self.plain = plain; super.init(
            nibName: nil,
            bundle: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if !plain {
            let scroll = UIScrollView(frame: view.bounds)
            scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scroll.contentSize = CGSize(width: 1, height: height)
            view.addSubview(scroll); self.scroll = scroll
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); appearCount += 1
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); disappearCount += 1; onDisappear?()
    }
}

@MainActor private final class ScrollDelegate: NSObject, UIScrollViewDelegate {}
@MainActor private final class OffsetCallbackScrollView: UIScrollView {
    var onSetContentOffset: (() -> Void)?
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(contentOffset, animated: animated)
        onSetContentOffset?()
    }
}

@MainActor private final class IndicatorWriteTrackingScrollView: UIScrollView {
    var indicatorWrites = 0
    var visibilityWrites = 0
    var onVisibilityChange: (() -> Void)?
    override dynamic var showsVerticalScrollIndicator: Bool {
        didSet { indicatorWrites += 1; visibilityWrites += 1; onVisibilityChange?() }
    }

    override dynamic var showsHorizontalScrollIndicator: Bool {
        didSet { indicatorWrites += 1; visibilityWrites += 1; onVisibilityChange?() }
    }

    override var verticalScrollIndicatorInsets: UIEdgeInsets {
        didSet { indicatorWrites += 1 }
    }
}

@MainActor private final class FixturePan: UIPanGestureRecognizer {
    private var testState: UIGestureRecognizer.State = .possible
    private var testTranslation: CGPoint = .zero
    var testVelocity = CGPoint(x: 0, y: -100)
    override var state: UIGestureRecognizer.State {
        get { testState } set { testState = newValue }
    }

    override func translation(in view: UIView?) -> CGPoint {
        testTranslation
    }

    override func velocity(in view: UIView?) -> CGPoint {
        testVelocity
    }

    func send(to pager: SPPageViewController, state: UIGestureRecognizer.State, y: CGFloat = 0) {
        testState = state; testTranslation = CGPoint(x: 0, y: y)
        pager.handleHeaderPan(self)
    }
}

@MainActor private final class PageDelegate: SPPageViewControllerDelegate {
    var selected: [Int] = []
    var progressEvents = 0
    func pageViewController(
        _ pageViewController: SPPageViewController,
        didScrollFrom fromIndex: Int,
        to toIndex: Int,
        progress: CGFloat
    ) {
        progressEvents += 1
    }

    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {
        selected.append(index)
    }
}

@MainActor private final class RecordingTabBar: SPTabBar {
    var lastAnimated: Bool?
    override func setSelectedIndex(_ index: Int?, animated: Bool) {
        lastAnimated = animated
        super.setSelectedIndex(index, animated: animated)
    }
}

@MainActor
private final class SelfSizingTableSource: NSObject, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        80
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = "内容 \(indexPath.row + 1)"
        content.secondaryText = "原生 UITableView · 已刷新 0 次"
        cell.contentConfiguration = content
        return cell
    }
}

@MainActor
private final class SizeTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    let isAnimated = true
    let presentationStyle: UIModalPresentationStyle = .none
    let initiallyInteractive = false
    let isInterruptible = false
    let isInteractive = false
    let isCancelled = false
    let transitionDuration: TimeInterval = 0.3
    let percentComplete: CGFloat = 1
    let completionVelocity: CGFloat = 0
    let completionCurve: UIView.AnimationCurve = .easeInOut
    let containerView = UIView()
    let targetTransform = CGAffineTransform.identity
    private var completions: [(any UIViewControllerTransitionCoordinatorContext) -> Void] = []
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? {
        nil
    }

    func view(forKey key: UITransitionContextViewKey) -> UIView? {
        nil
    }

    func animate(
        alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?
    ) -> Bool {
        animation?(self)
        if let completion {
            completions.append(completion)
        }
        return true
    }

    func animateAlongsideTransition(
        in view: UIView?,
        animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?
    ) -> Bool {
        animate(alongsideTransition: animation, completion: completion)
    }

    func notifyWhenInteractionChanges(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext)
        -> Void) {}
    func notifyWhenInteractionEnds(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func finish() {
        let pending = completions
        completions.removeAll()
        pending.forEach { $0(self) }
    }
}
