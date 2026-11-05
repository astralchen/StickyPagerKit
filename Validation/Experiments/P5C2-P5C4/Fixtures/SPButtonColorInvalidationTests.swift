import CryptoKit
import MachO
import UIKit
import XCTest

/// P5C3 独立 UIKit 夹具：四组干预不代表四个生产候选；计数不作为 CPU 收益。
@MainActor
final class SPButtonColorInvalidationTests: XCTestCase {
    func testStateMatrix() async throws {
        var rows: [[String: Any]] = []
        for state in ["normal", "highlighted", "disabled", "dimmed"] {
            for arm in SPColorWriteArm.allCases {
                let fixture = SPButtonInvalidationFixture()
                try await fixture.open()
                fixture.state(state)
                try await fixture.waitTicks(3)
                for progress: CGFloat in [0.2, 0.5, 0.8] {
                    fixture.log.reset()
                    fixture.apply(arm, color: UIColor(red: 1 - progress, green: 0, blue: progress, alpha: 1))
                    let immediate = fixture.pairedModel()
                    fixture.log.phase = "natural"
                    try await fixture.waitTicks(3)
                    let natural = fixture.pairedModel()
                    let events = fixture.log.events
                    fixture.log.phase = "forcedLayout"
                    fixture.buttons.forEach { $0.layoutIfNeeded() }
                    let afterLayout = fixture.pairedModel()
                    let rendered = try fixture.pairedImageHash()
                    rows.append([
                        "arm": arm.rawValue,
                        "state": state,
                        "progress": progress,
                        "immediate": immediate,
                        "natural": natural,
                        "afterLayout": afterLayout,
                        "renderedSHA256": rendered,
                        "naturalEvents": events,
                        "allEvents": fixture.log.events
                    ])
                }
                try await fixture.close()
            }
        }
        try attach(rows, name: "state-matrix")
    }

    func testNaturalProgressFactorial() async throws {
        var rows: [[String: Any]] = []
        for arm in SPColorWriteArm.allCases {
            let fixture = SPButtonInvalidationFixture()
            try await fixture.open()
            fixture.log.reset()
            var points: [[String: Any]] = []
            fixture.clock.action = { [weak fixture] tick in
                guard let fixture else {
                    return
                }
                let progress = CGFloat(tick) / 24
                fixture.log.point = tick
                fixture.apply(arm, color: UIColor(red: 1 - progress, green: 0, blue: progress, alpha: 1))
                points.append(["point": tick, "model": fixture.pairedModel()])
                fixture.log.phase = "natural"
            }
            fixture.clock.remaining = 24
            try await fixture.waitUntil { fixture.clock.remaining == 0 }
            fixture.clock.action = nil
            try await fixture.waitTicks(3)
            XCTAssertEqual(points.count, 24)
            let final = fixture.pairedModel()
            rows.append(["arm": arm.rawValue, "points": points, "final": final, "events": fixture.log.events])
            try await fixture.close()
        }
        try attach(rows, name: "natural-factorial")
    }

    func testSameColorWrites() async throws {
        var rows: [[String: Any]] = []
        for arm in SPColorWriteArm.allCases {
            let fixture = SPButtonInvalidationFixture()
            try await fixture.open()
            fixture.log.reset()
            for point in 1 ... 12 {
                fixture.log.point = point
                fixture.apply(arm, color: .red)
                fixture.log.phase = "natural"
                try await fixture.waitTicks(2)
            }
            rows.append(["arm": arm.rawValue, "model": fixture.pairedModel(), "events": fixture.log.events])
            try await fixture.close()
        }
        try attach(rows, name: "same-color")
    }

    func testStateChangesAfterColorUpdate() async throws {
        var rows: [[String: Any]] = []
        for arm in SPColorWriteArm.allCases {
            let fixture = SPButtonInvalidationFixture()
            try await fixture.open()
            fixture.apply(arm, color: .blue)
            try await fixture.waitTicks(3)
            for state in ["highlighted", "normal", "disabled", "normal", "dimmed", "normal"] {
                fixture.log.reset()
                fixture.state(state)
                let immediate = fixture.pairedModel()
                fixture.log.phase = "natural"
                try await fixture.waitTicks(3)
                let natural = fixture.pairedModel()
                fixture.buttons.forEach { $0.layoutIfNeeded() }
                rows.append([
                    "arm": arm.rawValue,
                    "state": state,
                    "immediate": immediate,
                    "natural": natural,
                    "afterLayout": fixture.pairedModel(),
                    "renderedSHA256": try fixture.pairedImageHash(),
                    "events": fixture.log.events
                ])
            }
            // 使用公开请求入口验证观察器；不直接调用 updateConfiguration。
            fixture.log.reset()
            fixture.buttons.forEach { $0.setNeedsUpdateConfiguration() }
            try await fixture.waitTicks(3)
            XCTAssertGreaterThan(fixture.log.events.filter { $0["name"] as? String == "update.begin" }.count, 0)
            _ = fixture.pairedModel()
            try await fixture.close()
        }
        try attach(rows, name: "state-cycle")
    }

    private func attach(_ rows: [[String: Any]], name: String) throws {
        let checker = (0 ..< _dyld_image_count()).contains { index in
            _dyld_get_image_name(index).map { String(cString: $0).hasSuffix("/libMainThreadChecker.dylib") } ?? false
        }
        XCTAssertFalse(checker)
        let report: [String: Any] = [
            "schema": "sp-button-invalidation-v1",
            "experiment": name,
            "rows": rows,
            "mainThreadCheckerLoaded": checker,
            "note": "直接计数夹具自己的标题 transformer；子类回调转发 super。普通 UIButton 对照核对模型与静态像素。时序有诊断开销，非性能计时或真实触摸。"
        ]
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "button-invalidation-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private enum SPColorWriteArm: String, CaseIterable {
    case none, tint, configuration, both
    var writesTint: Bool {
        self == .tint || self == .both
    }

    var writesConfiguration: Bool {
        self == .configuration || self == .both
    }
}

@MainActor
private final class SPInvalidationLog {
    var phase = "setup"
    var point = 0
    var events: [[String: Any]] = []
    func record(_ name: String) {
        events.append(["name": name, "phase": phase, "point": point, "time": CACurrentMediaTime()])
    }

