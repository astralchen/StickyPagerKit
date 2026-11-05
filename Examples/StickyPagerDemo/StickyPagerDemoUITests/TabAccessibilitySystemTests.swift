import XCTest
import UIKit

/// 只操作真实系统设置；串行运行，并在 tearDown 恢复本次读取的原值。
@MainActor
final class TabAccessibilitySystemTests: XCTestCase {
    private let app = XCUIApplication()
    private let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    private var originals: [Setting: Bool] = [:]
    private var confirmedVoiceOverState: Bool?
    private var settingsPage: Setting?
    private var hasOpenedSettings = false

    private enum Setting: String, CaseIterable {
        case motion, transparency, voiceOver

        var page: String {
            switch self {
            case .motion: "MOTION_TITLE"
            case .transparency: "DISPLAY_AND_TEXT"
            case .voiceOver: "VOICEOVER_TITLE"
            }
        }

        var labels: [String] {
            switch self {
            case .motion: ["REDUCE_MOTION", "减弱动态效果", "减少动态效果", "Reduce Motion"]
            case .transparency: ["REDUCE_TRANSPARENCY", "降低透明度", "减少透明度", "Reduce Transparency"]
            case .voiceOver: ["VoiceOverTouchEnabled", "旁白", "VoiceOver"]
            }
        }
    }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        // 恢复失败也要继续尝试剩余原值，避免 XCTest 在异步清理中递归中断。
        continueAfterFailure = true
        // 先恢复旁白，避免影响其他开关与后续测试的真实触摸语义。
        for setting in [Setting.voiceOver, .transparency, .motion] {
            if let value = originals[setting] {
                set(setting, enabled: value, remembersOriginal: false)
            }
        }
        app.terminate()
        settings.terminate()
    }

    func testDefaultScaleSpringRespondsToActualSystemSettings() throws {
        try verifySettings(custom: false)
    }

    func testCustomScaleSpringRespondsToActualSystemSettings() throws {
        try verifySettings(custom: true)
    }

    func testDefaultVoiceOverFocusAndSingleActivation() throws {
        try verifyVoiceOver(custom: false)
    }

    func testCustomVoiceOverFocusAndSingleActivation() throws {
        try verifyVoiceOver(custom: true)
    }

    private func launchGallery(custom: Bool) {
        app.launchArguments = ["--window-regression", "--spring-effects", "--accessibility-regression"]
        app.launch()
        let gallery = app.buttons["标签外观"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 8))
        gallery.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        if custom {
            app.buttons["配置"].tap()
            app.buttons["自定义卡片"].tap()
        }
        for index in 0 ... 2 {
            XCTAssertEqual(app.buttons.matching(identifier: "sp.tab.\(index)").count, 1)
        }
        // 自定义卡片较宽，禁用项可能尚未创建 Cell；滚入视口后核对唯一入口。
        let tabs = app.collectionViews["sp.tabBar.collection"]
        let needsScroll = !app.buttons["sp.tab.3"].exists
        if needsScroll {
            tabs.swipeLeft()
        }
        XCTAssertEqual(app.buttons.matching(identifier: "sp.tab.3").count, 1)
        XCTAssertFalse(app.buttons["sp.tab.3"].isEnabled)
        if needsScroll {
            tabs.swipeRight()
            XCTAssertTrue(app.buttons["sp.tab.0"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(identifier: "sp.tab.1").count, 1)
        }
    }

    private var status: XCUIElement {
        app.staticTexts["demo.gallery.status"]
    }

    private func value(_ key: String) -> String? {
        (status.value as? String)?.split(separator: ";").first { $0.hasPrefix("\(key)=") }
            .map { String($0.dropFirst(key.count + 1)) }
    }

    private func expect(_ key: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { [self] _, _ in value(key) == expected }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5),
            .completed,
            "\(key)=\(expected)，实际 \(status.value ?? "nil")",
            file: file,
            line: line
        )
    }

    private func verifySettings(custom: Bool) throws {
        set(.motion, enabled: false)
        set(.transparency, enabled: false)
        launchGallery(custom: custom)
        expect("motion", "0")
        XCTAssertGreaterThan(try XCTUnwrap(Int(value("scaleHosts") ?? "")), 0)
        app.buttons["sp.tab.1"].tap()
        expect("commits", "1")
        expect("selected", "1")
        set(.motion, enabled: true)
        app.activate()
        expect("motion", "1")
        print("REDUCE_MOTION_VISIBLE_SNAPSHOT \(status.value ?? "nil")")
        expect("scaleHosts", "0")
        expect("selected", "1")
        expect("commits", "1")
        if custom {
            // 屏幕外缓存允许延迟更新，但重新显示时必须立即遵守当前系统设置。
            let tabs = app.collectionViews["sp.tabBar.collection"]
            tabs.swipeLeft()
            expect("scaleHosts", "0")
            print("REDUCE_MOTION_SCROLLED_SNAPSHOT \(status.value ?? "nil")")
            tabs.swipeRight()
            expect("scaleHosts", "0")
            expect("commits", "1")
        }
        app.buttons["sp.tab.0"].tap()
        expect("commits", "2")
        expect("selected", "0")
        capture("reduce-motion-on")
        set(.motion, enabled: false)
        app.activate()
        expect("motion", "0")
        XCTAssertGreaterThan(try XCTUnwrap(Int(value("scaleHosts") ?? "")), 0)
        expect("commits", "2")

        app.buttons["配置"].tap()
        app.buttons["视觉与动画"].tap()
        app.buttons["内容淡化"].tap()
        XCTAssertLessThan(try XCTUnwrap(Double(value("minAlpha") ?? "")), 1)
        set(.transparency, enabled: true)
        app.activate()
        expect("transparency", "1")
        expect("minAlpha", "1.0")
        expect("selected", "0")
        expect("commits", "2")
        capture("reduce-transparency-on")
        set(.transparency, enabled: false)
        app.activate()
        expect("transparency", "0")
        XCTAssertLessThan(try XCTUnwrap(Double(value("minAlpha") ?? "")), 1)
    }

    private func verifyVoiceOver(custom: Bool) throws {
        set(.voiceOver, enabled: false)
        set(.motion, enabled: false)
        launchGallery(custom: custom)
        set(.voiceOver, enabled: true)
        dismissVoiceOverNotificationIfPresent()
        app.activate()
        dismissVoiceOverNotificationIfPresent(waitForPrompt: true)
        expect("applicationState", "0")
        expect("voiceOver", "1")
        // 系统开关先于旁白建立前台焦点；就绪前的触摸仍可能按普通点击派发。
        // 等待真实焦点出现，不补发触摸，也不以固定延时推进测试。
        expect("hasFocus", "1")
        expect("commits", "0")
        capture("voiceover-ready-before-first-touch")
        let target = app.buttons["sp.tab.1"]
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        expect("focus", "sp.tab.1")
        expect("commits", "0")
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
        expect("selected", "1")
        expect("commits", "1")
        expect("focus", "sp.tab.1")
        app.swipeRight()
        expect("focus", "sp.tab.2")
        expect("commits", "1")
        capture("voiceover-focused-next-tab")
    }

    private func set(_ setting: Setting, enabled: Bool, remembersOriginal: Bool = true) {
        dismissVoiceOverNotificationIfPresent()
        if !hasOpenedSettings || settings.state == .notRunning {
            settings.terminate()
            settings.launch()
            settingsPage = nil
            hasOpenedSettings = true
        } else {
            settings.activate()
        }
        if settingsPage != setting {
            if settingsPage != nil {
                let back = settings.navigationBars.buttons.firstMatch
                guard back.waitForExistence(timeout: 5) else {
                    XCTFail("无障碍设置页缺少返回入口：\(settings.debugDescription)"); return
                }
                activate(back)
            } else {
                let accessibility = settings.buttons["com.apple.settings.accessibility"]
                let voiceOver = confirmedVoiceOverState ?? UIAccessibility.isVoiceOverRunning
                // 真机首页还有网络等条目；先真实滚动／旁白导航到入口，不假定它首屏可见。
                for _ in 0 ..< (voiceOver ? 40 : 6) {
                    if accessibility.exists, accessibility.isHittable {
                        break
                    }
                    if voiceOver {
                        settings.swipeRight()
                    } else {
                        settings.swipeUp()
                    }
                }
                guard accessibility.exists, accessibility.isHittable else {
                    XCTFail("未找到可操作的无障碍入口：\(settings.debugDescription)"); return
                }
                activate(accessibility)
            }
            let page = settings.buttons[setting.page]
            guard page.waitForExistence(timeout: 5) else {
                XCTFail("未找到设置页面 \(setting.rawValue)：\(settings.debugDescription)"); return
            }
            activate(page)
        }
        let toggle = settings.switches.matching(NSPredicate(
            format: "identifier IN %@ OR label IN %@",
            setting.labels,
            setting.labels
        )).firstMatch
        guard toggle.waitForExistence(timeout: 5) else {
            XCTFail("未找到设置开关 \(setting.rawValue)：\(settings.debugDescription)"); return
        }
        settingsPage = setting
        guard let raw = toggle.value as? String, raw == "0" || raw == "1" else {
            XCTFail("无法读取系统开关：\(setting)"); return
        }
        if remembersOriginal, originals[setting] == nil {
            originals[setting] = raw == "1"
            print("SYSTEM_SETTING_ORIGINAL \(setting.rawValue)=\(raw)")
        }
        if setting == .voiceOver {
            confirmedVoiceOverState = raw == "1"
        }
        if (raw == "1") != enabled {
            // 当前系统把整行报告为 Switch；行中心并非实际开关命中区域。
            // 中文／英文设置页面均为 LTR，使用行尾可见开关，保留真实触摸和原值断言。
            let coordinate = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            let voiceOverWasRunning = confirmedVoiceOverState ?? UIAccessibility.isVoiceOverRunning
            print(
                "SYSTEM_SETTING_TOUCH \(setting.rawValue) frame=\(toggle.frame) value=\(raw) voiceOver=\(voiceOverWasRunning)"
            )
            coordinate.tap()
            if voiceOverWasRunning {
                coordinate.doubleTap()
            }
        }
        // 一次真实触摸后等待系统提交目标值，不重试触摸，也不直接写偏好。
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"),
            object: toggle
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [changed], timeout: 5),
            .completed,
            "系统开关 \(setting.rawValue) 未提交目标值，实际 \(toggle.value ?? "nil")"
        )
        if setting == .voiceOver, toggle.value as? String == (enabled ? "1" : "0") {
            // Runner 的 UIKit 状态通知可能晚于设置开关，导航以已确认的系统值为准。
            confirmedVoiceOverState = enabled
            print("VOICEOVER_CONFIRMED value=\(enabled) runner=\(UIAccessibility.isVoiceOverRunning)")
        }
        if setting == .voiceOver, enabled, settings.buttons["好"].waitForExistence(timeout: 1) {
            activate(settings.buttons["好"])
        }
        capture("settings-\(setting.rawValue)-\(enabled)")
    }

    private func activate(_ element: XCUIElement) {
        let voiceOverWasRunning = confirmedVoiceOverState ?? UIAccessibility.isVoiceOverRunning
        if !voiceOverWasRunning {
            // 导航元素在旁白关闭时只发送一次普通点击。
            element.tap()
            return
        }
        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
        if voiceOverWasRunning {
            coordinate.doubleTap()
        }
    }

    private func dismissVoiceOverNotificationIfPresent(waitForPrompt: Bool = false) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@",
            "旁白",
            "通知"
        )).firstMatch
        guard waitForPrompt ? alert.waitForExistence(timeout: 2) : alert.exists else {
            return
        }
        capture("voiceover-notification-permission")
        // 仅处理已观察到的旁白通知提示，不授权通知，也不吞掉其他系统提示。
        let decline = alert.buttons["不允许"]
        XCTAssertTrue(decline.exists)
        let point = decline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        point.tap()
        point.doubleTap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        print("VOICEOVER_NOTIFICATION_DISMISSED")
    }

    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
