import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class StickyPagerKitTests: XCTestCase {
    private var window: UIWindow?
    private var source: FixtureSource?
    private var pager: SPPageViewController?

    override func tearDown() async throws {
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil; pager = nil; source = nil
    }

    private func mount(ids: [Int] = [0, 1, 2, 3], plain: Set<Int> = [], height: CGFloat = 1800, inNavigation: Bool = false) -> SPPageViewController {
        let source = FixtureSource(ids: ids, plain: plain, contentHeight: height)
        let pager = SPPageViewController()
        pager.dataSource = source
        pager.headerView = UIView()
        pager.layout = SPPageLayout(headerHeight: 240, minimumHeaderHeight: 40)
        pager.reloadData()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = inNavigation ? UINavigationController(rootViewController: pager) : pager
        window.makeKeyAndVisible()
        pager.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        // 通用交互夹具保留 200 pt 折叠距离；总高度现在包含顶部安全区域。
        pager.layout.headerHeight = 240 + pager.view.safeAreaInsets.top
        self.window = window; self.source = source; self.pager = pager
        return pager
    }

    func testShortContentDoesNotShowIndicatorForSyntheticScrollRange() {
        let pager = mount(height: 216, inNavigation: true)
        let scroll = pager.currentScrollView!
        let binding = pager.records[0]!.binding!
        for height: CGFloat in [216, 0, 216] {
            scroll.contentSize.height = height
            for position: CGFloat in [0, 100, 200] {
                binding.setPosition(position)
                XCTAssertFalse(scroll.showsVerticalScrollIndicator)
                XCTAssertEqual(binding.maximumPosition, 200, accuracy: 0.01)
            }
        }
        scroll.contentSize.height = 1800
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        scroll.bounds.size.height = 2000
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        scroll.bounds.size.height = 500
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
    }

    func testIndicatorTrackFollowsVisibleHeaderAndKeepsBusinessInsets() {
        let pager = mount(inNavigation: true)
        let scroll = pager.currentScrollView!
        let base = UIEdgeInsets(top: 7, left: 3, bottom: 19, right: 5)
        scroll.verticalScrollIndicatorInsets = base
        let horizontal = scroll.horizontalScrollIndicatorInsets
        for position: CGFloat in [-30, 0, 100, 200, 350, 50] {
            scroll.contentOffset.y = position - scroll.adjustedContentInset.top
            let trackTop = scroll.convert(scroll.bounds.origin, to: pager.view).y + scroll.verticalScrollIndicatorInsets.top
            XCTAssertEqual(trackTop, pager.tabBar.frame.maxY + base.top, accuracy: 0.01)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.bottom, base.bottom)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.left, base.left)
            XCTAssertEqual(scroll.verticalScrollIndicatorInsets.right, base.right)
            XCTAssertEqual(scroll.horizontalScrollIndicatorInsets, horizontal)
        }
        pager.setSelectedIndex(1, animated: false)
        let next = pager.currentScrollView!
        XCTAssertEqual(next.verticalScrollIndicatorInsets.top, 150, accuracy: 0.01)
        pager.layout.headerHeight += 40
        XCTAssertEqual(next.verticalScrollIndicatorInsets.top, 190, accuracy: 0.01)
    }

    func testBindingRestoresLatestIndicatorPreferences() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let initial = UIEdgeInsets(top: 11, left: 2, bottom: 17, right: 4)
        scroll.verticalScrollIndicatorInsets = initial
        scroll.automaticallyAdjustsScrollIndicatorInsets = false
        let binding = SPScrollBinding(scrollView: scroll)
        binding.setRange(200)
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        let updated = UIEdgeInsets(top: 9, left: 6, bottom: 23, right: 8)
        scroll.verticalScrollIndicatorInsets = updated
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, updated)
        scroll.showsVerticalScrollIndicator = false
        scroll.contentSize.height = 1800
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        scroll.showsVerticalScrollIndicator = true
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets.top, 209)
        scroll.contentSize.height = 0
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        binding.detach()
        XCTAssertEqual(scroll.verticalScrollIndicatorInsets, updated)
        XCTAssertTrue(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets)
    }

    func testPagingHidesIndicatorsForOutgoingAndNewPagesUntilSettled() {
        let pager = mount()
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
        XCTAssertEqual(pager.tabBar.frame.maxY, pager.pagingView.frame.minY, accuracy: 0.01)
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
                XCTAssertEqual(scroll.contentInset.top, range + 13, accuracy: 0.01)
                let contentTop = scroll.convert(CGPoint.zero, to: pager.view).y
                XCTAssertEqual(contentTop, pager.tabBar.frame.maxY + 13 - max(0, position - range), accuracy: 0.01)
                XCTAssertEqual(pager.pagingView.frame.maxY, pager.view.bounds.maxY, accuracy: 0.01)
                pager.setSelectedIndex(1, animated: false)
                pager.view.layoutIfNeeded()
                let plain = try XCTUnwrap(pager.records[1]?.controller.view)
                XCTAssertEqual(plain.convert(.zero, to: pager.view).y, pager.tabBar.frame.maxY, accuracy: 0.01)
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
            XCTAssertEqual(scroll.convert(CGPoint.zero, to: pager.view).y - pager.tabBar.frame.maxY, before, accuracy: 0.01)
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
            XCTAssertEqual(contentBottom, pager.view.bounds.maxY - pager.view.safeAreaInsets.bottom - 17, accuracy: 0.01)
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
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).minY, pager.tabBar.frame.maxY, accuracy: 0.01)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            pan.send(to: pager, state: .cancelled)
            pager.setSelectedIndex(0, animated: false)
            let scroll = try XCTUnwrap(pager.currentScrollView)
            XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 240 - minimum, accuracy: 0.01)
            pager.setSelectedIndex(1, animated: false)
            pan.send(to: pager, state: .began)
            pan.send(to: pager, state: .changed, y: 1000)
            XCTAssertEqual(pager.collapseOffset, 0)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).minY, pager.tabBar.frame.maxY, accuracy: 0.01)
            XCTAssertEqual(plain.convert(plain.bounds, to: pager.view).maxY, pager.view.bounds.maxY, accuracy: 0.01)
            pan.send(to: pager, state: .cancelled)
        }
        XCTAssertNil(pager.currentScrollView)
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
        XCTAssertEqual(replacement.contentInset.top, 200)
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
        for size in [CGSize(width: 375, height: 630), CGSize(width: 690, height: 866),
                     CGSize(width: 535, height: 750), CGSize(width: 834, height: 1210)] {
            pager.view.frame.size = size
            pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertEqual(pager.records[0]!.binding!.position, initialPosition, accuracy: 0.5)
            XCTAssertEqual(pager.collapseOffset, 200, accuracy: 0.5)
            XCTAssertEqual(table.convert(.zero, to: pager.view).y - pager.tabBar.frame.maxY, -(initialPosition - 200), accuracy: 0.5)
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(pager.records[0]!.binding!.position, initialPosition, accuracy: 0.5)
        }
    }

    // 真实 UIWindow 内的尺寸矩阵；系统分屏与窗口手柄另由 UI 测试验证。
    func testContinuousResizePreservesHeaderAndSavedPositions() {
        let pager = mount(height: 4000)
        let sizes = [CGSize(width: 1194, height: 834), CGSize(width: 592, height: 834),
                     CGSize(width: 375, height: 700), CGSize(width: 640, height: 480),
                     CGSize(width: 834, height: 1194)]
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
                    XCTAssertEqual(pager.tabBar.frame.minY, pager.layout.headerHeight - min(position, 200), accuracy: 0.5)
                    let width = pager.pagingView.bounds.width
                    XCTAssertEqual(pager.pagingView.contentOffset.x, (rtl ? 2 : 1) * width, accuracy: 0.5)
                    XCTAssertEqual(scroll.convert(.zero, to: pager.view).y - pager.tabBar.frame.maxY,
                                   -max(0, position - 200), accuracy: 0.5)
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
            for insets in [UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 60),
                           UIEdgeInsets(top: 0, left: 60, bottom: 0, right: 24), .zero] {
                pager.additionalSafeAreaInsets = insets
                pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
                let bar = pager.tabBar
                bar.setNeedsLayout(); bar.layoutIfNeeded()
                let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
                XCTAssertEqual(bar.frame.minX, 0, accuracy: 0.01)
                XCTAssertEqual(bar.frame.width, pager.view.bounds.width, accuracy: 0.01)
                XCTAssertEqual(collection.frame.minX, pager.view.safeAreaInsets.left, accuracy: 0.01)
                XCTAssertEqual(collection.frame.maxX, pager.view.bounds.width - pager.view.safeAreaInsets.right, accuracy: 0.01)
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
            navigation.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: pager)
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
        XCTAssertEqual(pager.pagingView.bounds.width, pager.view.bounds.width - pager.view.safeAreaInsets.left - pager.view.safeAreaInsets.right, accuracy: 0.01)
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
            let pager = mount(ids: Array(0..<10))
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
            XCTAssertEqual(pager.pagingView.contentOffset.x, rtl ? 0 : pager.pagingView.bounds.width * 9, accuracy: 0.01)
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
    func testPlainPageStartsBelowVisibleTabBar() {
        let pager = mount(plain: [1])
        pager.setSelectedIndex(1, animated: false)
        pager.view.setNeedsLayout(); pager.view.layoutIfNeeded()
        let child = pager.records[1]!.controller.view!
        XCTAssertEqual(child.convert(child.bounds, to: pager.view).minY, pager.tabBar.frame.maxY, accuracy: 0.01)
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
    func testRefreshPinsHeaderAndRetainsBusinessControl() {
        let pager = mount()
        let scroll = pager.currentScrollView!
        let refresh = UIRefreshControl()
        scroll.refreshControl = refresh
        scroll.contentOffset.y = 300 - scroll.adjustedContentInset.top
        refresh.beginRefreshing()
        scroll.contentOffset.y += 1
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertTrue(scroll.refreshControl === refresh)
        refresh.endRefreshing()
        scroll.contentOffset.y = 120 - scroll.adjustedContentInset.top
        XCTAssertEqual(pager.collapseOffset, 120, accuracy: 0.01)
    }
    func testContainerReleaseRestoresOwnedInsets() {
        weak var weakPager: SPPageViewController?
        var scroll: UIScrollView!
        autoreleasepool {
            let container = mount()
            scroll = container.currentScrollView!
            weakPager = container
            window?.isHidden = true
            window?.rootViewController = nil
            self.pager = nil
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(weakPager)
        XCTAssertEqual(scroll.contentInset.top, 0)
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
        XCTAssertEqual(pager.currentScrollView!.convert(.zero, to: pager.view).y,
                       pager.tabBar.frame.maxY - 300, accuracy: 0.01)
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
        XCTAssertEqual(pager.tabBar.frame.maxY, pager.pagingView.frame.minY, accuracy: 0.01)
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
        XCTAssertEqual(replacement.convert(.zero, to: pager.view).y,
                       pager.tabBar.frame.maxY - 300, accuracy: 0.01)
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
        XCTAssertEqual(pager.tabBar.frame.maxY, pager.pagingView.frame.minY, accuracy: 0.01)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertLessThanOrEqual(pager.records[1]!.binding!.position, 0)
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
    var ids: [Int]
    var createdIDs: [Int] = []
    let plain: Set<Int>
    let contentHeight: CGFloat
    init(ids: [Int], plain: Set<Int>, contentHeight: CGFloat) { self.ids = ids; self.plain = plain; self.contentHeight = contentHeight }
    func numberOfPages(in pageViewController: SPPageViewController) -> Int { ids.count }
    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable { ids[index] }
    func pageViewController(_ pageViewController: SPPageViewController, viewControllerAt index: Int) -> UIViewController {
        createdIDs.append(ids[index])
        return FixturePage(height: contentHeight, plain: plain.contains(ids[index]))
    }
}
@MainActor
private final class FixturePage: UIViewController {
    let height: CGFloat
    let plain: Bool
    var scroll: UIScrollView?
    var appearCount = 0, disappearCount = 0
    var onDisappear: (() -> Void)?
    init(height: CGFloat, plain: Bool = false) { self.height = height; self.plain = plain; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        if !plain {
            let scroll = UIScrollView(frame: view.bounds)
            scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scroll.contentSize = CGSize(width: 1, height: height)
            view.addSubview(scroll); self.scroll = scroll
        }
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); appearCount += 1 }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); disappearCount += 1; onDisappear?() }
}
@MainActor private final class ScrollDelegate: NSObject, UIScrollViewDelegate {}
@MainActor private final class IndicatorWriteTrackingScrollView: UIScrollView {
    var indicatorWrites = 0
    override var showsVerticalScrollIndicator: Bool { didSet { indicatorWrites += 1 } }
    override var showsHorizontalScrollIndicator: Bool { didSet { indicatorWrites += 1 } }
    override var verticalScrollIndicatorInsets: UIEdgeInsets { didSet { indicatorWrites += 1 } }
}
@MainActor private final class FixturePan: UIPanGestureRecognizer {
    private var testState: UIGestureRecognizer.State = .possible
    private var testTranslation: CGPoint = .zero
    var testVelocity = CGPoint(x: 0, y: -100)
    override var state: UIGestureRecognizer.State { get { testState } set { testState = newValue } }
    override func translation(in view: UIView?) -> CGPoint { testTranslation }
    override func velocity(in view: UIView?) -> CGPoint { testVelocity }
    func send(to pager: SPPageViewController, state: UIGestureRecognizer.State, y: CGFloat = 0) {
        testState = state; testTranslation = CGPoint(x: 0, y: y)
        pager.handleHeaderPan(self)
    }
}
@MainActor private final class PageDelegate: SPPageViewControllerDelegate {
    var selected: [Int] = []
    var progressEvents = 0
    func pageViewController(_ pageViewController: SPPageViewController, didScrollFrom fromIndex: Int, to toIndex: Int, progress: CGFloat) { progressEvents += 1 }
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) { selected.append(index) }
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 80 }
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
    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }
    func animate(alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        animation?(self)
        if let completion { completions.append(completion) }
        return true
    }
    func animateAlongsideTransition(in view: UIView?, animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?, completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?) -> Bool {
        animate(alongsideTransition: animation, completion: completion)
    }
    func notifyWhenInteractionChanges(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func notifyWhenInteractionEnds(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {}
    func finish() {
        let pending = completions
        completions.removeAll()
        pending.forEach { $0(self) }
    }
}