    func reset() {
        events.removeAll(keepingCapacity: true); phase = "write"; point = 0
    }
}

@MainActor
private final class SPInvalidationButton: UIButton {
    weak var log: SPInvalidationLog?
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
private final class SPInvalidationClock: NSObject {
    var ticks = 0
    var remaining = 0
    var action: ((Int) -> Void)?
    @objc func tick(_: CADisplayLink) {
        ticks += 1
        if remaining > 0 {
            action?(25 - remaining); remaining -= 1
        }
    }
}

@MainActor
private final class SPInvalidationController: UIViewController {
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
private final class SPButtonInvalidationFixture {
    let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let controller = SPInvalidationController()
    let probe = SPInvalidationButton(type: .system)
    let reference = UIButton(type: .system)
    let log = SPInvalidationLog()
    let clock = SPInvalidationClock()
    var buttons: [UIButton] {
        [probe, reference]
    }

    private var link: CADisplayLink?
    private var bases: [UIButton.Configuration] = []

    init() {
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .light
        probe.log = log
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in
            UIImage(systemName: "star")!.draw(in: CGRect(x: 0, y: 0, width: 24, height: 24))
        }.withRenderingMode(.alwaysTemplate)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 30, y: 120 + index * 100, width: 100, height: 64)
            button.semanticContentAttribute = .forceLeftToRight
            var base = UIButton.Configuration.plain()
            base.title = "标签"
            base.image = image
            base.imagePlacement = .top
            base.imagePadding = 4
            base.baseForegroundColor = .red
            let log = index == 0 ? self.log : nil
            base.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [weak log] attributes in
                log?.record("titleTransformer")
                var result = attributes
                result.font = UIFont.systemFont(ofSize: 14)
                result.foregroundColor = UIColor.red
                return result
            }
            bases.append(base)
            button.tintColor = .red
            button.configuration = base
            controller.view.addSubview(button)
        }
    }

    func open() async throws {
        window.makeKeyAndVisible()
        let link = CADisplayLink(target: clock, selector: #selector(SPInvalidationClock.tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        try await waitUntil { controller.appeared }
        buttons.forEach { $0.layoutIfNeeded() }
        try await waitTicks(3)
        XCTAssertTrue(probe.automaticallyUpdatesConfiguration)
        XCTAssertTrue(reference.automaticallyUpdatesConfiguration)
    }

    func close() async throws {
        clock.action = nil
        link?.invalidate(); link = nil
        window.rootViewController = nil
        try await waitUntil { controller.disappeared }
        window.isHidden = true
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
        let target = clock.ticks + count
        try await waitUntil { clock.ticks >= target }
    }

    func apply(_ arm: SPColorWriteArm, color: UIColor) {
        log.phase = "write"
        for (index, button) in buttons.enumerated() {
            if arm.writesTint {
                if index == 0 {
                    log.record("explicitTint")
                }
                button.tintColor = color
            }
            if arm.writesConfiguration {
                // 每次从不变基础快照生成；不持有上一帧完整配置。
                var configuration = bases[index]
                configuration.baseForegroundColor = color
                if index == 0 {
                    log.record("explicitConfiguration")
                }
                button.configuration = configuration
            }
        }
    }

    func state(_ state: String) {
        log.phase = "state"
        for button in buttons {
            button.isHighlighted = state == "highlighted"
            button.isEnabled = state != "disabled"
            button.tintAdjustmentMode = state == "dimmed" ? .dimmed : .normal
        }
    }

    func pairedModel() -> [String: Any] {
        let actual = model(probe), expected = model(reference)
        XCTAssertTrue(NSDictionary(dictionary: actual).isEqual(to: expected), "诊断子类与普通 UIButton 必须保持相同模型")
        return actual
    }

    func pairedImageHash() throws -> String {
        let images = try buttons.map { button in
            try XCTUnwrap(UIGraphicsImageRenderer(bounds: button.bounds).image { context in
                button.layer.render(in: context.cgContext)
            }.pngData())
        }
        XCTAssertEqual(images[0], images[1], "诊断不能改变静态渲染结果")
        return SHA256.hash(data: images[0]).map { String(format: "%02x", $0) }.joined()
    }

    private func model(_ button: UIButton) -> [String: Any] {
        [
            "tint": rgba(button.tintColor),
            "imageTint": rgba(button.imageView?.tintColor),
            "titleColor": rgba(button.titleLabel?.textColor),
            "foreground": rgba(button.configuration?.baseForegroundColor),
            "title": button.titleLabel?.text ?? "",
            "enabled": button.isEnabled,
            "highlighted": button.isHighlighted,
            "adjustment": button.tintAdjustmentMode.rawValue,
            "titleFrame": rect(button.titleLabel?.frame ?? .zero),
            "imageFrame": rect(button.imageView?.frame ?? .zero)
        ]
    }

    private func rgba(_ color: UIColor?) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color?.getRed(&r, green: &g, blue: &b, alpha: &a) == true else {
            return []
        }
        return [r, g, b, a].map(Double.init)
    }

    private func rect(_ frame: CGRect) -> [Double] {
        [frame.origin.x, frame.origin.y, frame.width, frame.height].map(Double.init)
    }
}
