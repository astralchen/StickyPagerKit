import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarAutomaticContentTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window.rootViewController = nil
        window = nil
    }

    private func mount(_ source: any SPTabBarContentDelegate, count: Int = 2) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 320, height: 80))
        window.rootViewController!.view.addSubview(bar)
        bar.items = (0 ..< count).map { SPTabBarItem(title: "标签 \($0)") }
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.setSelectedIndex(0, animated: false)
        resize(bar, width: 320)
        return bar
    }

    private func resize(_ bar: SPTabBar, width: CGFloat) {
        bar.frame.size = CGSize(width: width, height: bar.sizeThatFits(CGSize(width: width, height: 0)).height)
        bar.layoutIfNeeded()
    }

    private func collection(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func view(_ bar: SPTabBar, index: Int = 0) -> AutoLayoutTabView {
        collection(bar).layoutIfNeeded()
        return collection(bar).cellForItem(at: IndexPath(item: index, section: 0))!.contentView.subviews
            .compactMap { $0 as? AutoLayoutTabView }.first!
    }

    func testBalancedWidthsStayContinuousAndMatchPhysicalFramesInRTL() {
        XCTAssertEqual(SPTabBarLayout.resolvedWidths([160, 44], viewportWidth: 320), [160, 160])
        XCTAssertEqual(SPTabBarLayout.resolvedWidths([161, 44], viewportWidth: 320), [161, 159])
        XCTAssertEqual(SPTabBarLayout.resolvedWidths([200, 60, 40], viewportWidth: 320), [200, 60, 60])
        XCTAssertEqual(SPTabBarLayout.resolvedWidths([200, 60, 40], viewportWidth: 280), [200, 60, 40])
        let source = WidthPolicySource()
        for rtl in [false, true] {
            source.widths = [160, 44]
            let bar = mount(source)
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            bar.setNeedsLayout()
            bar.layoutIfNeeded()
            let list = collection(bar)
            for first: CGFloat in [160, 161, 160] {
                source.widths[0] = first
                bar.reloadContent()
                resize(bar, width: 320)
                let a = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
                let b = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))!.frame
                XCTAssertEqual(a.width, first, accuracy: 0.01)
                XCTAssertEqual(b.width, 320 - first, accuracy: 0.01)
                XCTAssertEqual(a.minX, rtl ? b.width : 0, accuracy: 0.01)
                XCTAssertEqual(b.minX, rtl ? 0 : a.width, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width, 320, accuracy: 0.01)
            }
            for width: CGFloat in [319, 320, 321] {
                resize(bar, width: width)
                let a = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
                XCTAssertEqual(a.width, max(160, width / 2), accuracy: 0.01)
            }
            bar.removeFromSuperview()
        }
    }

    func testMinimumItemWidthUpdatesCustomDefaultAndFallbackItems() {
        let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: CGSize(
            width: 12,
            height: 28
        )))
        let bar = mount(source, count: 8)
        let list = collection(bar)
        XCTAssertEqual(bar.minimumItemWidth, 44)
        XCTAssertEqual(list.contentSize.width, 352, accuracy: 0.01)
        list.contentOffset.x = 32
        bar.minimumItemWidth = 24
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentSize.width, 320, accuracy: 0.01)
        XCTAssertEqual(list.contentOffset.x, 0, accuracy: 0.01)
        XCTAssertEqual(
            list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame.width,
            40,
            accuracy: 0.01
        )
        for style: SPTabBar.ContentStyle in [.default, .custom] {
            bar.contentStyle = style
            source.fallbackIndex = 0
            bar.minimumItemWidth = 90
            bar.layoutIfNeeded()
            for index in 0 ..< 8 {
                XCTAssertGreaterThanOrEqual(
                    list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
                        .width,
                    90
                )
            }
        }
        for (input, expected): (CGFloat, CGFloat) in [
            (-1, 0),
            (.nan, 44),
            (.infinity, 44),
            (2_000_000, 1_000_000),
            (0, 0)
        ] {
            bar.minimumItemWidth = input
            XCTAssertEqual(bar.minimumItemWidth, expected)
        }
    }

    func testMinimumWidthPreservesAnimationWhenAllocatedFramesDoNotChange() {
        let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: CGSize(
            width: 12,
            height: 28
        )))
        let bar = mount(source)
        let list = collection(bar)
        let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
        bar.setSelectedIndex(1, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let frame = indicator.frame
        bar.minimumItemWidth = 24
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, frame)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertNotEqual(indicator.frame, frame)
        bar.setTransitionProgress(from: 1, to: 0, progress: 0.4)
        let transition = indicator.frame
        bar.minimumItemWidth = 44
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, transition)
    }

    func testRequiredMinimumContentWidthMayOverflowViewportWithoutCompression() {
        let source = StaticAutomaticSource(configuration: RequiredWidthConfiguration())
        let bar = mount(source, count: 1)
        for rtl in [false, true] {
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            bar.setNeedsLayout()
            for width: CGFloat in [120, 320, 180] {
                resize(bar, width: width)
                let list = collection(bar)
                let frame = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
                XCTAssertEqual(frame.width, max(240, width), accuracy: 0.01)
                XCTAssertEqual(frame.height, 28, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width, max(240, width), accuracy: 0.01)
                let content = list.cellForItem(at: IndexPath(item: 0, section: 0))!.contentView.subviews
                    .compactMap { $0 as? RequiredWidthView }.first!
                XCTAssertGreaterThanOrEqual(content.bounds.width, 240)
                XCTAssertFalse(content.hasAmbiguousLayout)
            }
        }
    }

    func testVeryNarrowCustomCellsKeepIndicatorsWithinTheirFrames() {
        let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: CGSize(width: 1, height: 28)))
        let bar = mount(source, count: 40)
        bar.minimumItemWidth = 0
        resize(bar, width: 32)
        let list = collection(bar)
        for style: SPTabBarIndicatorLayout in [.capsule, .underline] {
            bar.standardAppearance.indicatorLayout = style
            bar.layoutIfNeeded()
            let item = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
            let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
            XCTAssertEqual(item.width, 1, accuracy: 0.01)
            XCTAssertFalse(indicator.frame.isNull)
            XCTAssertGreaterThanOrEqual(indicator.frame.minX, item.minX)
            XCTAssertLessThanOrEqual(indicator.frame.maxX, item.maxX)
        }
    }

    func testTinyCustomContentKeepsSelectionIndicatorInsideBounds() {
        let size = CGSize(width: 12, height: 1)
        let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: size))
        for explicit in [false, true] {
            source.explicitSize = explicit ? size : nil
            let bar = mount(source)
            for style: SPTabBarIndicatorLayout in [.capsule, .underline] {
                bar.standardAppearance.indicatorLayout = style
                bar.layoutIfNeeded()
                let indicator = collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
                XCTAssertEqual(bar.bounds.height, 1, accuracy: 0.01)
                XCTAssertFalse(indicator.frame.isNull)
                XCTAssertTrue(indicator.frame.origin.x.isFinite && indicator.frame.origin.y.isFinite)
                XCTAssertGreaterThanOrEqual(indicator.frame.minY, 0)
                XCTAssertLessThanOrEqual(indicator.frame.maxY, 1)
                XCTAssertEqual(indicator.frame.height, style == .capsule ? 0 : 1, accuracy: 0.01)
            }
            bar.removeFromSuperview()
        }
    }

    func testCompactAutomaticAndExplicitContentKeepHeightAndWidthPolicy() {
        let size = CGSize(width: 12, height: 28)
        let source = StaticAutomaticSource(configuration: IntrinsicTabConfiguration(size: size))
        for explicit in [false, true] {
            source.explicitSize = explicit ? size : nil
            for count in [2, 10] {
                let bar = mount(source, count: count)
                XCTAssertEqual(bar.bounds.height, 28, accuracy: 0.01)
                let list = collection(bar)
                let attributes = list.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!
                XCTAssertEqual(attributes.frame.height, 28, accuracy: 0.01)
                XCTAssertEqual(attributes.frame.width, count == 2 ? 160 : 44, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width, count == 2 ? 320 : 440, accuracy: 0.01)
                source.fallbackIndex = 0
                bar.reloadContent()
                resize(bar, width: 320)
                XCTAssertGreaterThanOrEqual(bar.bounds.height, 44, "混用默认项仍需满足默认图文的高度")
                source.fallbackIndex = nil
                bar.removeFromSuperview()
            }
        }
    }

    func testSystemConfigurationAndIntrinsicContentCanBeMeasuredAutomatically() {
        var list = UIListContentConfiguration.cell()
        list.text = String(repeating: "系统内容视图自动换行。", count: 12)
        list.textProperties.numberOfLines = 0
        let system = StaticAutomaticSource(configuration: list)
        let bar = mount(system)
        let wide = bar.sizeThatFits(CGSize(width: 600, height: 0)).height
        let narrow = bar.sizeThatFits(CGSize(width: 140, height: 0)).height
        XCTAssertGreaterThan(narrow, wide)
        XCTAssertGreaterThan(wide, 44)
        let intrinsic = StaticAutomaticSource(configuration: IntrinsicTabConfiguration())
        bar.contentDelegate = intrinsic
        resize(bar, width: 320)
        XCTAssertEqual(bar.bounds.height, 64, accuracy: 0.01)
        XCTAssertEqual(
            collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
                .width,
            160,
            accuracy: 0.01
        )
    }

    func testItemSpacingParticipatesInAutomaticMeasurementWithoutCommittingCandidateWidths() {
        let source = AutomaticTabSource()
        let bar = mount(source)
        source.samples.removeAll()
        bar.itemSpacing = 40
        resize(bar, width: 320)
        let list = collection(bar)
        let first = list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
        let second = list.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))!.frame
        XCTAssertEqual(first.width, 140, accuracy: 0.01)
        XCTAssertEqual(second.minX - first.maxX, 40, accuracy: 0.01)
        XCTAssertTrue(source.samples.contains { $0.horizontal == .required && abs($0.target.width - 140) < 0.01 })
        _ = bar.sizeThatFits(CGSize(width: 700, height: 0))
        list.layoutIfNeeded()
        XCTAssertEqual(list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame, first)
        XCTAssertEqual(list.contentSize.width, 320, accuracy: 0.01)

        source.text = String(repeating: "长标题自动换行", count: 12)
        let host = window.rootViewController!
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        child.view.addSubview(bar)
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: child
        )
        child.view.layoutIfNeeded()
        bar.reloadContent()
        resize(bar, width: 320)
        let a = list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
        let b = list.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))!.frame
        XCTAssertEqual(b.minX - a.maxX, 40, accuracy: 0.01)
        XCTAssertTrue(source.samples.contains { $0.horizontal == .required && abs($0.target.width - a.width) < 0.01 })
        XCTAssertEqual(
            source.samples.last { $0.index == 0 && $0.horizontal == .required }?.category,
            .accessibilityExtraExtraExtraLarge
        )
        let content = view(bar)
        content.layoutIfNeeded()
        let expectedHeight = content.label.sizeThatFits(CGSize(
            width: content.bounds.width - 32,
            height: .greatestFiniteMagnitude
        )).height + 24
        XCTAssertEqual(bar.bounds.height, ceil(expectedHeight), accuracy: 1)
    }

    func testAutomaticContentMeasuresMultilineHeightAtAllocatedWidth() {
        let source = AutomaticTabSource()
        source.text = String(repeating: "自动布局根据实际宽度换行并计算高度。", count: 5)
        let bar = mount(source)
        for width: CGFloat in [320, 150, 500] {
            resize(bar, width: width)
            let content = view(bar)
            content.layoutIfNeeded()
            let expected = content.label.sizeThatFits(CGSize(
                width: content.bounds.width - 32,
                height: .greatestFiniteMagnitude
            )).height + 24
            XCTAssertEqual(bar.bounds.height, ceil(expected), accuracy: 1)
            XCTAssertLessThanOrEqual(content.bounds.width, width + 1)
            XCTAssertEqual(content.label.frame.minX, 16, accuracy: 0.01)
            XCTAssertLessThanOrEqual(content.label.frame.maxY, content.bounds.height - 12 + 1)
            XCTAssertTrue(source.samples
                .contains { $0.horizontal == .required && abs($0.target.width - content.bounds.width) < 1 })
        }
    }

    func testCandidateMeasurementsAreIsolatedCachedAndReleaseTemporaryViews() {
        let source = AutomaticTabSource()
        source.text = String(repeating: "自动测量隔离", count: 30)
        let bar = mount(source)
        let content = view(bar)
        let frame = collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!
            .frame
        let offset = collection(bar).contentOffset
        let alive = source.views.allObjects.count
        let wide = autoreleasepool { bar.sizeThatFits(CGSize(width: 600, height: 0)).height }
        let narrow = autoreleasepool { bar.sizeThatFits(CGSize(width: 140, height: 0)).height }
        XCTAssertGreaterThan(narrow, wide)
        let calls = source.samples.count
        let creations = source.creations
        for _ in 0 ..< 5 {
            _ = bar.sizeThatFits(CGSize(width: 140, height: 0))
        }
        XCTAssertEqual(source.samples.count, calls)
        XCTAssertEqual(source.creations, creations)
        XCTAssertEqual(source.views.allObjects.count, alive, "候选测量视图不留在层级或缓存中")
        collection(bar).layoutIfNeeded()
        XCTAssertTrue(view(bar) === content)
        XCTAssertEqual(
            collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame,
            frame
        )
        XCTAssertEqual(collection(bar).contentOffset, offset)
        resize(bar, width: 140)
        XCTAssertEqual(bar.bounds.height, narrow)
    }

    func testAutomaticAndExplicitSizesCoexistAndInvalidMeasurementFallsBack() {
        let source = AutomaticTabSource()
        source.fixedFirst = CGSize(width: 180, height: 90)
        let bar = mount(source)
        XCTAssertEqual(bar.bounds.height, 90)
        XCTAssertFalse(source.samples.contains { $0.index == 0 }, "显式尺寸不创建测量视图")
        XCTAssertTrue(source.samples.contains { $0.index == 1 })
        source.fixedFirst = nil
        source.invalidIndex = 1
        bar.reloadContent()
        resize(bar, width: 320)
        let cell = collection(bar).cellForItem(at: IndexPath(item: 1, section: 0))!
        XCTAssertTrue(cell.contentView.subviews.compactMap { $0 as? AutoLayoutTabView }.isEmpty)
        XCTAssertEqual(cell.contentView.subviews.compactMap { $0 as? UIButton }.first?.configuration?.title, "标签 1")
        XCTAssertTrue(bar.bounds.height.isFinite)
        source.invalidIndex = nil
        bar.reloadContent()
        resize(bar, width: 320)
        XCTAssertNotNil(view(bar, index: 1))
    }

    func testReloadAndEnvironmentUpdateAutomaticHeightAndMeasurementState() {
        let source = AutomaticTabSource()
        let bar = mount(source)
        let oldHeight = bar.bounds.height
        source.text = String(repeating: "异步内容更新后的多行文字。", count: 10)
        bar.reloadContent()
        resize(bar, width: 220)
        XCTAssertGreaterThan(bar.bounds.height, oldHeight)
        let host = window.rootViewController!
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        child.view.addSubview(bar)
        bar.semanticContentAttribute = .forceRightToLeft
        host.setOverrideTraitCollection(
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            forChild: child
        )
        child.view.layoutIfNeeded()
        resize(bar, width: 220)
        let selected = source.samples.last { $0.index == 0 && $0.horizontal == .required }!
        XCTAssertTrue(selected.selected)
        XCTAssertEqual(selected.direction, .rightToLeft)
        XCTAssertEqual(selected.category, .accessibilityExtraExtraExtraLarge)
        XCTAssertEqual(selected.vertical, .fittingSizeLevel)
        bar.items[0].isEnabled = false
        resize(bar, width: 220)
        XCTAssertTrue(source.samples.last { $0.index == 0 }!.disabled)
        XCTAssertTrue(view(bar).value.disabled)
    }

    func testAutomaticReloadAndCandidateMeasurementPreserveScrollAndAnimation() {
        for rtl in [false, true] {
            let source = AutomaticTabSource()
            source.text = "自动布局标签内容"
            let bar = mount(source, count: 10)
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            bar.setNeedsLayout()
            bar.layoutIfNeeded()
            let list = collection(bar)
            list.contentOffset.x = 130
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(list.contentOffset.x, 130, accuracy: 0.01)
            bar.setSelectedIndex(6, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
            let frame = indicator.frame
            let offset = list.contentOffset
            _ = bar.sizeThatFits(CGSize(width: 100, height: 0))
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator.frame, frame)
            XCTAssertEqual(list.contentOffset, offset)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertNotEqual(indicator.frame, frame)
            bar.setTransitionProgress(from: 6, to: 5, progress: 0.4)
            let pagingFrame = indicator.frame
            let pagingOffset = list.contentOffset
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator.frame, pagingFrame)
            XCTAssertEqual(list.contentOffset, pagingOffset)
        }
    }
}

