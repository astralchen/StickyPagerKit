import XCTest

@MainActor
final class TabBarAccessoryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        capture("结束")
        app.terminate()
        UITestOrientation.set(.portrait)
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name)-\(title)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(_ arguments: [String] = []) {
        app.launchArguments = ["--accessories", "--window-regression"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["demo.accessory.more"].waitForExistence(timeout: 8))
    }

    private func expect(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed)
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        UITestOrientation.set(orientation)
        let expected: UIInterfaceOrientation = orientation == .landscapeLeft ? .landscapeRight
            : orientation == .landscapeRight ? .landscapeLeft : .portrait
        let status = app.staticTexts["demo.gallery.status"]
        let predicate = NSPredicate { _, _ in
            (status.value as? String ?? "").contains("interfaceOrientation=\(expected.rawValue);")
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 6)
        XCTAssertEqual(
            result,
            .completed,
            "请求界面方向 \(expected.rawValue)，实际：\(status.value ?? "<无方向>")，window=\(app.windows.firstMatch.frame)"
        )
        print("ACCESSORY ORIENTATION \(status.value ?? ""), window=\(app.windows.firstMatch.frame)")
    }

    private func drag(_ collection: XCUIElement, forward: Bool, rtl: Bool) {
        let from: CGFloat = forward != rtl ? 0.85 : 0.15
        collection.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5))
            .press(
                forDuration: 0.1,
                thenDragTo: collection.coordinate(withNormalizedOffset: CGVector(dx: 1 - from, dy: 0.5))
            )
    }

    private func checkGallery(rtl: Bool, extra: [String] = []) {
        launch(["--open-gallery"] + (rtl ? ["--rtl"] : []) + extra)
        let search = app.buttons["demo.accessory.search"]
        let more = app.buttons["demo.accessory.more"]
        let collection = app.collectionViews["sp.tabBar.collection"]
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(more.isHittable)
        XCTAssertEqual(search.label, "搜索频道")
        XCTAssertEqual(more.label, "更多频道")
        let a = search.frame, b = more.frame
        if rtl {
            XCTAssertGreaterThan(a.minX, b.minX)
        } else {
            XCTAssertLessThan(a.minX, b.minX)
        }
        let selected = app.buttons["sp.tab.0"]
        XCTAssertTrue(selected.exists)
        XCTAssertGreaterThan(selected.frame.intersection(collection.frame).width, 20)
        capture("首端")
        drag(collection, forward: true, rtl: rtl)
        XCTAssertEqual(search.frame, a)
        XCTAssertEqual(more.frame, b)
        capture("中间")
        for _ in 0 ..< 8 {
            drag(collection, forward: true, rtl: rtl)
        }
        capture("尾端")
        search.tap()
        XCTAssertTrue(app.alerts["搜索频道"].waitForExistence(timeout: 3))
        app.alerts.buttons["关闭"].tap()
        more.tap()
        let channel = app.buttons["频道 2：收藏"]
        XCTAssertTrue(channel.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["频道 3：通知"].exists)
        channel.tap()
        expect { self.app.staticTexts["demo.gallery.status"].label.contains("已选择：收藏") }
        XCTAssertEqual(search.frame, a)
        XCTAssertEqual(more.frame, b)
    }

    func testGalleryFixedAccessoriesAndChannelMenu() {
        checkGallery(rtl: false)
    }

    func testGalleryRTLAndDarkAppearance() {
        checkGallery(rtl: true, extra: ["--dark"])
    }

    func testGalleryAccessibilitySizeRotationAndNarrowViewport() {
        launch([
            "--open-gallery",
            "--narrow-tabs",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let collection = app.collectionViews["sp.tabBar.collection"]
        let search = app.buttons["demo.accessory.search"], more = app.buttons["demo.accessory.more"]
        XCTAssertTrue(search.isHittable)
        XCTAssertTrue(more.isHittable)
        XCTAssertLessThan(collection.frame.width, 200)
        capture("窄栏辅助字号")
        drag(collection, forward: true, rtl: false)
        rotate(to: .landscapeLeft)
        let host = app.otherElements["sp.tabBar.leadingAccessory"]
        XCTAssertTrue(host.waitForExistence(timeout: 3))
        let visible = search.frame.intersection(host.frame).intersection(app.windows.firstMatch.frame)
        XCTAssertFalse(visible.isEmpty)
        // 极窄窗口中附件理想 frame 可能大于承载区域，点击真实可见部分。
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: visible.midX - window.frame.minX,
            dy: visible.midY - window.frame.minY
        )).tap()
        XCTAssertTrue(app.alerts["搜索频道"].waitForExistence(timeout: 3))
        app.alerts.buttons["关闭"].tap()
        capture("横屏辅助字号")
        rotate(to: .portrait)
        expect { collection.exists && collection.frame.width > 0 }
        drag(collection, forward: false, rtl: false)
    }

    func testPagerAccessoryMenuAndHeightRecovery() {
        launch(["--open-demo"])
        let more = app.buttons["demo.accessory.more"]
        more.tap()
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "频道 2：")).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 3))
        second.tap()
        expect { (self.app.staticTexts["demo.status"].value as? String ?? "").contains("page=list") }
        let collection = app.collectionViews["sp.tabBar.collection"]
        let old = collection.frame.height
        func changeHeight() {
            app.buttons["demo.pages"].tap()
            app.buttons["留白与附件"].tap()
            app.buttons["切换高附件"].tap()
        }
        changeHeight()
        expect {
            print(
                "ACCESSORY HEIGHT old=\(old), collection=\(collection.frame), more=\(more.frame), window=\(self.app.windows.firstMatch.frame)"
            )
            // 坐标变换可能将 80 表达为 79.99999999999997；只容纳浮点运算误差。
            return collection.frame.height + 0.000001 >= 80
        }
        XCTAssertGreaterThan(collection.frame.height, old)
        XCTAssertEqual(app.tables["demo.list"].frame.minY, collection.frame.maxY, accuracy: 1)
        XCTAssertTrue(more.isHittable)
        capture("附件撑高分页栏")
        changeHeight()
        expect { abs(collection.frame.height - old) < 1 }
        XCTAssertEqual(app.tables["demo.list"].frame.minY, collection.frame.maxY, accuracy: 1)
        XCTAssertTrue(app.buttons["demo.accessory.search"].isHittable)
    }
}
