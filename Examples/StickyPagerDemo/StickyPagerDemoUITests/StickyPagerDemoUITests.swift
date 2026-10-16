import XCTest

@MainActor
final class StickyPagerDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        if name.contains("testSystem") { app.launchArguments = ["--window-regression"] }
        app.launch()
        restoreFullScreen()
        app.buttons["demo.open"].tap()
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
    }
    override func tearDown() async throws {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        restoreFullScreen()
        if name.contains("testSystemSplit") {
            let companion = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if companion.state != .notRunning { companion.terminate() }
        }
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

    private func expectSelectedTabAlignment(_ index: Int) {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let selected = app.buttons["sp.tab.\(index)"]
        let rtl = (status.value as? String)?.contains("direction=rtl") == true
        let leftEdge = app.buttons["sp.tab.\(rtl ? 11 : 0)"]
        let rightEdge = app.buttons["sp.tab.\(rtl ? 0 : 11)"]
        let aligned = NSPredicate { _, _ in
            let viewport = tabs.frame, frame = selected.frame
            guard selected.isSelected, frame.minX >= viewport.minX - 1,
                  frame.maxX <= viewport.maxX + 1 else { return false }
            let delta = frame.midX - viewport.midX
            if abs(delta) < 1 { return true }
            // 无法继续居中时，必须有对应的真实内容端点与视口边界重合。
            if delta < 0 { return leftEdge.exists && abs(leftEdge.frame.minX - viewport.minX) < 1 }
            return rightEdge.exists && abs(rightEdge.frame.maxX - viewport.maxX) < 1
        }
        expectation(for: aligned, evaluatedWith: selected)
        waitForExpectations(timeout: 5)
    }

    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    private func restoreFullScreen() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let frame = app.windows.firstMatch.frame
        guard frame.width < springboard.frame.width - 1 || frame.height < springboard.frame.height - 1 else { return }
        let controls = springboard.buttons["window-controls:dev.stickypager.StickyPagerDemo"]
        if controls.exists {
            controls.tap()
            springboard.buttons["Zoom-button"].tap()
        }
    }

    private func resizeSystemWindow(dx: CGFloat, dy: CGFloat) {
        let frame = app.windows.firstMatch.frame
        let screen = springboard.coordinate(withNormalizedOffset: .zero)
        // 系统右下角手柄；以实时窗口坐标定位，不能使用应用全屏 frame。
        let handle = screen.withOffset(CGVector(dx: frame.maxX - 8, dy: frame.maxY - 8))
        handle.press(forDuration: 0.2,
                     thenDragTo: screen.withOffset(CGVector(dx: frame.maxX - 8 + dx, dy: frame.maxY - 8 + dy)),
                     withVelocity: .slow, thenHoldForDuration: 0.5)
    }

    private func recordWindow(_ phase: String) {
        print("WINDOW GEOMETRY \(phase): window=\(app.windows.firstMatch.frame), list=\(app.tables["demo.list"].frame)")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = phase; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func contentPosition() -> CGFloat {
        let table = app.tables["demo.list"]
        guard let value = table.value as? String, let position = Double(value) else {
            XCTFail("未取得 UITableView 的真实滚动坐标")
            return .nan
        }
        // Demo 的 Header 高度为 220，吸顶基线为当前窗口中的导航栏底边。
        let safeTop = app.navigationBars.firstMatch.frame.maxY - app.windows.firstMatch.frame.minY
        return max(0, CGFloat(position) - max(0, 220 - safeTop))
    }

    private func assertPinnedList(position: CGFloat) {
        expect("page=list"); expect("progress=1.00")
        let table = app.tables["demo.list"]
        let tab = app.buttons["sp.tab.1"]
        XCTAssertEqual(tab.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        XCTAssertEqual(table.frame.minY, tab.frame.maxY, accuracy: 1)
        XCTAssertEqual(table.frame.minX, app.windows.firstMatch.frame.minX, accuracy: 1)
        XCTAssertEqual(table.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        XCTAssertEqual(contentPosition(), position, accuracy: 1)
    }

    func testSystemWindowResizePreservesPinnedListAndPaging() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统窗口缩放仅适用于 iPad")
        select(1)
        let table = app.tables["demo.list"]
        table.swipeUp(); expect("progress=1.00")
        let initialPosition = contentPosition()
        let full = app.windows.firstMatch.frame
        resizeSystemWindow(dx: -250, dy: -350)
        XCTAssertLessThan(app.windows.firstMatch.frame.width, full.width - 100)
        assertPinnedList(position: initialPosition); recordWindow("浮动小窗口")
        for delta: CGVector in [CGVector(dx: 160, dy: 120), CGVector(dx: -80, dy: -60)] {
            let before = app.windows.firstMatch.frame
            resizeSystemWindow(dx: delta.dx, dy: delta.dy)
            XCTAssertGreaterThan(abs(app.windows.firstMatch.frame.width - before.width), 40)
            assertPinnedList(position: initialPosition); recordWindow("连续缩放 \(delta)")
            table.swipeLeft(); expect("page=short")
            app.tables["demo.list"].swipeRight(); expect("page=list")
            assertPinnedList(position: initialPosition)
        }
        // 重新触摸必须仍可滚动，切回后保存该次滚动的位置。
        table.swipeUp()
        let moved = contentPosition()
        XCTAssertGreaterThan(moved, initialPosition + 50)
        restoreFullScreen()
        assertPinnedList(position: moved); recordWindow("恢复全屏")
    }

    func testSystemSplitWindowsPreservePositionAndPaging() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        let companion = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        select(1)
        app.tables["demo.list"].swipeUp(); expect("progress=1.00")
        let initialPosition = contentPosition()
        resizeSystemWindow(dx: -250, dy: -350)
        companion.launch()
        app.activate()
        springboard.buttons["window-controls:dev.stickypager.StickyPagerDemo"].tap()
        springboard.buttons["Zoom-button"].press(forDuration: 1)
        springboard.buttons["左右"].tap()
        print("SPLIT WINDOWS", app.windows.firstMatch.frame, companion.windows.firstMatch.frame)
        assertPinnedList(position: initialPosition); recordWindow("系统左右分屏")
        let left = app.windows.firstMatch.frame, right = companion.windows.firstMatch.frame
        XCTAssertLessThan(left.width, springboard.frame.width * 0.7)
        XCTAssertLessThan(right.width, springboard.frame.width * 0.7)
        XCTAssertLessThanOrEqual(left.intersection(right).width, 1)
        app.tables["demo.list"].swipeLeft(); expect("page=short")
        app.tables["demo.list"].swipeRight(); expect("page=list")
        assertPinnedList(position: initialPosition)
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
        // 不同设备的滚动余量不同：验证居中，以及首尾边界的精确钳制。
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for (index, page) in [(3, "empty"), (9, "weekly"), (6, "hot")] {
            select(index)
            expect("page=\(page)")
            let selected = app.buttons["sp.tab.\(index)"]
            expectSelectedTabAlignment(index)
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
        expectSelectedTabAlignment(3)
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
        let start = tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -180)))
        expect("page=grid")
        expect("progress=1.00")
        XCTAssertEqual(app.buttons["sp.tab.0"].frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
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
        expectSelectedTabAlignment(9)
    }
    func testRotationAndBackGesture() {
        select(1)
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            expect("page=list"); expect("progress=1.00")
            XCTAssertEqual(app.buttons["sp.tab.1"].frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
            XCTAssertEqual(app.tables["demo.list"].frame.minY, app.buttons["sp.tab.1"].frame.maxY, accuracy: 1)
        }
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 1, dy: app.frame.height * 0.5))
        // 小幅慢拖并停留后释放，取消系统返回；后续新触摸必须仍能正常翻页。
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 80, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.5)
        expect("page=list"); expect("progress=1.00")
        XCTAssertFalse(app.buttons["demo.open"].exists)
        app.tables["demo.list"].swipeLeft()
        expect("page=short"); expect("progress=1.00")
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
        app.buttons["demo.open"].tap()
        expect("page=grid"); expect("progress=0.00")
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
    }
    func testDiagonalDragAndShortContentBounce() {
        select(2)
        let table = app.tables["demo.list"]
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75)).press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.2)))
        expect("page=short"); expect("progress=1.00")
        table.swipeDown(); expect("progress=0.00")
    }
}
