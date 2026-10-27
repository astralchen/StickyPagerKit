import XCTest
import UIKit
@testable import StickyPagerKit

/// 这些用例验证同步回调边界；直接驱动的 pan／分页状态不代表真实触摸验证。
@MainActor
final class SPPageReentrancyTests: XCTestCase {
    private var window: UIWindow?
    private var source: ReentrantSource!
    private var pager: SPPageViewController!
    private var recorder: ReentrantDelegate!

    override func tearDown() async throws {
        source?.onCreate = nil
        recorder?.onSelect = nil
        window?.closeForTesting()
        window?.rootViewController = nil
        window = nil; pager = nil; source = nil; recorder = nil
    }

    private func mount(rtl: Bool = false, capacity: Int = 3) {
        source?.onCreate = nil
        recorder?.onSelect = nil
        window?.closeForTesting()
        window?.rootViewController = nil
        source = ReentrantSource()
        pager = SPPageViewController()
        pager.dataSource = source
        pager.headerView = UIView()
        pager.layout = SPPageLayout(headerHeight: 240, minimumHeaderHeight: 40)
        pager.maximumCachedPageCount = capacity
        pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        pager.reloadData()
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        self.window = window
        window.rootViewController = pager
        window.showForTesting()
        pager.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        pager.layout.headerHeight = 240 + pager.view.safeAreaInsets.top
        recorder = ReentrantDelegate()
        pager.delegate = recorder
    }

    private func assertSelection(_ id: Int?, file: StaticString = #filePath, line: UInt = #line) {
        let index = id.flatMap { source.ids.firstIndex(of: $0) }
        XCTAssertEqual(pager.selectedIndex, index, file: file, line: line)
        XCTAssertEqual(pager.tabBar.selectedIndex, index, file: file, line: line)
        let rtl = pager.view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let physical = index.map { rtl ? source.ids.count - 1 - $0 : $0 } ?? 0
        XCTAssertEqual(
            pager.pagingView.contentOffset.x,
            CGFloat(physical) * pager.pagingView.bounds.width,
            accuracy: 0.01,
            file: file,
            line: line
        )
        XCTAssertEqual(
            Set(pager.children.map(ObjectIdentifier.init)),
            Set(pager.records.values.map { ObjectIdentifier($0.controller) }),
            file: file,
            line: line
        )
    }

    private func assertBalanced(_ page: ReentrantPage, file: StaticString = #filePath, line: UInt = #line) {
        for phase in ["Appear", "Disappear"] {
            XCTAssertEqual(
                page.events.filter { $0 == "will" + phase }.count,
                page.events.filter { $0 == "did" + phase }.count,
                file: file,
                line: line
            )
        }
    }

    func testMountReloadCancelsOldSelectionAcrossSnapshotChanges() {
        for rtl in [false, true] {
            for target in [1, 2] {
                for replacement in [[0, target], [target, 0, 3], [0], []] {
                    mount(rtl: rtl)
                    let source = source!, pager = pager!
                    source.onCreate = { _, page in
                        page.onMount = {
                            page.onMount = nil
                            source.ids = replacement
                            pager.reloadData()
                        }
                    }
                    pager.setSelectedIndex(target, animated: target == 1)
                    assertSelection(replacement.isEmpty ? nil : 0)
                    XCTAssertTrue(recorder.selected.allSatisfy { replacement[$0] == 0 })
                    for record in pager.records.values {
                        assertBalanced(record.controller as! ReentrantPage)
                    }
                }
            }
        }
    }

    func testVisiblePageLoadingStopsAfterSnapshotRemoval() {
        mount()
        let source = source!, pager = pager!
        source.onCreate = { _, page in
            page.onMount = {
                page.onMount = nil
                source.ids = []
                pager.reloadData()
            }
        }
        pager.pagingView.contentOffset.x = pager.pagingView.bounds.width * 0.6
        assertSelection(nil)
        XCTAssertTrue(pager.records.isEmpty)
        XCTAssertTrue(recorder.selected.isEmpty)
    }

