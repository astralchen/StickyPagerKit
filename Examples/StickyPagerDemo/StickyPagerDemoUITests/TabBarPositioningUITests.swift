import XCTest

@MainActor
final class TabBarPositioningUITests: XCTestCase {
    private var app: XCUIApplication!
    private let modes = [
        "均衡分配",
        "等宽填充",
        "内容居中",
        "起始对齐"
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
        // 最大辅助字号恢复完整卡片后，总宽度可能超过十个视口。
        for _ in 0 ..< 20 {
            let viewport = collection.frame
            var delta: CGFloat = rtl ? -0.6 : 0.6
            if tab.exists {
                let frame = tab.frame
                if viewport.insetBy(dx: viewport.width * 0.05, dy: 0).contains(CGPoint(x: frame.midX, y: frame.midY)),
                   tab.isHittable {
                    return
                }
                // 已出现的项按实际位置滚动，避免对部分露出的项使用不稳定的自动点击坐标。
                delta = min(0.6, max(-0.6, (viewport.midX - frame.midX) / viewport.width))
            }
            let start: CGFloat = delta > 0 ? 0.2 : 0.8
            collection.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5)).press(
                forDuration: 0.1,
                thenDragTo: collection.coordinate(withNormalizedOffset: CGVector(dx: start + delta, dy: 0.5)),
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
        }
        XCTFail("目标标签未进入可点击的视口中心区域")
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
            // 默认首尾各 16 pt 的滚动留白不参与项宽分配。
            let width = mode < 2 ? max(44, (collection.frame.width - 32) / 5) : 44
            expect { abs(first.frame.width - width) < 1 }
            XCTAssertTrue(second.isSelected)
            if mode < 2 {
                XCTAssertEqual(
                    rtl ? first.frame.maxX : first.frame.minX,
                    rtl ? original.maxX : original.minX,
                    accuracy: 1
                )
            } else {
                let slack = max(0, collection.frame.width - 32 - 5 * 44)
                let margin = 16 + (mode == 2 ? slack / 2 : 0)
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

    func testDefaultDimensionsAndFixedWidthPreserveSelectionAndRestore() {
        app.launchArguments = ["--open-gallery"]
        app.launch()
        let collection = app.collectionViews["sp.tabBar.collection"]
        let second = app.buttons["sp.tab.1"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        second.tap()
        expect { second.isSelected }
        let originalHeight = collection.frame.height
        func choose(_ title: String, submenu: String) {
            app.buttons["配置"].tap()
            app.buttons[submenu].tap()
            let action = app.buttons[title]
            XCTAssertTrue(action.waitForExistence(timeout: 4))
            action.tap()
        }
        choose("紧凑图文", submenu: "默认内容尺寸")
        expect { collection.frame.height < originalHeight }
        XCTAssertTrue(second.isSelected)
        choose("固定宽度居中", submenu: "标签布局模式")
        expect { abs(second.frame.width - 80) < 1 }
        XCTAssertTrue(second.isSelected)
        choose("宽松图文", submenu: "默认内容尺寸")
        expect { collection.frame.height > originalHeight }
        XCTAssertTrue(second.isSelected)
        choose("恢复默认尺寸", submenu: "默认内容尺寸")
        expect { abs(collection.frame.height - originalHeight) < 1 }
        XCTAssertEqual(second.frame.width, 80, accuracy: 1)
        capture("默认尺寸恢复与固定项宽")
    }

    func testAutomaticIndicatorContentStylesLTR() {
        checkAutomaticIndicatorStyles(rtl: false)
    }

    func testAutomaticIndicatorContentStylesRTL() {
        checkAutomaticIndicatorStyles(rtl: true)
    }

    private func checkAutomaticIndicatorStyles(rtl: Bool) {
        app.launchArguments = ["--open-gallery"] + (rtl ? ["--rtl"] : [])
        app.launch()
        let second = app.buttons["sp.tab.1"]
        let collection = app.collectionViews["sp.tabBar.collection"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        second.tap()
        expect { second.isSelected }
        capture("默认图文下划线")
        func choose(_ title: String, indicator: Bool = false) {
            app.buttons["配置"].tap()
            if indicator {
                app.buttons["指示器"].tap()
            }
            app.buttons[title].tap()
            reveal(second, in: collection, rtl: rtl)
            expect { second.isSelected }
            capture(title)
        }
        choose("自定义卡片")
        choose("默认下划线", indicator: true)
        choose("自动匹配内容", indicator: true)
        choose("紧凑编号内容")
        choose("默认内容")
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
        expect { abs(first.frame.width - max(44, (collection.frame.width - 32) / 13)) < 1 }
        for mode in [2, 3, 0] {
            chooseMode(mode, gallery: false)
            expect { abs(first.frame.width - originalWidth) < 1 }
            XCTAssertTrue((status.value as? String ?? "").contains("page=list;"))
            XCTAssertTrue(second.isSelected)
        }
        capture("分页模式切换后")
    }

    private func tapCardMenuAction(_ title: String) {
        let action = app.buttons[title]
        // 最大辅助字号下系统菜单会滚动并回收屏幕外的项。
        for _ in 0 ..< 8 {
            if action.exists, action.isHittable {
                action.tap()
                return
            }
            let menu = app.collectionViews.matching(NSPredicate(format: "identifier != %@", "sp.tabBar.collection"))
                .firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 4))
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).press(
                forDuration: 0.1,
                thenDragTo: menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            )
        }
        XCTFail("菜单项不可点击：\(title)")
    }

