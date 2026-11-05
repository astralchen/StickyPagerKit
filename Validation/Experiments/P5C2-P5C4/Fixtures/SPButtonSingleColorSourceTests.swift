import CryptoKit
import MachO
import UIKit
import XCTest

/// P5C4：内部配置表示与可观察呈现分开记录；候选等价性由完整记录判定。
@MainActor
final class SPButtonSingleColorSourceTests: XCTestCase {
    func testExplicitColorStateMatrix() async throws {
        var rows: [[String: Any]] = []
        for original in [false, true] {
            let fixture = SPSingleSourceFixture(original: original)
            defer { fixture.window.isHidden = true }
            try await fixture.open()
            for state in ["normal", "highlighted", "disabled", "dimmed"] {
                fixture.setState(state)
                try await fixture.waitTicks(3)
                for progress: CGFloat in [0.2, 0.5, 0.8] {
                    fixture.resetLogs()
                    let color = UIColor(red: 1 - progress, green: 0, blue: progress, alpha: progress == 0.5 ? 0.4 : 1)
                    fixture.apply(icon: color)
                    rows.append(try await fixture.capture("\(original)-\(state)-\(progress)", metadata: [
                        "original": original,
                        "state": state,
                        "progress": progress
                    ]))
                }
            }
            try await fixture.close()
        }
        try attach(rows, name: "explicit-matrix")
    }

    func testStateRestorationAndTraits() async throws {
        let fixture = SPSingleSourceFixture()
        defer { fixture.window.isHidden = true }
        try await fixture.open()
        fixture.apply(icon: .blue)
        try await fixture.waitTicks(3)
        var rows: [[String: Any]] = []
        for (index, state) in [
            "highlighted",
            "normal",
            "disabled",
            "normal",
            "dimmed",
            "normal",
            "disabledDimmed",
            "normal"
        ].enumerated() {
            fixture.resetLogs()
            fixture.setState(state)
            rows.append(try await fixture.capture("state-\(index)-\(state)"))
        }
        for dimmed in [true, false] {
            fixture.resetLogs()
            fixture.parent.tintAdjustmentMode = dimmed ? .dimmed : .automatic
            rows.append(try await fixture.capture("parent-dim-\(dimmed)"))
        }
        let dynamic = UIColor { traits in traits.userInterfaceStyle == .dark ? .cyan : .magenta }
        fixture.resetLogs()
        fixture.apply(icon: dynamic)
        rows.append(try await fixture.capture("dynamic-initial-light"))
        for (index, style) in [UIUserInterfaceStyle.dark, .light].enumerated() {
            fixture.resetLogs()
            fixture.window.overrideUserInterfaceStyle = style
            rows.append(try await fixture.capture("dynamic-trait-\(index)"))
        }
        try await fixture.close()
        try attach(rows, name: "state-restoration")
    }

    func testTintInheritanceAndExplicitPriority() async throws {
        let fixture = SPSingleSourceFixture()
        defer { fixture.window.isHidden = true }
        try await fixture.open()
        fixture.apply(icon: .blue)
        try await fixture.waitTicks(3)
        var rows: [[String: Any]] = []
        let actions: [(String, () -> Void)] = [
            ("explicit-parent-green", { fixture.parent.tintColor = .green }),
            ("explicit-parent-orange", { fixture.parent.tintColor = .orange }),
            ("inherit-clear-explicit", { fixture.buttons.forEach { $0.tintColor = nil } }),
            ("inherit-parent-green", { fixture.parent.tintColor = .green }),
            ("inherit-reparent-purple", { fixture.move(to: fixture.otherParent) }),
            ("inherit-parent-dim", { fixture.otherParent.tintAdjustmentMode = .dimmed }),
            ("inherit-parent-normal", { fixture.otherParent.tintAdjustmentMode = .automatic }),
            ("explicit-restore-blue", { fixture.apply(icon: .blue) }),
            ("explicit-reparent-green", { fixture.move(to: fixture.parent) }),
            ("explicit-parent-orange-again", { fixture.parent.tintColor = .orange }),
            // 模拟上层重新解析父 tint 后提交颜色；不是把 UIButton 继承直接等同于 SPTabBar 接入。
            ("resolved-parent-refresh", { fixture.apply(icon: fixture.parent.tintColor) })
        ]
        for (name, action) in actions {
            fixture.resetLogs()
            action()
            rows.append(try await fixture.capture(name))
            let expected: UIColor = name.hasPrefix("inherit") ? fixture.buttons[0].superview!.tintColor :
                name == "resolved-parent-refresh" ? fixture.parent.tintColor : .blue
            for button in fixture.buttons {
                XCTAssertEqual(button.tintColor, expected, "显式优先级与清除后的继承必须符合操作意图")
            }
        }
        try await fixture.close()
        try attach(rows, name: "inheritance")
    }

