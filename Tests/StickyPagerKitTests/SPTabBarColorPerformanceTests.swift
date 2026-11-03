import XCTest
import UIKit
import os
@testable import StickyPagerKit

/// 颜色单因素基准；计时期间不附加工作量计数器。
@MainActor
final class SPTabBarColorPerformanceTests: XCTestCase {
    private enum Work: String {
        case frames, commit, complete, combined, flushed
    }

    private static let log = OSLog(subsystem: "StickyPagerKit.Validation", category: "DefaultColors")

    func testAFramesFirst() throws {
        try measureColors(false, work: .frames)
    }

    func testBFramesSecond() throws {
        try measureColors(true, work: .frames)
    }

    func testCCommitFirst() throws {
        try measureColors(false, work: .commit)
    }

    func testDCommitSecond() throws {
        try measureColors(true, work: .commit)
    }

    func testECompleteFirst() throws {
        try measureColors(false, work: .complete)
    }

    func testFCompleteSecond() throws {
        try measureColors(true, work: .complete)
    }

    func testGCombinedFirst() throws {
        try measureColors(false, work: .combined)
    }

    func testHCombinedSecond() throws {
        try measureColors(true, work: .combined)
    }

    func testIFlushedFirst() throws {
        try measureColors(false, work: .flushed)
    }

    func testJFlushedSecond() throws {
        try measureColors(true, work: .flushed)
    }

    private func measureColors(_ second: Bool, work: Work) throws {
        let reversed = ProcessInfo.processInfo.environment["SP_TAB_COLOR_REVERSE"] == "1"
        let colors = reversed ? !second : second
        let fixture = try SPTabColorFixture(colors: colors, combined: work == .combined)
        defer { fixture.close() }
        fixture.beginSelection()
        let indicator = try XCTUnwrap(fixture.collection.subviews.first {
            $0.accessibilityIdentifier == "sp.tabBar.indicator"
        })
        let start = indicator.frame
        fixture.bar.advanceSelectionAnimation(to: 0.25)
        fixture.bar.layoutIfNeeded()
        XCTAssertNotEqual(indicator.frame, start)
        let middle = indicator.frame
        fixture.bar.advanceSelectionAnimation(to: 1)
        XCTAssertNotEqual(indicator.frame, middle)
        // 仅供独立 Instruments 采集延长工作负载；此模式的样本不并入基线。
        let profiling = ProcessInfo.processInfo.environment["SP_TAB_COLOR_PROFILE"] == "1"
        if profiling {
            // 给外部采集器附加测试宿主的时间，位于所有测量区间之外。
            Thread.sleep(forTimeInterval: 8)
        }
        let options = XCTMeasureOptions()
        options.iterationCount = profiling ? 200 : 10
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(
            metrics: [XCTClockMetric(), XCTMemoryMetric()],
            options: options
        ) {
            fixture.bar.setSelectedIndex(0, animated: false)
            fixture.bar.layoutIfNeeded()
            if work == .frames || work == .flushed {
                fixture.beginSelection()
            }
            let identifier = OSSignpostID(log: Self.log)
            os_signpost(
                .begin,
                log: Self.log,
                name: "DefaultColorBatch",
                signpostID: identifier,
                "work=%{public}s colors=%{public}d",
                work.rawValue,
                colors ? 1 : 0
            )
            self.startMeasuring()
            autoreleasepool {
                if work == .frames || work == .flushed {
                    // 单次选择的 360 个手动进度点；提交与初始布局在计时外。
                    fixture.frames(360, flushButtons: work == .flushed)
                } else {
                    for step in 1 ... 12 {
                        fixture.bar.setSelectedIndex(step % 6, animated: true)
                        fixture.bar.layoutIfNeeded()
                        if work != .commit {
                            fixture.frames(30)
                        }
                    }
                }
            }
            self.stopMeasuring()
            os_signpost(.end, log: Self.log, name: "DefaultColorBatch", signpostID: identifier)
            XCTAssertEqual(fixture.bar.selectedIndex, work == .frames || work == .flushed ? 1 : 0)
            XCTAssertEqual(fixture.collection.visibleCells.count, 6)
            if work == .flushed {
                let target = try! fixture.button(at: 1)
                XCTAssertEqual(target.titleLabel?.textColor, UIColor.blue)
            }
        }
        let attachment = XCTAttachment(string: """
        颜色单因素：work=\(work.rawValue)，colors=\(colors)，profiling=\(profiling)，reversed=\(reversed)。
        \(options.iterationCount) 个记录样本，另丢弃首轮预热；profiling 样本不并入性能基线。
        6 个可见默认图文，360x64 pt，LTR，浅色，固定红蓝端点。计时期间工作量诊断关闭。
        frames：一次标准选择的 360 个进度点及同步布局；提交在计时外。
        flushed：与 frames 相同，并逐点对六个按钮执行 layoutIfNeeded，终态核对实际标题颜色。
        commit：12 次程序选择与提交布局，不推进动画；连续接管成本计入。
        complete/combined：12 次选择，每次 30 个进度点及同步布局；组合组只在对照间改变颜色开关。
        Clock 为墙钟耗时，Memory 为宿主物理内存；均非真实帧率或分配次数。CPU 热点另用 Instruments。
        各路径工作量不同，不可把独立批次直接相减分解总成本；同步布局未涵盖所有延后系统工作。
        原始 signpost 标记供 Instruments 定位，不代表动画卡顿指标；无历史性能阈值。
        """)
        attachment.name = "default-color-benchmark-contract"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