    private func checkFixedCardHeight(rtl: Bool) {
        app.launchArguments = ["--open-demo", "--custom-tabs"] + (rtl ? ["--rtl"] : [])
        if rtl {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let second = app.buttons["sp.tab.1"]
        XCTAssertTrue(second.waitForExistence(timeout: 8))
        let collection = app.collectionViews["sp.tabBar.collection"]
        reveal(second, in: collection, rtl: rtl)
        second.tap()
        let status = app.staticTexts["demo.status"]
        expect { second.isSelected && (status.value as? String ?? "").contains("page=list;") }
        let originalHeight = collection.frame.height
        XCTAssertGreaterThanOrEqual(originalHeight, 76)
        var lastHeightAction = ""
        var lastInsetsAction = ""
        for (title, height, insetsTitle, verticalInsets): (String, CGFloat, String, CGFloat) in [
            ("固定栏高 32", 32, "无留白", 0),
            ("固定栏高 32", 32, "对称留白", 12),
            ("固定栏高 32", 32, "非对称留白", 14),
            ("固定栏高 60", 60, "对称留白", 12),
            ("固定栏高 60", 60, "非对称留白", 14),
            ("隐藏标签栏", 0, "非对称留白", 14),
            ("固定栏高 32", 32, "非对称留白", 14),
            ("最小栏高 44", originalHeight + 14, "非对称留白", 14),
            ("最小栏高 44", originalHeight, "无留白", 0)
        ] {
            if title != lastHeightAction {
                app.buttons["demo.pages"].tap()
                tapCardMenuAction("标签栏高度")
                tapCardMenuAction(title)
                lastHeightAction = title
            }
            if insetsTitle != lastInsetsAction {
                app.buttons["demo.pages"].tap()
                tapCardMenuAction("留白与附件")
                tapCardMenuAction("内容留白")
                tapCardMenuAction(insetsTitle)
                lastInsetsAction = insetsTitle
            }
            if height == 0 {
                expect { !second.exists || !second.isHittable }
            } else {
                expect { abs(collection.frame.height - height) < 1 }
                reveal(second, in: collection, rtl: rtl)
                XCTAssertEqual(second.frame.height, height - verticalInsets, accuracy: 1)
                XCTAssertTrue(second.isSelected)
                // 紧凑卡片仍可真实点击切页，恢复时也不能累积点击回调。
                let first = app.buttons["sp.tab.0"]
                reveal(first, in: collection, rtl: rtl)
                first.tap()
                expect { first.isSelected }
                reveal(second, in: collection, rtl: rtl)
                second.tap()
                expect { second.isSelected }
            }
            XCTAssertTrue((status.value as? String ?? "").contains("page=list;"))
            if height > 0 {
                capture(title + "-" + insetsTitle)
            }
        }
        capture("自定义卡片固定栏高恢复")
    }

    func testPagerCardsFixedHeightAndRestore() {
        checkFixedCardHeight(rtl: false)
    }

    func testPagerCardsFixedHeightAndRestoreInRTL() {
        checkFixedCardHeight(rtl: true)
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
