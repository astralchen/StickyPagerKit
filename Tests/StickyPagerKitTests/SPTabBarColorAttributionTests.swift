import Darwin
import MachO
import os
import UIKit
import XCTest
@testable import StickyPagerKit

/// P5C2 独立诊断，不修改 P5A 的工作量契约，也不把采集器运行混入耗时基线。
@MainActor
final class SPTabBarColorAttributionTests: XCTestCase {
    private static let log = OSLog(subsystem: "StickyPagerKit.Validation", category: .pointsOfInterest)

    func testWorkloadColorsOff() async throws {
        try await workload(colors: false)
    }

    func testWorkloadColorsOn() async throws {
        try await workload(colors: true)
    }

    func testNativeStandardColorsOff() async throws {
        try await native(colors: false, spring: false)
    }

    func testNativeStandardColorsOn() async throws {
        try await native(colors: true, spring: false)
    }

    func testNativeSpringColorsOff() async throws {
        try await native(colors: false, spring: true)
    }

    func testNativeSpringColorsOn() async throws {
        try await native(colors: true, spring: true)
    }

    func testWorkloadTitleOnly() async throws {
        try await workload(colors: true, channel: "title")
    }

    func testWorkloadIconOnly() async throws {
        try await workload(colors: true, channel: "icon")
    }

    func testNativeStandardTitleOnly() async throws {
        try await native(colors: true, spring: false, channel: "title")
    }

    func testNativeStandardIconOnly() async throws {
        try await native(colors: true, spring: false, channel: "icon")
    }

    func testNativeSpringTitleOnly() async throws {
        try await native(colors: true, spring: true, channel: "title")
    }

    func testNativeSpringIconOnly() async throws {
        try await native(colors: true, spring: true, channel: "icon")
    }

