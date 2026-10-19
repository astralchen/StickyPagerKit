import XCTest

@MainActor
final class StickyPagerDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--window-regression"]
        if name.contains("testSystemSplit") || name.contains("testSystemWindowResize") { app.launchArguments.append("--paging-trace") }
        if name.contains("testSiblingLabel") { app.launchArguments.append("--mixed-page") }
        if name.contains("testSystemSplitWindowsRTL") || name.contains("testSystemWindowResizeRTL") { app.launchArguments.append("--rtl") }
        app.launch()
        restoreFullScreen()
        app.buttons["demo.open"].tap()
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
    }
    override func tearDown() async throws {
        // 在窗口清理产生新触摸之前保留最后输入，便于区分系统取消和框架状态错误。
        if app.launchArguments.contains("--paging-trace"), status.exists {
            print("FINAL PAGING STATUS \(status.value ?? "")")
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        restoreFullScreen()
        // 陪测应用只提供窗口，不修改其内容；恢复 Demo 全屏后保留后台实例供后续分屏复用。
        // 避免在每个用例间反复终止仍由系统窗口管理关联的进程。
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }
    private var status: XCUIElement { app.staticTexts["demo.status"] }
    private func expect(_ fragment: String) {
        // 每次轮询重新解析元素，避免 KVC 谓词复用切页或旋转前的辅助快照。
        var latestValue = "<尚未找到状态>"
        let predicate = NSPredicate { [weak self] _, _ in
            guard let self else { return false }
            let current = self.app.staticTexts["demo.status"]
            guard current.exists else { return false }
            latestValue = current.value as? String ?? "<无状态值>"
            return latestValue.contains(fragment)
        }
        let expected = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed,
                       "等待状态 \(fragment)，实际：\(latestValue)")
    }
    private func select(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let target = app.buttons["sp.tab.\(index)"]
        // 标签可能尚未创建 Cell；先滚动至可见，避免依赖 XCTest 对屏幕外元素的隐式滚动。
        for _ in 0..<20 {
            let viewport = tabs.frame
            if target.exists {
                let visibleFrame = target.frame.intersection(viewport)
                if !visibleFrame.isNull, visibleFrame.width >= 44, visibleFrame.height >= 20 {
                    // 点击真实露出的按钮区域；避免 XCTest 在裁切标签上查询无效激活点。
                    tabs.coordinate(withNormalizedOffset: .zero).withOffset(
                        CGVector(dx: visibleFrame.midX - viewport.minX, dy: visibleFrame.midY - viewport.minY)
                    ).tap()
                    return
                }
            }
            // 仅查询物理可见范围；iOS 27 对裁切按钮的 isHittable 查询可能抛出激活点错误。
            let visible = tabs.buttons.allElementsBoundByIndex.filter {
                let visibleFrame = $0.frame.intersection(viewport)
                return !visibleFrame.isNull && visibleFrame.width > 1 && visibleFrame.height > 1
            }
                .compactMap { Int($0.identifier.replacingOccurrences(of: "sp.tab.", with: "")) }
            guard let first = visible.min() else { break }
            let towardStart = index < first
            let rtl = (status.value as? String)?.contains("direction=rtl") == true
            // 短标签容易被快速 swipe 的惯性整段越过；使用小幅拖动逐步查找。
            // 目标已露出一部分时按物理位置补足；它等于首个可见索引，不能按 index < first 判断方向。
            let movesRight = target.exists ? target.frame.midX < viewport.midX : towardStart != rtl
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
        let leftEdge = app.buttons["sp.tab.\(rtl ? 12 : 0)"]
        let rightEdge = app.buttons["sp.tab.\(rtl ? 0 : 12)"]
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

    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        // 设备方向请求可能被模拟器忽略；必须看到系统界面方向改变，不能在原方向下误报通过。
        let expected: UIInterfaceOrientation = orientation == .landscapeLeft ? .landscapeRight
            : orientation == .landscapeRight ? .landscapeLeft : .portrait
        expect("interfaceOrientation=\(expected.rawValue);")
        print("INTERFACE ORIENTATION: \(expected.rawValue), window=\(app.windows.firstMatch.frame)")
    }

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
        print("WINDOW GEOMETRY \(phase): window=\(app.windows.firstMatch.frame), list=\(app.tables["demo.list"].frame), tabs=\(app.collectionViews["sp.tabBar.collection"].frame), state=\(status.value ?? "")")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = phase; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func contentPosition() -> CGFloat {
        let table = app.tables["demo.list"]
        guard let value = table.value as? String, let data = value.data(using: .utf8),
              let geometry = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let position = geometry["position"] else {
            XCTFail("未取得 UITableView 的真实滚动坐标")
            return .nan
        }
        // Demo 的 Header 高度为 220，吸顶基线为当前窗口中的导航栏底边。
        let safeTop = app.navigationBars.firstMatch.frame.maxY - app.windows.firstMatch.frame.minY
        return max(0, CGFloat(position) - max(0, 220 - safeTop))
    }

    private func assertPageFrame(_ page: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(page.frame.minX, window.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(page.frame.maxX, window.maxX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(page.frame.width, window.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(page.frame.minY, app.collectionViews["sp.tabBar.collection"].frame.maxY, accuracy: 1,
                       "页面根视图应始终紧接当前标签栏底部", file: file, line: line)
        XCTAssertEqual(page.frame.maxY, window.maxY, accuracy: 1,
                       "页面根视图应始终延伸至实际窗口底边", file: file, line: line)
    }

    private func assertListSafeArea(file: StaticString = #filePath, line: UInt = #line) {
        let table = app.tables["demo.list"]
        assertPageFrame(table, file: file, line: line)
        guard let value = table.value as? String, let data = value.data(using: .utf8),
              let geometry = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let left = geometry["safeLeft"], let right = geometry["safeRight"] else {
            XCTFail("未取得内容页原生安全区域", file: file, line: line)
            return
        }
        let viewport = app.collectionViews["sp.tabBar.collection"].frame
        XCTAssertEqual(table.frame.minX + CGFloat(left), viewport.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(table.frame.maxX - CGFloat(right), viewport.maxX, accuracy: 1, file: file, line: line)
        print("PAGE GEOMETRY: window=\(app.windows.firstMatch.frame), page=\(table.frame), safeLeft=\(left), safeRight=\(right), tabs=\(viewport)")
    }

    private func assertGridCellsSafeArea(file: StaticString = #filePath, line: UInt = #line) {
        let grid = app.collectionViews["demo.grid"]
        assertPageFrame(grid, file: file, line: line)
        let safeViewport = app.collectionViews["sp.tabBar.collection"].frame
        let cells = (0..<3).map { grid.cells["demo.grid.cell.\($0)"].frame }
        for cell in cells {
            XCTAssertEqual(cell.minY, cells[0].minY, accuracy: 1, "网格应在安全区域内保持三列", file: file, line: line)
            XCTAssertGreaterThanOrEqual(cell.minX, safeViewport.minX + 11, file: file, line: line)
            XCTAssertLessThanOrEqual(cell.maxX, safeViewport.maxX - 11, file: file, line: line)
            XCTAssertEqual(cell.width, floor((safeViewport.width - 40) / 3), accuracy: 1, file: file, line: line)
        }
        XCTAssertEqual(cells.map(\.minX).min()!, safeViewport.minX + 12, accuracy: 1, file: file, line: line)
        XCTAssertEqual(cells.map(\.maxX).max()!, safeViewport.maxX - 12, accuracy: 1, file: file, line: line)
        print("GRID CELLS: window=\(app.windows.firstMatch.frame), safeViewport=\(safeViewport), cells=\(cells)")
    }

    func testGridCellsRespectSafeAreaAcrossRotations() {
        for rtl in [false, true] {
            app.terminate()
            app.launchArguments = ["--open-demo", "--window-regression"] + (rtl ? ["--rtl"] : [])
            app.launch()
            expect("page=grid")
            for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft, .landscapeRight, .portrait] {
                rotate(to: orientation)
                assertGridCellsSafeArea()
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "网格安全区域-\(rtl ? "rtl" : "ltr")-\(orientation.rawValue)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    private func assertPinnedList(position: CGFloat) {
        expect("page=list"); expect("progress=1.00")
        let table = app.tables["demo.list"]
        let tab = app.buttons["sp.tab.1"]
        XCTAssertEqual(tab.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        XCTAssertEqual(table.frame.minY, tab.frame.maxY, accuracy: 1)
        XCTAssertEqual(table.frame.minX, app.windows.firstMatch.frame.minX, accuracy: 1)
        XCTAssertEqual(table.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        assertListSafeArea()
        XCTAssertEqual(contentPosition(), position, accuracy: 1)
    }

    /// 使用真实触摸覆盖展开、部分折叠和吸顶；短列表不会改变原列表保存的正文位置。
    private func verifyRootFollowsHeaderInCurrentWindow() {
        select(2); expect("page=short")
        let table = app.tables["demo.list"]
        table.swipeDown(); expect("progress=0.00")
        assertListSafeArea(); recordWindow("Header 展开")
        select(4); expect("page=plain")
        assertPageFrame(app.staticTexts["demo.plain"])
        select(2); expect("page=short")
        let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -35)),
                    withVelocity: .slow, thenHoldForDuration: 0.5)
        let progress = (status.value as? String)?.components(separatedBy: "progress=").last.flatMap(Double.init)
        XCTAssertNotNil(progress)
        XCTAssertGreaterThan(progress ?? 0, 0)
        XCTAssertLessThan(progress ?? 1, 1)
        assertListSafeArea(); recordWindow("Header 部分折叠")
        table.swipeUp(); expect("progress=1.00")
        assertListSafeArea(); recordWindow("Header 再次吸顶")
        select(1); expect("page=list")
    }

    func testSystemWindowResizePreservesPinnedListAndPaging() throws {
        try verifySystemWindowResize(rtl: false)
    }

    func testSystemWindowResizeRTLPreservesPinnedListAndPaging() throws {
        try verifySystemWindowResize(rtl: true)
    }

    private func verifySystemWindowResize(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统窗口缩放仅适用于 iPad")
        expect(rtl ? "direction=rtl" : "direction=ltr")
        select(1)
        let table = app.tables["demo.list"]
        table.swipeUp(); expect("progress=1.00")
        let initialPosition = contentPosition()
        let full = app.windows.firstMatch.frame
        resizeSystemWindow(dx: -250, dy: -350)
        XCTAssertLessThan(app.windows.firstMatch.frame.width, full.width - 100)
        assertPinnedList(position: initialPosition); recordWindow("浮动小窗口")
        verifyRootFollowsHeaderInCurrentWindow()
        assertPinnedList(position: initialPosition)
        for delta: CGVector in [CGVector(dx: 160, dy: 120), CGVector(dx: -80, dy: -60)] {
            let before = app.windows.firstMatch.frame
            resizeSystemWindow(dx: delta.dx, dy: delta.dy)
            XCTAssertGreaterThan(abs(app.windows.firstMatch.frame.width - before.width), 40)
            assertPinnedList(position: initialPosition); recordWindow("连续缩放 \(delta)")
            try swipePage(towardNext: true, rtl: rtl, expectedPage: "short"); assertListSafeArea()
            try swipePage(towardNext: false, rtl: rtl, expectedPage: "list"); assertPinnedList(position: initialPosition)
            verifyRootFollowsHeaderInCurrentWindow()
            assertPinnedList(position: initialPosition)
        }
        // 重新触摸必须仍可滚动，切回后保存该次滚动的位置。
        table.swipeUp()
        _ = try pagingTrace()
        let moved = contentPosition()
        XCTAssertGreaterThan(moved, initialPosition + 50)
        restoreFullScreen()
        assertPinnedList(position: moved); recordWindow("恢复全屏")
        verifyRootFollowsHeaderInCurrentWindow()
        assertPinnedList(position: moved)
    }

    func testSystemSplitWindowsPreservePositionAndPaging() throws {
        try verifySystemSplitWindows(rtl: false)
    }

    func testSystemSplitWindowsRTLPreservePositionAndPaging() throws {
        try verifySystemSplitWindows(rtl: true)
    }

    private func arrangeSideBySide() {
        app.activate()
        springboard.buttons["window-controls:dev.stickypager.StickyPagerDemo"].tap()
        springboard.buttons["Zoom-button"].press(forDuration: 1)
        springboard.buttons["左右"].tap()
    }

    private func pagingTrace(file: StaticString = #filePath, line: UInt = #line) throws -> [String: Any] {
        let value = status.value as? String ?? ""
        let encoded = value.components(separatedBy: ";").first?.replacingOccurrences(of: "gesture=", with: "") ?? ""
        let data = try XCTUnwrap(Data(base64Encoded: encoded), file: file, line: line)
        let trace = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], file: file, line: line)
        print("PAGING TRACE \(String(data: data, encoding: .utf8) ?? "")")
        return trace
    }

    /// 默认 swipe 的固定 200 pt 行程可能不足半页，改用当前实际视口内的确定行程。
    /// 终点停留消除松手速度的影响；只发送一次触摸，不重试、不用标签点击代替翻页。
    private func swipePage(towardNext: Bool, rtl: Bool, expectedPage: String, from page: XCUIElement? = nil,
                           file: StaticString = #filePath, line: UInt = #line) throws {
        let before = try pagingTrace(file: file, line: line)
        let window = app.windows.firstMatch.frame
        let viewport = (page ?? app.tables["demo.list"]).frame.intersection(window)
        XCTAssertGreaterThan(viewport.width, 200, file: file, line: line)
        let movesLeft = towardNext != rtl
        let startPoint = CGPoint(x: viewport.minX + viewport.width * (movesLeft ? 0.85 : 0.15), y: viewport.midY)
        let endPoint = CGPoint(x: viewport.minX + viewport.width * (movesLeft ? 0.15 : 0.85), y: viewport.midY)
        // 分页触摸绑定业务窗口；AX frame 是屏幕坐标，先减去浮动/右侧窗口原点。
        // SpringBoard 坐标仅用于系统窗口控件，避免将应用内拖动路由给系统进程。
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        print("PAGING INPUT window=\(window) start=\(startPoint) end=\(endPoint)")
        origin.withOffset(CGVector(dx: startPoint.x - window.minX, dy: startPoint.y - window.minY)).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(CGVector(dx: endPoint.x - window.minX, dy: endPoint.y - window.minY)),
            withVelocity: .slow, thenHoldForDuration: 0.2)
        let trace = try pagingTrace(file: file, line: line)
        XCTAssertGreaterThan(try XCTUnwrap(trace["sequence"] as? Int), try XCTUnwrap(before["sequence"] as? Int), file: file, line: line)
        let samples = try XCTUnwrap(trace["samples"] as? [[String: Double]])
        XCTAssertEqual(samples.last?["phase"], 3, "触摸必须正常结束，不能将输入取消误报为分页失败", file: file, line: line)
        let width = try XCTUnwrap(trace["width"] as? Double)
        let touchTravel = abs(try XCTUnwrap(samples.last?["x"]) - XCTUnwrap(samples.first?["x"]))
        XCTAssertGreaterThan(touchTravel, width * 0.65, "应用必须收到完整水平拖动", file: file, line: line)
        let travel = try XCTUnwrap(trace["maxOffset"] as? Double) - XCTUnwrap(trace["minOffset"] as? Double)
        XCTAssertGreaterThan(travel, width * 0.5, "实际分页位移必须越过半页", file: file, line: line)
        let release = try XCTUnwrap(trace["release"] as? [String: Double])
        let initial = try XCTUnwrap(before["offset"] as? Double)
        XCTAssertEqual(try XCTUnwrap(release["target"]), initial + (movesLeft ? width : -width), accuracy: 1, file: file, line: line)
        expect("page=\(expectedPage)")
        let settled = try pagingTrace(file: file, line: line)
        XCTAssertEqual(try XCTUnwrap(settled["offset"] as? Double), try XCTUnwrap(release["target"]), accuracy: 1, file: file, line: line)
        XCTAssertEqual(settled["dragging"] as? Bool, false, file: file, line: line)
        XCTAssertEqual(settled["decelerating"] as? Bool, false, file: file, line: line)
    }

    func testSystemSplitPagingGestureBoundaries() throws {
        try verifyPagingGestureBoundaries(rtl: false)
    }

    func testSystemSplitWindowsRTLPagingGestureBoundaries() throws {
        try verifyPagingGestureBoundaries(rtl: true)
    }

    private func verifyPagingGestureBoundaries(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        expect(rtl ? "direction=rtl" : "direction=ltr")
        select(1)
        app.tables["demo.list"].swipeUp(); expect("progress=1.00")
        let position = contentPosition()
        resizeSystemWindow(dx: -250, dy: -350)
        let companion = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        // 陪测应用只需提供第二个窗口；复用系统恢复的实例，避免 launch 强制终止再启动。
        companion.activate(); arrangeSideBySide()
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft] {
            rotate(to: orientation)
            if app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame).width > 1 { arrangeSideBySide() }
            XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame).width, 1)
            assertPinnedList(position: position)
            // 低速、短于半页的触摸应按 UIKit 目标回到原页；框架不能强行翻页。
            let before = try pagingTrace()
            let table = app.tables["demo.list"]
            print("VERTICAL BEFORE \(table.value ?? "")")
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: rtl ? -100 : 100, dy: 0))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: rtl ? 200 : -200, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
            expect("page=list")
            let cancelled = try pagingTrace()
            print("VERTICAL AFTER \(table.value ?? "")")
            let release = try XCTUnwrap(cancelled["release"] as? [String: Double])
            XCTAssertEqual(try XCTUnwrap(release["target"]), try XCTUnwrap(before["offset"] as? Double), accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(cancelled["offset"] as? Double), try XCTUnwrap(release["target"]), accuracy: 1)
            assertPinnedList(position: position)
            for _ in 0..<3 {
                try swipePage(towardNext: true, rtl: rtl, expectedPage: "short")
                assertListSafeArea()
                try swipePage(towardNext: false, rtl: rtl, expectedPage: "list")
                assertPinnedList(position: position)
            }
            recordWindow("分页手势边界-\(rtl ? "rtl" : "ltr")-\(orientation.rawValue)")
        }
    }

    private func verifySystemSplitWindows(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        expect(rtl ? "direction=rtl" : "direction=ltr")
        let companion = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        select(1)
        app.tables["demo.list"].swipeUp(); expect("progress=1.00")
        let initialPosition = contentPosition()
        resizeSystemWindow(dx: -250, dy: -350)
        companion.activate()
        arrangeSideBySide()
        print("SPLIT WINDOWS", app.windows.firstMatch.frame, companion.windows.firstMatch.frame)
        assertPinnedList(position: initialPosition); recordWindow("系统左右分屏")
        let left = app.windows.firstMatch.frame, right = companion.windows.firstMatch.frame
        XCTAssertLessThan(left.width, springboard.frame.width * 0.7)
        XCTAssertLessThan(right.width, springboard.frame.width * 0.7)
        XCTAssertLessThanOrEqual(left.intersection(right).width, 1)
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft, .portrait] {
            rotate(to: orientation)
            assertPinnedList(position: initialPosition)
            // 系统旋转可能将左右排列恢复为浮动窗口；先验证该状态，再重新建立真实分屏。
            if app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame).width > 1 {
                recordWindow("旋转后浮动窗口-\(rtl ? "rtl" : "ltr")-\(orientation.rawValue)")
                arrangeSideBySide()
            }
            let pageWindow = app.windows.firstMatch.frame
            let companionWindow = companion.windows.firstMatch.frame
            let screen = springboard.frame
            let screenWidth = orientation.isLandscape ? max(screen.width, screen.height) : min(screen.width, screen.height)
            XCTAssertLessThan(pageWindow.width, screenWidth * 0.7)
            XCTAssertLessThan(companionWindow.width, screenWidth * 0.7)
            XCTAssertLessThanOrEqual(pageWindow.intersection(companionWindow).width, 1)
            assertPinnedList(position: initialPosition)
            try swipePage(towardNext: true, rtl: rtl, expectedPage: "short"); assertListSafeArea()
            try swipePage(towardNext: false, rtl: rtl, expectedPage: "list"); assertPinnedList(position: initialPosition)
            select(0); expect("page=grid"); assertGridCellsSafeArea()
            select(1); expect("page=list"); assertPinnedList(position: initialPosition)
            recordWindow("系统分屏-\(rtl ? "rtl" : "ltr")-\(orientation.rawValue)")
            verifyRootFollowsHeaderInCurrentWindow()
            assertPinnedList(position: initialPosition)
        }
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
            XCTAssertEqual(app.tables["demo.list"].frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 1,
                           "吸顶时内容页应延伸到实际窗口底边", file: file, line: line)
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
        rotate(to: .landscapeLeft)
        assertPinned()
        rotate(to: .portrait)
        assertPinned()
    }

    func testSiblingLabelFollowsTabBarDuringScrollAndPaging() {
        select(1)
        let label = app.staticTexts["demo.mixed.label"]
        let table = app.tables["demo.list"]
        func assertGeometry(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertTrue(label.isHittable, file: file, line: line)
            XCTAssertEqual(label.frame.minY, app.buttons["sp.tab.1"].frame.maxY + 12, accuracy: 1, file: file, line: line)
            XCTAssertEqual(table.frame.minY, label.frame.maxY + 8, accuracy: 1, file: file, line: line)
            XCTAssertEqual(table.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 1, file: file, line: line)
        }
        expect("progress=0.00")
        assertGeometry()
        XCTAssertEqual(table.cells.firstMatch.frame.minY, table.frame.minY, accuracy: 1)
        table.swipeUp()
        expect("progress=1.00")
        assertGeometry()
        table.swipeUp()
        assertGeometry()
        select(0); select(1)
        expect("progress=1.00")
        assertGeometry()
        rotate(to: .landscapeLeft)
        assertGeometry()
        rotate(to: .portrait)
        assertGeometry()
        for _ in 0..<8 {
            if (status.value as? String)?.contains("progress=0.00") == true { break }
            table.swipeDown()
        }
        expect("progress=0.00")
        assertGeometry()
        XCTAssertEqual(table.cells.firstMatch.frame.minY, table.frame.minY, accuracy: 1)
        // 展开后用新触摸再次折叠，验证 inset 更新未破坏原生拖动。
        table.swipeUp()
        expect("progress=1.00")
        assertGeometry()
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
    func testDynamicTabContentAndDisabledItemStillAllowsPaging() {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let oldHeight = tabs.frame.height
        app.buttons["demo.pages"].tap()
        app.buttons["切换图文标签"].tap()
        XCTAssertGreaterThan(tabs.frame.height, oldHeight)
        app.buttons["demo.pages"].tap()
        app.buttons["更新角标和标题"].tap()
        XCTAssertEqual(app.buttons["sp.tab.0"].label, "新作品")
        XCTAssertEqual(app.buttons["sp.tab.0"].value as? String, "99+")
        app.buttons["demo.pages"].tap()
        app.buttons["切换第二项禁用"].tap()
        XCTAssertFalse(app.buttons["sp.tab.1"].isEnabled)
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        app.buttons["demo.pages"].tap()
        app.buttons["切换选中样式"].tap()
        expect("page=list")
    }

    func testStandaloneTabGallerySelectionAndLiveContent() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["标签外观"].tap()
        let favorites = app.buttons["sp.tab.1"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        favorites.tap()
        XCTAssertTrue(favorites.isSelected)
        app.buttons["配置"].tap()
        app.buttons["更新内容"].tap()
        XCTAssertEqual(favorites.value as? String, "99+")
        app.buttons["配置"].tap()
        app.buttons["横向图文"].tap()
        XCTAssertTrue(favorites.isSelected)
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
    func testRTLHorizontalPaging() throws {
        app.terminate()
        app.launchArguments = ["--rtl", "--window-regression", "--paging-trace"]
        app.launch()
        app.buttons["demo.open"].tap()
        expect("direction=rtl")
        try swipePage(towardNext: true, rtl: true, expectedPage: "list", from: app.collectionViews["demo.grid"])
        select(0); expect("page=grid")
        select(9); expect("page=weekly")
        expectSelectedTabAlignment(9)
    }
    func testSafeAreaTabsLTR() { verifySafeAreaTabs(rtl: false, largeText: false) }
    func testSafeAreaTabsRTL() { verifySafeAreaTabs(rtl: true, largeText: false) }
    func testSafeAreaTabsLargeTextLTR() { verifySafeAreaTabs(rtl: false, largeText: true) }
    func testSafeAreaTabsLargeTextRTL() { verifySafeAreaTabs(rtl: true, largeText: true) }

    func testTabScrollEdgeAppearance() {
        for rtl in [false, true] {
            app.terminate()
            app.launchArguments = ["--open-demo", "--window-regression"] + (rtl ? ["--rtl"] : [])
            app.launch()
            XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
            rotate(to: .landscapeLeft)
            let tabs = app.collectionViews["sp.tabBar.collection"]
            for index in [0, 10, 12] {
                select(index)
                expectSelectedTabAlignment(index)
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "tab-edge-\(rtl ? "rtl" : "ltr")-\(index)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            // 小幅拖离端点，保存文字经过裁切边缘的状态；滚动不改变当前页面。
            let start = tabs.coordinate(withNormalizedOffset: CGVector(dx: rtl ? 0.6 : 0.4, dy: 0.5))
            let end = tabs.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            expect("page=topics")
            let scrolled = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            scrolled.name = "tab-edge-\(rtl ? "rtl" : "ltr")-scrolled"
            scrolled.lifetime = .keepAlways
            add(scrolled)
            select(0)
            expect("page=grid")
            expectSelectedTabAlignment(0)
        }
    }

    private func verifySafeAreaTabs(rtl: Bool, largeText: Bool) {
        app.terminate()
        app.launchArguments = ["--open-demo", "--window-regression"] + (rtl ? ["--rtl"] : [])
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for (step, orientation) in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight, .portrait].enumerated() {
            rotate(to: orientation)
            expect(step == 0 ? "page=grid" : "page=weekly")
            expectSelectedTabAlignment(step == 0 ? 0 : 9)
            select(0); expect("page=grid")
            assertPageFrame(app.collectionViews["demo.grid"])
            expectSelectedTabAlignment(0)
            let viewport = tabs.frame
            let window = app.windows.firstMatch.frame
            if orientation == .portrait || UIDevice.current.userInterfaceIdiom == .pad {
                XCTAssertEqual(viewport.minX, window.minX, accuracy: 1)
                XCTAssertEqual(viewport.maxX, window.maxX, accuracy: 1)
            } else {
                XCTAssertGreaterThan(viewport.minX, app.frame.minX)
                XCTAssertLessThan(viewport.maxX, app.frame.maxX)
                // 安全区域外的背景不应命中标签或切换页面。
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewport.minX / 2, dy: viewport.midY)).tap()
                expect("page=grid")
            }
            if largeText { XCTAssertGreaterThan(viewport.height, 44) }
            else { XCTAssertEqual(viewport.height, 44, accuracy: 1) }
            select(12); expect("page=topics")
            expectSelectedTabAlignment(12)
            select(9); expect("page=weekly")
            assertListSafeArea()
            expectSelectedTabAlignment(9)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "safe-area-\(rtl ? "rtl" : "ltr")-\(largeText ? "axxxl" : "default")-\(orientation.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            // 从标签栏内开始纵向拖动，避免横屏时列表的默认 swipe 起点落入底部工具栏。
            let expandedCenterY = tabs.frame.midY
            // tabs.frame 是屏幕坐标；浮动窗口有非零原点，不能再叠加应用窗口的位置。
            let origin = springboard.coordinate(withNormalizedOffset: .zero)
            let collapseStart = origin.withOffset(CGVector(dx: tabs.frame.midX, dy: expandedCenterY))
            collapseStart.press(forDuration: 0.05,
                                thenDragTo: origin.withOffset(CGVector(dx: tabs.frame.midX, dy: app.navigationBars.firstMatch.frame.maxY + 4)),
                                withVelocity: .slow, thenHoldForDuration: 0.2)
            expect("progress=1.00")
            assertListSafeArea()
            XCTAssertEqual(tabs.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
            let collapsed = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            collapsed.name = "safe-area-collapsed-\(rtl ? "rtl" : "ltr")-\(largeText ? "axxxl" : "default")-\(orientation.rawValue)"
            collapsed.lifetime = .keepAlways
            add(collapsed)
            // 折叠拖动也可能推进正文；用后续新触摸消耗这段位移，再恢复完全展开。
            for _ in 0..<3 {
                if (status.value as? String)?.contains("progress=0.00") == true { break }
                let expandStart = origin.withOffset(CGVector(dx: tabs.frame.midX, dy: tabs.frame.midY))
                expandStart.press(forDuration: 0.05,
                                  thenDragTo: origin.withOffset(CGVector(dx: tabs.frame.midX, dy: min(app.windows.firstMatch.frame.maxY - 90, expandedCenterY + 90))),
                                  withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            expect("progress=0.00")
            assertListSafeArea()
        }
    }

    func testRotationAndBackGesture() {
        select(1)
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait] {
            rotate(to: orientation)
            expect("page=list"); expect("progress=1.00")
            XCTAssertEqual(app.buttons["sp.tab.1"].frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
            XCTAssertEqual(app.tables["demo.list"].frame.minY, app.buttons["sp.tab.1"].frame.maxY, accuracy: 1)
            assertListSafeArea()
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

    func testScrollIndicatorWithShortEmptyAndLongContent() {
        for (index, page) in [(2, "short"), (3, "empty"), (1, "list")] {
            select(index)
            // 相邻页动画期间可同时存在两个同名表格，提交选择后再发送新触摸。
            expect("page=\(page)")
            let table = app.tables["demo.list"]
            table.swipeUp()
            expect("page=\(page)"); expect("progress=1.00")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "滚动指示器-\(page)-吸顶"
            attachment.lifetime = .keepAlways
            add(attachment)
            if page == "short" {
                XCTAssertTrue(table.staticTexts["内容 1"].isHittable)
                XCTAssertTrue(table.staticTexts["内容 3"].isHittable)
            }
            // 指示器配置不得影响新触摸展开 Header。
            table.swipeDown()
            if page != "list" { expect("progress=0.00") }
        }
    }
}