    func testRejectedSnapshotDoesNotCancelPendingTransition() {
        mount()
        pager.setSelectedIndex(1, animated: true)
        source.ids = [7, 7]
        pager.reloadData()
        source.ids = [0, 1, 2, 3]
        pager.pagingView.setContentOffset(CGPoint(x: pager.pagingView.bounds.width, y: 0), animated: false)
        pager.scrollViewDidEndScrollingAnimation(pager.pagingView)
        assertSelection(1)
        XCTAssertEqual(recorder.selected, [1])
    }

    func testFactoryRemovalNeverAttachesDeletedController() {
        for ids in [[0], []] {
            mount()
            let source = source!, pager = pager!
            weak var removed: ReentrantPage?
            source.onCreate = { _, page in
                removed = page
                source.ids = ids
                pager.reloadData()
            }
            pager.rediscoverScrollView(forPageAt: 2)
            XCTAssertNil(pager.records[2])
            XCTAssertNil(removed)
            assertSelection(ids.isEmpty ? nil : 0)
        }
    }

    func testRecursiveFactorySelectionCreatesOneControllerAndCommitsLatestRequest() {
        mount(capacity: 1)
        let source = source!, pager = pager!
        source.onCreate = { id, _ in
            source.onCreate = nil
            pager.rediscoverScrollView(forPageAt: id)
            pager.setSelectedIndex(id, animated: false)
        }
        pager.setSelectedIndex(2, animated: false)
        assertSelection(2)
        XCTAssertEqual(source.created.filter { $0 == 2 }.count, 1)
        XCTAssertEqual(recorder.selected, [2])
        XCTAssertEqual(pager.records.count, 1)
    }

    func testAppearanceReentrantSelectionWinsWithoutDuplicateCommit() {
        for rtl in [false, true] {
            for event in ["willAppear", "didAppear", "didDisappear"] {
                mount(rtl: rtl, capacity: 1)
                let pager = pager!
                let old = pager.records[0]!.controller as! ReentrantPage
                var incoming: ReentrantPage?
                let callback: (String) -> Void = { observed in
                    guard observed == event else {
                        return
                    }
                    old.onEvent = nil
                    incoming?.onEvent = nil
                    pager.setSelectedIndex(3, animated: false)
                    pager.setSelectedIndex(2, animated: false)
                }
                if event == "didDisappear" {
                    old.onEvent = callback
                }
                source.onCreate = { id, page in
                    guard id == 1 else {
                        return
                    }
                    incoming = page
                    if event != "didDisappear" {
                        page.onEvent = callback
                    }
                }
                pager.setSelectedIndex(1, animated: false)
                assertSelection(2)
                XCTAssertEqual(recorder.selected, [2])
                assertBalanced(old)
                if let incoming {
                    assertBalanced(incoming)
                }
                XCTAssertEqual(pager.records.count, 1)
                old.onEvent = nil; incoming?.onEvent = nil
            }
        }
    }

    func testAppearanceReloadClearsSnapshotBeforeOldCommit() {
        for event in ["willAppear", "didAppear", "didDisappear"] {
            mount()
            let source = source!, pager = pager!
            let old = pager.records[0]!.controller as! ReentrantPage
            var incoming: ReentrantPage?
            let callback: (String) -> Void = { observed in
                guard observed == event else {
                    return
                }
                old.onEvent = nil; incoming?.onEvent = nil
                source.ids = []
                pager.reloadData()
            }
            if event == "didDisappear" {
                old.onEvent = callback
            }
            source.onCreate = { id, page in
                guard id == 1 else {
                    return
                }
                incoming = page
                if event != "didDisappear" {
                    page.onEvent = callback
                }
            }
            pager.setSelectedIndex(1, animated: false)
            assertSelection(nil)
            XCTAssertTrue(recorder.selected.isEmpty)
            assertBalanced(old)
            if let incoming {
                assertBalanced(incoming); XCTAssertNil(incoming.parent)
            }
        }
    }