    /// 通道干预使用完整图文；计时不挂工作量计数器，也不把合成循环称为自然动画。
    func testChannelIsolation() async throws {
        let reverse = ProcessInfo.processInfo.environment["SP_P5C2_CHANNEL_REVERSE"] == "1"
        var conditions: [(String, Bool)] = ["off", "fixed", "title", "icon", "both"].flatMap { mode in
            [false, true].map { (mode, $0) }
        }
        if reverse {
            conditions.reverse()
        }
        var reports: [[String: Any]] = []
        for (mode, flush) in conditions {
            let titleChanges = mode == "title" || mode == "both" || mode == "off"
            let iconChanges = mode == "icon" || mode == "both" || mode == "off"
            let fixture = SPColorAttributionFixture(
                colors: mode != "off",
                titleChanges: titleChanges,
                iconChanges: iconChanges
            )
            defer { fixture.window.isHidden = true }
            try await fixture.waitForAppearance()
            let button = try fixture.button(at: 1)
            fixture.beginSelection()
            fixture.channelFrames(360, flush: flush)
            fixture.flushLayout()
            var samples: [[String: Double]] = []
            for _ in 0 ..< 30 {
                fixture.beginSelection()
                // 选择复位会创建新内容快照；身份约束仅适用于当前快照内的连续呈现。
                let image = button.configuration?.image
                let before = cpuTime()
                let start = CACurrentMediaTime()
                autoreleasepool { fixture.channelFrames(360, flush: flush) }
                let elapsed = CACurrentMediaTime() - start
                let after = cpuTime()
                samples.append([
                    "wallSeconds": elapsed,
                    "cpuSeconds": after.0 + after.1 - before.0 - before.1
                ])
                // 不逐点布局的条件在计时外排空，避免积压到下一个条件。
                fixture.flushLayout()
                XCTAssertTrue(button.configuration?.image === image)
            }
            XCTAssertEqual(fixture.bar.selectedIndex, 1)
            XCTAssertEqual(button.titleLabel?.textColor, titleChanges ? UIColor.blue : .red)
            XCTAssertEqual(button.tintColor, iconChanges ? UIColor.blue : .red)
            XCTAssertEqual(button.configuration?.title, "标签 1")

            // 单独的非计时诊断遍历，读取当前进度的模型颜色并核验两项参与更新。
            fixture.beginSelection()
            fixture.bar.advanceSelectionAnimation(to: 0.01)
            fixture.flushLayout()
            let diagnostics = SPTabColorDiagnostics()
            try fixture.attachDiagnostics(diagnostics)
            var tintChanges = 0
            var previousTint = button.tintColor
            for point in 1 ... 30 {
                fixture.bar.advanceSelectionAnimation(to: 0.01 + CGFloat(point) * 0.98 / 30)
                fixture.flushLayout()
                if button.tintColor != previousTint {
                    tintChanges += 1
                }
                previousTint = button.tintColor
            }
            let counters = diagnostics.statistics
            XCTAssertEqual(counters.baseConfigurationAssignments, 0)
            // icon 已在诊断前的 0.01 进度进入局部 tint 路径；连续更新不再应用配置。
            XCTAssertEqual(counters.colorConfigurationAssignments, ["off", "fixed", "icon"].contains(mode) ? 0 : 60)
            XCTAssertEqual(counters.titleTransformerCreations, mode == "title" || mode == "both" ? 60 : 0)
            XCTAssertEqual(tintChanges, mode == "icon" || mode == "both" ? 30 : 0)
            try fixture.attachDiagnostics(nil)
            let counterObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(counters))
            reports.append([
                "mode": mode,
                "flushEachPoint": flush,
                "samples": samples,
                "diagnosticCounters": counterObject,
                "observedTargetTintChanges": tintChanges,
                "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
                "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled
            ])
            try await fixture.close()
        }
        try attach([
            "schema": "sp-color-channels-v1",
            "reverse": reverse,
            "mainThreadCheckerLoaded": mainThreadCheckerLoaded,
            "batchesPerCondition": 30,
            "pointsPerBatch": 360,
            "conditions": reports,
            "note": "五种通道乘两种布局边界；同进程批次相关。无强制布局仍可能含 UIKit 同步工作；不是纯 setter 或自然帧成本。"
        ], name: "color-channels")
    }

    private func workload(colors: Bool, channel: String = "both") async throws {
        let fixture = SPColorAttributionFixture(
            colors: colors,
            titleChanges: channel != "icon",
            iconChanges: channel != "title"
        )
        defer { fixture.window.isHidden = true }
        try await fixture.waitForAppearance()
        fixture.beginSelection()
        fixture.frames(360, flushButtons: true)
        let handshake = ProcessInfo.processInfo.environment["SP_P5C2_HANDSHAKE"] == "1"
        let folder = captureFolder
        if handshake {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try write(
                ["pid": ProcessInfo.processInfo.processIdentifier, "colors": colors, "channel": channel],
                to: folder.appendingPathComponent("ready.json")
            )
            try await waitForFile(folder.appendingPathComponent("go"))
        }
        let identifier = OSSignpostID(log: Self.log)
        os_signpost(
            .begin,
            log: Self.log,
            name: "ColorAttributionWorkload",
            signpostID: identifier,
            "colors=%d",
            colors ? 1 : 0
        )
        var samples: [[String: Double]] = []
        samples.reserveCapacity(120)
        for _ in 0 ..< 120 {
            fixture.beginSelection()
            let before = cpuTime()
            let start = CACurrentMediaTime()
            autoreleasepool { fixture.frames(360, flushButtons: true) }
            let elapsed = CACurrentMediaTime() - start
            let after = cpuTime()
            samples.append([
                "wallSeconds": elapsed,
                "userCPUSeconds": after.0 - before.0,
                "systemCPUSeconds": after.1 - before.1
            ])
        }
        os_signpost(.end, log: Self.log, name: "ColorAttributionWorkload", signpostID: identifier)
        XCTAssertEqual(fixture.bar.selectedIndex, 1)
        XCTAssertEqual(try fixture.button(at: 1).titleLabel?.textColor, channel == "icon" ? UIColor.red : .blue)
        XCTAssertEqual(try fixture.button(at: 1).tintColor, channel == "title" ? UIColor.red : .blue)
        let report: [String: Any] = [
            "schema": "sp-color-attribution-v1",
            "channel": channel,
            "colors": colors,
            "profiled": handshake,
            "mainThreadCheckerLoaded": mainThreadCheckerLoaded,
            "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "batches": 120,
            "pointsPerBatch": 360,
            "samples": samples,
            "note": "进程 CPU 包含其他线程；批次包含同步布局和 autoreleasepool，选择复位在计时外。不是逐帧显示成本。"
        ]
        try attach(report, name: "color-attribution-\(colors)")
        if handshake {
            try write(report, to: folder.appendingPathComponent("done.json"))
            try await waitForFile(folder.appendingPathComponent("release"))
        }
        try await fixture.close()
    }

    private func native(colors: Bool, spring: Bool, channel: String = "both") async throws {
        let fixture = SPColorAttributionFixture(
            colors: colors,
            combined: spring,
            titleChanges: channel != "icon",
            iconChanges: channel != "title"
        )
        defer { fixture.window.isHidden = true }
        try await fixture.waitForAppearance()
        let handshake = ProcessInfo.processInfo.environment["SP_P5C2_HANDSHAKE"] == "1"
        if handshake {
            try FileManager.default.createDirectory(at: captureFolder, withIntermediateDirectories: true)
            try write(
                ["pid": ProcessInfo.processInfo.processIdentifier, "colors": colors, "channel": channel],
                to: captureFolder.appendingPathComponent("ready.json")
            )
            try await waitForFile(captureFolder.appendingPathComponent("go"))
        }
        let observer = SPColorDisplayObserver()
        observer.observesTint = channel != "both"
        let link = CADisplayLink(target: observer, selector: #selector(SPColorDisplayObserver.tick(_:)))
        link.add(to: .main, forMode: .common)
        defer { link.invalidate() }
        let startupStart = CACurrentMediaTime()
        while observer.samples.count < 2, CACurrentMediaTime() - startupStart < 5 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertGreaterThanOrEqual(observer.samples.count, 2, "显示链必须先实际启动")
        let startup = observer.samples
        var rounds: [[String: Any]] = []
        for round in 0 ..< 12 {
            let index = (round + 1) % 6
            let button = try fixture.button(at: index)
            observer.button = button
            observer.samples.removeAll(keepingCapacity: true)
            let start = CACurrentMediaTime()
            fixture.bar.setSelectedIndex(index, animated: true)
            // 只让出主 actor；不调用手动进度、强制布局或提前完成动画。
            try await Task.sleep(nanoseconds: spring ? 650_000_000 : 400_000_000)
            let samples = observer.samples
            XCTAssertEqual(fixture.bar.selectedIndex, index)
            XCTAssertEqual(button.titleLabel?.textColor, channel == "icon" ? UIColor.red : .blue)
            XCTAssertEqual(button.tintColor, channel == "title" ? UIColor.red : .blue)
            XCTAssertGreaterThan(samples.count, 2)
            if colors {
                XCTAssertTrue(
                    samples.contains {
                        let blue = $0[channel == "icon" ? "iconBlue" : "blue", default: -1]
                        return blue > 0.05 && blue < 0.95
                    },
                    "必须观察到自然动画中间颜色"
                )
            }
            if channel != "both" {
                let fixedKey = channel == "icon" ? "blue" : "iconBlue"
                XCTAssertTrue(samples.allSatisfy { abs($0[fixedKey, default: -1]) < 0.001 }, "固定通道必须保持红色")
            }
            rounds.append(["index": index, "start": start, "end": CACurrentMediaTime(), "samples": samples])
        }
        let report: [String: Any] = [
            "schema": "sp-color-native-v1",
            "channel": channel,
            "colors": colors,
            "spring": spring,
            "profiled": handshake,
            "mainThreadCheckerLoaded": mainThreadCheckerLoaded,
            "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "displayLinkStartup": startup,
            "appearanceWaitSeconds": fixture.appearanceWaitSeconds,
            "rounds": rounds,
            "note": "自然 CADisplayLink 动画；额外观察者仅记录回调和模型标题颜色。回调间隔不等于 GPU 帧率或系统 hitch 指标。"
        ]
        try attach(report, name: "color-native-\(spring)-\(colors)")
        if handshake {
            try write(report, to: captureFolder.appendingPathComponent("done.json"))
            try await waitForFile(captureFolder.appendingPathComponent("release"))
        }
        link.invalidate()
        try await fixture.close()
    }

    /// 在计时外核对实际加载状态，不能只凭 xctestrun 开关推定诊断已关闭。
    private var mainThreadCheckerLoaded: Bool {
        (0 ..< _dyld_image_count()).contains { index in
            guard let name = _dyld_get_image_name(index) else {
                return false
            }
            return String(cString: name).hasSuffix("/libMainThreadChecker.dylib")
        }
    }

    private var captureFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("sp-p5c2", isDirectory: true)
            .appendingPathComponent(ProcessInfo.processInfo.environment["SP_P5C2_TOKEN"] ?? "local", isDirectory: true)
    }

    private func cpuTime() -> (Double, Double) {
        var usage = rusage()
        XCTAssertEqual(getrusage(RUSAGE_SELF, &usage), 0)
        return (
            Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000,
            Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        )
    }

    private func waitForFile(_ url: URL) async throws {
        let deadline = CACurrentMediaTime() + 120
        while !FileManager.default.fileExists(atPath: url.path), CACurrentMediaTime() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "采集器握手超时：\(url.lastPathComponent)")
        if !FileManager.default.fileExists(atPath: url.path) {
            throw CocoaError(.fileReadNoSuchFile)
        }
    }

    private func write(_ value: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(
            to: url,
            options: .atomic
        )
    }

    private func attach(_ value: [String: Any], name: String) throws {
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// 异步诊断专用窗口：不在 MainActor 任务内嵌套 RunLoop 驱动 appearance。
/// 几何与默认图文输入保持 P5A 的六项配置，但不改变 P5A 原夹具。
@MainActor
private final class SPColorAttributionFixture {
    let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let controller = SPColorWindowController()
    let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 64))
    private(set) var appearanceWaitSeconds: Double = 0
    private var buttons: [UIButton] = []

    init(colors: Bool, combined: Bool = false, titleChanges: Bool = true, iconChanges: Bool = true) {
        window.rootViewController = controller
        bar.semanticContentAttribute = .forceLeftToRight
        bar.overrideUserInterfaceStyle = .light
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 6).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        bar.standardAppearance.itemAppearance.normal.titleColor = .red
        bar.standardAppearance.itemAppearance.normal.iconColor = .red
        bar.standardAppearance.itemAppearance.selected.titleColor = titleChanges ? .blue : .red
        bar.standardAppearance.itemAppearance.selected.iconColor = iconChanges ? .blue : .red
        if combined {
            bar.visualStyle = .fadeAndStretch
            bar.visualStyle.unselectedScale = 0.94
            bar.selectionAnimationStyle = .spring
        }
        bar.visualStyle.interpolatesDefaultColors = colors
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
        appearanceWaitSeconds = CACurrentMediaTime() - start
        XCTAssertTrue(controller.appeared, "必须收到真实 viewDidAppear")
        if !controller.appeared {
            throw CocoaError(.coderInvalidValue)
        }
        XCTAssertEqual(collection.visibleCells.count, 6)
        buttons = try (0 ..< 6).map { try button(at: $0) }
    }

    func close() async throws {
        bar.setSelectedIndex(0, animated: false)
        window.rootViewController = nil
        let start = CACurrentMediaTime()
        while !controller.disappeared, CACurrentMediaTime() - start < 5 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(controller.disappeared, "必须收到真实 viewDidDisappear")
        window.isHidden = true
    }

    private var collection: UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    func button(at index: Int) throws -> UIButton {
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
        let host = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" } ?? cell
            .contentView
        return try XCTUnwrap(host.subviews.compactMap { $0 as? UIButton }.first)
    }

    func beginSelection() {
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        bar.setSelectedIndex(1, animated: true)
        bar.layoutIfNeeded()
    }

    func frames(_ count: Int, flushButtons: Bool) {
        // 与 P5A 一样，在推进循环外固定六个按钮，避免逐点查找混入工作量。
        for sample in 1 ... count {
            bar.advanceSelectionAnimation(to: CGFloat(sample) / CGFloat(count))
            bar.layoutIfNeeded()
            if flushButtons {
                buttons.forEach { $0.layoutIfNeeded() }
            }
        }
    }

    func channelFrames(_ count: Int, flush: Bool) {
        for point in 1 ... count {
            bar.advanceSelectionAnimation(to: CGFloat(point) / CGFloat(count))
            if flush {
                flushLayout()
            }
        }
    }

    func flushLayout() {
        bar.layoutIfNeeded()
        buttons.forEach { $0.layoutIfNeeded() }
    }

    func attachDiagnostics(_ diagnostics: SPTabColorDiagnostics?) throws {
        for index in 0 ..< 6 {
            let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
            let host = try XCTUnwrap(cell.contentView as? SPTabColorDiagnosing)
            host.colorDiagnostics = diagnostics
        }
    }
}

@MainActor
private final class SPColorWindowController: UIViewController {
    var appeared = false
    var disappeared = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appeared = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disappeared = true
    }
}

/// 观察器不推进动画，也不将 nominal duration 当成实际调度间隔。
@MainActor
private final class SPColorDisplayObserver: NSObject {
    weak var button: UIButton?
    var observesTint = false
    var samples: [[String: Double]] = []

    @objc func tick(_ link: CADisplayLink) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let convertible = button?.titleLabel?.textColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) ?? false
        var sample: [String: Double] = [
            "timestamp": link.timestamp,
            "targetTimestamp": link.targetTimestamp,
            "callbackTime": CACurrentMediaTime(),
            "red": convertible ? Double(red) : -1,
            "blue": convertible ? Double(blue) : -1
        ]
        if observesTint {
            let iconConvertible = button?.tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) ?? false
            sample["iconBlue"] = iconConvertible ? Double(blue) : -1
        }
        samples.append(sample)
    }
}
