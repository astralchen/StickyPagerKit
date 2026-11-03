import XCTest
import UIKit
@testable import StickyPagerKit

/// 固定工作量的呈现基线。手动推进动画并同步布局，测量宿主进程的耗时与物理内存；
/// 不运行真实显示节拍，不测 GPU、卡顿、分配次数，也不代表业务自定义内容的成本。
@MainActor
final class SPTabBarPerformanceTests: XCTestCase {
    func testDefaultStandardPresentationBatch() throws {
        try measurePresentation(custom: false, combined: false)
    }

    func testDefaultCombinedPresentationBatch() throws {
        try measurePresentation(custom: false, combined: true)
    }

    func testCustomStandardPresentationBatch() throws {
        try measurePresentation(custom: true, combined: false)
    }

    func testCustomCombinedPresentationBatch() throws {
        try measurePresentation(custom: true, combined: true)
    }

    private func measurePresentation(custom: Bool, combined: Bool) throws {
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.showForTesting()
        defer { window.closeForTesting() }
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 64))
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 6).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        let source = PerformanceContentSource()
        if custom {
            bar.contentDelegate = source
            bar.contentStyle = .custom
        }
        if combined {
            bar.visualStyle = .fadeAndStretch
            bar.visualStyle.unselectedScale = 0.94
            bar.visualStyle.interpolatesDefaultColors = true
            bar.selectionAnimationStyle = .spring
        }
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        XCTAssertEqual(collection.visibleCells.count, 6)
        // 测量前证明同步布局不会提前终止动画，避免采到静止路径。
        let indicator = try XCTUnwrap(collection.subviews.first {
            $0.accessibilityIdentifier == "sp.tabBar.indicator"
        })
        let startFrame = indicator.frame
        bar.setSelectedIndex(1, animated: false)
        bar.layoutIfNeeded()
        let endFrame = indicator.frame
        bar.setSelectedIndex(0, animated: false)
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.25)
        bar.layoutIfNeeded()
        XCTAssertNotEqual(indicator.frame, startFrame)
        XCTAssertNotEqual(indicator.frame, endFrame)
        bar.setSelectedIndex(0, animated: false)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        // 初始化与每轮复位不计入测量；XCTest 另执行并丢弃第一轮预热。
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            bar.setSelectedIndex(0, animated: false)
            bar.layoutIfNeeded()
            self.startMeasuring()
            autoreleasepool {
                for step in 1 ... 12 {
                    bar.setSelectedIndex(step % 6, animated: true)
                    for sample in 1 ... 30 {
                        bar.advanceSelectionAnimation(to: CGFloat(sample) / 30)
                        bar.layoutIfNeeded()
                    }
                }
            }
            self.stopMeasuring()
            XCTAssertEqual(bar.selectedIndex, 0)
            XCTAssertEqual(collection.visibleCells.count, 6)
        }
        let metadata = XCTAttachment(string: """
        固定呈现批次：6 个可见项，360x64 pt，LTR，默认 traits。
        custom=\(custom)，combined=\(combined)。
        每轮 12 次选择，每次手动推进 30 个进度采样点，并同步布局。
        记录 5 轮，另丢弃首轮预热；复位不计时，autoreleasepool 释放计入批次。
        Clock 为整批墙钟耗时，Memory 为整个宿主的物理内存，不是分配次数。
        尚无历史性能阈值，不代表帧率、GPU 或真机表现。
        """)
        metadata.name = "presentation-benchmark-contract"
        metadata.lifetime = .keepAlways
        add(metadata)
        withExtendedLifetime(source) {}
    }
}

@MainActor
private final class PerformanceContentSource: SPTabBarContentDelegate {
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        var content = SPTabBarContent(
            configuration: PerformanceContentConfiguration(title: item.title ?? ""),
            size: CGSize(width: 60, height: 50)
        )
        content.tracksSelectionProgress = true
        return content
    }
}

private struct PerformanceContentConfiguration: UIContentConfiguration {
    var title: String
    var progress: CGFloat = 0

    func makeContentView() -> UIView & UIContentView {
        PerformanceContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        var result = self
        result.progress = (state as? UICellConfigurationState)?.spSelectionProgress ?? 0
        return result
    }
}

@MainActor
private final class PerformanceContentView: UIView, UIContentView {
    private var value: PerformanceContentConfiguration
    private let label = UILabel()
    var configuration: any UIContentConfiguration {
        get { value }
        set {
            guard let configuration = newValue as? PerformanceContentConfiguration else {
                return
            }
            value = configuration
            apply()
        }
    }

    init(configuration: PerformanceContentConfiguration) {
        value = configuration
        super.init(frame: .zero)
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        addSubview(label)
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError("不支持 coder")
    }

    private func apply() {
        label.text = value.title
        label.textColor = UIColor(red: 1 - value.progress, green: 0, blue: value.progress, alpha: 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}
