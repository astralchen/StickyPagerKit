import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarSelectionProgressTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window = nil
    }

    private func mount(_ source: ProgressSource, rtl: Bool = false) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 60))
        bar.layoutConfiguration.contentInsets = .zero
        bar.layoutConfiguration.itemSpacing = 0
        bar.layoutConfiguration.itemSizing = .equal
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)") }
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.indicatorStyle = .none
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func list(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func probe(_ bar: SPTabBar, _ index: Int) throws -> ProgressView {
        let cell = try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: index, section: 0)))
        let root = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" }
            ?? cell.contentView
        return try XCTUnwrap(root.subviews.compactMap { $0 as? ProgressView }.first)
    }

    private func assertWeights(
        _ bar: SPTabBar,
        _ values: [CGFloat],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for (index, value) in values.enumerated() {
            XCTAssertEqual(try probe(bar, index).value.progress, value, accuracy: 0.0001, file: file, line: line)
        }
    }

    func testSpringScaleDoesNotLeakOvershootIntoCustomConfigurationAndRetargetsWithoutRebuilding() throws {
        for rtl in [false, true] {
            let source = ProgressSource()
            let bar = mount(source, rtl: rtl)
            bar.visualStyle = .scale
            bar.visualStyle.unselectedAlpha = 0.55
            bar.selectionAnimationStyle = .spring
            bar.setSelectedIndex(2, animated: true)
            let views = try (0 ..< 3).map { try probe(bar, $0) }
            let requests = source.requests, stats = bar.refreshStatistics
            bar.advanceSelectionAnimation(to: 0.25)
            try assertWeights(bar, [0.5, 0, 0.5])
            bar.advanceSelectionAnimation(to: 0.45)
            try assertWeights(bar, [0.028, 0, 0.972])
            let visual = try XCTUnwrap(views[2].superview)
            XCTAssertGreaterThan(visual.transform.a, 1)
            XCTAssertEqual(source.requests, requests)
            XCTAssertEqual(bar.refreshStatistics, stats)
            bar.setSelectedIndex(1, animated: true)
            try assertWeights(bar, [0.028, 0, 0.972])
            // 改选可更新离散配置；逐帧呈现不重新请求内容或测量。
            let retargetRequests = source.requests, retargetStats = bar.refreshStatistics
            for p: CGFloat in [0.1, 0.25, 0.45, 0.5, 0.7, 1] {
                bar.advanceSelectionAnimation(to: p)
                for (index, view) in views.enumerated() {
                    XCTAssertTrue(try probe(bar, index) === view)
                    XCTAssertTrue((0 ... 1).contains(view.value.progress))
                }
            }
            try assertWeights(bar, [0, 1, 0])
            XCTAssertEqual(source.requests, retargetRequests)
            XCTAssertEqual(bar.refreshStatistics, retargetStats)
            bar.setSelectedIndex(nil, animated: true)
            bar.advanceSelectionAnimation(to: 0.25)
            try assertWeights(bar, [0, 0.5, 0])
            bar.advanceSelectionAnimation(to: 1)
            try assertWeights(bar, [0, 0, 0])
            for view in views {
                XCTAssertEqual(try XCTUnwrap(view.superview).transform.a, 0.94, accuracy: 0.0001)
            }
            bar.removeFromSuperview()
            withExtendedLifetime(source) {}
        }
    }

    func testPagingProgressPreservesLogicalSelectionAndDoesNotRequestOrMeasure() throws {
        for rtl in [false, true] {
            let source = ProgressSource()
            let bar = mount(source, rtl: rtl)
            let requests = source.requests
            let stats = bar.refreshStatistics
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
            try assertWeights(bar, [0.75, 0.25, 0])
            XCTAssertFalse(try probe(bar, 1).value.selected)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.75)
            try assertWeights(bar, [0.25, 0.75, 0])
            XCTAssertTrue(try probe(bar, 1).value.selected)
            XCTAssertEqual(bar.selectedIndex, 0)
            let button = try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: 1, section: 0))?.contentView.subviews
                .compactMap { $0 as? UIButton }.first)
            XCTAssertFalse(button.accessibilityTraits.contains(.selected))
            XCTAssertEqual(source.requests, requests)
            XCTAssertEqual(bar.refreshStatistics.measurementPasses, stats.measurementPasses)
            bar.setSelectedIndex(0, animated: false)
            try assertWeights(bar, [1, 0, 0])
            bar.removeFromSuperview()
        }
    }

    func testPendingClickPreviewDoesNotJumpContinuousProgressAndAccessibilityNotificationSettlesAnimation() throws {
        let source = ProgressSource()
        let bar = mount(source)
        bar.beginUserSelection(bar.items[1])
        XCTAssertTrue(try probe(bar, 1).value.selected)
        try assertWeights(bar, [1, 0, 0])
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        try assertWeights(bar, [0.8, 0.2, 0])
        bar.cancelUserSelection()
        bar.setSelectedIndex(0, animated: false)
        try assertWeights(bar, [1, 0, 0])
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        try assertWeights(bar, [0.5, 0.5, 0])
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        bar.layoutIfNeeded()
        try assertWeights(bar, [0, 1, 0])
        bar.advanceSelectionAnimation(to: 0.7)
        try assertWeights(bar, [0, 1, 0])
    }

    func testContentOnlyAnimationAndRepeatedSelectionContinueFromAllCurrentWeights() throws {
        let source = ProgressSource()
        let bar = mount(source)
        bar.setSelectedIndex(1, animated: true)
        try assertWeights(bar, [1, 0, 0])
        bar.advanceSelectionAnimation(to: 0.5)
        try assertWeights(bar, [0.5, 0.5, 0])
        bar.setSelectedIndex(2, animated: true)
        try assertWeights(bar, [0.5, 0.5, 0])
        bar.advanceSelectionAnimation(to: 0.5)
        try assertWeights(bar, [0.25, 0.25, 0.5])
        bar.advanceSelectionAnimation(to: 1)
        try assertWeights(bar, [0, 0, 1])
        bar.setSelectedIndex(nil, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        try assertWeights(bar, [0, 0, 0.5])
        bar.advanceSelectionAnimation(to: 1)
        try assertWeights(bar, [0, 0, 0])
    }

    func testPagingTakesOverAnimationAndNonadjacentProgressUsesOnlyEndpoints() throws {
        for rtl in [false, true] {
            let source = ProgressSource()
            let bar = mount(source, rtl: rtl)
            bar.setSelectedIndex(1, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0)
            try assertWeights(bar, [0.5, 0.5, 0])
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.4)
            try assertWeights(bar, [0.3, 0.7, 0])
            bar.advanceSelectionAnimation(to: 1)
            try assertWeights(bar, [0.3, 0.7, 0])
            bar.setTransitionProgress(from: 0, to: 2, progress: 0.25)
            try assertWeights(bar, [0.75, 0, 0.25])
            bar.setTransitionProgress(from: 0, to: 2, progress: .nan)
            try assertWeights(bar, [0.75, 0, 0.25])
            bar.setTransitionProgress(from: 0, to: 2, progress: 2)
            try assertWeights(bar, [0, 0, 1])
            bar.removeFromSuperview()
        }
    }

    func testLayoutReloadAndReorderKeepProgressInTheCorrectGeneration() throws {
        let source = ProgressSource()
        let bar = mount(source)
        bar.setTransitionProgress(from: 0, to: 2, progress: 0.3)
        bar.frame.size.width = 420
        bar.layoutIfNeeded()
        try assertWeights(bar, [0.7, 0, 0.3])
        bar.reloadContent()
        bar.layoutIfNeeded()
        try assertWeights(bar, [0.7, 0, 0.3])
        let selected = bar.items[0]
        bar.items = [bar.items[2], selected, bar.items[1]]
        bar.layoutIfNeeded()
        try assertWeights(bar, [0, 1, 0])
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        bar.frame.size.width = 300
        bar.layoutIfNeeded()
        try assertWeights(bar, [0, 0, 1])
        bar.advanceSelectionAnimation(to: 0.8)
        try assertWeights(bar, [0, 0, 1])
    }

    func testProgressUpdatesReuseViewAndPreserveHighlightWithoutOptingLegacyContentIn() throws {
        let source = ProgressSource()
        let bar = mount(source)
        let view = try probe(bar, 0)
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        let cell = try XCTUnwrap(list(bar).cellForItem(at: IndexPath(item: 0, section: 0)))
        let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
        button.isHighlighted = true
        XCTAssertTrue(view.value.highlighted)
        XCTAssertEqual(view.value.progress, 0.8, accuracy: 0.0001)
        let updates = view.updates
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        XCTAssertEqual(view.updates, updates)
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        XCTAssertTrue(try probe(bar, 0) === view)
        XCTAssertTrue(view.value.highlighted)
        source.tracksProgress = false
        bar.reloadContent()
        bar.setSelectedIndex(0, animated: false)
        let legacyUpdates = view.updates
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        XCTAssertEqual(view.updates, legacyUpdates)
        try assertWeights(bar, [1, 0, 0])
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.7)
        try assertWeights(bar, [0, 1, 0])
    }
}

@MainActor
private final class ProgressSource: SPTabBarContentDelegate {
    var requests = 0
    var tracksProgress = true
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        requests += 1
        XCTAssertEqual(context.state.spSelectionProgress, context.state.isSelected ? 1 : 0)
        var content = SPTabBarContent(configuration: ProgressConfiguration(), size: CGSize(width: 60, height: 50))
        content.tracksSelectionProgress = tracksProgress
        return content
    }
}

private struct ProgressConfiguration: UIContentConfiguration {
    var progress: CGFloat = 0
    var selected = false
    var highlighted = false
    func makeContentView() -> UIView & UIContentView {
        ProgressView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else {
            return self
        }
        var result = self
        result.progress = state.spSelectionProgress
        result.selected = state.isSelected
        result.highlighted = state.isHighlighted
        return result
    }
}

@MainActor
private final class ProgressView: UIView, UIContentView {
    var value: ProgressConfiguration
    var updates = 0
    var configuration: any UIContentConfiguration {
        get { value }
        set { value = newValue as! ProgressConfiguration; updates += 1 }
    }

    init(configuration: ProgressConfiguration) {
        value = configuration
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("不支持 coder")
    }
}
