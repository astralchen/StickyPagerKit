import XCTest

/// 通过公开 UI 入口及真实触摸验证系统容器的布局；坐标来自当前窗口，不写死系统栏高度。
@MainActor
final class SystemContainerTests: XCTestCase {
    private var app: XCUIApplication!
    private var table: XCUIElement {
        app.tables["demo.list"]
    }

    private var tabs: XCUIElement {
        app.collectionViews["sp.tabBar.collection"]
    }

    private var systemTabs: XCUIElement {
        app.tabBars["demo.systemTabBar"]
    }

    private var status: XCUIElement {
        app.staticTexts["demo.status"]
    }

    private func systemTab(_ identifier: String, title: String) -> XCUIElement {
        // iPhone 暴露为 Button，iPad 顶部系统栏暴露为 Tab；标识相同，不限定元素类型。
        let identified = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        return identified.exists ? identified : app.descendants(matching: .any).matching(identifier: title).firstMatch
    }

    private var systemTabsFrame: CGRect {
        if systemTabs.exists {
            return systemTabs.frame
        }
        // iPad 顶部系统标签不暴露独立 TabBar 节点，使用实际可交互按钮的联合区域。
        return systemTab("demo.systemTab.pager", title: "联动演示").frame
            .union(systemTab("demo.systemTab.info", title: "布局说明").frame)
    }

    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
        app.launchArguments = ["--window-regression"]
        if name.contains("RTL") {
            app.launchArguments.append("--rtl")
        }
        app.launch()
        XCTAssertTrue(app.buttons["demo.openSystemContainer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["demo.open"].exists)
        app.buttons["demo.openSystemContainer"].tap()
        expect("page=grid;")
        XCTAssertTrue(systemTab("demo.systemTab.pager", title: "联动演示").isHittable)
        XCTAssertTrue(systemTab("demo.systemTab.info", title: "布局说明").isHittable)
        XCTAssertTrue(app.buttons["demo.systemContainer.close"].isHittable)
        XCTAssertLessThanOrEqual(
            status.frame.maxY,
            app.navigationBars.firstMatch.frame.maxY,
            "系统容器场景将状态放入导航栏，不叠加底部工具栏"
        )
    }

    override func tearDown() async throws {
        record("结束状态")
        UITestOrientation.set(.portrait)
        app.terminate()
    }

    private func expect(_ fragment: String) {
        let predicate = NSPredicate { [self] _, _ in (status.value as? String)?.contains(fragment) == true }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5),
            .completed,
            "未达到 \(fragment)，实际 \(status.value ?? "")"
        )
    }

    private func geometry() throws -> [String: Double] {
        let data = try XCTUnwrap((table.value as? String)?.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Double])
    }

    private func contentPosition() throws -> Double {
        let safeTop = app.navigationBars.firstMatch.frame.maxY - app.windows.firstMatch.frame.minY
        return max(0, try XCTUnwrap(geometry()["position"]) - max(0, 220 - safeTop))
    }

    private func record(_ phase: String) {
        let hasSystemTabs = app.buttons["demo.systemContainer.close"].exists
        print(
            "SYSTEM CONTAINER \(phase): window=\(app.windows.firstMatch.frame), nav=\(app.navigationBars.firstMatch.frame), systemTabs=\(hasSystemTabs ? systemTabsFrame : .zero), componentTabs=\(tabs.exists ? tabs.frame : .zero), table=\(table.exists ? table.value ?? "" : "offscreen")"
        )
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = phase
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func select(_ index: Int, page: String) {
        app.buttons["sp.tab.\(index)"].tap()
        expect("page=\(page);")
    }

    private func assertGeometry(pinned: Bool) throws {
        let values = try geometry()
        let frame = table.frame
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(frame.maxY, window.maxY, accuracy: 1, "背景应延伸至窗口底边")
        XCTAssertEqual(frame.minY, tabs.frame.maxY, accuracy: 1, "页面根视图应跟随组件标签栏")
        XCTAssertEqual(frame.minX + (try XCTUnwrap(values["safeLeft"])), tabs.frame.minX, accuracy: 1)
        XCTAssertEqual(frame.maxX - (try XCTUnwrap(values["safeRight"])), tabs.frame.maxX, accuracy: 1)
        let safeBottom = try XCTUnwrap(values["safeBottom"])
        let bottom = try XCTUnwrap(values["adjustedBottom"])
        XCTAssertEqual(
            bottom,
            (try XCTUnwrap(values["insetBottom"])) + safeBottom,
            accuracy: 1,
            "系统底部安全区域应只补偿一次"
        )
        // 系统标签栏可以位于底部、顶部或 Duo 侧边；按实际安全区域验证避让。
        let safeContent = CGRect(
            x: frame.minX + (try XCTUnwrap(values["safeLeft"])),
            y: frame.minY,
            width: frame.width - (try XCTUnwrap(values["safeLeft"])) - (try XCTUnwrap(values["safeRight"])),
            height: frame.height - safeBottom
        )
        let overlap = safeContent.intersection(systemTabsFrame)
        XCTAssertTrue(
            overlap.isNull || overlap.width <= 1 || overlap.height <= 1,
            "内容安全区域 \(safeContent) 不应被系统标签栏 \(systemTabsFrame) 遮挡"
        )
        XCTAssertEqual(try XCTUnwrap(values["automaticIndicators"]), 1)
        let isShort = (status.value as? String)?.contains("page=short;") == true
        XCTAssertEqual(try XCTUnwrap(values["showsIndicator"]), isShort ? 0 : 1)
        XCTAssertEqual(
            try XCTUnwrap(values["indicatorBottom"]),
            0,
            accuracy: 1,
            "保留 UIKit 自动处理底部指示器避让，不再手动叠加安全区域"
        )
        if pinned {
            expect("progress=1.00")
            XCTAssertEqual(tabs.frame.minY, app.navigationBars.firstMatch.frame.maxY, accuracy: 1)
        }
    }

    private func verticalDrag(up: Bool, distance: CGFloat? = nil) {
        let barFrame = systemTabsFrame
        let x = tabs.frame.midX
        let blocksDrag = barFrame.minX < x && x < barFrame.maxX && barFrame.midY > table.frame.midY
        let bottom = min(table.frame.maxY, blocksDrag ? barFrame.minY : table.frame.maxY)
        let visibleHeight = bottom - table.frame.minY
        let origin = table.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: x - table.frame.minX, dy: visibleHeight * (up ? 0.8 : 0.2)))
        let end = start.withOffset(CGVector(dx: 0, dy: (up ? -1 : 1) * (distance ?? visibleHeight * 0.6)))
        print(
            "SYSTEM CONTAINER DRAG: visibleHeight=\(visibleHeight), distance=\(distance ?? visibleHeight * 0.6), table=\(table.frame)"
        )
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    func testExpandedPartialPinnedAndLastRow() throws {
        select(2, page: "short")
        expect("progress=0.00")
        XCTAssertEqual(app.otherElements["demo.headerView"].frame.minY, app.windows.firstMatch.frame.minY, accuracy: 1)
        XCTAssertEqual(table.cells.firstMatch.frame.minY, tabs.frame.maxY, accuracy: 1)
        try assertGeometry(pinned: false)
        record("系统容器-展开")
        let expandedTop = tabs.frame.minY
        verticalDrag(up: true, distance: 50)
        XCTAssertLessThan(tabs.frame.minY, expandedTop - 10)
        XCTAssertGreaterThan(tabs.frame.minY, app.navigationBars.firstMatch.frame.maxY + 1)
        try assertGeometry(pinned: false)
        record("系统容器-部分折叠")
        verticalDrag(up: true)
        try assertGeometry(pinned: true)
        XCTAssertTrue(table.staticTexts["内容 1"].isHittable)
        XCTAssertTrue(table.staticTexts["内容 3"].isHittable)
        record("系统容器-吸顶短列表")
        verticalDrag(up: false)
        expect("progress=0.00")
        select(1, page: "list")
        for _ in 0 ..< 24 {
            let last = table.staticTexts["内容 80"]
            let values = try geometry()
            if last.exists, !last.frame.isEmpty, last.isHittable,
               last.frame.maxY <= table.frame.maxY - (values["safeBottom"] ?? 0) {
                break
            }
            table.swipeUp()
        }
        let last = table.staticTexts["内容 80"]
        XCTAssertTrue(last.isHittable)
        XCTAssertLessThanOrEqual(last.frame.maxY, table.frame.maxY - (try XCTUnwrap(geometry()["safeBottom"])) + 1)
        try assertGeometry(pinned: true)
        record("系统容器-列表末项")
    }

    func testPagingRotationAndSystemTabRestore() throws {
        try verifyPagingAndRotation(rtl: false)
    }

    func testRTLPagingRotationAndSystemTabRestore() throws {
        try verifyPagingAndRotation(rtl: true)
    }

    private func verifyPagingAndRotation(rtl: Bool) throws {
        select(1, page: "list")
        verticalDrag(up: true)
        try assertGeometry(pinned: true)
        let position = try XCTUnwrap(geometry()["position"])
        if rtl {
            table.swipeRight()
        } else {
            table.swipeLeft()
        }
        expect("page=short;")
        try assertGeometry(pinned: true)
        if rtl {
            table.swipeLeft()
        } else {
            table.swipeRight()
        }
        expect("page=list;")
        XCTAssertEqual(try XCTUnwrap(geometry()["position"]), position, accuracy: 1)
        systemTab("demo.systemTab.info", title: "布局说明").tap()
        XCTAssertTrue(app.navigationBars["布局说明"].waitForExistence(timeout: 5))
        systemTab("demo.systemTab.pager", title: "联动演示").tap()
        expect("page=list;")
        XCTAssertEqual(try XCTUnwrap(geometry()["position"]), position, accuracy: 1)
        for (orientation, interface) in [
            (UIDeviceOrientation.landscapeLeft, UIInterfaceOrientation.landscapeRight),
            (.landscapeRight, .landscapeLeft),
            (.portrait, .portrait)
        ] {
            let savedContentPosition = try contentPosition()
            UITestOrientation.set(orientation)
            expect("interfaceOrientation=\(interface.rawValue);")
            try assertGeometry(pinned: true)
            XCTAssertEqual(try contentPosition(), savedContentPosition, accuracy: 1, "安全区域变化后保留正文滚动位置")
            record("系统容器-\(rtl ? "RTL" : "LTR")-方向\(interface.rawValue)")
            let before = try XCTUnwrap(geometry()["position"])
            // 按当前可见视口验证旋转后的滚动能力，兼顾内外屏及横竖屏。
            verticalDrag(up: true)
            XCTAssertGreaterThan(try XCTUnwrap(geometry()["position"]), before + 10, "旋转后新触摸仍能滚动")
        }
        app.buttons["demo.systemContainer.close"].tap()
        XCTAssertTrue(app.buttons["demo.open"].waitForExistence(timeout: 5))
        app.buttons["demo.open"].tap()
        expect("page=grid;")
        XCTAssertTrue(status.isHittable)
        XCTAssertGreaterThan(
            status.frame.minY,
            app.windows.firstMatch.frame.midY,
            "原有演示的状态控件仍显示在底部工具栏中"
        )
    }
}
