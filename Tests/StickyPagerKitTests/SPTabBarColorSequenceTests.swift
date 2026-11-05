import MachO
import ObjectiveC.runtime
import UIKit
import XCTest
@testable import StickyPagerKit

/// 仅在测试宿主观察公开 Objective-C 入口；不修改参数、不合并提交，也不作为耗时基线。
@MainActor
final class SPTabBarColorSequenceTests: XCTestCase {
    func testStandardTitleSequence() async throws {
        try await sequence(channel: "title", spring: false)
    }

    func testStandardIconSequence() async throws {
        try await sequence(channel: "icon", spring: false)
    }

    func testStandardBothSequence() async throws {
        try await sequence(channel: "both", spring: false)
    }

    func testSpringTitleSequence() async throws {
        try await sequence(channel: "title", spring: true)
    }

    func testSpringIconSequence() async throws {
        try await sequence(channel: "icon", spring: true)
    }

    func testSpringBothSequence() async throws {
        try await sequence(channel: "both", spring: true)
    }

    private func sequence(channel: String, spring: Bool) async throws {
        let fixture = SPColorSequenceFixture(channel: channel, spring: spring)
        defer { fixture.window.isHidden = true }
        try await fixture.waitForAppearance()
        let observer = try SPColorSequenceObserver(fixture: fixture)
        defer { observer.stop() }
        observer.start()
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertGreaterThan(observer.tickNumber, 1)
        let settling: UInt64 = spring ? 750_000_000 : 450_000_000
        var rounds: [[String: Any]] = []
        for scenario in ["normal", "interrupt", "reverse", "interactiveReverse"] {
            observer.scenario = scenario
            let begin = observer.events.count
            let sampleBegin = observer.samples.count
            if scenario == "normal" {
                observer.action("select-1") { fixture.bar.setSelectedIndex(1, animated: true) }
            } else if scenario == "interrupt" {
                observer.action("select-2") { fixture.bar.setSelectedIndex(2, animated: true) }
                try await Task.sleep(nanoseconds: 100_000_000)
                observer.action("retarget-3") { fixture.bar.setSelectedIndex(3, animated: true) }
            } else if scenario == "reverse" {
                observer.action("select-4") { fixture.bar.setSelectedIndex(4, animated: true) }
                try await Task.sleep(nanoseconds: 100_000_000)
                observer.action("return-3") { fixture.bar.setSelectedIndex(3, animated: true) }
            } else {
                // 模拟分页来源只提供进度；不是 advanceSelectionAnimation，也不代表真实触摸。
                observer.interactiveStart = CACurrentMediaTime()
            }
            try await Task.sleep(nanoseconds: settling)
            let selected = scenario == "normal" ? 1 : 3
            XCTAssertEqual(fixture.bar.selectedIndex, selected)
            XCTAssertNil(observer.interactiveStart, "模拟分页反转必须完成")
            for index in 0 ..< 6 {
                let button = fixture.buttons[index]
                XCTAssertEqual(
                    button.titleLabel?.textColor,
                    channel != "icon" && index == selected ? UIColor.blue : .red
                )
                XCTAssertEqual(button.tintColor, channel != "title" && index == selected ? UIColor.blue : .red)
            }
            let samples = Array(observer.samples.dropFirst(sampleBegin))
            let key = channel == "icon" ? "iconBlue" : "titleBlue"
            XCTAssertTrue(samples.contains { sample in
                let colors = sample["colors"] as! [[String: Double]]
                return colors.contains { $0[key, default: -1] > 0.05 && $0[key, default: -1] < 0.95 }
            }, "每种场景必须自然观察到中间颜色")
            if channel != "both" {
                let fixed = channel == "icon" ? "titleBlue" : "iconBlue"
                XCTAssertTrue(samples.allSatisfy { sample in
                    (sample["colors"] as! [[String: Double]]).allSatisfy { abs($0[fixed, default: -1]) < 0.001 }
                }, "固定颜色通道不能随另一通道改变")
            }
            rounds.append([
                "scenario": scenario,
                "eventBegin": begin,
                "eventEnd": observer.events.count,
                "sampleBegin": sampleBegin,
                "sampleEnd": observer.samples.count,
                "selectedIndex": selected
            ])
        }
        let counters = fixture.diagnostics.map(\.statistics)
        let assignments = counters
            .reduce(UInt(0)) { $0 + $1.baseConfigurationAssignments + $1.colorConfigurationAssignments }
        let observedAssignments = observer.events.filter { $0["name"] as? String == "configuration.begin" }.count
        XCTAssertGreaterThan(assignments, 0)
        XCTAssertEqual(observedAssignments, Int(assignments), "配置观察入口必须与框架独立计数一致")
        XCTAssertTrue(observer.events.contains { $0["name"] as? String == "button.layout.begin" })
        // 自然路径是否调用此公开入口是观测结果；用区间外的阳性对照验证入口有效。
        let updateProbe = observer.verifyUpdateObservation()
        observer.stop()
        XCTAssertTrue(observer.restored)
        let loaded = (0 ..< _dyld_image_count()).contains { index in
            _dyld_get_image_name(index).map { String(cString: $0).hasSuffix("/libMainThreadChecker.dylib") } ?? false
        }
        XCTAssertFalse(loaded)
        let report: [String: Any] = [
            "schema": "sp-color-sequence-v1",
            "channel": channel,
            "spring": spring,
            "mainThreadCheckerLoaded": loaded,
            "selectorsRestored": observer.restored,
            "updateEntryProbe": updateProbe,
            "rounds": rounds,
            "events": observer.events,
            "samples": observer.samples,
            "counters": try JSONSerialization.jsonObject(with: JSONEncoder().encode(counters)),
            "note": "诊断入口有额外开销，不用于时间基线。observer tick、RunLoop beforeSources 序号均不是屏幕呈现帧。UILabel setter 不是 transformer 调用次数。interactiveReverse 是合成分页输入，不是真实手势。"
        ]
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "color-sequence-\(channel)-\(spring)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try await fixture.close()
    }
}

