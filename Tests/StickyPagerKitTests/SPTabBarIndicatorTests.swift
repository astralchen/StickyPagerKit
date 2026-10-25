import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarIndicatorTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.closeForTesting()
        window?.rootViewController = nil
        window = nil
    }

    private func mount(rtl: Bool = false) -> (SPTabBar, UICollectionView, UIView) {
        window?.closeForTesting()
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        window.rootViewController = UIViewController()
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 320, height: 60))
        // 此夹具保留胶囊作为几何基线，频道型默认线条由专门用例覆盖。
        bar.indicatorStyle = .capsule
        bar.layoutConfiguration.itemSizing = .balanced
        window.rootViewController!.view.addSubview(bar)
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.items = ["短", "较长的第二个标题", "第三项", "第四个标签", "第五项"].map { SPTabBarItem(title: $0) }
        bar.selectedItem = bar.items[0]
        bar.layoutIfNeeded()
        let collection = bar.subviews.compactMap { $0 as? UICollectionView }.first!
        let indicator = collection.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
        return (bar, collection, indicator)
    }

    private func frame(_ index: Int, _ collection: UICollectionView) -> CGRect {
        collection.layoutIfNeeded()
        return collection.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    func testContentReferenceTracksSpacingInsetsAndSizeAfterIntermediateIndicatorRefresh() {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            let provider = IndicatorContentProvider()
            bar.contentDelegate = provider
            bar.contentStyle = .custom
            var layout = SPTabBarIndicatorLayout()
            layout.reference = .content
            bar.standardAppearance.indicatorLayout = layout
            bar.setSelectedIndex(2, animated: false)
            let changes: [(SPTabBar) -> Void] = [
                { $0.layoutConfiguration.itemSpacing = 24 },
                { $0.layoutConfiguration.minimumItemWidth = 140 },
                { $0.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                    top: 7,
                    leading: 19,
                    bottom: 11,
                    trailing: 31
                ) },
                { $0.frame.size = CGSize(width: 500, height: 90) },
                { $0.layoutConfiguration.itemSpacing = 0 }
            ]
            for change in changes {
                change(bar)
                // 模拟同一轮更新中，外观 setter 或滚动回调在 Collection View prepare 前读取几何。
                bar.reloadIndicator()
                bar.layoutIfNeeded()
                let item = frame(2, collection)
                XCTAssertEqual(indicator.frame, provider.rect!.offsetBy(dx: item.minX, dy: item.minY))
                XCTAssertEqual(bar.selectedIndex, 2)
            }
        }
    }

    func testItemAndAppearanceRefreshPreservePagingEndpointsAndProgress() {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            let renderer = RecordingIndicator()
            bar.indicatorStyle = .custom
            bar.indicatorView = renderer
            bar.layoutConfiguration.minimumItemWidth = 100
            bar.layoutIfNeeded()
            bar.setTransitionProgress(from: 1, to: 2, progress: 0.35)
            let changes: [(SPTabBar) -> Void] = [
                { $0.items[1].title = "分页中的长标题发生变化" },
                { $0.standardAppearance.itemAppearance.normal.font = .systemFont(ofSize: 28) },
                { $0.items[2].badgeValue = "新内容" },
                { $0.items[1].setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 32)], for: .normal) },
                { $0.standardAppearance = SPTabBarAppearance(barAppearance: $0.standardAppearance) },
                { $0.defaultContentLayout.imagePlacement = .inline }
            ]
            for change in changes {
                change(bar)
                bar.layoutIfNeeded()
                let a = frame(1, collection).insetBy(dx: 4, dy: 4)
                let b = frame(2, collection).insetBy(dx: 4, dy: 4)
                XCTAssertEqual(indicator.frame.midX, a.midX + (b.midX - a.midX) * 0.35, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.width, a.width + (b.width - a.width) * 0.35, accuracy: 0.01)
                XCTAssertEqual(renderer.state?.fromIndex, 1)
                XCTAssertEqual(renderer.state?.toIndex, 2)
                XCTAssertEqual(renderer.state?.progress, 0.35)
                XCTAssertEqual(bar.selectedIndex, 0)
            }
        }
    }

    func testAppearanceOnlyRefreshPreservesSelectionAnimationAndManualOffset() {
        let (bar, collection, indicator) = mount()
        bar.layoutConfiguration.minimumItemWidth = 150
        bar.layoutIfNeeded()
        collection.contentOffset.x = 90
        bar.items[0].accessibilityHint = "查看频道"
        bar.standardAppearance.backgroundColor = .systemPink
        bar.layoutIfNeeded()
        XCTAssertEqual(collection.contentOffset.x, 90, accuracy: 0.01)
        bar.setSelectedIndex(4, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let midway = indicator.frame
        let offset = collection.contentOffset.x
        bar.standardAppearance.itemAppearance.normal.titleColor = .systemGreen
        bar.items[0].badgeColor = .systemOrange
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, midway)
        XCTAssertEqual(collection.contentOffset.x, offset, accuracy: 0.01)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, frame(4, collection).insetBy(dx: 4, dy: 4))
    }

    func testIndicatorColorRefreshKeepsAnimationForBarAndItemAppearance() {
        for itemOverride in [false, true] {
            let (bar, _, indicator) = mount()
            if itemOverride {
                bar.items[4].standardAppearance = SPTabBarAppearance()
            }
            let renderer = RecordingIndicator()
            bar.indicatorStyle = .custom
            bar.indicatorView = renderer
            bar.setSelectedIndex(4, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            let midway = indicator.frame
            let appearance = itemOverride ? bar.items[4].standardAppearance! : bar.standardAppearance
            appearance.indicatorColor = .systemPink
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator.frame, midway)
            XCTAssertEqual(renderer.state?.progress, 0.5)
            XCTAssertEqual(renderer.state?.fromIndex, 0)
            XCTAssertEqual(renderer.state?.toIndex, 4)
            XCTAssertEqual(renderer.state?.color, .systemPink)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertNotEqual(indicator.frame, midway)
        }
    }

    func testDefaultContentReferenceMatchesTitleAfterGeometryAndFontChanges() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            var layout = SPTabBarIndicatorLayout()
            layout.reference = .content
            bar.standardAppearance.indicatorLayout = layout
            bar.setSelectedIndex(2, animated: false)
            let changes: [(SPTabBar) -> Void] = [
                { $0.layoutConfiguration.itemSpacing = 24 },
                { $0.layoutConfiguration.minimumItemWidth = 160 },
                { $0.items[2].title = "动态更新标题" },
                { $0.items[2].setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 28)], for: .selected) },
                { $0.frame.size.height = 90 }
            ]
            for change in changes {
                change(bar)
                bar.reloadIndicator()
                bar.layoutIfNeeded()
                // 手动滚动策略允许选中项离开屏幕；滚至该项后核对实际显示内容。
                collection.scrollToItem(at: IndexPath(item: 2, section: 0), at: .centeredHorizontally, animated: false)
                collection.layoutIfNeeded()
                let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 2, section: 0)))
                cell.layoutIfNeeded()
                let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
                button.layoutIfNeeded()
                let title = try XCTUnwrap(button.titleLabel)
                let actual = title.convert(title.bounds, to: collection)
                XCTAssertEqual(indicator.frame.midX, actual.midX, accuracy: 1)
                XCTAssertEqual(indicator.frame.width, actual.width, accuracy: 1)
                XCTAssertEqual(indicator.frame.midY, actual.midY, accuracy: 1)
            }
        }
    }

    func testContentGeometryChangeSettlesAnimationEvenWhenItemFramesStayEqual() throws {
        for rtl in [false, true] {
            for changedIndex in [0, 2] {
                let (bar, collection, indicator) = mount(rtl: rtl)
                bar.items.forEach { $0.title = "短" }
                bar.layoutConfiguration.minimumItemWidth = 200
                var layout = SPTabBarIndicatorLayout()
                layout.reference = .content
                bar.standardAppearance.indicatorLayout = layout
                bar.setSelectedIndex(0, animated: false)
                bar.setSelectedIndex(2, animated: true)
                bar.advanceSelectionAnimation(to: 0.5)
                let itemFrames = bar.items.indices.map { frame($0, collection) }
                bar.items[changedIndex].title = "更新后的标题"
                bar.layoutIfNeeded()
                XCTAssertEqual(bar.items.indices.map { frame($0, collection) }, itemFrames)
                let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 2, section: 0)))
                cell.layoutIfNeeded()
                let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
                button.layoutIfNeeded()
                let title = try XCTUnwrap(button.titleLabel)
                let expected = title.convert(title.bounds, to: collection)
                XCTAssertEqual(indicator.frame.midX, expected.midX, accuracy: 1)
                XCTAssertEqual(indicator.frame.width, expected.width, accuracy: 1)
                bar.advanceSelectionAnimation(to: 1)
                XCTAssertEqual(indicator.frame.midX, expected.midX, accuracy: 1)
                XCTAssertEqual(indicator.frame.width, expected.width, accuracy: 1)
            }
        }
    }

    func testReplacingAppearanceRecalculatesAnimationIndicatorWithUnchangedItemFrames() {
        let (bar, collection, indicator) = mount()
        bar.layoutConfiguration.minimumItemWidth = 200
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let item = frame(2, collection)
        let appearance = SPTabBarAppearance(barAppearance: bar.standardAppearance)
        var layout = SPTabBarIndicatorLayout()
        layout.width = .fixed(23)
        layout.height = 5
        appearance.indicatorLayout = layout
        bar.standardAppearance = appearance
        bar.layoutIfNeeded()
        let expected = CGRect(x: item.midX - 11.5, y: item.midY - 2.5, width: 23, height: 5)
        XCTAssertEqual(frame(2, collection), item)
        XCTAssertEqual(indicator.frame, expected)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, expected)
    }

    func testContentGeometryChangeRebasesPagingOriginTakenFromAnimation() {
        for rtl in [false, true] {
            for changeBeforeTakeover in [false, true] {
                let (bar, collection, indicator) = mount(rtl: rtl)
                let provider = IndicatorContentProvider()
                bar.contentDelegate = provider
                bar.contentStyle = .custom
                var layout = SPTabBarIndicatorLayout()
                layout.reference = .content
                bar.standardAppearance.indicatorLayout = layout
                bar.setSelectedIndex(0, animated: false)
                bar.setSelectedIndex(2, animated: true)
                bar.advanceSelectionAnimation(to: 0.5)
                let updateContent = {
                    provider.rect = CGRect(x: 17, y: 11, width: 41, height: 19)
                    bar.items[2].title = "更新内容区域"
                }
                if changeBeforeTakeover {
                    updateContent()
                }
                bar.setTransitionProgress(from: 0, to: 2, progress: 0.4)
                if !changeBeforeTakeover {
                    updateContent()
                }
                bar.layoutIfNeeded()
                let a = frame(0, collection), b = frame(2, collection)
                XCTAssertEqual(indicator.frame.minX, a.minX + (b.minX - a.minX) * 0.4 + 17, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.minY, 11)
                XCTAssertEqual(indicator.frame.size, CGSize(width: 41, height: 19))
                XCTAssertEqual(bar.selectedIndex, 2)
            }
        }
    }

    func testReduceMotionNotificationSettlesAnimationWhileTransparencyPreservesIt() {
        let (bar, collection, indicator) = mount()
        bar.setSelectedIndex(4, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let midway = indicator.frame
        NotificationCenter.default.post(
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, midway)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        bar.layoutIfNeeded()
        let expected = frame(4, collection).insetBy(dx: 4, dy: 4)
        XCTAssertEqual(indicator.frame, expected)
        bar.advanceSelectionAnimation(to: 0.7)
        XCTAssertEqual(indicator.frame, expected)
    }

    func testBuiltinStylesResolveGeometryAndColorWithoutAppearanceConfiguration() {
        let (bar, collection, indicator) = mount()
        bar.tintColor = .systemPink
        let item = frame(0, collection)
        XCTAssertEqual(bar.indicatorStyle, .capsule)
        XCTAssertNil(bar.standardAppearance.indicatorLayout)
        XCTAssertNil(bar.standardAppearance.indicatorColor)
        XCTAssertEqual(indicator.frame, item.insetBy(dx: 4, dy: 4))
        XCTAssertEqual(indicator.backgroundColor, .tertiarySystemFill)
        bar.indicatorStyle = .underline
        let cell = collection.cellForItem(at: IndexPath(item: 0, section: 0))!
        let button = cell.contentView.subviews.compactMap { $0 as? UIButton }.first!
        button.layoutIfNeeded()
        let title = button.titleLabel!
        let titleFrame = title.convert(title.bounds, to: collection)
        XCTAssertEqual(indicator.frame.minX, titleFrame.minX, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.width, titleFrame.width, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.maxY, item.maxY, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.height, 3)
        XCTAssertEqual(indicator.backgroundColor, .systemPink)
        bar.indicatorStyle = .capsule
        XCTAssertEqual(indicator.frame, item.insetBy(dx: 4, dy: 4))
        XCTAssertEqual(indicator.backgroundColor, .tertiarySystemFill)
    }

    func testAutomaticCornerRadiusUsesSmallerDimensionAcrossStylesAndSizeChanges() {
        let (bar, _, indicator) = mount()
        let renderer = RecordingIndicator()
        bar.indicatorView = renderer
        let cases: [(width: CGFloat, height: CGFloat, radius: CGFloat)] = [
            (40, 10, 5),
            (20, 20, 10),
            (10, 40, 5),
            (0, 40, 0),
            (40, 0, 0),
            (0, 0, 0)
        ]
        for style: SPTabBar.IndicatorStyle in [.capsule, .underline, .custom] {
            bar.indicatorStyle = style
            for value in cases {
                var layout = SPTabBarIndicatorLayout()
                layout.width = .fixed(value.width)
                layout.height = value.height
                bar.standardAppearance.indicatorLayout = layout
                XCTAssertEqual(indicator.bounds.size, CGSize(width: value.width, height: value.height))
                XCTAssertEqual(indicator.layer.cornerRadius, value.radius, "\(style): \(value)")
                XCTAssertEqual(indicator.isHidden, value.width == 0 || value.height == 0)
                if style == .custom {
                    XCTAssertEqual(renderer.state?.cornerRadius, value.radius)
                    XCTAssertEqual(renderer.layer.cornerRadius, value.radius)
                }
            }
        }
    }

    func testFixedCornerRadiusClampsAndAutomaticRestoresRadius() {
        let (bar, _, indicator) = mount()
        for size in [CGSize(width: 40, height: 10), CGSize(width: 20, height: 20), CGSize(width: 10, height: 40)] {
            var layout = SPTabBarIndicatorLayout()
            layout.width = .fixed(size.width)
            layout.height = size.height
            let maximumRadius: CGFloat = size.width == size.height ? 10 : 5
            let cases: [(radius: CGFloat, expected: CGFloat)] = [
                (4, 4),
                (100, maximumRadius),
                (0, 0),
                (-1, 0),
                (.nan, 0),
                (.infinity, 0)
            ]
            for value in cases {
                layout.cornerRadius = .fixed(value.radius)
                bar.standardAppearance.indicatorLayout = layout
                XCTAssertEqual(indicator.layer.cornerRadius, value.expected)
                bar.standardAppearance.indicatorLayout?.cornerRadius = .automatic
                XCTAssertEqual(indicator.layer.cornerRadius, maximumRadius)
                XCTAssertEqual(indicator.bounds.size, size)
            }
        }
    }

    func testOverridesSurviveStyleChangesAndNilRestoresCurrentPreset() {
        let (bar, collection, indicator) = mount()
        var layout = SPTabBarIndicatorLayout()
        layout.width = .fixed(22); layout.height = 5
        layout.verticalAlignment = .top
        bar.standardAppearance.indicatorLayout = layout
        bar.standardAppearance.indicatorColor = .systemOrange
        let customFrame = indicator.frame
        for style: SPTabBar.IndicatorStyle in [.underline, .capsule, .custom] {
            bar.indicatorStyle = style
            XCTAssertEqual(indicator.frame, customFrame)
            XCTAssertEqual(indicator.backgroundColor, .systemOrange)
        }
        bar.indicatorStyle = .underline
        bar.standardAppearance.indicatorLayout = nil
        bar.standardAppearance.indicatorColor = nil
        XCTAssertEqual(indicator.frame.height, 3)
        XCTAssertEqual(indicator.frame.maxY, frame(0, collection).maxY)
        XCTAssertEqual(indicator.backgroundColor, bar.tintColor)
        bar.indicatorStyle = .capsule
        XCTAssertEqual(indicator.backgroundColor, .tertiarySystemFill)
    }

    func testNoneHidesIndicatorSuppressesCustomCallbacksAndRestoresSelection() {
        let (bar, _, indicator) = mount()
        let view = RecordingIndicator()
        let provider = GeometryProvider()
        bar.indicatorStyle = .custom
        bar.indicatorView = view
        bar.indicatorLayoutDelegate = provider
        let calls = provider.calls
        let state = view.state
        bar.indicatorStyle = .none
        bar.setSelectedIndex(2, animated: false)
        bar.setTransitionProgress(from: 2, to: 3, progress: 0.4)
        XCTAssertTrue(indicator.isHidden)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(indicator.frame, .zero)
        XCTAssertEqual(provider.calls, calls)
        XCTAssertEqual(view.state?.frame, state?.frame)
        XCTAssertEqual(bar.selectedIndex, 2)
        bar.indicatorStyle = .custom
        XCTAssertFalse(indicator.isHidden)
        XCTAssertFalse(view.isHidden)
        XCTAssertGreaterThan(provider.calls, calls)
        XCTAssertEqual(view.state?.progress, 0.4)
        bar.setSelectedIndex(2, animated: false)
        bar.indicatorStyle = .underline
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(indicator.frame.height, 3)
    }

    func testUnspecifiedLayoutAndColorRemainUnspecifiedAfterCopyAndArchive() throws {
        let original = SPTabBarAppearance()
        let copy = try XCTUnwrap(original.copy() as? SPTabBarAppearance)
        let data = try NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        XCTAssertNil(decoded.indicatorLayout)
        XCTAssertNil(decoded.indicatorColor)
        let (bar, _, indicator) = mount()
        bar.standardAppearance = decoded
        bar.indicatorStyle = .underline
        XCTAssertEqual(indicator.frame.height, 3)
        bar.indicatorStyle = .capsule
        XCTAssertEqual(indicator.frame.height, bar.bounds.height - 8)
    }

    func testHiddenOrEmptyIndicatorKeepsAnimatedCenteringAndRetargeting() {
        XCTAssertFalse(UIAccessibility.isReduceMotionEnabled)
        for rtl in [false, true] {
            for style: SPTabBar.IndicatorStyle in [.underline, .none, .custom] {
                let (bar, collection, indicator) = mount(rtl: rtl)
                bar.items = (0 ..< 10).map { SPTabBarItem(title: "动画标签 \($0)") }
                bar.indicatorStyle = style
                if style == .custom {
                    var layout = SPTabBarIndicatorLayout.underline
                    layout.height = 0
                    bar.standardAppearance.indicatorLayout = layout
                }
                bar.setSelectedIndex(0, animated: false)
                bar.layoutIfNeeded()
                let tolerance = 1 / max(1, bar.traitCollection.displayScale)
                let start = collection.contentOffset.x
                let maximum = max(0, collection.contentSize.width - collection.bounds.width)
                let target = min(maximum, max(0, frame(9, collection).midX - collection.bounds.width / 2))
                XCTAssertGreaterThan(abs(target - start), 100)
                bar.setSelectedIndex(9, animated: true)
                XCTAssertEqual(collection.contentOffset.x, start, accuracy: tolerance)
                bar.advanceSelectionAnimation(to: 0.5)
                let midway = collection.contentOffset.x
                XCTAssertEqual(midway, (start + target) / 2, accuracy: tolerance)
                if style != .underline {
                    XCTAssertTrue(indicator.isHidden)
                }

                // 连续选择从当前滚动位置接续；不依赖指示器是否存在。
                let next = min(maximum, max(0, frame(2, collection).midX - collection.bounds.width / 2))
                bar.setSelectedIndex(2, animated: true)
                XCTAssertEqual(collection.contentOffset.x, midway, accuracy: tolerance)
                bar.advanceSelectionAnimation(to: 0.5)
                XCTAssertEqual(collection.contentOffset.x, (midway + next) / 2, accuracy: tolerance)
                bar.advanceSelectionAnimation(to: 1)
                XCTAssertEqual(collection.contentOffset.x, next, accuracy: tolerance)
                XCTAssertEqual(bar.selectedIndex, 2)
                bar.setSelectedIndex(0, animated: false)
                XCTAssertEqual(collection.contentOffset.x, start, accuracy: tolerance)
            }
        }
    }

    func testCustomRendererStartsAtZeroAndRetargetsWithoutPrematureCompletion() {
        XCTAssertFalse(UIAccessibility.isReduceMotionEnabled)
        let (bar, collection, indicator) = mount()
        let renderer = RecordingIndicator()
        bar.indicatorStyle = .custom
        bar.indicatorView = renderer
        bar.layoutIfNeeded()
        let initialFrame = indicator.frame
        let initialOffset = collection.contentOffset.x
        renderer.states.removeAll()
        bar.setSelectedIndex(4, animated: true)
        XCTAssertFalse(renderer.states.isEmpty)
        XCTAssertTrue(renderer.states.allSatisfy { $0.fromIndex == 0 && $0.toIndex == 4 && $0.progress == 0 })
        XCTAssertEqual(renderer.state?.frame, initialFrame)
        XCTAssertEqual(collection.contentOffset.x, initialOffset)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertEqual(renderer.state?.progress, 0.5)
        let midway = indicator.frame
        renderer.states.removeAll()
        bar.setSelectedIndex(2, animated: true)
        XCTAssertFalse(renderer.states.isEmpty)
        XCTAssertTrue(renderer.states.allSatisfy { $0.fromIndex == 4 && $0.toIndex == 2 && $0.progress == 0 })
        XCTAssertEqual(renderer.state?.frame, midway)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(renderer.state?.progress, 1)
        XCTAssertEqual(renderer.state?.toIndex, 2)
        renderer.states.removeAll()
        bar.setSelectedIndex(0, animated: false)
        XCTAssertFalse(renderer.states.isEmpty)
        XCTAssertTrue(renderer.states.allSatisfy { $0.fromIndex == 0 && $0.toIndex == 0 && $0.progress == 1 })
        XCTAssertEqual(renderer.state?.frame, indicator.frame)
    }

    func testCustomRendererPreservesNilSelectionEndpointsDuringAnimation() throws {
        XCTAssertFalse(UIAccessibility.isReduceMotionEnabled)
        let (bar, collection, _) = mount()
        let renderer = RecordingIndicator()
        bar.indicatorStyle = .custom
        bar.indicatorView = renderer
        bar.setSelectedIndex(nil, animated: false)
        renderer.states.removeAll()
        let start = collection.contentOffset.x
        bar.setSelectedIndex(4, animated: true)
        XCTAssertEqual(try XCTUnwrap(renderer.state).progress, 0)
        XCTAssertNil(try XCTUnwrap(renderer.state).fromIndex)
        XCTAssertEqual(renderer.state?.toIndex, 4)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertGreaterThan(collection.contentOffset.x, start)
        XCTAssertNil(try XCTUnwrap(renderer.state).fromIndex)
        XCTAssertEqual(renderer.state?.toIndex, 4)
        bar.advanceSelectionAnimation(to: 1)
        bar.setSelectedIndex(nil, animated: true)
        XCTAssertEqual(renderer.state?.fromIndex, 4)
        XCTAssertNil(try XCTUnwrap(renderer.state).toIndex)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertNil(bar.selectedIndex)
    }

    func testNegativeCustomGeometryFallsBackToConfiguredLayout() {
        let (bar, collection, indicator) = mount()
        let geometry = GeometryProvider()
        let content = IndicatorContentProvider()
        bar.indicatorStyle = .custom
        bar.indicatorLayoutDelegate = geometry
        for invalid in [
            CGRect(x: 7, y: 9, width: -31, height: 17),
            CGRect(x: 7, y: 9, width: 31, height: -17)
        ] {
            geometry.overrideRect = invalid
            bar.reloadIndicator()
            XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        }
        bar.indicatorLayoutDelegate = nil
        bar.contentDelegate = content
        bar.contentStyle = .custom
        var layout = SPTabBarIndicatorLayout()
        layout.reference = .content
        bar.standardAppearance.indicatorLayout = layout
        for invalid in [
            CGRect(x: 7, y: 9, width: -31, height: 17),
            CGRect(x: 7, y: 9, width: 31, height: -17)
        ] {
            content.rect = invalid
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator.frame, frame(0, collection))
        }
    }

    func testPresetsAndFixedTopGeometryDoNotChangeContentMeasurement() throws {
        let (bar, collection, indicator) = mount()
        let item = frame(0, collection)
        XCTAssertEqual(indicator.frame, item.insetBy(dx: 4, dy: 4))
        let size = bar.sizeThatFits(CGSize(width: 320, height: 0))
        let contentSize = collection.contentSize
        var layout = SPTabBarIndicatorLayout()
        layout.width = .fixed(24); layout.height = 5
        layout.verticalAlignment = .top
        layout.offset.y = 2
        layout.cornerRadius = .fixed(1)
        layout.placement = .foreground
        bar.standardAppearance.indicatorLayout = layout
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, CGRect(x: item.midX - 12, y: 2, width: 24, height: 5))
        XCTAssertEqual(indicator.layer.cornerRadius, 1)
        XCTAssertEqual(indicator.layer.zPosition, 1)
        XCTAssertFalse(indicator.isUserInteractionEnabled)
        XCTAssertTrue(indicator.accessibilityElementsHidden)
        XCTAssertEqual(bar.sizeThatFits(CGSize(width: 320, height: 0)), size)
        XCTAssertEqual(collection.contentSize, contentSize)
        bar.standardAppearance.indicatorLayout = .capsule
        bar.standardAppearance.indicatorLayout = .underline
        bar.standardAppearance.indicatorColor = nil
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
        cell.layoutIfNeeded(); button.layoutIfNeeded()
        let title = try XCTUnwrap(button.titleLabel)
        let titleFrame = title.convert(title.bounds, to: collection)
        XCTAssertEqual(indicator.frame, CGRect(x: titleFrame.minX, y: 57, width: titleFrame.width, height: 3))
        bar.indicatorStyle = .none
        XCTAssertTrue(indicator.isHidden)
    }

    func testActualTitleGeometryForVisibleAndOffscreenItemsInBothDirections() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            var layout = SPTabBarIndicatorLayout()
            layout.reference = .content
            bar.standardAppearance.indicatorLayout = layout
            for index in [0, 4, 1] {
                bar.setSelectedIndex(index, animated: false)
                collection.layoutIfNeeded()
                let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
                let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
                cell.layoutIfNeeded(); button.layoutIfNeeded()
                let title = try XCTUnwrap(button.titleLabel)
                let actual = title.convert(title.bounds, to: collection)
                XCTAssertEqual(indicator.frame.minX, actual.minX, accuracy: 1)
                XCTAssertEqual(indicator.frame.width, actual.width, accuracy: 1)
                XCTAssertEqual(indicator.frame.minY, actual.minY, accuracy: 1)
                XCTAssertGreaterThan(indicator.frame.width, 0)
            }
        }
    }

    func testDelegateInterpolatesAllComponentsAndRecoversFromCancellationAndResize() {
        let (bar, collection, indicator) = mount()
        let provider = GeometryProvider()
        bar.indicatorStyle = .custom
        bar.indicatorLayoutDelegate = provider
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.5)
        let a = provider.rect(0, frame(0, collection)), b = provider.rect(1, frame(1, collection))
        XCTAssertEqual(indicator.frame.minX, (a.minX + b.minX) / 2, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.minY, (a.minY + b.minY) / 2, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.width, (a.width + b.width) / 2, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.height, (a.height + b.height) / 2, accuracy: 0.01)
        bar.standardAppearance.indicatorColor = .systemPink
        XCTAssertEqual(indicator.frame.minY, (a.minY + b.minY) / 2, accuracy: 0.01)
        bar.frame.size.width = 500; bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, (a.width + b.width) / 2, accuracy: 0.01)
        bar.setSelectedIndex(0, animated: false)
        XCTAssertEqual(indicator.frame, provider.rect(0, frame(0, collection)))
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        XCTAssertEqual(indicator.frame.height, (a.height + b.height) / 2, accuracy: 0.01)
        let midway = indicator.frame
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0)
        XCTAssertEqual(indicator.frame, midway)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator.frame, provider.rect(2, frame(2, collection)))
    }

    func testCustomViewReceivesProgressReplacesAndReleases() {
        let (bar, _, indicator) = mount()
        let view = RecordingIndicator()
        bar.indicatorStyle = .custom
        bar.indicatorView = view
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.35)
        XCTAssertEqual(view.state?.progress, 0.35)
        XCTAssertEqual(view.state?.fromIndex, 0)
        XCTAssertEqual(view.state?.toIndex, 1)
        XCTAssertEqual(view.frame, indicator.bounds)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertTrue(view.accessibilityElementsHidden)
        bar.indicatorView = nil
        XCTAssertNil(view.superview)
        XCTAssertNotEqual(indicator.backgroundColor, .clear)
        weak var released: RecordingIndicator?
        autoreleasepool {
            let replacement = RecordingIndicator()
            released = replacement
            bar.indicatorView = replacement
        }
        XCTAssertNotNil(released)
        autoreleasepool { bar.indicatorView = nil }
        // UIKit 的事务暂持视图，跨过提交点后再验证框架已释放所有权。
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNil(released)
    }

    func testInvalidDelegateFallsBackAndWeakDelegateReleaseRestoresPreset() {
        let (bar, collection, indicator) = mount()
        var provider: GeometryProvider? = GeometryProvider()
        bar.indicatorStyle = .custom
        bar.indicatorLayoutDelegate = provider
        provider?.invalid = true
        bar.reloadIndicator()
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        provider?.invalid = false
        bar.reloadIndicator()
        XCTAssertEqual(indicator.frame.height, 4)
        provider = nil
        bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        var layout = SPTabBarIndicatorLayout()
        layout.width = .fixed(-.infinity); layout.height = -8
        layout.offset = CGPoint(x: CGFloat.nan, y: CGFloat.infinity)
        bar.standardAppearance.indicatorLayout = layout
        XCTAssertTrue(indicator.frame.origin.x.isFinite)
        XCTAssertEqual(indicator.frame.height, 0)
        XCTAssertTrue(indicator.isHidden)
    }

    func testRTLAlignmentScrollingAndSafeViewportCoordinates() {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            var layout = SPTabBarIndicatorLayout()
            layout.width = .fixed(12); layout.height = 4
            layout.horizontalAlignment = .leading
            layout.horizontalInset = 5
            bar.standardAppearance.indicatorLayout = layout
            let item = frame(0, collection)
            XCTAssertEqual(indicator.frame.minX, rtl ? item.maxX - 17 : item.minX + 5, accuracy: 0.01)
            let stored = indicator.frame
            let before = indicator.convert(indicator.bounds, to: bar)
            collection.contentOffset.x += 10
            let after = indicator.convert(indicator.bounds, to: bar)
            XCTAssertEqual(indicator.frame, stored)
            XCTAssertEqual(after.minX, before.minX - 10, accuracy: 0.01)
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            window.rootViewController!.view.layoutIfNeeded()
            bar.setNeedsLayout(); bar.layoutIfNeeded()
            XCTAssertEqual(collection.frame.minX, bar.safeAreaInsets.left, accuracy: 0.01)
            XCTAssertTrue(collection.clipsToBounds)
        }
    }

    func testIndicatorModesAreIndependentFromContentAndFallbackWhenMissing() {
        let (bar, collection, indicator) = mount()
        let provider = GeometryProvider()
        let view = RecordingIndicator()
        bar.indicatorLayoutDelegate = provider
        bar.indicatorView = view
        XCTAssertEqual(bar.indicatorStyle, .capsule)
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        XCTAssertNil(view.state)
        XCTAssertTrue(view.isHidden)
        bar.indicatorStyle = .custom
        XCTAssertEqual(indicator.frame, provider.rect(0, frame(0, collection)))
        XCTAssertNotNil(view.state)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(bar.contentStyle, .default)
        bar.indicatorStyle = .capsule
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        XCTAssertTrue(view.isHidden)
        bar.indicatorLayoutDelegate = nil; bar.indicatorView = nil
        bar.indicatorStyle = .custom
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        XCTAssertNotEqual(indicator.backgroundColor, .clear)
    }

    func testTintRefreshPreservesRendererProgressForPagingAndProgramAnimation() {
        let (bar, _, indicator) = mount()
        let view = RecordingIndicator()
        bar.indicatorStyle = .custom
        bar.indicatorView = view
        bar.standardAppearance.indicatorColor = nil
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        bar.tintColor = .systemPink
        XCTAssertEqual(view.state?.progress, 0.3)
        XCTAssertEqual(view.state?.fromIndex, 0)
        XCTAssertEqual(view.state?.toIndex, 1)
        XCTAssertEqual(view.state?.color, .systemPink)
        bar.setSelectedIndex(0, animated: false)
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let frame = indicator.frame
        bar.tintColor = .systemOrange
        XCTAssertEqual(view.state?.progress, 0.5)
        XCTAssertEqual(view.state?.fromIndex, 0)
        XCTAssertEqual(view.state?.toIndex, 2)
        XCTAssertEqual(view.state?.frame, frame)
        XCTAssertEqual(view.state?.color, .systemOrange)
        bar.advanceSelectionAnimation(to: 1)
        bar.setItems([])
        XCTAssertNil(view.state?.fromIndex)
        XCTAssertNil(view.state?.toIndex)
        bar.layoutIfNeeded()
        XCTAssertTrue(indicator.isHidden)
        XCTAssertEqual(indicator.frame, .zero)
    }

    func testCustomContentRegionAndFallback() {
        let (bar, collection, indicator) = mount()
        let provider = IndicatorContentProvider()
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        var layout = SPTabBarIndicatorLayout()
        layout.reference = .content
        bar.standardAppearance.indicatorLayout = layout
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, CGRect(x: frame(0, collection).minX + 7, y: 9, width: 31, height: 17))
        provider.rect = nil
        bar.reloadContent(); bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, frame(0, collection))
        provider.rect = CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)
        bar.reloadContent(); bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, frame(0, collection))
    }

    func testContentGeometryRefreshesForDynamicTypeAndItemAppearance() {
        let (bar, collection, indicator) = mount()
        var layout = SPTabBarIndicatorLayout()
        layout.reference = .content
        bar.standardAppearance.indicatorLayout = layout
        let original = indicator.frame.width
        let host = window.rootViewController!
        let child = UIViewController()
        host.addChild(child); host.view.addSubview(child.view); child.didMove(toParent: host)
        child.view.addSubview(bar)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: child
        )
        child.view.layoutIfNeeded(); bar.setNeedsLayout(); bar.layoutIfNeeded()
        XCTAssertGreaterThan(indicator.frame.width, original)
        let appearance = SPTabBarAppearance()
        layout.reference = .item; layout.width = .fixed(19); layout.height = 8
        appearance.indicatorLayout = layout
        bar.items[0].standardAppearance = appearance
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, 19)
        bar.items[0].standardAppearance?.indicatorLayout?.width = .fixed(25)
        XCTAssertEqual(indicator.frame.width, 25)
        XCTAssertEqual(indicator.frame.midX, frame(0, collection).midX, accuracy: 0.01)
    }

    func testMissingIndicatorArchiveConfigurationUsesCurrentStyleDefaults() throws {
        let appearance = SPTabBarAppearance()
        appearance.indicatorColor = .systemOrange
        appearance.indicatorLayout = .underline
        let data = try NSKeyedArchiver.archivedData(withRootObject: appearance, requiringSecureCoding: true)
        var archive = try XCTUnwrap(PropertyListSerialization
            .propertyList(from: data, format: nil) as? [String: Any])
        var objects = try XCTUnwrap(archive["$objects"] as? [Any])
        let index = try XCTUnwrap(objects.firstIndex { ($0 as? [String: Any])?["SP.indicatorLayout"] != nil })
        var object = try XCTUnwrap(objects[index] as? [String: Any])
        XCTAssertNotNil(object.removeValue(forKey: "SP.indicatorColor"))
        XCTAssertNotNil(object.removeValue(forKey: "SP.indicatorLayout"))
        objects[index] = object
        archive["$objects"] = objects
        let archived = try PropertyListSerialization.data(fromPropertyList: archive, format: .binary, options: 0)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
            ofClass: SPTabBarAppearance.self,
            from: archived
        ))
        XCTAssertNil(decoded.indicatorColor)
        XCTAssertNil(decoded.indicatorLayout)
        let (bar, collection, indicator) = mount()
        bar.indicatorStyle = .none
        bar.standardAppearance = decoded
        XCTAssertEqual(bar.indicatorStyle, .none)
        XCTAssertTrue(indicator.isHidden)
        bar.indicatorStyle = .underline
        XCTAssertFalse(indicator.isHidden)
        XCTAssertEqual(indicator.frame.height, 3)
        XCTAssertEqual(indicator.backgroundColor, bar.tintColor)
        bar.indicatorStyle = .capsule
        XCTAssertEqual(indicator.frame, frame(0, collection).insetBy(dx: 4, dy: 4))
        XCTAssertEqual(indicator.backgroundColor, .tertiarySystemFill)
    }

    func testArchiveRetainsNonfiniteConfigurationAndLayoutNormalizesIt() throws {
        let appearance = SPTabBarAppearance()
        appearance.indicatorLayout = .capsule
        appearance.indicatorLayout?.width = .fixed(.nan)
        appearance.indicatorLayout?.height = -10
        appearance.indicatorLayout?.offset.x = .infinity
        let data = try NSKeyedArchiver.archivedData(withRootObject: appearance, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        guard case let .fixed(width) = decoded.indicatorLayout?.width else {
            return XCTFail("归档应保留固定宽度模式")
        }
        XCTAssertTrue(width.isNaN)
        XCTAssertEqual(decoded.indicatorLayout?.height, -10)
        let (bar, _, indicator) = mount()
        bar.standardAppearance = decoded
        bar.layoutIfNeeded()
        XCTAssertTrue(indicator.frame.origin.x.isFinite)
        XCTAssertTrue(indicator.frame.width.isFinite)
        XCTAssertEqual(indicator.frame.height, 0)
    }

    func testAppearanceCopyAndArchivePreserveLayoutValues() throws {
        let appearance = SPTabBarAppearance()
        var layout = SPTabBarIndicatorLayout()
        layout.reference = .content; layout.width = .fixed(32); layout.height = 7
        layout.offset = CGPoint(x: -2, y: 5); layout.placement = .foreground
        appearance.indicatorLayout = layout
        appearance.indicatorColor = nil
        let (bar, _, _) = mount()
        bar.standardAppearance = appearance
        appearance.indicatorLayout?.width = .fixed(99)
        XCTAssertEqual(bar.standardAppearance.indicatorLayout, layout)
        let data = try NSKeyedArchiver.archivedData(withRootObject: bar.standardAppearance, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        XCTAssertEqual(decoded.indicatorLayout, layout)
        XCTAssertNil(decoded.indicatorColor)
    }
}

@MainActor
private final class GeometryProvider: SPTabBarIndicatorLayoutDelegate {
    var invalid = false
    var overrideRect: CGRect?
    var calls = 0
    func rect(_ index: Int, _ item: CGRect) -> CGRect {
        CGRect(
            x: item.midX - 10,
            y: CGFloat(index * 8 + 2),
            width: CGFloat(20 + index * 7),
            height: CGFloat(4 + index * 3)
        )
    }

    func tabBar(_ tabBar: SPTabBar, indicatorFrameFor context: SPTabBarIndicatorLayoutContext) -> CGRect? {
        calls += 1
        return overrideRect ?? (invalid ? CGRect(x: CGFloat.nan, y: 0, width: 1, height: 2) : rect(
            context.index,
            context.itemFrame
        ))
    }
}

@MainActor
private final class RecordingIndicator: SPTabBarIndicatorView {
    var state: SPTabBarIndicatorState?
    var states: [SPTabBarIndicatorState] = []
    override func update(_ state: SPTabBarIndicatorState) {
        super.update(state)
        self.state = state
        states.append(state)
    }
}

@MainActor
private final class IndicatorContentProvider: SPTabBarContentDelegate {
    var rect: CGRect? = CGRect(x: 7, y: 9, width: 31, height: 17)
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        var config = UIListContentConfiguration.cell()
        config.text = item.title
        var content = SPTabBarContent(configuration: config, size: CGSize(width: 80, height: 50))
        content.indicatorContentRect = rect
        return content
    }
}