@MainActor
final class AutomaticTabSource: SPTabBarContentDelegate {
    struct Sample {
        let index: Int
        let target: CGSize
        let horizontal: UILayoutPriority
        let vertical: UILayoutPriority
        let selected: Bool
        let disabled: Bool
        let direction: UIUserInterfaceLayoutDirection
        let category: UIContentSizeCategory
    }

    var text = "自动标签"
    var fixedFirst: CGSize?
    var invalidIndex: Int?
    var creations = 0
    var samples: [Sample] = []
    let views = NSHashTable<UIView>.weakObjects()
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        let configuration = AutoLayoutTabConfiguration(
            text: text,
            font: .preferredFont(forTextStyle: .body, compatibleWith: context.state.traitCollection),
            index: index,
            invalid: index == invalidIndex,
            source: self
        )
        var result = SPTabBarContent(configuration: configuration)
        if index == 0 {
            result.size = fixedFirst
        }
        return result
    }
}

private struct AutoLayoutTabConfiguration: UIContentConfiguration {
    let text: String
    let font: UIFont
    let index: Int
    let invalid: Bool
    weak var source: AutomaticTabSource?
    var selected = false
    var disabled = false
    func makeContentView() -> UIView & UIContentView {
        source?.creations += 1
        let view = AutoLayoutTabView(value: self)
        source?.views.add(view)
        return view
    }