@MainActor
private final class SPColorSequenceFixture {
    let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 64))
    let controller = SPColorSequenceController()
    var buttons: [UIButton] = []
    var contents: [UIView] = []
    var diagnostics: [SPTabColorDiagnostics] = []

    init(channel: String, spring: Bool) {
        window.rootViewController = controller
        bar.semanticContentAttribute = .forceLeftToRight
        bar.overrideUserInterfaceStyle = .light
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 6).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        bar.standardAppearance.itemAppearance.normal.titleColor = .red
        bar.standardAppearance.itemAppearance.normal.iconColor = .red
        bar.standardAppearance.itemAppearance.selected.titleColor = channel == "icon" ? .red : .blue
        bar.standardAppearance.itemAppearance.selected.iconColor = channel == "title" ? .red : .blue
        if spring {
            bar.visualStyle = .fadeAndStretch
            bar.visualStyle.unselectedScale = 0.94
            bar.selectionAnimationStyle = .spring
        }
        bar.visualStyle.interpolatesDefaultColors = true
        controller.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        window.makeKeyAndVisible()
        bar.layoutIfNeeded()
    }

    func waitForAppearance() async throws {
        let start = CACurrentMediaTime()
        while !controller.appeared, CACurrentMediaTime() - start < 5 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(controller.appeared)
        let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        for index in 0 ..< 6 {
            let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
            let host = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" } ?? cell
                .contentView
            buttons.append(try XCTUnwrap(host.subviews.compactMap { $0 as? UIButton }.first))
            contents.append(cell.contentView)
            let diagnostics = SPTabColorDiagnostics()
            try XCTUnwrap(cell.contentView as? SPTabColorDiagnosing).colorDiagnostics = diagnostics
            self.diagnostics.append(diagnostics)
        }
    }

    func close() async throws {
        window.rootViewController = nil
        let start = CACurrentMediaTime()
        while !controller.disappeared,
              CACurrentMediaTime() - start < 5 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(controller.disappeared)
        window.isHidden = true
    }
}

@MainActor
private final class SPColorSequenceController: UIViewController {
    var appeared = false
    var disappeared = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated); appeared = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated); disappeared = true
    }
}