    func testNaturalIconAndCombinedProgress() async throws {
        var rows: [[String: Any]] = []
        for combined in [false, true] {
            let fixture = SPSingleSourceFixture()
            defer { fixture.window.isHidden = true }
            try await fixture.open()
            fixture.resetLogs()
            var points: [[String: Any]] = []
            fixture.clock.action = { [weak fixture] point in
                guard let fixture else {
                    return
                }
                let before = fixture.models()
                let progress = CGFloat(point) / 24
                let color = UIColor(red: 1 - progress, green: 0, blue: progress, alpha: 1)
                fixture.logs.forEach { $0.point = point }
                fixture.apply(icon: color, title: combined ? color : nil)
                points.append(["point": point, "before": before, "immediate": fixture.models()])
                fixture.logs.forEach { $0.phase = "natural" }
            }
            fixture.clock.remaining = 24
            try await fixture.waitUntil { fixture.clock.remaining == 0 }
            fixture.clock.action = nil
            try await fixture.waitTicks(3)
            XCTAssertEqual(points.count, 24)
            rows.append([
                "combined": combined,
                "points": points,
                "final": fixture.models(),
                "events": fixture.logs.map(\.events)
            ])
            try await fixture.close()
        }
        try attach(rows, name: "natural-progress")
    }

    private func attach(_ rows: [[String: Any]], name: String) throws {
        let checker = (0 ..< _dyld_image_count()).contains { index in
            _dyld_get_image_name(index).map { String(cString: $0).hasSuffix("/libMainThreadChecker.dylib") } ?? false
        }
        XCTAssertFalse(checker)
        let report: [String: Any] = [
            "schema": "sp-button-single-source-v1",
            "experiment": name,
            "rows": rows,
            "mainThreadCheckerLoaded": checker,
            "note": "每组的诊断与普通按钮严格核对；跨方案差异保留给等价性分析。即时模型、自然调度、静态像素分开；非性能计时或真实触摸。"
        ]
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "single-source-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
    }
}

@MainActor
private final class SPSourceLog {
    var phase = "setup"
    var point = 0
    var events: [[String: Any]] = []
    func record(_ name: String) {
        events.append([
            "name": name,
            "phase": phase,
            "point": point,
            "time": CACurrentMediaTime()
        ])
    }

    func reset() {
        events.removeAll(keepingCapacity: true); phase = "write"; point = 0
    }
}

@MainActor
private final class SPSourceButton: UIButton {
    weak var log: SPSourceLog?
    override func updateConfiguration() {
        log?.record("update.begin"); super.updateConfiguration(); log?.record("update.end")
    }

    override func tintColorDidChange() {
        log?.record("tintChanged.begin"); super.tintColorDidChange(); log?.record("tintChanged.end")
    }

    override func layoutSubviews() {
        log?.record("layout.begin"); super.layoutSubviews(); log?.record("layout.end")
    }
}

@MainActor
private final class SPSourceClock: NSObject {
    var ticks = 0
    var remaining = 0
    var action: ((Int) -> Void)?
    @objc func tick(_: CADisplayLink) {
        ticks += 1; if remaining > 0 {
            action?(25 - remaining); remaining -= 1
        }
    }
}

@MainActor
private final class SPSourceController: UIViewController {
    var appeared = false
    var disappeared = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); appeared = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); disappeared = true
    }
}

@MainActor
private final class SPSingleSourceFixture {
    let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let controller = SPSourceController()
    let parent = UIView(frame: CGRect(x: 0, y: 80, width: 180, height: 500))
    let otherParent = UIView(frame: CGRect(x: 190, y: 80, width: 180, height: 500))
    let buttons: [UIButton] = [
        SPSourceButton(type: .system),
        UIButton(type: .system),
        SPSourceButton(type: .system),
        UIButton(type: .system)
    ]
    let logs = [SPSourceLog(), SPSourceLog()]
    let clock = SPSourceClock()
    private var bases: [UIButton.Configuration] = []
    private var link: CADisplayLink?

