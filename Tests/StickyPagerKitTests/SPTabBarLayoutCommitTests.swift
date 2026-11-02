import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarLayoutCommitTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window.rootViewController = nil
        window = nil
    }

    private func mount(_ source: CommitContentSource, rtl: Bool = false) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 320, height: 80))
        bar.layoutConfiguration.contentInsets = .zero
        bar.layoutConfiguration.itemSpacing = 0
        bar.items = (0 ..< 12).map { SPTabBarItem(title: "标签 \($0)") }
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.indicatorStyle = .custom
        var layout = SPTabBarIndicatorLayout()
        layout.horizontalInset = 0
        layout.verticalInset = 0
        bar.standardAppearance.indicatorLayout = layout
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(5, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func collection(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func frame(_ bar: SPTabBar, _ index: Int) -> CGRect {
        collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    private func indicator(_ bar: SPTabBar) -> UIView {
        collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
    }

    func testContentAndViewportChangesRenderOnlyCommittedGeometryAndPreserveManualOffset() {
        for rtl in [false, true] {
            let source = CommitContentSource()
            let bar = mount(source, rtl: rtl)
            let view = CommitIndicatorView()
            bar.indicatorView = view
            view.inspect = { [weak self, weak bar] state in
                guard let self, let bar else {
                    return nil
                }
                return (state.frame, self.frame(bar, 5), self.collection(bar).bounds.width)
            }
            collection(bar).contentOffset.x = 100
            source.width = 110
            bar.reloadContent()
            _ = bar.sizeThatFits(CGSize(width: 160, height: 0))
            view.samples.removeAll()
            bar.frame.size.width = 420
            bar.layoutIfNeeded()
            XCTAssertEqual(
                collection(bar).contentOffset.x,
                100,
                accuracy: 0.01,
                "内容变化优先处理手动偏移，不能因同时改变视口而强制居中"
            )
            XCTAssertEqual(frame(bar, 5).width, 110, accuracy: 0.01)
            XCTAssertFalse(view.samples.isEmpty)
            for sample in view.samples {
                XCTAssertEqual(sample.0, frame(bar, 5), "不能向指示器视图提交旧端点")
                XCTAssertEqual(sample.1, frame(bar, 5))
                XCTAssertEqual(sample.2, 420, accuracy: 0.01)
            }
            XCTAssertEqual(bar.selectedIndex, 5)
            bar.removeFromSuperview()
        }
    }

    func testTransitionEntryFlushesPendingLayoutBeforeTakingOrigin() {
        for rtl in [false, true] {
            let source = CommitContentSource(), referenceSource = CommitContentSource()
            let bar = mount(source, rtl: rtl), reference = mount(referenceSource, rtl: rtl)
            for (current, provider) in [(bar, source), (reference, referenceSource)] {
                current.setSelectedIndex(8, animated: true)
                current.advanceSelectionAnimation(to: 0.3)
                provider.width = 105
                current.reloadContent()
                current.frame.size.width = 430
                let before = indicator(current).frame
                _ = current.sizeThatFits(CGSize(width: 150, height: 0))
                XCTAssertEqual(indicator(current).frame, before, "候选测量不能提前提交动画端点")
            }
            reference.layoutIfNeeded()
            bar.setTransitionProgress(from: 8, to: 7, progress: 0.4)
            reference.setTransitionProgress(from: 8, to: 7, progress: 0.4)
            XCTAssertEqual(indicator(bar).frame, indicator(reference).frame)
            XCTAssertEqual(collection(bar).contentOffset, collection(reference).contentOffset)
            XCTAssertEqual(frame(bar, 7), frame(reference, 7))
            // 程序化切页也必须从完成同步布局后的呈现状态起步。
            bar.frame.size.width = 360
            reference.frame.size.width = 360
            reference.layoutIfNeeded()
            bar.setSelectedIndex(4, animated: true)
            reference.setSelectedIndex(4, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            reference.advanceSelectionAnimation(to: 0.5)
            XCTAssertEqual(indicator(bar).frame, indicator(reference).frame)
            XCTAssertEqual(collection(bar).contentOffset, collection(reference).contentOffset)
            bar.removeFromSuperview()
            reference.removeFromSuperview()
        }
    }

    func testViewportOnlyResizeAlignsSelectionWithoutRepeatedContentResolution() {
        let source = CommitContentSource()
        let bar = mount(source)
        collection(bar).contentOffset.x = 70
        bar.frame.size.width = 420
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(bar, 5).midX - collection(bar).contentOffset.x, 210, accuracy: 0.01)
        let committed = bar.refreshStatistics
        let geometry = indicator(bar).frame
        for _ in 0 ..< 3 {
            bar.setNeedsLayout()
            bar.layoutIfNeeded()
        }
        XCTAssertEqual(bar.refreshStatistics, committed)
        XCTAssertEqual(indicator(bar).frame, geometry)
    }

    func testSelectionReentryWithPendingLayoutDoesNotCommitOriginalRequest() {
        let source = CommitContentSource()
        let bar = mount(source)
        let delegate = CommitSelectionDelegate()
        bar.delegate = delegate
        let target = bar.items[8], replacement = bar.items[2]
        source.width = 130
        bar.reloadContent()
        bar.frame.size.width = 460
        delegate.shouldSelect = { current in
            current.items = Array(current.items.reversed())
            current.setSelectedItem(replacement, animated: false)
        }
        bar.requestSelection(of: target)
        bar.layoutIfNeeded()
        XCTAssertTrue(bar.selectedItem === replacement)
        XCTAssertEqual(bar.selectedIndex, 9)
        XCTAssertTrue(delegate.committed.isEmpty)
        XCTAssertEqual(indicator(bar).frame, frame(bar, 9))
    }
}

@MainActor
private final class CommitContentSource: SPTabBarContentDelegate {
    var width: CGFloat = 80
    func content(
        for item: SPTabBarContentItem,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(configuration: configuration, size: CGSize(width: width, height: 60))
    }
}

@MainActor
private final class CommitIndicatorView: SPTabBarIndicatorView {
    var samples: [(CGRect, CGRect, CGFloat)] = []
    var inspect: ((SPTabBarIndicatorState) -> (CGRect, CGRect, CGFloat)?)?
    override func update(_ state: SPTabBarIndicatorState) {
        super.update(state)
        if let value = inspect?(state) {
            samples.append(value)
        }
    }
}

@MainActor
private final class CommitSelectionDelegate: SPTabBarDelegate {
    var shouldSelect: ((SPTabBar) -> Void)?
    var committed: [SPTabBarItem] = []
    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool {
        shouldSelect?(tabBar)
        return true
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        committed.append(item)
    }
}