/// 所有替换仅存在于串行测试进程，按原参数调用原 IMP，结束时恢复并检查。
/// 继承方法在目标类上安装同签名入口，不改父类实现；UILabel 的入口仅记录指定对象。
@MainActor
private final class SPColorSequenceObserver: NSObject {
    let fixture: SPColorSequenceFixture
    var events: [[String: Any]] = []
    var samples: [[String: Any]] = []
    var tickNumber = 0
    var runLoopSequence = 0
    var scenario = "startup"
    var interactiveStart: Double?
    private var displayLink: CADisplayLink?
    private var runLoopObserver: CFRunLoopObserver?
    private var hooks: [(AnyClass, Selector, IMP, IMP, String)] = []
    private var indices: [ObjectIdentifier: Int] = [:]
    private var stack: [String] = []
    private var lastBase = [UInt](repeating: 0, count: 6)
    private var lastColor = [UInt](repeating: 0, count: 6)
    private(set) var restored = false

    init(fixture: SPColorSequenceFixture) throws {
        self.fixture = fixture
        super.init()
        events.reserveCapacity(20000)
        samples.reserveCapacity(600)
        for index in 0 ..< 6 {
            indices[ObjectIdentifier(fixture.buttons[index])] = index
            indices[ObjectIdentifier(fixture.contents[index])] = index
            if let label = fixture.buttons[index].titleLabel {
                indices[ObjectIdentifier(label)] = index
            }
        }
        do {
            let buttonClass: AnyClass = try XCTUnwrap(object_getClass(fixture.buttons[0]))
            try hook(
                buttonClass,
                selector: NSSelectorFromString("setConfiguration:"),
                name: "configuration",
                argument: true
            )
            try hook(
                buttonClass,
                selector: #selector(UIButton.updateConfiguration),
                name: "button.update",
                argument: false
            )
            try hook(buttonClass, selector: #selector(UIView.layoutSubviews), name: "button.layout", argument: false)
            try hook(buttonClass, selector: #selector(setter: UIView.tintColor), name: "button.tint", argument: true)
            try hook(
                XCTUnwrap(object_getClass(fixture.contents[0])),
                selector: #selector(UIView.layoutSubviews),
                name: "content.layout",
                argument: false
            )
            try hook(
                UILabel.self,
                selector: #selector(setter: UILabel.attributedText),
                name: "title.attributedText",
                argument: true
            )
            try hook(
                UILabel.self,
                selector: #selector(setter: UILabel.textColor),
                name: "title.textColor",
                argument: true
            )
        } catch {
            stop()
            throw error
        }
    }

    func start() {
        let activities = CFRunLoopActivity.beforeSources.rawValue | CFRunLoopActivity.beforeWaiting.rawValue
        runLoopObserver = CFRunLoopObserverCreateWithHandler(nil, activities, true, 0) { [weak self] _, activity in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                if activity == .beforeSources {
                    self.runLoopSequence += 1
                }
                self.record(activity == .beforeSources ? "runloop.beforeSources" : "runloop.beforeWaiting", index: -1)
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, .commonModes)
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        if let runLoopObserver {
            CFRunLoopObserverInvalidate(runLoopObserver)
        }
        runLoopObserver = nil
        for hook in hooks.reversed() {
            let cls: AnyClass = hook.0
            let (selector, original, replacement, encoding) = (hook.1, hook.2, hook.3, hook.4)
            class_replaceMethod(cls, selector, original, encoding)
            XCTAssertTrue(class_getMethodImplementation(cls, selector) == original)
            imp_removeBlock(replacement)
        }
        hooks.removeAll()
        restored = true
    }

    /// 在全部场景结束后显式调用一次；证据单列，不混入自然路径的次数和时序。
    func verifyUpdateObservation() -> [[String: Any]] {
        let start = events.count
        action("probe-update") { fixture.buttons[0].updateConfiguration() }
        let probe = Array(events.dropFirst(start))
        XCTAssertEqual(probe.filter { $0["name"] as? String == "button.update.begin" }.count, 1)
        events.removeSubrange(start...)
        return probe
    }

    func action(_ name: String, body: () -> Void) {
        record("action.\(name).begin", index: -1)
        stack.append("action.\(name)")
        body()
        stack.removeLast()
        record("action.\(name).end", index: -1)
    }

    @objc private func tick(_ link: CADisplayLink) {
        tickNumber += 1
        record("display.tick", index: -1)
        if let start = interactiveStart {
            let fraction = min(1, (CACurrentMediaTime() - start) / 0.30)
            let progress = CGFloat(fraction <= 0.5 ? fraction * 1.4 : (1 - fraction) * 1.4)
            action("interactive-progress") { fixture.bar.setTransitionProgress(from: 3, to: 4, progress: progress) }
            if fraction == 1 {
                action("interactive-cancel") { fixture.bar.setSelectedIndex(3, animated: false) }
                interactiveStart = nil
            }
        }
        let colors = fixture.buttons
            .map { ["titleBlue": blue($0.titleLabel?.textColor), "iconBlue": blue($0.tintColor)] }
        samples.append([
            "time": CACurrentMediaTime(),
            "timestamp": link.timestamp,
            "targetTimestamp": link.targetTimestamp,
            "tick": tickNumber,
            "runLoopSequence": runLoopSequence,
            "scenario": scenario,
            "colors": colors,
            "attempts": fixture.diagnostics.map { $0.statistics.colorUpdateAttempts },
            "colorAssignments": fixture.diagnostics.map { $0.statistics.colorConfigurationAssignments },
            "baseAssignments": fixture.diagnostics.map { $0.statistics.baseConfigurationAssignments },
            "contentLayouts": fixture.diagnostics.map { $0.statistics.contentLayoutPasses }
        ])
    }

    private func blue(_ color: UIColor?) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        return color?.getRed(&r, green: &g, blue: &b, alpha: &a) == true ? Double(b) : -1
    }

    private func record(_ name: String, index: Int, kind: String = "") {
        events.append([
            "sequence": events.count,
            "time": CACurrentMediaTime(),
            "tick": tickNumber,
            "runLoopSequence": runLoopSequence,
            "scenario": scenario,
            "name": name,
            "item": index,
            "stack": stack,
            "kind": kind
        ])
    }

    private func invoke(_ object: AnyObject, name: String, body: () -> Void) {
        guard let index = indices[ObjectIdentifier(object)] else {
            body(); return
        }
        var kind = ""
        if name == "configuration" {
            let counters = fixture.diagnostics[index].statistics
            kind = counters.baseConfigurationAssignments > lastBase[index] ? "base" :
                counters.colorConfigurationAssignments > lastColor[index] ? "color" : "other"
            lastBase[index] = counters.baseConfigurationAssignments
            lastColor[index] = counters.colorConfigurationAssignments
        }
        record(name + ".begin", index: index, kind: kind)
        stack.append(name)
        body()
        stack.removeLast()
        record(name + ".end", index: index, kind: kind)
    }

    private func hook(_ cls: AnyClass, selector: Selector, name: String, argument: Bool) throws {
        let method = try XCTUnwrap(class_getInstanceMethod(cls, selector))
        let original = method_getImplementation(method)
        let encoding = String(cString: try XCTUnwrap(method_getTypeEncoding(method)))
        XCTAssertEqual(method_getNumberOfArguments(method), argument ? 3 : 2)
        let replacement: IMP
        if argument {
            let call = unsafeBitCast(original, to: (@convention(c) (AnyObject, Selector, AnyObject?) -> Void).self)
            let block: @convention(block) (AnyObject, AnyObject?) -> Void = { [weak self] object, value in
                MainActor.assumeIsolated {
                    guard let self else {
                        call(object, selector, value); return
                    }
                    self.invoke(object, name: name) { call(object, selector, value) }
                }
            }
            replacement = imp_implementationWithBlock(block)
        } else {
            let call = unsafeBitCast(original, to: (@convention(c) (AnyObject, Selector) -> Void).self)
            let block: @convention(block) (AnyObject) -> Void = { [weak self] object in
                MainActor.assumeIsolated {
                    guard let self else {
                        call(object, selector); return
                    }
                    self.invoke(object, name: name) { call(object, selector) }
                }
            }
            replacement = imp_implementationWithBlock(block)
        }
        class_replaceMethod(cls, selector, replacement, encoding)
        hooks.append((cls, selector, original, replacement, encoding))
    }
}
