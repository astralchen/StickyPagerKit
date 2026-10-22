import XCTest

@MainActor
final class TabBarBadgeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
        UITestOrientation.set(.portrait)
    }

    private func checkBadges(arguments: [String]) {
        app.launchArguments = ["--open-gallery", "--window-regression", "--chinese-badges"] + arguments
        app.launch()
        let first = app.buttons["sp.tab.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertEqual(first.value as? String, "新")
        first.tap()
        let status = app.staticTexts["demo.gallery.status"]
        XCTAssertTrue(status.label.contains("已选择：推荐"))
        XCTAssertTrue(status.label.contains("角标：新"))
        let favorite = app.buttons["sp.tab.1"]
        XCTAssertEqual(favorite.value as? String, "上新")
        favorite.tap()
        XCTAssertTrue(status.label.contains("已选择：收藏"))
        XCTAssertTrue(status.label.contains("角标：上新"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "中文右上角角标-\(arguments.joined(separator: "-"))"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testChineseBadgesAndSelection() {
        checkBadges(arguments: [])
    }

    func testChineseBadgesRTLAndDarkAppearance() {
        checkBadges(arguments: ["--rtl", "--dark"])
    }
}
