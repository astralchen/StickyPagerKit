import XCTest

@MainActor
final class StickyPagerDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.buttons["demo.open"].tap()
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
    }
    override func tearDown() async throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }
    private var status: XCUIElement { app.staticTexts["demo.status"] }
    private func expect(_ fragment: String) {
        let predicate = NSPredicate(format: "value CONTAINS %@", fragment)
        expectation(for: predicate, evaluatedWith: status)
        waitForExpectations(timeout: 5)
    }
    private func select(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let target = app.buttons["sp.tab.\(index)"]
        // 标签可能尚未创建 Cell；先滚动至可见，避免依赖 XCTest 对屏幕外元素的隐式滚动。
        for _ in 0..<20 {
            if target.isHittable { target.tap(); return }
            let visible = tabs.buttons.allElementsBoundByIndex.filter(\.isHittable)
                .compactMap { Int($0.identifier.replacingOccurrences(of: "sp.tab.", with: "")) }
            guard let first = visible.min() else { break }
            let towardStart = index < first
            let rtl = (status.value as? String)?.contains("direction=rtl") == true
            // 短标签容易被快速 swipe 的惯性整段越过；使用小幅拖动逐步查找。
            let movesRight = towardStart != rtl
            let start = tabs.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.3 : 0.7, dy: 0.5))
            let end = tabs.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.7 : 0.3, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTFail("未找到可点击的标签 \(index)", file: file, line: line)
    }

    func testHeaderStartsAtScreenTopAndPageContentMeetsTabBar() {
        let header = app.otherElements["demo.headerView"]
        let tab = app.buttons["sp.tab.0"]
        expect("progress=0.00")
        XCTAssertEqual(header.frame.minY, app.frame.minY, accuracy: 1)
        XCTAssertEqual(header.frame.height, 220, accuracy: 1)
        XCTAssertTrue(app.staticTexts["demo.headerTitle"].isHittable)
        XCTAssertEqual(tab.frame.minY, app.frame.minY + 220, accuracy: 1)
        let grid = app.collectionViews["demo.grid"]
        XCTAssertEqual(grid.cells.firstMatch.frame.minY, tab.frame.maxY + 12, accuracy: 1)
        grid.swipeLeft(); expect("page=list"); expect("progress=0.00")
        app.tables["demo.list"].swipeUp(); expect("progress=1.00")
        XCTAssertEqual(app.buttons["sp.tab.1"].frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        select(4); expect("page=plain"); expect("progress=1.00")
        let plain = app.staticTexts["demo.plain"]
        plain.swipeDown(); expect("progress=0.00")
        XCTAssertEqual(header.frame.minY, app.frame.minY, accuracy: 1)
        XCTAssertEqual(plain.frame.minY, app.buttons["sp.tab.4"].frame.maxY, accuracy: 1)
        app.buttons["demo.header"].tap(); expect("header=controller")
        XCTAssertEqual(header.frame.minY, app.frame.minY, accuracy: 1)
        app.buttons["demo.height"].tap(); expect("height=300")
        XCTAssertEqual(header.frame.height, 300, accuracy: 1)
        XCTAssertEqual(app.buttons["sp.tab.4"].frame.minY, app.frame.minY + 300, accuracy: 1)
    }

    func testCollapsedTabBarStaysAtNavigationBarBottom() {
        func assertPinned(file: StaticString = #filePath, line: UInt = #line) {
            expect("progress=1.00")
            let navigationBar = app.navigationBars.firstMatch
            let tab = app.buttons["sp.tab.1"]
            XCTAssertEqual(tab.frame.minY, navigationBar.frame.maxY, accuracy: 1,
                           "Header 折叠后标签栏应紧贴导航栏底部", file: file, line: line)
            XCTAssertEqual(app.tables["demo.list"].frame.minY, tab.frame.maxY, accuracy: 1,
                           "列表视口应紧贴标签栏底部", file: file, line: line)
            XCTAssertEqual(app.tables["demo.list"].frame.maxY, app.frame.maxY, accuracy: 1,
                           "吸顶时内容页应延伸到屏幕底边", file: file, line: line)
        }

        select(1)
        let table = app.tables["demo.list"]
        table.swipeUp()
        assertPinned()
        table.swipeUp()
        assertPinned()
        select(0); select(1)
        assertPinned()
        app.buttons["demo.header"].tap()
        table.swipeUp()
        assertPinned()
        app.buttons["demo.height"].tap()
        table.swipeUp()
        assertPinned()
        XCUIDevice.shared.orientation = .landscapeLeft
        assertPinned()
        XCUIDevice.shared.orientation = .portrait
        assertPinned()
    }

    func testHeaderDragAndListScroll() {
        let header = app.otherElements["demo.headerView"]
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85)).press(forDuration: 0.05, thenDragTo: header.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.1)))
        expect("progress=1.00")
        select(1)
        expect("page=list")
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        XCTAssertTrue(app.tables["demo.list"].cells.count > 0)
    }
    func testHeaderReplacementHeightAndPlainPage() {
        app.buttons["demo.header"].tap(); expect("header=controller")
        app.buttons["demo.height"].tap(); expect("height=300")
        app.buttons["demo.header"].tap(); expect("header=view")
        select(4); expect("page=plain")
        XCTAssertTrue(app.staticTexts["demo.plain"].exists)
    }
    func testPlainPageDragCollapsesAndExpandsHeader() {
        select(4); expect("page=plain")
        let plain = app.staticTexts["demo.plain"]
        plain.swipeUp()
        expect("progress=1.00")
        let tab = app.buttons["sp.tab.4"]
        XCTAssertEqual(tab.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        XCTAssertEqual(plain.frame.minY, tab.frame.maxY, accuracy: 1)
        XCTAssertEqual(plain.frame.maxY, app.frame.maxY, accuracy: 1)
        plain.swipeUp(); expect("progress=1.00")
        plain.swipeDown(); expect("progress=0.00")
        XCTAssertEqual(plain.frame.minY, tab.frame.maxY, accuracy: 1)
        XCTAssertEqual(plain.frame.maxY, app.frame.maxY, accuracy: 1)
        plain.swipeDown(); expect("progress=0.00")

        let header = app.otherElements["demo.headerView"]
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.85))
            .press(forDuration: 0.05, thenDragTo: header.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.1)))
        expect("progress=1.00")
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
        expect("progress=0.00"); expect("page=plain")
        plain.swipeUp(); expect("progress=1.00")
        select(1); expect("page=list"); expect("progress=1.00")
        select(4); expect("page=plain"); expect("progress=1.00")
        plain.swipeDown(); expect("progress=0.00")
        app.scrollViews["sp.pages"].swipeRight(); expect("page=empty")
    }
    func testPagingAndRapidSelection() {
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        select(0); select(2); select(1)
        expect("page=list")
    }
    func testRefreshFromExpandedHeader() {
        select(1)
        let table = app.tables["demo.list"]
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        XCTAssertTrue(table.staticTexts["原生 UITableView · 已刷新 1 次"].firstMatch.waitForExistence(timeout: 5))
        expect("progress=0.00")
    }
    func testPageReorderDeletionAndEmptySnapshot() {
        select(1)
        app.buttons["demo.pages"].tap(); app.buttons["重排页面"].tap(); expect("page=list")
        app.buttons["demo.pages"].tap(); app.buttons["删除当前页"].tap(); expect("page=grid")
        app.buttons["demo.pages"].tap(); app.buttons["清空页面"].tap(); expect("page=none")
    }
    func testAsyncDiscoveryAndReplacement() {
        select(5)
        app.buttons["demo.replaceScroll"].tap()
        XCTAssertTrue(app.scrollViews["demo.asyncScroll"].exists)
        app.scrollViews["demo.asyncScroll"].swipeUp(); expect("progress=1.00")
        app.buttons["demo.replaceScroll"].tap()
        XCTAssertTrue(app.scrollViews["demo.asyncScroll"].exists)
    }
    func testNonAdjacentSelectionPreservesHeaderAndAllowsPaging() {
        select(1)
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        select(4)
        expect("page=plain")
        expect("progress=1.00")
        app.scrollViews["sp.pages"].swipeRight()
        expect("page=empty")
        expect("progress=1.00")
        select(0)
        expect("page=grid")
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        expect("progress=1.00")
    }

    func testScrollableTabSelectionCentersAndHorizontalDragPreservesPage() {
        // Demo 的长短标题与更多标签为中间项提供足够的左右滚动余量。
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for (index, page) in [(3, "empty"), (9, "weekly"), (6, "hot")] {
            select(index)
            expect("page=\(page)")
            let selected = app.buttons["sp.tab.\(index)"]
            let centered = NSPredicate { _, _ in abs(selected.frame.midX - tabs.frame.midX) < 1 }
            expectation(for: centered, evaluatedWith: selected)
            waitForExpectations(timeout: 5)
            XCTAssertTrue(selected.isSelected)
        }
        select(0)
        tabs.swipeLeft()
        expect("page=grid")
        XCTAssertFalse(app.buttons["sp.tab.0"].isHittable)
        tabs.swipeRight()
        expect("page=grid")
        XCTAssertTrue(app.buttons["sp.tab.0"].isHittable)
        select(1)
        expect("page=list")
    }

    func testHeldTabButtonYieldsToHorizontalDrag() {
        select(3); expect("page=empty")
        let tab = app.buttons["sp.tab.3"]
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let centered = NSPredicate { _, _ in abs(tab.frame.midX - tabs.frame.midX) < 1 }
        expectation(for: centered, evaluatedWith: tab)
        waitForExpectations(timeout: 5)
        let before = tab.frame.midX
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: before, dy: tab.frame.midY))
        // 超过触摸延迟后向左拖动；向右会受内容起点约 39 pt 的剩余距离限制。
        start.press(forDuration: 0.4, thenDragTo: start.withOffset(CGVector(dx: -80, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertGreaterThan(before - tab.frame.midX, 40, "按钮已按下时仍应能拖动标签栏")
        expect("page=empty")
        XCTAssertTrue(tab.isSelected)
        select(1); expect("page=list")
    }

    func testTabBarVerticalDragDoesNotSelectTappedItem() {
        let tab = app.buttons["sp.tab.1"]
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.12)))
        expect("page=grid")
        expect("progress=1.00")
    }
    func testRTLHorizontalPaging() {
        app.terminate()
        app.launchArguments = ["--rtl"]
        app.launch()
        app.buttons["demo.open"].tap()
        expect("direction=rtl")
        app.collectionViews["demo.grid"].swipeRight()
        expect("page=list")
        select(0); expect("page=grid")
        select(9); expect("page=weekly")
        let selected = app.buttons["sp.tab.9"]
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let centered = NSPredicate { _, _ in abs(selected.frame.midX - tabs.frame.midX) < 1 }
        expectation(for: centered, evaluatedWith: selected)
        waitForExpectations(timeout: 5)
    }
    func testRotationAndBackGesture() {
        select(1)
        XCUIDevice.shared.orientation = .landscapeLeft
        expect("page=list")
        XCUIDevice.shared.orientation = .portrait
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 1, dy: app.frame.height * 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
    }
    func testDiagonalDragAndShortContentBounce() {
        select(2)
        let table = app.tables["demo.list"]
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75)).press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.2)))
        expect("page=short"); expect("progress=1.00")
        table.swipeDown(); expect("progress=0.00")
    }
}
