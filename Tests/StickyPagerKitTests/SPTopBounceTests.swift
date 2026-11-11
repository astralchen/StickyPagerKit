import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTopBounceTests: XCTestCase {
    private var window: UIWindow?
    private var source: BounceSource!
    private var pager: SPPageViewController!

    override func tearDown() async throws {
        window?.closeForTesting()
        window = nil; pager = nil; source = nil
    }

    private func mount(plain: Bool = false, header: Bool = true) {
        source = BounceSource()
        source.plain = plain
        pager = SPPageViewController()
        pager.dataSource = source
        if header {
            pager.headerView = UIView()
        }
        pager.layout = SPPageLayout(headerHeight: 240, minimumHeaderHeight: 40)
        pager.reloadData()
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        self.window = window
        window.rootViewController = pager
        window.showForTesting()
        pager.view.layoutIfNeeded()
    }

    func testRegrabAndGeometryChangeClearOnlyTemporaryDisplacement() {
        mount()
        pager.topBounceBehavior = .container
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 220)
        pan.send(pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        let before = pager.topBounce.displacement
        pan.send(pager, state: .began)
        XCTAssertEqual(pager.topBounce.displacement, before, accuracy: 0.01)
        pan.send(pager, state: .changed, y: 20)
        XCTAssertGreaterThan(pager.topBounce.displacement, before)
        pager.layout.headerHeight += 20
        XCTAssertEqual(pager.topBounce.displacement, 0)
        XCTAssertEqual(pager.store.position(for: 0), 0)
        pan.send(pager, state: .changed, y: 300)
        XCTAssertEqual(pager.topBounce.displacement, 0)
    }

    func testPresentationPreservesTabDirectionAcrossRuntimeChangesAndBounce() throws {
        mount()
        let collection = try XCTUnwrap(pager.tabBar.subviews.compactMap { $0 as? UICollectionView }.first)
        for direction: UISemanticContentAttribute in [.forceRightToLeft, .forceLeftToRight] {
            pager.view.semanticContentAttribute = direction
            pager.view.setNeedsLayout()
            pager.view.layoutIfNeeded()
            pager.tabBar.layoutIfNeeded()
            collection.layoutIfNeeded()
            let first = try XCTUnwrap(collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(
                item: 0,
                section: 0
            )))
            let second = try XCTUnwrap(collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(
                item: 1,
                section: 0
            )))
            XCTAssertEqual(first.frame.midX > second.frame.midX, direction == .forceRightToLeft)
            pager.topBounceBehavior = .container
            let pan = BouncePan()
            pan.send(pager, state: .began)
            pan.send(pager, state: .changed, y: 200)
            XCTAssertGreaterThan(pager.topBounce.displacement, 0)
            XCTAssertEqual(
                collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame,
                first.frame
            )
            pager.topBounce.cancel()
        }
    }

    func testDisablingScrollAndUnbindingCancelActiveBounceWithoutEndingRefresh() throws {
        mount()
        pager.topBounceBehavior = .container
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 200)
        scroll.isScrollEnabled = false
        XCTAssertEqual(pager.topBounce.displacement, 0)
        pan.send(pager, state: .changed, y: 300)
        XCTAssertEqual(pager.topBounce.displacement, 0)
        scroll.isScrollEnabled = true
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 200)
        pager.setScrollViewBinding(.unbound, forPageAt: 0)
        XCTAssertEqual(pager.topBounce.displacement, 0)
        XCTAssertNil(pager.currentScrollView)
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 200)
        XCTAssertGreaterThan(pager.topBounce.displacement, 0, "显式解绑仍保留 Header 入口")
    }

    func testHeaderInertiaCrossingTopUsesContainerBounce() throws {
        mount()
        pager.topBounceBehavior = .container
        let binding = try XCTUnwrap(pager.currentRecord?.binding)
        binding.scrollView.contentOffset.y = 50 - binding.scrollView.adjustedContentInset.top
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.testVelocity = 1500
        pan.send(pager, state: .ended)
        var peak: CGFloat = 0
        for _ in 0 ..< 60 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            peak = max(peak, pager.topBounce.displacement)
            XCTAssertGreaterThanOrEqual(binding.position, 0)
        }
        XCTAssertGreaterThan(peak, 1)
        XCTAssertEqual(pager.topBounce.displacement, 0, accuracy: 0.01)
        XCTAssertEqual(binding.position, 0, accuracy: 0.01)
    }

    func testPolicyPrecedenceAndUnknownIdentifierDoNotLoadPages() {
        mount()
        XCTAssertEqual(pager.topBounceBehavior, .container)
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .container)
        source.behaviors[0] = .page
        pager.reloadData()
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .page)
        let created = source.created
        pager.setTopBounceBehavior(.container, forPageIdentifier: 0)
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .container)
        pager.setTopBounceBehavior(.page, forPageIdentifier: 2)
        pager.setTopBounceBehavior(.container, forPageIdentifier: 99)
        XCTAssertEqual(source.created, created)
        XCTAssertNil(pager.store.topBounceBehavior(for: 99))
        pager.setTopBounceBehavior(nil, forPageIdentifier: 0)
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .page)
        source.behaviors = [:]
        pager.reloadData()
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .container)
    }

    func testOverridesSurviveReorderEvictionAndRejectedSnapshotButNotDeletion() {
        mount()
        pager.topBounceBehavior = .page
        pager.maximumCachedPageCount = 1
        pager.setTopBounceBehavior(.container, forPageIdentifier: 0)
        pager.setSelectedIndex(1, animated: false)
        XCTAssertNil(pager.records[0])
        source.ids = [2, 1, 0]
        pager.reloadData()
        pager.setSelectedIndex(2, animated: false)
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .container)
        source.ids = [0, 0]
        source.behaviors[0] = .page
        let queries = source.queries
        pager.reloadData()
        XCTAssertEqual(source.queries, queries)
        XCTAssertEqual(pager.identifiers, [AnyHashable(2), AnyHashable(1), AnyHashable(0)])
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .container)
        source.ids = [1, 2]
        pager.reloadData()
        source.ids = [0, 1, 2]
        source.behaviors = [:]
        pager.reloadData()
        pager.setSelectedIndex(0, animated: false)
        XCTAssertEqual(pager.effectiveTopBounceBehavior, .page)
    }

    func testContainerHeaderDragPreservesInsetsHistoryAndBusinessSettings() throws {
        mount()
        let binding = try XCTUnwrap(pager.currentRecord?.binding)
        let scroll = binding.scrollView
        scroll.bounces = false
        scroll.alwaysBounceVertical = false
        let inset = scroll.adjustedContentInset
        let safeArea = pager.currentRecord!.controller.view.safeAreaInsets
        let headerFrame = pager.headerHost.frame
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 240)
        pager.view.layoutIfNeeded()
        XCTAssertGreaterThan(pager.topBounce.displacement, 50)
        XCTAssertEqual(pager.headerHost.frame, headerFrame)
        XCTAssertEqual(binding.position, 0, accuracy: 0.01)
        XCTAssertEqual(pager.collapseOffset, 0)
        XCTAssertEqual(pager.store.position(for: 0), 0)
        XCTAssertEqual(scroll.adjustedContentInset, inset)
        XCTAssertEqual(pager.currentRecord!.controller.view.safeAreaInsets, safeArea)
        XCTAssertFalse(scroll.bounces)
        XCTAssertFalse(scroll.alwaysBounceVertical)
        let delta = pager.topBounce.displacement
        XCTAssertEqual(pager.headerHost.convert(.zero, to: pager.view).y, delta, accuracy: 0.01)
        XCTAssertEqual(pager.tabBar.convert(.zero, to: pager.view).y, headerFrame.height + delta, accuracy: 0.01)
        pan.send(pager, state: .changed, y: 200)
        XCTAssertLessThan(pager.topBounce.displacement, delta)
        pan.send(pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.2))
        XCTAssertEqual(pager.topBounce.displacement, 0, accuracy: 0.01)
        XCTAssertEqual(binding.position, 0, accuracy: 0.01)
    }

    func testPageModeKeepsNativeNegativeOffsetAndHeaderDragBounded() throws {
        mount()
        pager.topBounceBehavior = .page
        let binding = try XCTUnwrap(pager.currentRecord?.binding)
        binding.scrollView.contentOffset.y = -80 - binding.scrollView.adjustedContentInset.top
        XCTAssertEqual(binding.position, -80, accuracy: 0.01)
        XCTAssertEqual(pager.topBounce.displacement, 0)
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 240)
        XCTAssertEqual(pager.topBounce.displacement, 0)
        XCTAssertEqual(binding.position, 0, accuracy: 0.01)
    }

    func testPlainPageWithoutHeaderCanBounceAndSelectionClearsTemporaryState() {
        mount(plain: true, header: false)
        pager.topBounceBehavior = .container
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 160)
        XCTAssertGreaterThan(pager.topBounce.displacement, 0)
        pager.setSelectedIndex(1, animated: false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.2))
        XCTAssertEqual(pager.topBounce.displacement, 0)
        pan.send(pager, state: .changed, y: 300)
        XCTAssertEqual(pager.topBounce.displacement, 0)
    }

    func testRuntimeChangeWaitsForHeaderGestureAndRefreshRemainsOwnedByBusiness() throws {
        mount()
        pager.topBounceBehavior = .container
        let scroll = try XCTUnwrap(pager.currentScrollView)
        let refresh = UIRefreshControl()
        scroll.refreshControl = refresh
        refresh.beginRefreshing()
        let pan = BouncePan()
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 180)
        let before = pager.topBounce.displacement
        pager.setTopBounceBehavior(.page, forPageIdentifier: 0)
        pan.send(pager, state: .changed, y: 220)
        XCTAssertGreaterThan(pager.topBounce.displacement, before)
        XCTAssertTrue(refresh.isRefreshing)
        pan.send(pager, state: .ended)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.2))
        pan.send(pager, state: .began)
        pan.send(pager, state: .changed, y: 200)
        XCTAssertEqual(pager.topBounce.displacement, 0)
        XCTAssertTrue(refresh.isRefreshing)
        refresh.endRefreshing()
    }
}

