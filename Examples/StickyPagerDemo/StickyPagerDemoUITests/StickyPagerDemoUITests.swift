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
    private func select(_ index: Int) { app.buttons["sp.tab.\(index)"].tap() }

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
    func testScrollableTabSelectionCentersAndHorizontalDragPreservesPage() {
        // 增加一个标签，让中间项有足够的左右滚动余量；首尾边界另由库测试覆盖。
        app.buttons["demo.pages"].tap()
        app.buttons["添加页面"].tap()
        let tabs = app.collectionViews["sp.tabBar.collection"]
        select(3)
        expect("page=empty")
        let selected = app.buttons["sp.tab.3"]
        let centered = NSPredicate { _, _ in abs(selected.frame.midX - tabs.frame.midX) < 1 }
        expectation(for: centered, evaluatedWith: selected)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(selected.isSelected)
        tabs.swipeLeft()
        expect("page=empty")
        XCTAssertTrue(app.buttons["sp.tab.6"].isHittable)
        tabs.swipeRight()
        expect("page=empty")
        XCTAssertTrue(app.buttons["sp.tab.0"].isHittable)
        select(1)
        expect("page=list")
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