    func testCancellationAppearanceRequestSupersedesCancellingSelection() {
        mount()
        let pager = pager!
        pager.setSelectedIndex(1, animated: true)
        let incoming = pager.records[1]!.controller as! ReentrantPage
        incoming.onEvent = { event in
            guard event == "didDisappear" else {
                return
            }
            incoming.onEvent = nil
            pager.setSelectedIndex(2, animated: false)
        }
        pager.setSelectedIndex(0, animated: false)
        assertSelection(2)
        XCTAssertEqual(recorder.selected, [2])
        assertBalanced(incoming)
    }

    func testCommittedDelegateSelectionKeepsNotificationOrder() {
        mount()
        let pager = pager!
        recorder.onSelect = { index in
            if index == 1 {
                pager.setSelectedIndex(2, animated: false)
            }
        }
        pager.setSelectedIndex(1, animated: false)
        assertSelection(2)
        XCTAssertEqual(recorder.selected, [1, 2])
    }

    func testAnimationCompletionCallbackCanStartAnotherAnimatedSelection() {
        mount()
        let pager = pager!
        recorder.onSelect = { index in
            if index == 1 {
                pager.setSelectedIndex(2, animated: true)
            }
        }
        pager.setSelectedIndex(1, animated: true)
        pager.pagingView.setContentOffset(CGPoint(x: pager.pagingView.bounds.width, y: 0), animated: false)
        pager.scrollViewDidEndScrollingAnimation(pager.pagingView)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        assertSelection(2)
        XCTAssertEqual(recorder.selected, [1, 2])
    }

    func testParentAppearanceCallbackQueuesSelectionUntilPairIsFinished() {
        mount()
        let pager = pager!
        pager.beginAppearanceTransition(false, animated: false)
        pager.endAppearanceTransition()
        let old = pager.records[0]!.controller as! ReentrantPage
        old.onEvent = { event in
            guard event == "didAppear" else {
                return
            }
            old.onEvent = nil
            pager.setSelectedIndex(2, animated: false)
        }
        pager.beginAppearanceTransition(true, animated: false)
        pager.endAppearanceTransition()
        assertSelection(2)
        assertBalanced(old)
        assertBalanced(pager.records[2]!.controller as! ReentrantPage)
        XCTAssertEqual(recorder.selected, [2])
    }

    func testSelectionDuringParentAppearanceRollsBackSupersededIncomingPage() {
        mount()
        let pager = pager!
        pager.beginAppearanceTransition(false, animated: false)
        pager.endAppearanceTransition()
        let old = pager.records[0]!.controller as! ReentrantPage
        pager.beginAppearanceTransition(true, animated: false)
        old.onEvent = { event in
            guard event == "didAppear" else {
                return
            }
            old.onEvent = nil
            pager.setSelectedIndex(2, animated: false)
        }
        pager.setSelectedIndex(1, animated: false)
        pager.endAppearanceTransition()
        assertSelection(2)
        XCTAssertEqual(recorder.selected, [2])
        for record in pager.records.values {
            let page = record.controller as! ReentrantPage
            assertBalanced(page)
            if record.identifier != AnyHashable(2) {
                XCTAssertEqual(
                    page.events.filter { $0 == "didAppear" }.count,
                    page.events.filter { $0 == "didDisappear" }.count
                )
            }
        }
    }

    func testHeaderOffsetCallbackCannotOverwriteNewPageHistory() {
        verifyOffsetReentry(inertia: false)
    }

    func testInertiaOffsetCallbackCannotOverwriteNewPageHistory() {
        verifyOffsetReentry(inertia: true)
    }