    init(original: Bool = false) {
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .light
        parent.tintColor = .green; otherParent.tintColor = .purple
        controller.view.addSubview(parent); controller.view.addSubview(otherParent)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in
            UIImage(systemName: "star")!.withTintColor(.orange, renderingMode: .alwaysOriginal).draw(in: CGRect(
                x: 0,
                y: 0,
                width: 24,
                height: 24
            ))
        }.withRenderingMode(original ? .alwaysOriginal : .alwaysTemplate)
        for (index, button) in buttons.enumerated() {
            let log = index % 2 == 0 ? logs[index / 2] : nil
            (button as? SPSourceButton)?.log = log
            button.frame = CGRect(x: 20, y: index * 100, width: 100, height: 64)
            button.semanticContentAttribute = .forceLeftToRight
            var base = UIButton.Configuration.plain()
            base.title = "标签"; base.image = image; base.imagePlacement = .top; base.imagePadding = 4
            base.baseForegroundColor = index < 2 ? .red : nil
            base.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak log] attributes in
                log?.record("titleTransformer")
                var result = attributes; result.font = UIFont.systemFont(ofSize: 14); result.foregroundColor = UIColor
                    .red
                return result
            }
            bases.append(base)
            button.tintColor = .red; button.configuration = base; parent.addSubview(button)
        }
    }

    func open() async throws {
        window.makeKeyAndVisible()
        let link = CADisplayLink(target: clock, selector: #selector(SPSourceClock.tick(_:)))
        link.add(to: .main, forMode: .common); self.link = link
        try await waitUntil { controller.appeared }
        buttons.forEach { $0.layoutIfNeeded() }
        try await waitTicks(3)
        buttons.forEach { XCTAssertTrue($0.automaticallyUpdatesConfiguration) }
    }

    func close() async throws {
        clock.action = nil; link?.invalidate(); link = nil; window.rootViewController = nil
        try await waitUntil { controller.disappeared }; window.isHidden = true
    }

    func waitUntil(_ predicate: () -> Bool) async throws {
        let start = CACurrentMediaTime()
        while !predicate(), CACurrentMediaTime() - start < 5 {
            try await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(predicate(), "自然调度或窗口生命周期等待超时")
        if !predicate() {
            throw CocoaError(.coderInvalidValue)
        }
    }

    func waitTicks(_ count: Int) async throws {
        let target = clock.ticks + count; try await waitUntil { clock.ticks >= target }
    }

    func resetLogs() {
        logs.forEach { $0.reset() }
    }

    func move(to host: UIView) {
        buttons.forEach { host.addSubview($0) }
    }

    func apply(icon: UIColor, title: UIColor? = nil) {
        logs.forEach { $0.phase = "write" }
        for (index, button) in buttons.enumerated() {
            let log = index % 2 == 0 ? logs[index / 2] : nil
            log?.record("explicitTint"); button.tintColor = icon
            if index < 2 || title != nil {
                var configuration = bases[index]
                if index < 2 {
                    configuration.baseForegroundColor = icon
                }
                if let title {
                    let base = configuration.titleTextAttributesTransformer
                    configuration
                        .titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                            var result = base?(attributes) ?? attributes; result.foregroundColor = title; return result
                        }
                }
                log?.record("explicitConfiguration"); button.configuration = configuration
            }
        }
    }

    func setState(_ state: String) {
        logs.forEach { $0.phase = "state" }
        for button in buttons {
            button.isHighlighted = state == "highlighted"
            button.isEnabled = state != "disabled" && state != "disabledDimmed"
            button.tintAdjustmentMode = state == "dimmed" || state == "disabledDimmed" ? .dimmed : .automatic
        }
    }

    func capture(_ name: String, metadata: [String: Any] = [:]) async throws -> [String: Any] {
        let immediate = models()
        logs.forEach { $0.phase = "natural" }
        try await waitTicks(3)
        let natural = models(), events = logs.map(\.events)
        logs.forEach { $0.phase = "forcedLayout" }
        buttons.forEach { $0.layoutIfNeeded() }
        let afterLayout = models()
        let hashes = try imageHashes()
        return [
            "name": name,
            "metadata": metadata,
            "immediate": immediate,
            "natural": natural,
            "afterLayout": afterLayout,
            "hashes": hashes,
            "naturalEvents": events,
            "allEvents": logs.map(\.events)
        ]
    }

    func models() -> [[String: Any]] {
        let values = buttons.map(model)
        XCTAssertTrue(NSDictionary(dictionary: values[0]).isEqual(to: values[1]), "基线观察器不能改变模型")
        XCTAssertTrue(NSDictionary(dictionary: values[2]).isEqual(to: values[3]), "候选观察器不能改变模型")
        return [values[0], values[2]]
    }

    private func imageHashes() throws -> [String] {
        let data = try buttons.map { button in
            try XCTUnwrap(UIGraphicsImageRenderer(bounds: button.bounds).image { context in
                button.layer.render(in: context.cgContext)
            }.pngData())
        }
        XCTAssertEqual(data[0], data[1]); XCTAssertEqual(data[2], data[3])
        return [data[0], data[2]].map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }

    private func model(_ button: UIButton) -> [String: Any] {
        let presentation: [String: Any] = [
            "tint": rgba(button.tintColor, button),
            "imageTint": rgba(button.imageView?.tintColor, button),
            "titleColor": rgba(button.titleLabel?.textColor, button),
            "title": button.titleLabel?.text ?? "",
            "enabled": button.isEnabled,
            "highlighted": button.isHighlighted,
            "adjustment": button.tintAdjustmentMode.rawValue,
            "titleFrame": rect(button.titleLabel?.frame ?? .zero),
            "imageFrame": rect(button.imageView?.frame ?? .zero),
            "font": button.titleLabel?.font.fontName ?? "",
            "fontSize": button.titleLabel?.font.pointSize ?? 0,
            "accessibilityTraits": button.accessibilityTraits.rawValue
        ]
        return ["presentation": presentation, "representation": [
            "foreground": rgba(button.configuration?.baseForegroundColor, button),
            "foregroundIsNil": button.configuration?.baseForegroundColor == nil
        ]]
    }

    private func rgba(_ color: UIColor?, _ button: UIButton) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color?.resolvedColor(with: button.traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a) == true else {
            return []
        }
        return [r, g, b, a].map(Double.init)
    }

    private func rect(_ frame: CGRect) -> [Double] {
        [frame.origin.x, frame.origin.y, frame.width, frame.height]
            .map(Double.init)
    }
}
