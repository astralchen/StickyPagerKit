import XCTest

@MainActor
final class TabBarPositioningUITests: XCTestCase {
    private var app: XCUIApplication!
    private let modes = [
        "自动分配 · automatic",
        "强制等宽 · fill",
        "内容居中 · centered",
        "起始对齐 · leading"
    ]

    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
        UITestOrientation.set(.portrait)
    }

    private func expect(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed)
    }

    private func chooseMode(_ index: Int, gallery: Bool) {
        app.buttons[gallery ? "配置" : "demo.pages"].tap()
        let submenu = app.buttons["标签布局模式"]
        XCTAssertTrue(submenu.waitForExistence(timeout: 4))
        submenu.tap()
        for title in modes {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 4))
        }
        app.buttons[modes[index]].tap()
    }

    private func capture(_ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name)-\(title)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ tab: XCUIElement, in collection: XCUIElement, rtl: Bool) {
        // 切换为宽内容时保留原有物理滚动偏移；先拖动到目标，避免查询视口外已回收的 Cell。
        for _ in 0 ..< 5 {
            if tab.exists, tab.isHittable {
                return
            }
            let start: CGFloat = rtl ? 0.8 : 0.2
            collection.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5)).press(
                forDuration: 0.1,
                thenDragTo: collection.coordinate(withNormalizedOffset: CGVector(dx: 1 - start, dy: 0.5))
            )
        }
        XCTAssertTrue(tab.exists && tab.isHittable)
    }

    private func checkGallery(rtl: Bool) {
        app.launchArguments = ["--open-gallery"] + (rtl ? ["--rtl"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["配置"].waitForExistence(timeout: 8))
        app.buttons["配置"].tap()
        app.buttons["紧凑编号内容"].tap()
        let collection = app.collectionViews["sp.tabBar.collection"]
        let first = app.buttons["sp.tab.0"]
        let second = app.buttons["sp.tab.1"]
        XCTAssertTrue(second.waitForExistence(timeout: 4))
        second.tap()
        expect { second.isSelected }
        let original = first.frame
        for mode in [1, 2, 3, 0] {
            chooseMode(mode, gallery: true)
            let width = mode < 2 ? max(44, collection.frame.width / 5) : 44
            expect { abs(first.frame.width - width) < 1 }
            XCTAssertTrue(second.isSelected)
            if mode < 2 {
                XCTAssertEqual(first.frame.minX, original.minX, accuracy: 1)
            } else {
                let slack = max(0, collection.frame.width - 5 * 44)
                let margin = mode == 2 ? slack / 2 : 0
                if rtl {
                    XCTAssertEqual(collection.frame.maxX - first.frame.maxX, margin, accuracy: 1)
                } else {
                    XCTAssertEqual(first.frame.minX - collection.frame.minX, margin, accuracy: 1)
                }
            }
            capture(modes[mode])
        }
        // 切回自定义卡片时不能残留紧凑编号内容，模式与选中项保持。
        app.buttons["配置"].tap()
        app.buttons["自定义卡片"].tap()
        reveal(second, in: collection, rtl: rtl)
        expect { second.frame.height > 44 }
        XCTAssertTrue(second.isSelected)
        app.buttons["配置"].tap()
        app.buttons["默认内容"].tap()
        reveal(second, in: collection, rtl: rtl)
        expect { second.label == "收藏" }
        XCTAssertTrue(second.isSelected)
    }

    func testGallerySwitchesAllPositioningModes() {
        checkGallery(rtl: false)
    }

    func testGallerySwitchesAllPositioningModesInRTL() {
        checkGallery(rtl: true)
    }

    func testPagerPositioningMenuPreservesPageAndAppliesWidths() {
        app.launchArguments = ["--open-demo"]
        app.launch()
        let first = app.buttons["sp.tab.0"]
        let second = app.buttons["sp.tab.1"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        second.tap()
        let status = app.staticTexts["demo.status"]
        expect { (status.value as? String ?? "").contains("page=list;") }
        let originalWidth = first.frame.width
        let collection = app.collectionViews["sp.tabBar.collection"]
        chooseMode(1, gallery: false)
        expect { abs(first.frame.width - max(44, collection.frame.width / 13)) < 1 }
        for mode in [2, 3, 0] {
            chooseMode(mode, gallery: false)
            expect { abs(first.frame.width - originalWidth) < 1 }
            XCTAssertTrue((status.value as? String ?? "").contains("page=list;"))
            XCTAssertTrue(second.isSelected)
        }
        capture("分页模式切换后")
    }

    private func checkPagerCards(rtl: Bool) {
        app.launchArguments = ["--open-demo", "--custom-tabs"] + (rtl ? ["--rtl"] : [])
        app.launch()
        let second = app.buttons["sp.tab.1"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        second.tap()
        let collection = app.collectionViews["sp.tabBar.collection"]
        let status = app.staticTexts["demo.status"]
        expect { (status.value as? String ?? "").contains("page=list;") }
        for mode in [1, 2, 3, 0, 1] {
            chooseMode(mode, gallery: false)
            reveal(second, in: collection, rtl: rtl)
            expect { mode == 1 ? abs(second.frame.width - 44) < 1 : second.frame.width >= 160 }
            XCTAssertTrue(second.isSelected)
            XCTAssertTrue((status.value as? String ?? "").contains("page=list;"))
            XCTAssertGreaterThanOrEqual(second.frame.height, 76)
            capture("卡片-" + modes[mode])
        }
        // fill 中仍可真实点击切页，恢复默认内容不改变模式或选择。
        let third = app.buttons["sp.tab.2"]
        reveal(third, in: collection, rtl: rtl)
        third.tap()
        expect { third.isSelected }
        app.buttons["demo.pages"].tap()
        app.buttons["切换自定义标签"].tap()
        expect { abs(third.frame.width - 44) < 1 }
        XCTAssertTrue(third.isSelected)
    }

    func testPagerCardsSwitchAllModes() {
        checkPagerCards(rtl: false)
    }

    func testPagerCardsSwitchAllModesInRTL() {
        checkPagerCards(rtl: true)
    }
}
