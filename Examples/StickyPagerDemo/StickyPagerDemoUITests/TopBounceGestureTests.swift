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
            app.buttons["bounce.mode"].tap()
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