    private func verifyOffsetReentry(inertia: Bool) {
        for rtl in [false, true] {
            for action in 0 ..< 3 {
                mount(rtl: rtl)
                let pager = pager!
                pager.setSelectedIndex(1, animated: false)
                let second = pager.currentScrollView!
                second.contentOffset.y = 1000 - second.adjustedContentInset.top
                pager.setSelectedIndex(0, animated: false)
                let first = pager.currentScrollView as! ReentrantScrollView
                first.contentOffset.y = 500 - first.adjustedContentInset.top
                let originalBody = pager.records[0]!.binding!.position - pager.collapseOffset
                let pan = ReentrantPan()
                pan.send(pager, state: .began)
                var called = false
                var replacement: UIScrollView?
                var expectedCollapse: CGFloat = 0
                first.onOffset = {
                    first.onOffset = nil
                    called = true
                    switch action {
                    case 0: pager.setSelectedIndex(1, animated: false)
                    case 1:
                        let root = pager.records[0]!.controller.view!
                        let scroll = UIScrollView(frame: root.bounds)
                        scroll.contentSize.height = 3000
                        root.addSubview(scroll)
                        replacement = scroll
                        pager.setScrollView(scroll, forPageAt: 0)
                    default: pager.setScrollViewBinding(.unbound, forPageAt: 0)
                    }
                    expectedCollapse = pager.collapseOffset
                }
                if inertia {
                    pan.send(pager, state: .ended)
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
                } else {
                    pan.send(pager, state: .changed, y: -20)
                }
                XCTAssertTrue(called)
                XCTAssertEqual(pager.collapseOffset, expectedCollapse, accuracy: 0.01)
                if action == 0 {
                    assertSelection(1)
                    XCTAssertEqual(pager.records[1]!.binding!.position, 1000, accuracy: 0.01)
                    pager.setSelectedIndex(0, animated: false)
                    pager.setSelectedIndex(1, animated: false)
                    XCTAssertEqual(pager.records[1]!.binding!.position, 1000, accuracy: 0.01)
                } else {
                    if action == 2 {
                        pager.setScrollView(first, forPageAt: 0)
                    }
                    if let replacement {
                        XCTAssertTrue(pager.currentScrollView === replacement)
                    }
                    XCTAssertEqual(
                        pager.records[0]!.binding!.position - pager.collapseOffset,
                        originalBody,
                        accuracy: 0.01
                    )
                }
            }
        }
    }
}

@MainActor
private final class ReentrantSource: SPPageViewControllerDataSource {
    var ids = [0, 1, 2, 3]
    var created: [Int] = []
    var onCreate: ((Int, ReentrantPage) -> Void)?
    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        ids.count
    }

    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable {
        ids[index]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        let id = ids[index]
        created.append(id)
        let page = ReentrantPage()
        onCreate?(id, page)
        return page
    }
}

@MainActor
private final class ReentrantPage: UIViewController {
    let scroll = ReentrantScrollView()
    var events: [String] = []
    var onEvent: ((String) -> Void)?
    var onMount: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        scroll.frame = view.bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.contentSize = CGSize(width: 1, height: 3000)
        scroll.contentInsetAdjustmentBehavior = .never
        view.addSubview(scroll)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil {
            onMount?()
        }
    }

    private func report(_ event: String) {
        events.append(event); onEvent?(event)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); report("willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); report("didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); report("willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); report("didDisappear")
    }
}

@MainActor
private final class ReentrantScrollView: UIScrollView {
    var onOffset: (() -> Void)?
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(contentOffset, animated: animated)
        onOffset?()
    }
}

@MainActor
private final class ReentrantDelegate: SPPageViewControllerDelegate {
    var selected: [Int] = []
    var onSelect: ((Int) -> Void)?
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {
        selected.append(index)
        onSelect?(index)
    }
}

@MainActor
private final class ReentrantPan: UIPanGestureRecognizer {
    private var testState: UIGestureRecognizer.State = .possible
    private var displacement = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { testState } set { testState = newValue }
    }

    override func translation(in view: UIView?) -> CGPoint {
        displacement
    }

    override func velocity(in view: UIView?) -> CGPoint {
        CGPoint(x: 0, y: -500)
    }

    func send(_ pager: SPPageViewController, state: UIGestureRecognizer.State, y: CGFloat = 0) {
        testState = state; displacement.y = y
        pager.handleHeaderPan(self)
    }
}