    func updated(for state: UIConfigurationState) -> Self {
        var value = self
        if let state = state as? UICellConfigurationState {
            value.selected = state.isSelected
            value.disabled = state.isDisabled
        }
        return value
    }
}

@MainActor
private final class AutoLayoutTabView: UIView, UIContentView {
    let label = UILabel()
    var value: AutoLayoutTabConfiguration
    var configuration: any UIContentConfiguration {
        get { value }
        set {
            guard let value = newValue as? AutoLayoutTabConfiguration else {
                return
            }
            self.value = value
            apply()
        }
    }

    init(value: AutoLayoutTabConfiguration) {
        self.value = value
        super.init(frame: .zero)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        apply()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func apply() {
        label.text = value.text
        label.font = value.font
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        value.source?.samples.append(.init(
            index: value.index,
            target: targetSize,
            horizontal: horizontalFittingPriority,
            vertical: verticalFittingPriority,
            selected: value.selected,
            disabled: value.disabled,
            direction: effectiveUserInterfaceLayoutDirection,
            category: traitCollection.preferredContentSizeCategory
        ))
        if value.invalid {
            return .zero
        }
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
}

@MainActor
final class StaticAutomaticSource: SPTabBarContentDelegate {
    var configuration: any UIContentConfiguration
    var explicitSize: CGSize?
    var fallbackIndex: Int?
    init(configuration: any UIContentConfiguration) {
        self.configuration = configuration
    }

    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        guard index != fallbackIndex else {
            return nil
        }
        var content = SPTabBarContent(configuration: configuration)
        content.size = explicitSize
        return content
    }
}

struct IntrinsicTabConfiguration: UIContentConfiguration {
    var size = CGSize(width: 120, height: 64)
    func makeContentView() -> UIView & UIContentView {
        let view = IntrinsicTabView()
        view.configuration = self
        return view
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

@MainActor
private final class IntrinsicTabView: UIView, UIContentView {
    var configuration: any UIContentConfiguration = IntrinsicTabConfiguration()
    override var intrinsicContentSize: CGSize {
        (configuration as! IntrinsicTabConfiguration).size
    }
}

@MainActor
private final class WidthPolicySource: SPTabBarContentDelegate {
    var widths: [CGFloat] = [160, 44]
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        SPTabBarContent(configuration: IntrinsicTabConfiguration(), size: CGSize(width: widths[index], height: 28))
    }
}

private struct RequiredWidthConfiguration: UIContentConfiguration {
    func makeContentView() -> UIView & UIContentView {
        RequiredWidthView()
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

@MainActor
private final class RequiredWidthView: UIView, UIContentView {
    var configuration: any UIContentConfiguration = RequiredWidthConfiguration()
    override var intrinsicContentSize: CGSize {
        CGSize(width: 120, height: 28)
    }

    init() {
        super.init(frame: .zero)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
