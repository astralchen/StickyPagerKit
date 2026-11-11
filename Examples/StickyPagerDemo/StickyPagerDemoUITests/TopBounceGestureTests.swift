import XCTest

@MainActor
final class TopBounceGestureTests: XCTestCase {
    private func values(_ app: XCUIApplication) throws -> [String: Double] {
        let element = app.staticTexts["bounce.metrics"]
        let raw = try XCTUnwrap(element.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Double])
    }

    private func verify(
        page: Int,
        container: Bool,
        disabled: Bool = false,
        rtl: Bool = false,
        area: String = "list",
        toggleDefault: Bool = false,
        scrollFirst: Bool = false,
        flick: Bool = false
    ) throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        let app = XCUIApplication()
        app.launchArguments = ["--open-bounce"]
        if disabled {
            app.launchArguments.append("--bounce-disabled")
        }
        if rtl {
            app.launchArguments.append("--rtl")
        }
        app.launch()
        defer { app.terminate() }
        let tab = app.buttons["sp.tab.\(page)"]
        XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 10))
        if rtl {
            XCTAssertGreaterThan(app.buttons["sp.tab.0"].frame.midX, app.buttons["sp.tab.1"].frame.midX)
        }
        let tabs = app.collectionViews["sp.tabBar.collection"]
        for _ in 0 ..< 3 where !tab.exists || !tab.isHittable {
            if rtl {
                tabs.swipeRight()
            } else {
                tabs.swipeLeft()
            }
        }
        XCTAssertTrue(tab.exists)
        if page != 0 {
            tab.tap()
        }
        if toggleDefault {
            let modeButton = app.buttons["bounce.mode"]
            func menuOption(_ title: String) -> XCUIElement {
                app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", title, "bounce.mode"))
                    .firstMatch
            }
            let containerMode = menuOption("容器回弹")
            let pageMode = menuOption("页面回弹")
            XCTAssertEqual(modeButton.label, "容器回弹")
            modeButton.tap()
            XCTAssertTrue(containerMode.isSelected)
            XCTAssertFalse(pageMode.isSelected)
            pageMode.tap()
            XCTAssertEqual(modeButton.label, "页面回弹")
            modeButton.tap()
            XCTAssertFalse(containerMode.isSelected)
            XCTAssertTrue(pageMode.isSelected)
            let menu = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            menu.name = "默认回弹模式-页面回弹已选"
            menu.lifetime = .keepAlways
            add(menu)
            pageMode.tap()
        }
        let surface = area == "header" ? app.staticTexts["bounce.header"] : area == "tab" ? tab : page == 4 ? app
            .staticTexts["bounce.fixed"] : app.scrollViews["bounce.scroll"]
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        if scrollFirst {
            let initial = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            initial.press(
                forDuration: 0.1,
                thenDragTo: initial.withOffset(CGVector(dx: 0, dy: -100)),
                withVelocity: .slow,
                thenHoldForDuration: 0.5
            )
            XCTAssertGreaterThan(try XCTUnwrap(try values(app)["position"]), 50)
        }
        let start = surface.coordinate(withNormalizedOffset: CGVector(
            dx: 0.5,
            dy: area == "header" ? 0.8 : page == 4 ? 0.5 : 0.35
        ))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: app.frame.height * (flick ? 0.06 : 0.28))),
            withVelocity: flick ? .fast : .slow,
            thenHoldForDuration: flick ? 0 : 0.3
        )
        let settled = NSPredicate { _, _ in
            guard let result = try? self.values(app) else {
                return false
            }
            return abs(result["container"] ?? 999) < 1 && abs(result["position"] ?? 999) < 1
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 6),
            .completed
        )
        let result = try values(app)
        print("TOP BOUNCE METRICS \(result)")
        if container {
            XCTAssertGreaterThan(try XCTUnwrap(result["peakContainer"]), flick ? 1 : 25)
            XCTAssertGreaterThan(try XCTUnwrap(result["frames"]), 2)
            XCTAssertLessThan(try XCTUnwrap(result["mismatch"]), 1)
        } else {
            XCTAssertLessThan(try XCTUnwrap(result["peakContainer"]), 1)
            XCTAssertGreaterThan(try XCTUnwrap(result["peakList"]), 25)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "回弹终态"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDownwardDecelerationUsesContainer() throws {
        try verify(page: 0, container: true, scrollFirst: true, flick: true)
    }

    func testHeaderDrag() throws {
        try verify(page: 0, container: true, area: "header")
    }

    func testTabDrag() throws {
        try verify(page: 0, container: true, area: "tab")
    }

    func testRuntimeDefaultSwitch() throws {
        try verify(page: 0, container: false, toggleDefault: true)
    }

    func testContinuousReturnFromContent() throws {
        try verify(page: 0, container: true, scrollFirst: true)
    }

    func testContainerLongList() throws {
        try verify(page: 0, container: true)
    }

    func testRowTextStaysInsideSafeAreaAcrossLandscapeRotations() throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        let app = XCUIApplication()
        app.launchArguments = ["--open-bounce"]
        app.launch()
        defer {
            UITestOrientation.set(.portrait)
            app.terminate()
        }
        let scroll = app.scrollViews["bounce.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for (device, interface) in [
            (UIDeviceOrientation.landscapeLeft, UIInterfaceOrientation.landscapeRight),
            (.landscapeRight, .landscapeLeft),
            (.portrait, .portrait)
        ] {
            UITestOrientation.set(device)
            let rotated = NSPredicate { _, _ in
                (try? self.values(app)["interfaceOrientation"]) == Double(interface.rawValue)
            }
            XCTAssertEqual(
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 8),
                .completed
            )
            if device == .landscapeLeft {
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                start.press(
                    forDuration: 0.1,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: -220)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.4
                )
            }
            let window = app.windows.firstMatch.frame
            let metrics = try values(app)
            let left = window.minX + CGFloat(try XCTUnwrap(metrics["safeLeft"]))
            let right = window.maxX - CGFloat(try XCTUnwrap(metrics["safeRight"]))
            if interface.isLandscape {
                XCTAssertGreaterThan(window.width - (right - left), 0)
            }
            let row = scroll.staticTexts["第 5 行 · 下拉观察回弹归属"]
            XCTAssertTrue(row.isHittable)
            let frame = row.frame
            print("文字安全区域：方向 \(interface.rawValue)，可用 \(left)...\(right)，第 5 行 \(frame)")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "列表文字-方向\(interface.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertEqual(frame.minX - left, 16, accuracy: 1)
            XCTAssertEqual(right - frame.maxX, 16, accuracy: 1)
            XCTAssertEqual(scroll.frame.width, window.width, accuracy: 1)
        }
    }

    func testCollapsedTabBarAlignsWithSafeAreaTop() {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        let app = XCUIApplication()
        app.launchArguments = ["--open-bounce"]
        app.launch()
        defer { app.terminate() }
        let tabs = app.collectionViews["sp.tabBar.collection"]
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        let navigation = app.navigationBars.firstMatch
        XCTAssertGreaterThan(tabs.frame.minY, navigation.frame.maxY + 1)
        app.scrollViews["bounce.scroll"].swipeUp()
        let tabTop = tabs.frame.minY
        let safeTop = navigation.frame.maxY
        print("吸顶坐标：标签栏顶部 \(tabTop)，导航栏底边 \(safeTop)")
        XCTAssertEqual(tabTop, safeTop, accuracy: 1)
    }

    func testContainerWithNativeBouncesDisabled() throws {
        try verify(page: 0, container: true, disabled: true)
    }

    func testPageOverrideAndRefresh() throws {
        try verify(page: 1, container: false)
    }

    func testShortList() throws {
        try verify(page: 2, container: true)
    }

    func testEmptyList() throws {
        try verify(page: 3, container: true)
    }

    func testPlainPage() throws {
        try verify(page: 4, container: true)
    }

    func testMixedPageRTL() throws {
        try verify(page: 5, container: true, rtl: true)
    }
}
