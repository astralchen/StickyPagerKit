import CryptoKit
import UIKit
import XCTest
@testable import StickyPagerKit

@MainActor
final class SPTabBarIconFastPathTests: XCTestCase {
    /// 计数只约束局部路径，呈现颜色在调用返回时核对，不以强制布局补齐高亮颜色。
    func testEligibleUpdatesAndHighlightFallbackAreSynchronous() throws {
        for style: UIUserInterfaceStyle in [.light, .dark] {
            try verifyHighlightFallback(style: style)
        }
    }

    private func verifyHighlightFallback(style: UIUserInterfaceStyle) throws {
        let fixture = try SPTabColorFixture(colors: true)
        defer { fixture.close() }
        fixture.bar.overrideUserInterfaceStyle = style
        fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .red
        fixture.beginSelection()
        let button = try fixture.button(at: 1)
        let reference = UIButton(type: .system)
        reference.frame = CGRect(x: 0, y: 200, width: 100, height: 64)
        // 两个按钮继承同一标签栏的外观，UIKit 会按外观解析图标高亮色。
        fixture.bar.addSubview(reference)
        reference.layoutIfNeeded()
        XCTAssertEqual(reference.traitCollection.userInterfaceStyle, style)
        XCTAssertEqual(button.traitCollection.userInterfaceStyle, style)
        let base = try XCTUnwrap(button.configuration)
        let diagnostics = SPTabColorDiagnostics()
        try fixture.attach(diagnostics)
        func progress(_ value: CGFloat, assignments: UInt) {
            diagnostics.statistics = .init()
            fixture.bar.setTransitionProgress(from: 0, to: 1, progress: value)
            let color = UIColor(red: 1 - value, green: 0, blue: value, alpha: 1)
            reference.isHighlighted = button.isHighlighted
            var config = base
            config.baseForegroundColor = color
            reference.tintColor = color
            reference.configuration = config
            XCTAssertEqual(button.tintColor, color)
            XCTAssertEqual(button.imageView?.tintColor, reference.imageView?.tintColor)
            XCTAssertEqual(button.titleLabel?.textColor, UIColor.red)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, assignments)
            XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, 0)
        }
        // 保持在同一预览快照内；跨 0.5 的离散刷新由状态快照矩阵另行验证。
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.12)
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.16)
        progress(0.2, assignments: 0)
        XCTAssertNil(button.configuration?.baseForegroundColor)
        diagnostics.statistics = .init()
        button.isHighlighted = true
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 1)
        XCTAssertEqual(button.configuration?.baseForegroundColor, button.tintColor)
        XCTAssertEqual(button.imageView?.tintColor, button.tintColor)
        progress(0.25, assignments: 1)
        button.isHighlighted = false
        progress(0.3, assignments: 1)
        progress(0.35, assignments: 0)
        XCTAssertNil(button.configuration?.baseForegroundColor)
    }

    /// 独立候选先验证高亮前固定当前颜色；不依赖 UIKit 下一次自动更新来补齐颜色。
    func testHighlightFallbackPrototype() throws {
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController(); window.showForTesting()
        defer { window.closeForTesting() }
        let baseline = UIButton(type: .system), candidate = SPFastPathPrototypeButton(type: .system)
        var base = UIButton.Configuration.plain()
        base.title = "标签"; base.image = UIImage(systemName: "star")?.withRenderingMode(.alwaysTemplate)
        base.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in
            var result = input; result.foregroundColor = UIColor.red; return result
        }
        candidate.base = base
        for (index, button) in [baseline, candidate].enumerated() {
            button.frame = CGRect(x: 20, y: 100 + index * 80, width: 100, height: 64)
            window.rootViewController!.view.addSubview(button)
        }
        for highlighted in [false, true, false, true, false] {
            baseline.isHighlighted = highlighted; candidate.isHighlighted = highlighted
            for progress: CGFloat in [0.2, 0.5, 0.8] {
                let color = UIColor(red: 1 - progress, green: 0, blue: progress, alpha: 1)
                var config = base; config.baseForegroundColor = color
                baseline.tintColor = color; baseline.configuration = config
                candidate.apply(color)
                XCTAssertEqual(candidate.tintColor, baseline.tintColor)
                XCTAssertEqual(candidate.imageView?.tintColor, baseline.imageView?.tintColor, "调用返回时必须已与基线一致")
                XCTAssertEqual(candidate.titleLabel?.textColor, baseline.titleLabel?.textColor)
                [baseline, candidate].forEach { $0.layoutIfNeeded() }
                XCTAssertEqual(candidate.imageView?.tintColor, baseline.imageView?.tintColor)
            }
        }
    }

    /// 相同脚本分别运行于冻结的 A/B，配置表示另列，不把内部字段差异当呈现失败。
    func testIntegratedStateSnapshots() throws {
        var records: [[String: Any]] = []
        for mode in ["eligible", "automatic", "both", "original"] {
            let fixture = try SPTabColorFixture(colors: true)
            defer { fixture.close() }
            if mode != "both" {
                fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .red
            }
            if mode == "automatic" {
                fixture.bar.standardAppearance.itemAppearance.normal.iconColor = nil
                fixture.bar.standardAppearance.itemAppearance.selected.iconColor = nil
            }
            if mode ==
                "original" {
                fixture.bar.items.forEach { $0.image = $0.image?.withRenderingMode(.alwaysOriginal) }
            }
            fixture.beginSelection()
            let button = try fixture.button(at: 1)
            let diagnostics = SPTabColorDiagnostics(); try fixture.attach(diagnostics)
            func record(_ name: String, _ action: () -> Void) throws {
                action()
                let immediate = model(button)
                fixture.bar.layoutIfNeeded(); button.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: button.bounds)
                    .image { context in button.layer.render(in: context.cgContext) }
                let data = try XCTUnwrap(image.pngData())
                records.append([
                    "name": "\(mode)-\(name)",
                    "immediate": immediate,
                    "afterLayout": model(button),
                    "foreground": rgba(button.configuration?.baseForegroundColor),
                    "png": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                ])
            }
            for p: CGFloat in [0.2, 0.3] {
                try record("normal-\(p)") { fixture.bar.setTransitionProgress(
                    from: 0,
                    to: 1,
                    progress: p
                ) }
            }
            try record("highlight-enter") { button.isHighlighted = true }
            for p: CGFloat in [0.4, 0.5] {
                try record("highlight-\(p)") { fixture.bar.setTransitionProgress(
                    from: 0,
                    to: 1,
                    progress: p
                ) }
            }
            try record("highlight-exit") { button.isHighlighted = false }
            try record("normal-resume") { fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.6) }
            try record("parent-dim") { fixture.bar.tintAdjustmentMode = .dimmed }
            try record("dim-progress") { fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.7) }
            try record("parent-normal") { fixture.bar.tintAdjustmentMode = .normal }
            try record("normal-again") { fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.8) }
            try record("disabled") { fixture.bar.items[1].isEnabled = false }
            try record("reenabled") { fixture.bar.items[1].isEnabled = true }
            try record("new-snapshot") { fixture.bar.items[1].title = "新标题" }
            try record("parent-tint") { fixture.bar.tintColor = .purple }
            try record("reverse") { fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.4) }
            try record("commit") { fixture.bar.setSelectedIndex(1, animated: false) }
            XCTAssertEqual(fixture.bar.selectedIndex, 1)
        }
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: ["schema": "sp-icon-fastpath-v1", "records": records]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "icon-fastpath"; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func model(_ button: UIButton) -> [String: Any] {
        [
            "tint": rgba(button.tintColor),
            "imageTint": rgba(button.imageView?.tintColor),
            "titleColor": rgba(button.titleLabel?.textColor),
            "enabled": button.isEnabled,
            "highlighted": button.isHighlighted,
            "title": button.titleLabel?.text ?? "",
            "imageFrame": rect(button.imageView?.frame ?? .zero),
            "titleFrame": rect(button.titleLabel?.frame ?? .zero)
        ]
    }

    private func rgba(_ color: UIColor?) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color?.getRed(&r, green: &g, blue: &b, alpha: &a) == true else {
            return []
        }
        return [r, g, b, a].map(Double.init)
    }

    private func rect(_ value: CGRect) -> [Double] {
        [value.minX, value.minY, value.width, value.height]
            .map(Double.init)
    }
}

@MainActor
private final class SPFastPathPrototypeButton: UIButton {
    var base = UIButton.Configuration.plain()
    private var current: UIColor = .red
    private var tintOnly = false
    override var isHighlighted: Bool {
        willSet {
            if newValue != isHighlighted, tintOnly {
                var config = base; config.baseForegroundColor = current
                tintOnly = false; configuration = config
            }
        }
    }

    func apply(_ color: UIColor) {
        current = color; tintColor = color
        if isHighlighted {
            var config = base; config.baseForegroundColor = color; configuration = config; tintOnly = false
        } else if !tintOnly {
            var config = base; config.baseForegroundColor = nil; configuration = config; tintOnly = true
        }
    }
}
