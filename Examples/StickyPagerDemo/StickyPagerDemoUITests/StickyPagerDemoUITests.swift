import XCTest

@MainActor
final class StickyPagerDemoUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
        app.launchArguments = ["--window-regression"]
        if name.contains("testDisabledListStopsHeaderAndTabDraggingButAllowsPaging") {
            app.launchArguments.append("--disabled-list-regression")
        }
        if name.contains("testOptInPagingIndicatorVisibility") {
            app.launchArguments.append("--hide-indicators-during-paging")
        }
        if name.contains("WithAccessories") {
            app.launchArguments.append("--accessories")
        }
        if name.contains("testSystemSplit") || name
            .contains("testSystemWindowResize") || name.contains("testRotationAndBackGesture") || name
            .contains("testPagesMenu") || name.contains("testAutomaticCustomTabHeight") {
            app.launchArguments.append("--paging-trace")
        }
        if name.contains("CoalescedPaging") {
            app.launchArguments += ["--split-self-sizing-regression", "--coalesced-pan-regression"]
        }
        if name.contains("MomentumPaging") || name.contains("CancelledNativePaging") || name
            .contains("ReversingNativePaging") {
            app.launchArguments += ["--split-self-sizing-regression", "--coalesced-pan-regression"]
        }
        if name.contains("MomentumPaging") {
            app.launchArguments.append("--momentum-pan-regression")
        }
        if name.contains("CancelledNativePaging") {
            app.launchArguments.append("--cancel-pan-regression")
        }
        if name.contains("RowBoundary") {
            app.launchArguments += ["--split-self-sizing-regression", "--row-boundary-regression"]
        }
        if name.contains("ExactRegressionPosition") {
            app.launchArguments += ["--split-self-sizing-regression", "--exact-split-position-regression"]
        }
        if name.contains("SelfSizingPosition") {
            app.launchArguments.append("--split-self-sizing-regression")
        }
        if name.contains("testSiblingLabel") {
            app.launchArguments.append("--mixed-page")
        }
        if name.contains("testSystemSplitWindowsRTL") || name
            .contains("testSystemWindowResizeRTL") {
            app.launchArguments.append("--rtl")
        }
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
        UITestOrientation.set(.portrait)
        app.terminate()
    }

    private var status: XCUIElement {
        app.staticTexts["demo.status"]
    }

    /// 单次点击后检查真实输入和菜单响应；不以再次点击补救菜单丢失。
    @discardableResult
    private func openPagesMenu() throws -> Int {
        let before = try pagingTrace()
        let sequence = try XCTUnwrap(before["sequence"] as? Int)
        app.buttons["demo.pages"].tap()
        try assertMenuInput(sequence: sequence + 1)
        XCTAssertTrue(app.buttons["切换自定义标签"].waitForExistence(timeout: 5), "单次点击后页面菜单未保持展开")
        try assertMenuInput(sequence: sequence + 1)
        return sequence + 1
    }

    private func assertMenuInput(sequence: Int) throws {
        let trace = try pagingTrace()
        XCTAssertEqual(try XCTUnwrap(trace["sequence"] as? Int), sequence, "菜单阶段出现非预期触摸")
        XCTAssertEqual(try XCTUnwrap(trace["pointerScrollEvents"] as? Int), 0, "触摸回归期间收到额外滚轮／触控板输入")
    }

    func testPagesMenuRemainsPresentedUntilAction() throws {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let initialHeight = tabs.frame.height
        // 四轮分别验证默认、自定义及往返切换；任一轮失败即停止，没有失败重试。
        for index in 0 ..< 4 {
            let sequence = try openPagesMenu()
            let action = app.buttons["切换自定义标签"]
            let disappeared = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: action
            )
            disappeared.isInverted = true
            // 覆盖历史故障中入口点击返回前约 15 秒的空闲窗口。
            XCTAssertEqual(XCTWaiter.wait(for: [disappeared], timeout: 15), .completed, "未操作时菜单自行关闭")
            try assertMenuInput(sequence: sequence)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "页面菜单保持-\(index + 1)"
            attachment.lifetime = .keepAlways
            add(attachment)
            action.tap()
            try assertMenuInput(sequence: sequence + 1)
            XCTAssertFalse(action.exists)
            if index.isMultiple(of: 2) {
                XCTAssertGreaterThan(tabs.frame.height, initialHeight)
            } else {
                XCTAssertEqual(tabs.frame.height, initialHeight, accuracy: 1)
            }
            XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
            expect("page=grid")
        }
    }

    func testPagesMenuCancelsAndReopensWithoutChangingPage() throws {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let initialHeight = tabs.frame.height
        let sequence = try openPagesMenu()
        // 入口在右侧，使用窗口左侧的真实触摸取消，避免隐式滚动菜单项。
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.6)).tap()
        try assertMenuInput(sequence: sequence + 1)
        XCTAssertFalse(app.buttons["切换自定义标签"].exists)
        XCTAssertEqual(tabs.frame.height, initialHeight, accuracy: 1)
        expect("page=grid")
        try openPagesMenu()
        app.buttons["留白与附件"].tap()
        app.buttons["内容留白"].tap()
        app.buttons["对称留白"].tap()
        XCTAssertGreaterThan(tabs.frame.height, initialHeight)
        assertPageFrame(app.collectionViews["demo.grid"])
        try openPagesMenu()
        app.buttons["留白与附件"].tap()
        app.buttons["内容留白"].tap()
        app.buttons["无留白"].tap()
        XCTAssertEqual(tabs.frame.height, initialHeight, accuracy: 1)
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
        expect("page=grid")
    }

    func testPagesMenuOutsideDragCancelsWithoutInvokingAction() throws {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let initialHeight = tabs.frame.height
        let sequence = try openPagesMenu()
        let action = app.buttons["切换自定义标签"]
        let window = app.windows.firstMatch
        // 菜单外的真实触摸拖动是取消操作；不能与没有 UITouch 的滚轮输入混为一谈。
        // 按窗口比例取左侧路径，避免经过右侧菜单或依赖固定像素距离。
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.7))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(
                withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)
            ))
        try assertMenuInput(sequence: sequence + 1)
        let dragTrace = try pagingTrace()
        let samples = try XCTUnwrap(dragTrace["samples"] as? [[String: Double]])
        let startY = try XCTUnwrap(samples.first?["y"])
        let endY = try XCTUnwrap(samples.last?["y"])
        XCTAssertGreaterThan(startY - endY, window.frame.height * 0.1, "必须实际拖动，不能退化为菜单外点击")
        XCTAssertFalse(action.exists)
        XCTAssertEqual(tabs.frame.height, initialHeight, accuracy: 1)
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
        expect("page=grid")
        // 这是取消后的独立交互，不在菜单丢失时重开补救；前面的取消断言必须先通过。
        let reopenedSequence = try openPagesMenu()
        action.tap()
        try assertMenuInput(sequence: reopenedSequence + 1)
        XCTAssertFalse(action.exists)
        XCTAssertGreaterThan(tabs.frame.height, initialHeight)
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
        expect("page=grid")
    }

    func testPagesMenuPointerObservationPreservesTouchSamples() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "XCTest 的 pointer 输入仅在本用例的 iPad 环境受支持")
        try openPagesMenu()
        let before = try pagingTrace()
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
            .scroll(byDeltaX: 0, deltaY: -20)
        let after = try pagingTrace()
        // 该用例验证输入观测，不把 pointer 滚动与菜单关闭建立未经证实的契约。
        XCTAssertGreaterThan(try XCTUnwrap(after["pointerScrollEvents"] as? Int), 0)
        XCTAssertGreaterThan(try XCTUnwrap(after["lastPointerScrollTimestamp"] as? Double), 0)
        XCTAssertEqual(try XCTUnwrap(after["sequence"] as? Int), try XCTUnwrap(before["sequence"] as? Int))
        XCTAssertEqual(try XCTUnwrap(after["sampleCount"] as? Int), try XCTUnwrap(before["sampleCount"] as? Int))
        XCTAssertEqual(
            try XCTUnwrap(after["samples"] as? [[String: Double]]),
            try XCTUnwrap(before["samples"] as? [[String: Double]])
        )
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
        expect("page=grid")
    }

    private func expect(_ fragment: String) {
        // 将条件交给元素查询，避免在 XCTWaiter 的谓词回调中同步请求整棵 AX 快照。
        let matchingState = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label CONTAINS %@",
            "demo.status",
            fragment
        )).firstMatch
        XCTAssertTrue(matchingState.waitForExistence(timeout: 5), "等待状态 \(fragment)")
    }

    /// 排除窗口外及工具栏遮挡的区域，保证最大字号横屏时仍发送真实标签触摸。
    private func tabTouchViewport(_ tabs: XCUIElement) -> CGRect {
        var viewport = tabs.frame.intersection(app.windows.firstMatch.frame)
        let toolbar = app.toolbars.firstMatch
        if toolbar.exists, toolbar.frame.intersects(viewport) {
            viewport.size.height = max(0, toolbar.frame.minY - viewport.minY)
        }
        return viewport
    }

    private func select(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let target = app.buttons["sp.tab.\(index)"]
        // 标签可能尚未创建 Cell；先滚动至可见，避免依赖 XCTest 对屏幕外元素的隐式滚动。
        for _ in 0 ..< 20 {
            let tabFrame = tabs.frame
            let viewport = tabTouchViewport(tabs)
            if target.exists {
                let visibleFrame = target.frame.intersection(viewport)
                if !visibleFrame.isNull, visibleFrame.width >= min(44, target.frame.width), visibleFrame.height >= 20 {
                    // 点击真实露出的按钮区域；避免 XCTest 在裁切标签上查询无效激活点。
                    tabs.coordinate(withNormalizedOffset: .zero).withOffset(
                        CGVector(dx: visibleFrame.midX - tabFrame.minX, dy: visibleFrame.midY - tabFrame.minY)
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
            guard let first = visible.min() else {
                break
            }
            let towardStart = index < first
            let rtl = status.exists && (status.value as? String)?.contains("direction=rtl") == true
            // 短标签容易被快速 swipe 的惯性整段越过；使用小幅拖动逐步查找。
            // 目标已露出一部分时按物理位置补足；它等于首个可见索引，不能按 index < first 判断方向。
            let movesRight = target.exists ? target.frame.midX < viewport.midX : towardStart != rtl
            let origin = tabs.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: viewport.minX - tabFrame.minX + viewport.width * (movesRight ? 0.3 : 0.7),
                dy: viewport.midY - tabFrame.minY
            ))
            let end = origin.withOffset(CGVector(
                dx: viewport.minX - tabFrame.minX + viewport.width * (movesRight ? 0.7 : 0.3),
                dy: viewport.midY - tabFrame.minY
            ))
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
            guard selected.isSelected else {
                return false
            }
            // 大字号自定义卡片允许宽于视口，此时契约是居中显示，不能要求整项同时落入视口。
            if frame.width > viewport.width {
                return abs(frame.midX - viewport.midX) < 1 && frame.minX <= viewport.minX && frame.maxX >= viewport.maxX
            }
            guard frame.minX >= viewport.minX - 1,
                  frame.maxX <= viewport.maxX + 1 else {
                return false
            }
            let delta = frame.midX - viewport.midX
            if abs(delta) < 1 {
                return true
            }
            // 无法继续居中时，首尾 Item 与视口边界之间保留默认的 16 pt 内容留白。
            if delta < 0 {
                return leftEdge.exists && abs(leftEdge.frame.minX - viewport.minX - 16) < 1
            }
            return rightEdge.exists && abs(viewport.maxX - rightEdge.frame.maxX - 16) < 1
        }
        expectation(for: aligned, evaluatedWith: selected)
        waitForExpectations(timeout: 5)
    }

    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        UITestOrientation.set(orientation)
        // 设备方向请求可能被模拟器忽略；必须看到系统界面方向改变，不能在原方向下误报通过。
        let expected: UIInterfaceOrientation = orientation == .landscapeLeft ? .landscapeRight
            : orientation == .landscapeRight ? .landscapeLeft : .portrait
        let matchingState = app.staticTexts.matching(NSPredicate(
            format: "identifier IN %@ AND label CONTAINS %@",
            ["demo.status", "demo.gallery.status"],
            "interfaceOrientation=\(expected.rawValue);"
        )).firstMatch
        XCTAssertTrue(matchingState.waitForExistence(timeout: 6), "请求界面方向 \(expected.rawValue)")
        print("INTERFACE ORIENTATION: \(expected.rawValue), window=\(app.windows.firstMatch.frame)")
    }

    private func openGallery() {
        // Duo 将返回控件放在侧边；它不属于顶部导航栏的按钮序列。
        let back = app.buttons["BackButton"]
        if back.exists {
            back.tap()
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
        app.buttons["标签外观"].tap()
        XCTAssertTrue(app.staticTexts["demo.gallery.status"].waitForExistence(timeout: 5))
    }

    private func choosePageAction(_ title: String) {
        app.buttons["demo.pages"].tap()
        XCTAssertTrue(app.buttons["留白与附件"].waitForExistence(timeout: 5))
        // 菜单 CollectionView 的无障碍高度可能包含裁切部分，使用最小承载区域的实际 frame。
        let panels = app.otherElements.containing(.button, identifier: "留白与附件")
            .allElementsBoundByIndex.map(\.frame).filter { $0.width > 100 && $0.height > 100 }
        guard let panel = panels.min(by: { $0.width * $0.height < $1.width * $1.height }) else {
            XCTFail("未取得页面菜单的可见承载区域")
            return
        }
        let window = app.windows.firstMatch.frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        for _ in 0 ..< 6 {
            let action = app.buttons[title]
            if action.exists {
                let visible = action.frame.intersection(panel)
                if !visible.isNull, visible.height >= min(32, action.frame.height) {
                    origin.withOffset(CGVector(dx: visible.midX - window.minX, dy: visible.midY - window.minY)).tap()
                    return
                }
            }
            let start = origin.withOffset(CGVector(
                dx: panel.midX - window.minX,
                dy: panel.minY + panel.height * 0.85 - window.minY
            ))
            let end = origin.withOffset(CGVector(
                dx: panel.midX - window.minX,
                dy: panel.minY + panel.height * 0.3 - window.minY
            ))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTFail("未能滚动到菜单项：\(title)")
    }

    private func horizontalSafeInsets() -> (left: CGFloat, right: CGFloat) {
        let values = Dictionary(
            (status.value as? String ?? "").split(separator: ";").compactMap { component -> (String, CGFloat)? in
                let pair = component.split(separator: "=", maxSplits: 1)
                guard pair.count == 2, let number = Double(pair[1]) else {
                    return nil
                }
                return (String(pair[0]), CGFloat(number))
            },
            uniquingKeysWith: { _, latest in latest }
        )
        guard let left = values["safeLeft"], let right = values["safeRight"] else {
            XCTFail("未取得窗口横向安全区域")
            return (0, 0)
        }
        return (left, right)
    }

    private func collapseHeaderByTouch() {
        let header = app.otherElements["demo.headerView"].frame
        let window = app.windows.firstMatch.frame
        let safe = horizontalSafeInsets()
        let x = (window.minX + safe.left + window.maxX - safe.right) / 2
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(
            dx: x - window.minX,
            dy: header.minY + header.height * 0.85 - window.minY
        ))
        let end = origin.withOffset(CGVector(dx: x - window.minX, dy: header.minY + header.height * 0.1 - window.minY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func dragVisibleList(_ table: XCUIElement, up: Bool) {
        let window = app.windows.firstMatch.frame
        let frame = table.frame.intersection(window)
        let bottom = min(frame.maxY, status.frame.minY - 24)
        let height = bottom - frame.minY
        XCTAssertGreaterThan(height, 100, "列表应保留可用于真实拖动的可见区域")
        let safe = horizontalSafeInsets()
        let x = (window.minX + safe.left + window.maxX - safe.right) / 2
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(
            dx: x - window.minX,
            dy: frame.minY + height * (up ? 0.85 : 0.15) - window.minY
        ))
        let end = origin.withOffset(CGVector(
            dx: x - window.minX,
            dy: frame.minY + height * (up ? 0.15 : 0.85) - window.minY
        ))
        print("LIST TOUCH: frame=\(frame), status=\(status.frame), bottom=\(bottom), x=\(x)")
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    private func restoreFullScreen() {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return
        }
        let frame = app.windows.firstMatch.frame
        guard frame.width < springboard.frame.width - 1 || frame.height < springboard.frame.height - 1 else {
            return
        }
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
        handle.press(
            forDuration: 0.2,
            thenDragTo: screen.withOffset(CGVector(dx: frame.maxX - 8 + dx, dy: frame.maxY - 8 + dy)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )
    }

    private func recordWindow(_ phase: String) {
        print(
            "WINDOW GEOMETRY \(phase): window=\(app.windows.firstMatch.frame), list=\(app.tables["demo.list"].frame), tabs=\(app.collectionViews["sp.tabBar.collection"].frame), state=\(status.value ?? "")"
        )
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = phase; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func contentPosition() -> CGFloat {
        // 一次远程快照取得三个坐标，避免窗口转场中混用不同帧的 table／导航栏／window。
        guard let root = try? app.snapshot() else {
            XCTFail("未取得应用几何快照")
            return .nan
        }
        func first(
            in node: any XCUIElementSnapshot,
            matching predicate: (any XCUIElementSnapshot) -> Bool
        ) -> (any XCUIElementSnapshot)? {
            if predicate(node) {
                return node
            }
            for child in node.children {
                if let match = first(in: child, matching: predicate) {
                    return match
                }
            }
            return nil
        }
        guard let table = first(in: root, matching: { $0.identifier == "demo.list" && $0.elementType == .table }),
              let navigation = first(in: root, matching: { $0.elementType == .navigationBar }),
              let window = first(in: root, matching: { $0.elementType == .window }),
              let value = table.value as? String, let data = value.data(using: .utf8),
              let geometry = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let position = geometry["position"] else {
            XCTFail("未取得 UITableView 的真实滚动坐标")
            return .nan
        }
        // Demo 的 Header 高度为 220，吸顶基线仍由实际导航栏底边计算，容差不变。
        let safeTop = navigation.frame.maxY - window.frame.minY
        let body = max(0, CGFloat(position) - max(0, 220 - safeTop))
        print("BODY SNAPSHOT raw=\(position) safeTop=\(safeTop) body=\(body) window=\(window.frame) table=\(value)")
        return body
    }

    private func assertPageFrame(_ page: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(page.frame.minX, window.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(page.frame.maxX, window.maxX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(page.frame.width, window.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(
            page.frame.minY,
            app.collectionViews["sp.tabBar.collection"].frame.minY,
            accuracy: 1,
            "页面根视图顶部应始终与当前标签栏顶部对齐",
            file: file,
            line: line
        )
        XCTAssertEqual(
            page.frame.maxY,
            window.maxY,
            accuracy: 1,
            "页面根视图应始终延伸至实际窗口底边",
            file: file,
            line: line
        )
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
        var viewport = app.collectionViews["sp.tabBar.collection"].frame
        if name.contains("WithAccessories") {
            // Safe Area 包含固定附件区域，标签视口只占其中的剩余空间。
            viewport = viewport
                .union(app.otherElements["sp.tabBar.leadingAccessory"].frame)
                .union(app.otherElements["sp.tabBar.trailingAccessory"].frame)
        }
        XCTAssertEqual(table.frame.minX + CGFloat(left), viewport.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(table.frame.maxX - CGFloat(right), viewport.maxX, accuracy: 1, file: file, line: line)
        print(
            "PAGE GEOMETRY: window=\(app.windows.firstMatch.frame), page=\(table.frame), safeLeft=\(left), safeRight=\(right), tabs=\(viewport)"
        )
    }

    private func assertGridCellsSafeArea(file: StaticString = #filePath, line: UInt = #line) {
        let grid = app.collectionViews["demo.grid"]
        assertPageFrame(grid, file: file, line: line)
        let safeViewport = app.collectionViews["sp.tabBar.collection"].frame
        let cells = (0 ..< 3).map { grid.cells["demo.grid.cell.\($0)"].frame }
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
        let viewport = app.collectionViews["sp.tabBar.collection"].frame
        let verticalInset: CGFloat = name.contains("WithAccessories") ? 6 : 0
        XCTAssertEqual(viewport.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        XCTAssertEqual(tab.frame.minY, viewport.minY + verticalInset, accuracy: 1)
        XCTAssertEqual(tab.frame.maxY, viewport.maxY - verticalInset, accuracy: 1)
        XCTAssertEqual(table.frame.minY, viewport.minY, accuracy: 1)
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
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -35)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )
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

    func testSystemWindowResizeWithAccessories() throws {
        try verifySystemWindowResize(rtl: false)
        let search = app.buttons["demo.accessory.search"]
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(app.buttons["demo.accessory.more"].isHittable)
        search.tap()
        XCTAssertTrue(app.alerts["搜索频道"].waitForExistence(timeout: 3))
        app.alerts.buttons["关闭"].tap()
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
        if name.contains("WithAccessories") {
            XCTAssertTrue(app.buttons["demo.accessory.search"].isHittable)
            XCTAssertTrue(app.buttons["demo.accessory.more"].isHittable)
        }
        verifyRootFollowsHeaderInCurrentWindow()
        assertPinnedList(position: initialPosition)
        for delta: CGVector in [CGVector(dx: 160, dy: 120), CGVector(dx: -80, dy: -60)] {
            let before = app.windows.firstMatch.frame
            resizeSystemWindow(dx: delta.dx, dy: delta.dy)
            XCTAssertGreaterThan(abs(app.windows.firstMatch.frame.width - before.width), 40)
            assertPinnedList(position: initialPosition); recordWindow("连续缩放 \(delta)")
            try swipePage(towardNext: true, rtl: rtl, expectedPage: "short"); assertListSafeArea()
            try swipePage(
                towardNext: false,
                rtl: rtl,
                expectedPage: "list"
            ); assertPinnedList(position: initialPosition)
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
        let frame = app.windows.firstMatch.frame
        let screen = springboard.frame
        // 系统旋转也可能恢复全屏，此时没有窗口控制按钮；先用真实手柄建立浮动窗口。
        if max(frame.width, frame.height) >= max(screen.width, screen.height) - 1,
           min(frame.width, frame.height) >= min(screen.width, screen.height) - 1 {
            resizeSystemWindow(dx: -250, dy: -350)
            XCTAssertLessThan(app.windows.firstMatch.frame.width, frame.width - 100)
        }
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
    private func swipePage(
        towardNext: Bool,
        rtl: Bool,
        expectedPage: String,
        from page: XCUIElement? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
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
        origin.withOffset(CGVector(dx: startPoint.x - window.minX, dy: startPoint.y - window.minY)).press(
            forDuration: 0.1,
            thenDragTo: origin.withOffset(CGVector(dx: endPoint.x - window.minX, dy: endPoint.y - window.minY)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        let trace = try pagingTrace(file: file, line: line)
        XCTAssertGreaterThan(
            try XCTUnwrap(trace["sequence"] as? Int),
            try XCTUnwrap(before["sequence"] as? Int),
            file: file,
            line: line
        )
        let samples = try XCTUnwrap(trace["samples"] as? [[String: Double]])
        XCTAssertEqual(samples.last?["phase"], 3, "触摸必须正常结束，不能将输入取消误报为分页失败", file: file, line: line)
        let width = try XCTUnwrap(trace["width"] as? Double)
        let touchTravel = abs(try XCTUnwrap(samples.last?["x"]) - XCTUnwrap(samples.first?["x"]))
        XCTAssertGreaterThan(touchTravel, width * 0.65, "应用必须收到完整水平拖动", file: file, line: line)
        let travel = try XCTUnwrap(trace["maxOffset"] as? Double) - XCTUnwrap(trace["minOffset"] as? Double)
        XCTAssertGreaterThan(travel, width * 0.5, "实际分页位移必须越过半页", file: file, line: line)
        let release = try XCTUnwrap(trace["release"] as? [String: Double])
        let initial = try XCTUnwrap(before["offset"] as? Double)
        XCTAssertEqual(
            try XCTUnwrap(release["target"]),
            initial + (movesLeft ? width : -width),
            accuracy: 1,
            file: file,
            line: line
        )
        expect("page=\(expectedPage)")
        let settled = try pagingTrace(file: file, line: line)
        XCTAssertEqual(
            try XCTUnwrap(settled["offset"] as? Double),
            try XCTUnwrap(release["target"]),
            accuracy: 1,
            file: file,
            line: line
        )
        XCTAssertEqual(settled["dragging"] as? Bool, false, file: file, line: line)
        XCTAssertEqual(settled["decelerating"] as? Bool, false, file: file, line: line)
    }

    func testSystemSplitPagingGestureBoundaries() throws {
        try verifyPagingGestureBoundaries(rtl: false)
    }

    func testSystemSplitCoalescedPagingPreservesTravel() throws {
        try verifyCoalescedPaging(rtl: false)
    }

    func testSystemSplitWindowsRTLCoalescedPagingPreservesTravel() throws {
        try verifyCoalescedPaging(rtl: true)
    }

    private func verifyCoalescedPaging(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "使用真实 iPad 窗口尺寸")
        expect(rtl ? "direction=rtl" : "direction=ltr")
        expect("page=list"); expect("progress=1.00")
        resizeSystemWindow(dx: -500, dy: -600)
        XCTAssertLessThan(app.windows.firstMatch.frame.width, 650)
        let position = contentPosition()
        try swipePage(towardNext: true, rtl: rtl, expectedPage: "short")
        try assertRecognizedPagingTravel()
        try swipePage(towardNext: false, rtl: rtl, expectedPage: "list")
        try assertRecognizedPagingTravel()
        XCTAssertEqual(contentPosition(), position, accuracy: 1)
        let before = try pagingTrace()
        let table = app.tables["demo.list"]
        let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: rtl ? 180 : -180, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        expect("page=list")
        let cancelled = try pagingTrace()
        try assertRecognizedPagingTravel()
        XCTAssertEqual(
            try XCTUnwrap(cancelled["offset"] as? Double),
            try XCTUnwrap(before["offset"] as? Double),
            accuracy: 1
        )
        XCTAssertEqual(contentPosition(), position, accuracy: 1)
    }

    private func assertRecognizedPagingTravel(file: StaticString = #filePath, line: UInt = #line) throws {
        let trace = try pagingTrace()
        let first = try XCTUnwrap(trace["firstPan"] as? [String: Double])
        let samples = try XCTUnwrap(trace["samples"] as? [[String: Double]])
        let last = try XCTUnwrap(samples.last)
        let recognizedTravel = abs(try XCTUnwrap(last["x"]) - XCTUnwrap(first["x"]))
        let actualTravel = try XCTUnwrap(trace["maxOffset"] as? Double) - XCTUnwrap(trace["minOffset"] as? Double)
        XCTAssertEqual(actualTravel, recognizedTravel, accuracy: 1, "已获接受的触摸位移不能在开始拖动时丢失", file: file, line: line)
        let beganSamples = try XCTUnwrap(trace["beganSamples"] as? [[String: Double]])
        XCTAssertFalse(beganSamples.isEmpty, file: file, line: line)
        for sample in beganSamples {
            let movement = try XCTUnwrap(sample["x"]) - XCTUnwrap(sample["previousX"])
            if abs(movement) > 0.5 {
                let velocity = try XCTUnwrap(sample["velocity"])
                XCTAssertGreaterThan(abs(velocity), 1, "移动中的起拖速度不能被补偿操作清零", file: file, line: line)
                XCTAssertGreaterThan(velocity * movement, 0, "起拖速度应保持物理移动方向", file: file, line: line)
            }
        }
    }

    func testSystemSplitMomentumPaging() throws {
        try verifyMomentumPaging(rtl: false)
    }

    func testSystemSplitWindowsRTLMomentumPaging() throws {
        try verifyMomentumPaging(rtl: true)
    }

    private func verifyMomentumPaging(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "使用真实 iPad 窗口尺寸")
        expect("page=list"); expect("progress=1.00")
        resizeSystemWindow(dx: -500, dy: -600)
        let saved = contentPosition()
        for next in [true, false] {
            let before = try pagingTrace()
            let frame = app.windows.firstMatch.frame
            let page = app.tables["demo.list"].frame.intersection(frame)
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: frame.width * 0.5, dy: page.midY - frame.minY))
            let direction: CGFloat = (next != rtl) ? -1 : 1
            start.press(
                forDuration: 0.1,
                thenDragTo: start.withOffset(CGVector(dx: direction * frame.width * 0.35, dy: 0)),
                withVelocity: .fast,
                thenHoldForDuration: 0
            )
            expect(next ? "page=short" : "page=list")
            let after = try pagingTrace()
            let release = try XCTUnwrap(after["release"] as? [String: Double])
            let velocity = try XCTUnwrap(release["velocity"])
            XCTAssertGreaterThan(abs(velocity), 0.1, "松手必须保留非零速度")
            XCTAssertGreaterThan(velocity * -Double(direction), 0)
            let width = try XCTUnwrap(after["width"] as? Double)
            let initialOffset = try XCTUnwrap(before["offset"] as? Double)
            let releaseOffset = try XCTUnwrap(release["offset"])
            // ended 事件返回时可能已进入减速；手指行程必须在松手回调的同一时点测量。
            let travel = abs(releaseOffset - initialOffset)
            XCTAssertLessThan(travel, width * 0.5, "不足半页的输入应通过速度决定吸附")
            XCTAssertEqual(
                try XCTUnwrap(after["offset"] as? Double),
                try XCTUnwrap(before["offset"] as? Double) - Double(direction) * width,
                accuracy: 1
            )
            XCTAssertEqual(after["selectionEvents"] as? [Int], [next ? 2 : 1])
            let first = try XCTUnwrap(after["firstPan"] as? [String: Double])
            let last = try XCTUnwrap((after["samples"] as? [[String: Double]])?.last)
            XCTAssertEqual(last["phase"], Double(UITouch.Phase.ended.rawValue))
            let acceptedDelta = try XCTUnwrap(last["x"]) - XCTUnwrap(first["x"])
            XCTAssertEqual(
                releaseOffset,
                initialOffset - acceptedDelta,
                accuracy: 1,
                "松手时位移必须等于已获接受的触摸位移，不能包含后续减速"
            )
        }
        XCTAssertEqual(contentPosition(), saved, accuracy: 1)
    }

    func testSystemSplitReversingNativePaging() async throws {
        try await verifyReversingNativePaging(rtl: false)
    }

    func testSystemSplitWindowsRTLReversingNativePaging() async throws {
        try await verifyReversingNativePaging(rtl: true)
    }

    private func verifyReversingNativePaging(rtl: Bool) async throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "使用真实 iPad 窗口尺寸")
        guard let endpoint = ProcessInfo.processInfo.environment["SP_SIM_HID_WS"],
              let url = URL(string: endpoint) else {
            throw XCTSkip("连续触摸需要 serve-sim 桥接；运行 Scripts/validate_native_gestures.py")
        }
        let screen = app.windows.firstMatch.frame
        expect("page=list"); expect("progress=1.00")
        resizeSystemWindow(dx: -500, dy: -600)
        let saved = contentPosition()
        // 先验证桥接冷启动的静止触摸已完整送达，避免把初始化积压当成手势速度。
        let initial = try pagingTrace()
        let frame = app.windows.firstMatch.frame
        let page = app.tables["demo.list"].frame.intersection(frame)
        let warmPoint = CGPoint(x: frame.midX / screen.width, y: page.midY / screen.height)
        try await NativeTouchPath.drag(url: url, points: [warmPoint])
        let warmed = try pagingTrace()
        XCTAssertEqual(warmed["sequence"] as? Int, (try XCTUnwrap(initial["sequence"] as? Int)) + 1)
        XCTAssertEqual((warmed["samples"] as? [[String: Double]])?.last?["phase"], Double(UITouch.Phase.ended.rawValue))
        XCTAssertEqual(warmed["selectionEvents"] as? [Int], [])
        XCTAssertEqual(contentPosition(), saved, accuracy: 1)
        for next in [true, false] {
            let before = try pagingTrace()
            let frame = app.windows.firstMatch.frame
            let page = app.tables["demo.list"].frame.intersection(frame)
            let left = next != rtl
            func point(_ fraction: CGFloat) -> CGPoint {
                CGPoint(
                    x: (frame.minX + frame.width * (left ? fraction : 1 - fraction)) / screen.width,
                    y: page.midY / screen.height
                )
            }
            // 同一根手指先越过半页，再折返到不足半页；不重设 pan.translation 或滚动位置。
            try await NativeTouchPath.drag(url: url, points: [point(0.85), point(0.15), point(0.70)])
            expect("page=list")
            let after = try pagingTrace()
            XCTAssertEqual(after["sequence"] as? Int, (try XCTUnwrap(before["sequence"] as? Int)) + 1)
            XCTAssertEqual(after["touchReversals"] as? Int, 1)
            XCTAssertEqual(after["selectionEvents"] as? [Int], [])
            XCTAssertEqual(after["cancelledOffsets"] as? [Double], [])
            let width = try XCTUnwrap(after["width"] as? Double)
            XCTAssertGreaterThan(
                try XCTUnwrap(after["maxOffset"] as? Double) - XCTUnwrap(after["minOffset"] as? Double),
                width * 0.5
            )
            let first = try XCTUnwrap(after["firstPan"] as? [String: Double])
            let last = try XCTUnwrap((after["samples"] as? [[String: Double]])?.last)
            let release = try XCTUnwrap(after["release"] as? [String: Double])
            let acceptedDelta = try XCTUnwrap(last["x"]) - XCTUnwrap(first["x"])
            XCTAssertEqual(
                try XCTUnwrap(release["offset"]),
                try XCTUnwrap(before["offset"] as? Double) - acceptedDelta,
                accuracy: 1
            )
            XCTAssertLessThan(abs(acceptedDelta), width * 0.5)
            XCTAssertEqual(
                try XCTUnwrap(after["offset"] as? Double),
                try XCTUnwrap(before["offset"] as? Double),
                accuracy: 1
            )
            XCTAssertEqual(contentPosition(), saved, accuracy: 1)
        }
    }

    func testSystemSplitCancelledNativePaging() throws {
        try verifyCancelledNativePaging(rtl: false)
    }

    func testSystemSplitWindowsRTLCancelledNativePaging() throws {
        try verifyCancelledNativePaging(rtl: true)
    }

    private func verifyCancelledNativePaging(rtl: Bool) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "使用真实 iPad 窗口尺寸")
        expect("page=list"); expect("progress=1.00")
        resizeSystemWindow(dx: -500, dy: -600)
        let saved = contentPosition()
        let before = try pagingTrace()
        let frame = app.windows.firstMatch.frame
        let page = app.tables["demo.list"].frame.intersection(frame)
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: frame.width * (rtl ? 0.15 : 0.85), dy: page.midY - frame.minY))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: frame.width * (rtl ? 0.7 : -0.7), dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        expect("page=list")
        let after = try pagingTrace()
        XCTAssertEqual(try XCTUnwrap(after["cancelledOffsets"] as? [Double]).count, 1, "必须收到真实 recognizer .cancelled")
        XCTAssertGreaterThan(
            try XCTUnwrap(after["maxOffset"] as? Double) - XCTUnwrap(after["minOffset"] as? Double),
            frame.width * 0.5
        )
        XCTAssertEqual(
            try XCTUnwrap(after["offset"] as? Double),
            try XCTUnwrap(before["offset"] as? Double),
            accuracy: 1
        )
        XCTAssertEqual(after["selectionEvents"] as? [Int], [])
        XCTAssertEqual(contentPosition(), saved, accuracy: 1)
    }

    func testSystemSplitHeaderPartialAfterPageRoundTrip() throws {
        try verifySplitHeaderAfterPageRoundTrip()
    }

    func testSystemSplitWindowsRTLHeaderPartialAfterPageRoundTrip() throws {
        try verifySplitHeaderAfterPageRoundTrip()
    }

    private func verifySplitHeaderAfterPageRoundTrip() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        select(1)
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        arrangeSideBySide()
        verifyRootFollowsHeaderInCurrentWindow()
    }

    func testSystemSplitRowBoundaryPosition() throws {
        try verifySystemSplitRowBoundaryPosition()
    }

    func testSystemSplitWindowsRTLRowBoundaryPosition() throws {
        try verifySystemSplitRowBoundaryPosition()
    }

    private func verifySystemSplitRowBoundaryPosition() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        expect("page=list"); expect("progress=1.00")
        XCTAssertEqual(contentPosition(), 513.5, accuracy: 1)
        print("BOUNDARY BEFORE \(app.tables["demo.list"].value ?? "")")
        resizeSystemWindow(dx: -250, dy: -350)
        print("BOUNDARY FLOAT \(app.tables["demo.list"].value ?? "")")
        XCTAssertEqual(contentPosition(), 513.5, accuracy: 1)
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        arrangeSideBySide()
        print("BOUNDARY SPLIT \(app.tables["demo.list"].value ?? "")")
        assertPinnedList(position: 513.5)
        select(2); select(1)
        assertPinnedList(position: 513.5)
        restoreFullScreen()
        assertPinnedList(position: 513.5)
    }

    func testSystemSplitSelfSizingPosition() throws {
        try verifySplitSelfSizingPosition()
    }

    func testSystemSplitExactRegressionPosition() throws {
        try verifyExactRegressionPosition()
    }

    func testSystemSplitWindowsRTLExactRegressionPosition() throws {
        try verifyExactRegressionPosition()
    }

    func testSystemSplitUnobservedExactRegressionPosition() throws {
        try verifyExactRegressionPosition(observeFloatingWindow: false)
    }

    func testSystemSplitWindowsRTLUnobservedExactRegressionPosition() throws {
        try verifyExactRegressionPosition(observeFloatingWindow: false)
    }

    private func verifyExactRegressionPosition(observeFloatingWindow: Bool = true) throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        expect("page=list")
        assertPinnedList(position: 582)
        resizeSystemWindow(dx: -250, dy: -350)
        if observeFloatingWindow {
            assertPinnedList(position: 582)
        }
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        arrangeSideBySide()
        assertPinnedList(position: 582)
        select(2); select(1)
        assertPinnedList(position: 582)
        restoreFullScreen()
        assertPinnedList(position: 582)
    }

    func testSystemSplitPositionAfterDeceleration() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        for iteration in 0 ..< 3 {
            if iteration > 0 {
                app.terminate(); app.launch(); restoreFullScreen()
                app.buttons["demo.open"].tap()
                XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
            }
            select(1)
            app.tables["demo.list"].swipeUp(); expect("progress=1.00")
            let position = contentPosition()
            resizeSystemWindow(dx: -250, dy: -350)
            XCTAssertEqual(contentPosition(), position, accuracy: 1, "浮动窗口必须保持正文距离")
            XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
            arrangeSideBySide()
            XCTAssertEqual(contentPosition(), position, accuracy: 1, "分屏必须保持正文距离")
            restoreFullScreen()
            XCTAssertEqual(contentPosition(), position, accuracy: 1, "恢复全屏必须保持正文距离")
        }
    }

    func testSystemSplitWindowsRTLSelfSizingPosition() throws {
        try verifySplitSelfSizingPosition()
    }

    private func verifySplitSelfSizingPosition() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "系统分屏仅适用于 iPad")
        expect("page=list")
        expect("progress=1.00")
        let position = contentPosition()
        XCTAssertEqual(position, 546, accuracy: 1)
        let companion = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        for _ in 0 ..< 2 {
            resizeSystemWindow(dx: -250, dy: -350)
            companion.activate()
            arrangeSideBySide()
            rotate(to: .portrait)
            if app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame).width > 1 {
                arrangeSideBySide()
            }
            XCTAssertEqual(contentPosition(), position, accuracy: 1)
            assertPinnedList(position: position)
            select(2); expect("page=short")
            select(1); assertPinnedList(position: position)
            restoreFullScreen()
            assertPinnedList(position: position)
        }
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
            if app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame)
                .width > 1 {
                arrangeSideBySide()
            }
            XCTAssertLessThanOrEqual(
                app.windows.firstMatch.frame.intersection(companion.windows.firstMatch.frame).width,
                1
            )
            assertPinnedList(position: position)
            // 低速、短于半页的触摸应按 UIKit 目标回到原页；框架不能强行翻页。
            let before = try pagingTrace()
            let table = app.tables["demo.list"]
            print("VERTICAL BEFORE \(table.value ?? "")")
            let start = table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(
                dx: rtl ? -100 : 100,
                dy: 0
            ))
            start.press(
                forDuration: 0.1,
                thenDragTo: start.withOffset(CGVector(dx: rtl ? 200 : -200, dy: 0)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
            expect("page=list")
            let cancelled = try pagingTrace()
            print("VERTICAL AFTER \(table.value ?? "")")
            let release = try XCTUnwrap(cancelled["release"] as? [String: Double])
            XCTAssertEqual(try XCTUnwrap(release["target"]), try XCTUnwrap(before["offset"] as? Double), accuracy: 1)
            XCTAssertEqual(try XCTUnwrap(cancelled["offset"] as? Double), try XCTUnwrap(release["target"]), accuracy: 1)
            assertPinnedList(position: position)
            for _ in 0 ..< 3 {
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
            let screenWidth = orientation.isLandscape ? max(screen.width, screen.height) : min(
                screen.width,
                screen.height
            )
            XCTAssertLessThan(pageWindow.width, screenWidth * 0.7)
            XCTAssertLessThan(companionWindow.width, screenWidth * 0.7)
            XCTAssertLessThanOrEqual(pageWindow.intersection(companionWindow).width, 1)
            assertPinnedList(position: initialPosition)
            try swipePage(towardNext: true, rtl: rtl, expectedPage: "short"); assertListSafeArea()
            try swipePage(
                towardNext: false,
                rtl: rtl,
                expectedPage: "list"
            ); assertPinnedList(position: initialPosition)
            select(0); expect("page=grid"); assertGridCellsSafeArea()
            select(1); expect("page=list"); assertPinnedList(position: initialPosition)
            recordWindow("系统分屏-\(rtl ? "rtl" : "ltr")-\(orientation.rawValue)")
            verifyRootFollowsHeaderInCurrentWindow()
            assertPinnedList(position: initialPosition)
        }
    }

    func testStatusBarTapReturnsBusinessListToTop() throws {
        select(1)
        expect("page=list")
        let table = app.tables["demo.list"]
        table.swipeUp()
        expect("progress=1.00")
        XCTAssertGreaterThan(contentPosition(), 0)
        let statusBar = app.statusBars.firstMatch.exists ? app.statusBars
            .firstMatch : XCUIApplication(bundleIdentifier: "com.apple.springboard").statusBars.firstMatch
        XCTAssertTrue(statusBar.waitForExistence(timeout: 5))
        // 点击实际状态栏左侧，避开中央系统区域；由 UIKit 发起原生回顶部。
        statusBar.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        expect("progress=0.00")
        XCTAssertEqual(contentPosition(), 0, accuracy: 1)
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
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
        XCTAssertEqual(plain.frame.minY, app.buttons["sp.tab.4"].frame.minY, accuracy: 1)
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
            XCTAssertEqual(
                tab.frame.minY,
                navigationBar.frame.maxY,
                accuracy: 1,
                "Header 折叠后标签栏应紧贴导航栏底部",
                file: file,
                line: line
            )
            XCTAssertEqual(
                app.tables["demo.list"].frame.minY,
                tab.frame.minY,
                accuracy: 1,
                "列表视口顶部应与标签栏顶部对齐",
                file: file,
                line: line
            )
            XCTAssertEqual(
                app.tables["demo.list"].frame.maxY,
                app.windows.firstMatch.frame.maxY,
                accuracy: 1,
                "吸顶时内容页应延伸到实际窗口底边",
                file: file,
                line: line
            )
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
            XCTAssertEqual(
                label.frame.minY,
                app.buttons["sp.tab.1"].frame.maxY + 12,
                accuracy: 1,
                file: file,
                line: line
            )
            XCTAssertEqual(table.frame.minY, label.frame.maxY + 8, accuracy: 1, file: file, line: line)
            XCTAssertEqual(table.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 1, file: file, line: line)
        }
        expect("progress=0.00")
        assertGeometry()
        XCTAssertEqual(table.cells.firstMatch.frame.minY, table.frame.minY, accuracy: 1)
        dragVisibleList(table, up: true)
        expect("progress=1.00")
        assertGeometry()
        dragVisibleList(table, up: true)
        assertGeometry()
        select(0); select(1)
        expect("progress=1.00")
        assertGeometry()
        rotate(to: .landscapeLeft)
        assertGeometry()
        rotate(to: .portrait)
        assertGeometry()
        for _ in 0 ..< 8 {
            if (status.value as? String)?.contains("progress=0.00") == true {
                break
            }
            dragVisibleList(table, up: false)
        }
        expect("progress=0.00")
        assertGeometry()
        XCTAssertEqual(table.cells.firstMatch.frame.minY, table.frame.minY, accuracy: 1)
        // 展开后用新触摸再次折叠，验证 inset 更新未破坏原生拖动。
        dragVisibleList(table, up: true)
        expect("progress=1.00")
        assertGeometry()
    }

    func testHeaderDragAndListScroll() {
        collapseHeaderByTouch()
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
        XCTAssertEqual(plain.frame.minY, tab.frame.minY, accuracy: 1)
        XCTAssertEqual(plain.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 1)
        plain.swipeUp(); expect("progress=1.00")
        plain.swipeDown(); expect("progress=0.00")
        XCTAssertEqual(plain.frame.minY, tab.frame.minY, accuracy: 1)
        XCTAssertEqual(plain.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 1)
        plain.swipeDown(); expect("progress=0.00")

        collapseHeaderByTouch()
        expect("progress=1.00")
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.05,
                thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            )
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
        app.buttons["切换指示器样式"].tap()
        expect("page=list")
    }

    func testItemSpacingUpdatesGeometryAndPreservesSelectionAndPaging() {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for spacing in [24, 0] {
            app.buttons["demo.pages"].tap()
            app.buttons["标签间距"].tap()
            app.buttons["项间距 \(spacing)"].tap()
            let first = app.buttons["sp.tab.0"]
            let second = app.buttons["sp.tab.1"]
            XCTAssertTrue(first.isSelected)
            XCTAssertEqual(second.frame.minX - first.frame.maxX, CGFloat(spacing), accuracy: 1)
            if spacing > 0 {
                let gap = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: (first.frame.maxX + second.frame.minX) / 2,
                    dy: tabs.frame.midY
                ))
                gap.tap()
                XCTAssertTrue(first.isSelected)
                expect("page=grid")
            }
        }
        app.buttons["demo.pages"].tap()
        app.buttons["标签间距"].tap()
        app.buttons["项间距 16"].tap()
        select(1)
        expect("page=list")
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        app.tables["demo.list"].swipeRight()
        expect("page=grid")
        openGallery()
        app.buttons["配置"].tap()
        app.buttons["标签间距"].tap()
        app.buttons["项间距 8"].tap()
        XCTAssertEqual(app.buttons["sp.tab.1"].frame.minX - app.buttons["sp.tab.0"].frame.maxX, 8, accuracy: 1)
        select(1)
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
    }

    func testCustomIndicatorGalleryPresetsAndForegroundHitTesting() {
        openGallery()
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let originalHeight = tabs.frame.height
        for mode in ["默认下划线", "胶囊", "顶部固定线条", "跟随内容宽度", "内容背景", "自由布局与自定义视图", "隐藏指示器", "默认下划线"] {
            app.buttons["配置"].tap()
            app.buttons["指示器"].tap()
            app.buttons[mode].tap()
            select(1)
            XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
            XCTAssertEqual(tabs.frame.height, originalHeight, accuracy: 1)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = mode; screenshot.lifetime = .keepAlways
            add(screenshot)
            select(0)
        }
        app.buttons["配置"].tap(); app.buttons["自定义卡片"].tap()
        select(1)
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        rotate(to: .landscapeLeft)
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        select(0)
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
    }

    func testChannelIndicatorPagingAndCancelledGesture() {
        verifyPagingAndCancelledGesture()
    }

    func testChannelIndicatorDifferentTitleLengths() {
        verifyDifferentTitleLengths()
    }

    func testFixedUnderlineDifferentTitleLengths() {
        app.buttons["demo.pages"].tap()
        app.buttons["指示器"].tap()
        app.buttons["固定宽度下划线（20 pt）"].tap()
        verifyDifferentTitleLengths()
    }

    func testChannelIndicatorDifferentTitleLengthsWithSquareCorners() {
        useSquareIndicatorCorners()
        verifyDifferentTitleLengths()
    }

    func testFixedUnderlineDifferentTitleLengthsWithSquareCorners() {
        app.buttons["demo.pages"].tap()
        app.buttons["指示器"].tap()
        app.buttons["固定宽度下划线（20 pt）"].tap()
        useSquareIndicatorCorners()
        verifyDifferentTitleLengths()
    }

    private func useSquareIndicatorCorners() {
        app.buttons["demo.pages"].tap()
        app.buttons["指示器"].tap()
        app.buttons["指示器圆角"].tap()
        app.buttons["直角"].tap()
    }

    private func verifyDifferentTitleLengths() {
        app.buttons["demo.pages"].tap()
        app.buttons["长短标题演示"].tap()
        XCTAssertEqual(app.buttons["sp.tab.0"].label, "推荐")
        XCTAssertEqual(app.buttons["sp.tab.1"].label, "编辑精选与深度阅读")

        let pages = app.scrollViews["sp.pages"]
        for (source, target, direction) in [(0, 1, -1.0), (1, 0, 1.0)] {
            let start = pages.coordinate(withNormalizedOffset: CGVector(dx: direction < 0 ? 0.85 : 0.15, dy: 0.6))
            // 停住后松手，避免短拖动因末端速度变成完成分页。
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: pages.frame.width * 0.32 * direction, dy: 0)),
                withVelocity: .slow,
                thenHoldForDuration: 0.4
            )
            expect(source == 0 ? "page=grid" : "page=list")
            XCTAssertTrue(app.buttons["sp.tab.\(source)"].isSelected)
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: pages.frame.width * 0.7 * direction, dy: 0)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
            expect(target == 0 ? "page=grid" : "page=list")
            XCTAssertTrue(app.buttons["sp.tab.\(target)"].isSelected)
        }
    }

    private func verifyPagingAndCancelledGesture() {
        let page = app.collectionViews["demo.grid"]
        let start = page.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: -page.frame.width * 0.15, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.4
        )
        expect("page=grid")
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
        page.swipeLeft()
        expect("page=list")
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        select(0); expect("page=grid")
    }

    func testCustomIndicatorPagingAndCancelledGesture() {
        app.buttons["demo.pages"].tap()
        app.buttons["指示器"].tap()
        app.buttons["自由布局与自定义视图"].tap()
        verifyPagingAndCancelledGesture()
        app.buttons["demo.pages"].tap(); app.buttons["切换自定义标签"].tap()
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
    }

    func testStandaloneTabGallerySelectionAndLiveContent() {
        openGallery()
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

    func testCustomTabGallerySwitchesModeAndUpdatesContent() {
        openGallery()
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let defaultHeight = tabs.frame.height
        app.buttons["配置"].tap()
        app.buttons["自定义卡片"].tap()
        XCTAssertGreaterThan(tabs.frame.height, defaultHeight)
        select(1)
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        app.buttons["配置"].tap()
        app.buttons["更新内容"].tap()
        XCTAssertEqual(app.buttons["sp.tab.1"].value as? String, "99+")
        select(3)
        XCTAssertFalse(app.buttons["sp.tab.3"].isEnabled)
        // 禁用项不能提交选择；切回默认内容后原来的选中对象仍保留。
        app.buttons["配置"].tap()
        app.buttons["默认内容"].tap()
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        XCTAssertEqual(tabs.frame.height, defaultHeight, accuracy: 1)
    }

    func testCustomTabPagingAndHeldDragPreserveInteraction() {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        app.buttons["demo.pages"].tap()
        app.buttons["切换自定义标签"].tap()
        XCTAssertGreaterThan(tabs.frame.height, 44)
        assertPageFrame(app.collectionViews["demo.grid"])
        app.buttons["demo.pages"].tap()
        app.buttons["切换第二项禁用"].tap()
        select(1)
        expect("page=grid")
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        XCTAssertTrue(app.buttons["sp.tab.1"].isSelected)
        select(3); expect("page=empty")
        expectSelectedTabAlignment(3)
        let tab = app.buttons["sp.tab.3"]
        let before = tab.frame.midX
        let distance = tabs.frame.width * 0.25
        let start = tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.4,
            thenDragTo: start.withOffset(CGVector(dx: -distance, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        XCTAssertGreaterThan(before - tab.frame.midX, distance * 0.5)
        expect("page=empty")
        let scrolledFrame = tab.frame
        app.buttons["demo.pages"].tap()
        XCTAssertEqual(tab.frame.minX, scrolledFrame.minX, accuracy: 1)
        app.buttons["刷新自定义内容"].tap()
        XCTAssertEqual(tab.frame.minX, scrolledFrame.minX, accuracy: 1)
        XCTAssertEqual(tab.frame.width, scrolledFrame.width, accuracy: 1)
        expect("page=empty")
        XCTAssertTrue(tab.isSelected)
        select(0); expect("page=grid")
        let verticalStart = app.buttons["sp.tab.1"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        verticalStart.press(
            forDuration: 0.05,
            thenDragTo: verticalStart.withOffset(CGVector(dx: 0, dy: -tabs.frame.minY))
        )
        expect("page=grid")
        expect("progress=1.00")
        app.buttons["demo.pages"].tap()
        app.buttons["切换自定义标签"].tap()
        XCTAssertEqual(tabs.frame.height, 44, accuracy: 1)
        assertPageFrame(app.collectionViews["demo.grid"])
        expect("page=grid")
    }

    func testCustomWidthPolicyAndRequiredOverflowInBothDirections() {
        for rtl in [false, true] {
            app.terminate()
            app.launchArguments = ["--window-regression", "--open-demo"] + (rtl ? ["--rtl"] : [])
            app.launch()
            XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
            func choose(_ title: String) {
                app.buttons["demo.pages"].tap()
                app.buttons["标签宽度"].tap()
                app.buttons[title].tap()
            }
            choose("紧凑编号内容")
            let tabs = app.collectionViews["sp.tabBar.collection"]
            // 默认 content 策略保留自然宽度，宽屏也不均分余量。
            // 自定义配置收到的宽度已扣除默认首尾各 16 pt 留白。
            let availableWidth = max(0, tabs.frame.width - 32)
            let originalWidth = app.buttons["sp.tab.0"].frame.width
            XCTAssertEqual(originalWidth, 44, accuracy: 1)
            choose("最小项宽 24")
            // 最小项宽是下限；编号的自然宽度可能大于 24 pt。
            let compactWidth = app.buttons["sp.tab.0"].frame.width
            XCTAssertGreaterThanOrEqual(compactWidth, 24)
            XCTAssertLessThan(compactWidth, originalWidth - 1, "降低下限后编号项应实际缩小")
            select(1)
            expect("page=list")
            select(0)
            expect("page=grid")
            choose("最小项宽 120")
            // 宽度变化保留物理滚动偏移，RTL 的首项可能移出视口；用真实拖动重新找到目标。
            select(0)
            XCTAssertEqual(app.buttons["sp.tab.0"].frame.width, 120, accuracy: 1)
            select(1)
            expect("page=list")
            assertPageFrame(app.tables["demo.list"])
            choose("最小项宽 44")
            choose("不可压缩宽内容")
            expect("page=grid")
            XCTAssertGreaterThan(app.buttons["sp.tab.0"].frame.width, tabs.frame.width)
            XCTAssertEqual(app.buttons["sp.tab.0"].frame.width, max(480, availableWidth + 80), accuracy: 1)
            assertPageFrame(app.collectionViews["demo.grid"])
            select(1)
            expect("page=list")
        }
    }

    func testCompactCustomTabsRespectMinimumHeightAndRestoreAfterHiding() {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        app.buttons["demo.pages"].tap()
        app.buttons["切换紧凑标签"].tap()
        XCTAssertEqual(tabs.frame.height, 44, accuracy: 1)
        for height in [32, 60, 0, 32, 44] {
            app.buttons["demo.pages"].tap()
            app.buttons["标签栏高度"].tap()
            app.buttons[height == 0 ? "隐藏标签栏" : "最小栏高 \(height)"].tap()
            if height == 0 {
                XCTAssertFalse(app.buttons["sp.tab.0"].isHittable)
            } else {
                XCTAssertEqual(tabs.frame.height, CGFloat(height), accuracy: 1)
                assertPageFrame(app.collectionViews["demo.grid"])
                XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
            }
            expect("page=grid")
        }
        select(1)
        expect("page=list")
        XCTAssertEqual(tabs.frame.height, 44, accuracy: 1)
    }

    func testAutomaticCustomTabHeightUpdatesWithoutExplicitSize() throws {
        let tabs = app.collectionViews["sp.tabBar.collection"]
        try openPagesMenu()
        app.buttons["切换自定义标签"].tap()
        let initialHeight = tabs.frame.height
        try openPagesMenu()
        app.buttons["切换多行副标题"].tap()
        XCTAssertGreaterThan(tabs.frame.height, initialHeight)
        assertPageFrame(app.collectionViews["demo.grid"])
        expect("page=grid")
        try openPagesMenu()
        app.buttons["切换多行副标题"].tap()
        XCTAssertEqual(tabs.frame.height, initialHeight, accuracy: 1)
        assertPageFrame(app.collectionViews["demo.grid"])
        XCTAssertTrue(app.buttons["sp.tab.0"].isSelected)
    }

    func testCustomTabSafeAreaLargeTextRTL() {
        verifySafeAreaTabs(rtl: true, largeText: true, custom: true)
    }

    func testPagingAndRapidSelection() {
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
        select(0); select(2); select(1)
        expect("page=list")
    }

    func testRefreshFromExpandedHeader() {
        select(1)
        expect("page=list")
        let table = app.tables["demo.list"]
        // 从 Header 向下拖动不会替列表制造越界或触发业务刷新。
        let header = app.otherElements["demo.headerView"]
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(
            forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        )
        expect("progress=0.00")
        XCTAssertTrue(table.staticTexts["原生 UITableView · 已刷新 0 次"].firstMatch.exists)
        // 新触摸从列表开始，仍由 UIKit 原生下拉触发刷新。
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(
            forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        )
        XCTAssertTrue(table.staticTexts["原生 UITableView · 已刷新 1 次"].firstMatch.waitForExistence(timeout: 5))
        expect("progress=0.00")
    }

    func testPageReorderDeletionAndEmptySnapshot() {
        select(1)
        choosePageAction("重排页面"); expect("page=list")
        choosePageAction("删除当前页"); expect("page=grid")
        choosePageAction("清空页面"); expect("page=none")
    }

    func testAsyncDiscoveryAndReplacement() {
        select(5)
        app.buttons["demo.replaceScroll"].tap()
        XCTAssertTrue(app.scrollViews["demo.asyncScroll"].exists)
        print(
            "ASYNC VIEWPORT app=\(app.frame), window=\(app.windows.firstMatch.frame), scroll=\(app.scrollViews["demo.asyncScroll"].frame), toolbar=\(app.toolbars.firstMatch.exists ? app.toolbars.firstMatch.frame : .zero)"
        )
        let scroll = app.scrollViews["demo.asyncScroll"]
        let window = app.windows.firstMatch
        let visible = scroll.frame.intersection(window.frame)
        let bottom = min(visible.maxY, app.buttons["demo.replaceScroll"].frame.minY - 12)
        XCTAssertGreaterThan(bottom - visible.minY, 100)
        let origin = window.coordinate(withNormalizedOffset: .zero)
        // 默认 swipe 的起点会落在覆盖于滚动视图之上的替换按钮内。
        origin.withOffset(CGVector(dx: visible.midX - window.frame.minX, dy: bottom - window.frame.minY)).press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(
                dx: visible.midX - window.frame.minX,
                dy: visible.minY + 12 - window.frame.minY
            )),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        expect("progress=1.00")
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

    private func prepareScrollableTabContent() {
        // 默认标题在宽屏上可能只有十几 pt 滚动余量，无法验证长距离拖动接管。
        // 通过公开菜单建立足够宽的内容，不改变实际拖动或选中状态的验收要求。
        app.buttons["demo.pages"].tap()
        app.buttons["标签宽度"].tap()
        app.buttons["最小项宽 120"].tap()
        XCTAssertGreaterThanOrEqual(app.buttons["sp.tab.0"].frame.width, 120)
    }

    func testScrollableTabSelectionCentersAndHorizontalDragPreservesPage() {
        prepareScrollableTabContent()
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
        prepareScrollableTabContent()
        select(3); expect("page=empty")
        let tab = app.buttons["sp.tab.3"]
        expectSelectedTabAlignment(3)
        let before = tab.frame.midX
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let viewport = tabs.frame
        let distance = min(viewport.width * 0.3, before - viewport.minX - 12)
        XCTAssertGreaterThan(distance, 40)
        let start = tabs.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: before - viewport.minX, dy: tab.frame.midY - viewport.minY))
        // 使用标签视口坐标和相对距离，避免 Duo 的 App 坐标仍处于旧方向。
        start.press(
            forDuration: 0.4,
            thenDragTo: start.withOffset(CGVector(dx: -distance, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )
        XCTAssertGreaterThan(before - tab.frame.midX, distance * 0.5, "按钮已按下时仍应能拖动标签栏")
        expect("page=empty")
        XCTAssertTrue(tab.isSelected)
        select(1); expect("page=list")
    }

    func testDisabledListStopsHeaderAndTabDraggingButAllowsPaging() throws {
        select(1); expect("page=list"); expect("progress=0.00")
        let before = try indicatorGeometry()
        XCTAssertEqual(before["isScrollEnabled"], 0)
        collapseHeaderByTouch()
        expect("progress=0.00")
        let tab = app.buttons["sp.tab.1"]
        let start = tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -app.windows.firstMatch.frame.height * 0.2))
        )
        expect("page=list"); expect("progress=0.00")
        let after = try indicatorGeometry()
        XCTAssertEqual(after["position"], before["position"])
        XCTAssertEqual(after["offsetY"], before["offsetY"])
        app.tables["demo.list"].swipeLeft()
        expect("page=short")
        select(1); expect("page=list")
        XCTAssertEqual(try indicatorGeometry()["isScrollEnabled"], 0)
        XCTAssertEqual(try indicatorGeometry()["position"], before["position"])
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

    func testSafeAreaTabsLTR() {
        verifySafeAreaTabs(rtl: false, largeText: false)
    }

    func testSafeAreaTabsRTL() {
        verifySafeAreaTabs(rtl: true, largeText: false)
    }

    func testSafeAreaTabsLargeTextLTR() {
        verifySafeAreaTabs(rtl: false, largeText: true)
    }

    func testSafeAreaTabsLargeTextRTL() {
        verifySafeAreaTabs(rtl: true, largeText: true)
    }

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

    private func verifySafeAreaTabs(rtl: Bool, largeText: Bool, custom: Bool = false) {
        app.terminate()
        app.launchArguments = ["--open-demo", "--window-regression"] + (rtl ? ["--rtl"] : [])
        if custom {
            app.launchArguments.append("--custom-tabs")
        }
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for (step, orientation) in [UIDeviceOrientation.portrait, .landscapeLeft, .landscapeRight, .portrait]
            .enumerated() {
            rotate(to: orientation)
            expect(step == 0 ? "page=grid" : "page=weekly")
            for identifier in ["demo.headerTitle", "demo.headerSubtitle"] {
                let text = app.staticTexts[identifier]
                XCTAssertGreaterThanOrEqual(text.frame.minY, app.navigationBars.firstMatch.frame.maxY - 1)
                XCTAssertLessThanOrEqual(text.frame.maxY, tabs.frame.minY + 1)
                XCTAssertGreaterThanOrEqual(text.frame.minX, tabs.frame.minX)
                XCTAssertLessThanOrEqual(text.frame.maxX, tabs.frame.maxX)
            }
            expectSelectedTabAlignment(step == 0 ? 0 : 9)
            select(0); expect("page=grid")
            assertPageFrame(app.collectionViews["demo.grid"])
            expectSelectedTabAlignment(0)
            let viewport = tabs.frame
            let window = app.windows.firstMatch.frame
            let safe = horizontalSafeInsets()
            XCTAssertEqual(viewport.minX, window.minX + safe.left, accuracy: 1)
            XCTAssertEqual(viewport.maxX, window.maxX - safe.right, accuracy: 1)
            if safe.left > 1 {
                // 安全区域外的背景不应命中标签或切换页面。
                app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: safe.left / 2,
                    dy: viewport.midY - window.minY
                )).tap()
                expect("page=grid")
            }
            if largeText || custom {
                XCTAssertGreaterThan(viewport.height, 44)
            } else {
                XCTAssertEqual(viewport.height, 44, accuracy: 1)
            }
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
            // 多显示面设备的 SpringBoard 坐标可能属于另一屏；触摸锚定当前 App 窗口。
            // frame 为屏幕坐标，需扣除浮动窗口原点后转换为窗口内偏移。
            let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            let touchViewport = tabTouchViewport(tabs)
            let collapseStart = origin.withOffset(CGVector(
                dx: touchViewport.midX - window.minX,
                dy: touchViewport.midY - window.minY
            ))
            print(
                "SAFE AREA DRAG: window=\(window), tabs=\(tabs.frame), navigation=\(app.navigationBars.firstMatch.frame)"
            )
            collapseStart.press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(
                    dx: tabs.frame.midX - window.minX,
                    dy: app.navigationBars.firstMatch.frame.maxY + 4 - window.minY
                )),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
            expect("progress=1.00")
            assertListSafeArea()
            XCTAssertEqual(tabs.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
            let collapsed = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            collapsed.name = "safe-area-collapsed-\(rtl ? "rtl" : "ltr")-\(largeText ? "axxxl" : "default")-\(orientation.rawValue)"
            collapsed.lifetime = .keepAlways
            add(collapsed)
            // 折叠拖动也可能推进正文；用后续新触摸消耗这段位移，再恢复完全展开。
            for _ in 0 ..< 3 {
                if (status.value as? String)?.contains("progress=0.00") == true {
                    break
                }
                let expandStart = tabs.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                expandStart.press(
                    forDuration: 0.05,
                    thenDragTo: origin.withOffset(CGVector(
                        dx: tabs.frame.midX - window.minX,
                        dy: min(window.maxY - 90, expandedCenterY + 90) - window.minY
                    )),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.2
                )
            }
            expect("progress=0.00")
            assertListSafeArea()
        }
    }

    func testRotationAndBackGesture() throws {
        select(1)
        app.tables["demo.list"].swipeUp()
        expect("progress=1.00")
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait] {
            rotate(to: orientation)
            expect("page=list"); expect("progress=1.00")
            XCTAssertEqual(app.buttons["sp.tab.1"].frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
            XCTAssertEqual(app.tables["demo.list"].frame.minY, app.buttons["sp.tab.1"].frame.minY, accuracy: 1)
            assertListSafeArea()
        }
        // Duo 旋转后 App 锚点可能不投递边缘触摸；使用实际窗口，并核对新输入确实进入窗口。
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 1, dy: window.frame.height * 0.5))
        let before = try XCTUnwrap(try pagingTrace()["sequence"] as? Int)
        print("BACK GEOMETRY app=\(app.frame), window=\(app.windows.firstMatch.frame), start=\(start.screenPoint)")
        // 小幅慢拖并停留后释放，取消系统返回；后续新触摸必须仍能正常翻页。
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 80, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )
        expect("page=list"); expect("progress=1.00")
        XCTAssertFalse(app.buttons["demo.open"].exists)
        let cancelled = try pagingTrace()
        XCTAssertGreaterThan(try XCTUnwrap(cancelled["sequence"] as? Int), before, "边缘取消手势必须实际进入窗口")
        let samples = try XCTUnwrap(cancelled["samples"] as? [[String: Double]])
        XCTAssertEqual(try XCTUnwrap(samples.first?["x"]), 1, accuracy: 1)
        app.tables["demo.list"].swipeLeft()
        expect("page=short"); expect("progress=1.00")
        start.press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        if status.exists {
            print("BACK COMPLETE STATUS \(status.value ?? "")")
        }
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
        app.buttons["demo.open"].tap()
        expect("page=grid"); expect("progress=0.00")
        app.collectionViews["demo.grid"].swipeLeft()
        expect("page=list")
    }

    func testDiagonalDragAndShortContentBounce() {
        select(2)
        let table = app.tables["demo.list"]
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.75)).press(
            forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.2))
        )
        expect("page=short"); expect("progress=1.00")
        table.swipeDown(); expect("progress=0.00")
    }

    private func indicatorGeometry() throws -> [String: Double] {
        let value = try XCTUnwrap(app.tables["demo.list"].value as? String)
        let data = try XCTUnwrap(value.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Double])
    }

    func testOptInPagingIndicatorVisibility() throws {
        select(1); expect("page=list")
        let before = try indicatorGeometry()
        XCTAssertEqual(before["showsIndicator"], 1)
        XCTAssertEqual(before["showsHorizontalIndicator"], 1)
        app.tables["demo.list"].swipeLeft()
        expect("page=short")
        let short = try indicatorGeometry()
        XCTAssertEqual(short["showsIndicator"], 1)
        XCTAssertEqual(short["showsHorizontalIndicator"], 1)
        XCTAssertGreaterThan(try XCTUnwrap(short["verticalHideCount"]), 0)
        XCTAssertGreaterThan(try XCTUnwrap(short["horizontalHideCount"]), 0)
        app.tables["demo.list"].swipeRight()
        expect("page=list")
        let after = try indicatorGeometry()
        XCTAssertEqual(after["showsIndicator"], 1)
        XCTAssertEqual(after["showsHorizontalIndicator"], 1)
        XCTAssertGreaterThan(try XCTUnwrap(after["verticalHideCount"]), try XCTUnwrap(before["verticalHideCount"]))
        XCTAssertGreaterThan(try XCTUnwrap(after["horizontalHideCount"]), try XCTUnwrap(before["horizontalHideCount"]))
    }

    func testScrollIndicatorWithShortEmptyAndLongContent() throws {
        for (index, page) in [(2, "short"), (3, "empty"), (1, "list")] {
            select(index)
            // 相邻页动画期间可同时存在两个同名表格，提交选择后再发送新触摸。
            expect("page=\(page)")
            let table = app.tables["demo.list"]
            table.swipeUp()
            expect("page=\(page)"); expect("progress=1.00")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            let geometry = try indicatorGeometry()
            XCTAssertEqual(geometry["showsIndicator"], 1)
            XCTAssertEqual(geometry["showsHorizontalIndicator"], 1)
            XCTAssertEqual(geometry["verticalHideCount"], 0)
            XCTAssertEqual(geometry["horizontalHideCount"], 0)
            attachment.name = "滚动指示器-\(page)-吸顶"
            attachment.lifetime = .keepAlways
            add(attachment)
            if page == "short" {
                XCTAssertTrue(table.staticTexts["内容 1"].isHittable)
                XCTAssertTrue(table.staticTexts["内容 3"].isHittable)
            }
            // 指示器配置不得影响新触摸展开 Header。
            table.swipeDown()
            if page != "list" {
                expect("progress=0.00")
            }
        }
    }
}