@MainActor
private final class BounceSource: SPPageViewControllerDataSource {
    var ids = [0, 1, 2]
    var behaviors: [Int: SPTopBounceBehavior] = [:]
    var plain = false
    var created = 0
    var queries = 0
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
        topBounceBehaviorForPageAt index: Int
    ) -> SPTopBounceBehavior? {
        queries += 1
        return behaviors[ids[index]]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        created += 1
        let controller = UIViewController()
        if !plain {
            let scroll = UIScrollView()
            scroll.contentSize = CGSize(width: 440, height: 2000)
            controller.view = scroll
        }
        return controller
    }
}

@MainActor
private final class BouncePan: UIPanGestureRecognizer {
    var testState: UIGestureRecognizer.State = .possible
    var translationY: CGFloat = 0
    var testVelocity: CGFloat = 0
    override var state: UIGestureRecognizer.State {
        get { testState } set { testState = newValue }
    }

    override func translation(in view: UIView?) -> CGPoint {
        CGPoint(x: 0, y: translationY)
    }

    override func velocity(in view: UIView?) -> CGPoint {
        CGPoint(x: 0, y: testVelocity)
    }

    func send(_ pager: SPPageViewController, state: UIGestureRecognizer.State, y: CGFloat = 0) {
        testState = state; translationY = y
        pager.handleHeaderPan(self)
    }
}
