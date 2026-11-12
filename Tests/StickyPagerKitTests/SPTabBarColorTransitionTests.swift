import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarColorTransitionTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window = nil
    }

    private func mount(rtl: Bool = false) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 70))
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "频道 \($0)", image: UIImage(systemName: "star")) }
        bar.standardAppearance.itemAppearance.normal.titleColor = .red
        bar.standardAppearance.itemAppearance.selected.titleColor = .blue
        bar.standardAppearance.itemAppearance.normal.iconColor = .red
        bar.standardAppearance.itemAppearance.selected.iconColor = .blue
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func button(_ bar: SPTabBar, _ index: Int) throws -> UIButton {
        let list = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: index, section: 0)))
        let root = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" }
            ?? cell.contentView
        return try XCTUnwrap(root.subviews.compactMap { $0 as? UIButton }.first)
    }

    private func title(_ button: UIButton) throws -> UIColor {
        let config = try XCTUnwrap(button.configuration)
        return try XCTUnwrap(config.titleTextAttributesTransformer?(AttributeContainer()).foregroundColor)
    }

    private func assertColor(
        _ actual: UIColor?,
        _ expected: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("缺少颜色", file: file, line: line); return
        }
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        XCTAssertTrue(actual.getRed(&ar, green: &ag, blue: &ab, alpha: &aa), file: file, line: line)
        XCTAssertTrue(expected.getRed(&br, green: &bg, blue: &bb, alpha: &ba), file: file, line: line)
        let a = [ar, ag, ab, aa], b = [br, bg, bb, ba]
        for i in 0 ..< 4 {
            XCTAssertEqual(a[i], b[i], accuracy: 0.002, file: file, line: line)
        }
    }

    func testSpringScaleKeepsDefaultColorsBoundedAndVisualStyleChangesSettle() throws {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            bar.visualStyle = .scale
            bar.visualStyle.interpolatesDefaultColors = true
            bar.selectionAnimationStyle = .spring
            bar.setSelectedIndex(1, animated: true)
            let target = try button(bar, 1)
            let image = target.configuration?.image
            let stats = bar.refreshStatistics
            bar.advanceSelectionAnimation(to: 0.25)
            assertColor(try title(target), UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1))
            bar.advanceSelectionAnimation(to: 0.45)
            XCTAssertGreaterThan(try XCTUnwrap(target.superview).transform.a, 1)
            let color = UIColor(red: 0.028, green: 0, blue: 0.972, alpha: 1)
            assertColor(try title(target), color)
            assertColor(target.configuration?.baseForegroundColor, color)
            XCTAssertTrue(target.configuration?.image === image)
            XCTAssertEqual(bar.refreshStatistics, stats)
            bar.visualStyle = .standard
            bar.layoutIfNeeded()
            assertColor(try title(button(bar, 1)), .blue)
            assertColor(try title(button(bar, 0)), .red)
            XCTAssertEqual(target.superview?.transform, .identity)
            bar.advanceSelectionAnimation(to: 0.7)
            assertColor(try title(button(bar, 1)), .blue)
            // 分页中的样式切换保留当前手指进度，不使用已取消的弹簧状态。
            bar.setTransitionProgress(from: 1, to: 0, progress: 0.25)
            bar.visualStyle = .scale
            bar.visualStyle.interpolatesDefaultColors = true
            assertColor(try title(button(bar, 0)), UIColor(red: 0.75, green: 0, blue: 0.25, alpha: 1))
            XCTAssertEqual(try XCTUnwrap(button(bar, 0).superview).transform.a, 0.955, accuracy: 0.0001)
            bar.setSelectedIndex(1, animated: false)
            assertColor(try title(button(bar, 0)), .red)
            bar.removeFromSuperview()
        }
    }

    func testDefaultRemainsDiscreteAndOptInCrossesMidpointContinuously() throws {
        for rtl in [false, true] {
            let bar = mount(rtl: rtl)
            bar.setTransitionProgress(from: 0, to: 1, progress: 0.49)
            assertColor(try title(button(bar, 1)), .red)
            bar.visualStyle = .colorTransition
            for p: CGFloat in [0.25, 0.49, 0.51, 0.75] {
                bar.setTransitionProgress(from: 0, to: 1, progress: p)
                let target = try button(bar, 1)
                let color = UIColor(red: 1 - p, green: 0, blue: p, alpha: 1)
                assertColor(try title(target), color)
                assertColor(target.configuration?.baseForegroundColor, color)
                target.layoutIfNeeded()
                assertColor(target.titleLabel?.textColor, color)
                XCTAssertEqual(bar.selectedIndex, 0)
                XCTAssertFalse(target.accessibilityTraits.contains(.selected))
            }
            bar.setSelectedIndex(0, animated: false)
            assertColor(try title(button(bar, 1)), .red)
            bar.removeFromSuperview()
        }
    }

    func testFramesReuseImageAndDoNotRequestOrMeasureContent() throws {
        let bar = mount()
        bar.visualStyle = .colorTransition
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.1)
        let target = try button(bar, 1), image = target.configuration?.image, frame = target.frame
        let stats = bar.refreshStatistics
        for p: CGFloat in [0.2, 0.3, 0.4] {
            bar.setTransitionProgress(from: 0, to: 1, progress: p)
            XCTAssertTrue(target.configuration?.image === image)
            XCTAssertEqual(target.frame, frame)
        }
        XCTAssertEqual(bar.refreshStatistics, stats)
        target.isHighlighted = true
        target.isHighlighted = false
        target.updateConfiguration()
        target.layoutIfNeeded()
        assertColor(try title(target), UIColor(red: 0.6, green: 0, blue: 0.4, alpha: 1))
    }

    func testContentOnlyAnimationRetargetingAndPagingTakeover() throws {
        let bar = mount()
        bar.indicatorStyle = .none
        bar.visualStyle = .colorTransition
        bar.setSelectedIndex(2, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let middle = try title(button(bar, 2))
        assertColor(middle, UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1))
        bar.setSelectedIndex(1, animated: true)
        assertColor(try title(button(bar, 2)), middle)
        bar.advanceSelectionAnimation(to: 0.5)
        let before = try title(button(bar, 1))
        bar.setTransitionProgress(from: 1, to: 0, progress: 0)
        assertColor(try title(button(bar, 1)), before)
        bar.advanceSelectionAnimation(to: 1)
        assertColor(try title(button(bar, 1)), before)
        bar.setSelectedIndex(1, animated: false)
        assertColor(try title(button(bar, 1)), .blue)
        bar.visualStyle = .standard
        assertColor(try title(button(bar, 0)), .red)
    }

    func testExplicitTitleAttributesDisabledAndOriginalImage() throws {
        let bar = mount()
        bar.items[1].setTitleTextAttributes([.foregroundColor: UIColor.green], for: .normal)
        bar.items[1].setTitleTextAttributes([.foregroundColor: UIColor.blue], for: .selected)
        bar.items[1].image = UIImage(systemName: "star")!.withRenderingMode(.alwaysOriginal)
        bar.visualStyle = .colorTransition
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
        let target = try button(bar, 1)
        assertColor(try title(target), UIColor(red: 0, green: 0.75, blue: 0.25, alpha: 1))
        XCTAssertEqual(target.configuration?.image?.renderingMode, .alwaysOriginal)
        assertColor(target.configuration?.baseForegroundColor, .red)
        bar.standardAppearance.itemAppearance.disabled.titleColor = .orange
        bar.items[1].isEnabled = false
        bar.layoutIfNeeded()
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.8)
        assertColor(try title(button(bar, 1)), .green) // 普通标题属性优先于禁用 Appearance。
        bar.items[1].setTitleTextAttributes([.foregroundColor: UIColor.orange], for: .disabled)
        bar.layoutIfNeeded()
        assertColor(try title(button(bar, 1)), .orange)
        XCTAssertFalse(try button(bar, 1).isEnabled)
    }

    func testTintAndDynamicTraitsRefreshEndpointsWithoutLosingProgress() throws {
        let bar = mount()
        bar.overrideUserInterfaceStyle = .light
        bar.standardAppearance.itemAppearance.normal.titleColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .green : .red
        }
        bar.standardAppearance.itemAppearance.selected.titleColor = nil
        bar.tintColor = .blue
        bar.visualStyle = .colorTransition
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
        assertColor(try title(button(bar, 1)), UIColor(red: 0.75, green: 0, blue: 0.25, alpha: 1))
        bar.tintColor = .red
        assertColor(try title(button(bar, 1)), .red)
        bar.overrideUserInterfaceStyle = .dark
        if #available(iOS 17, *) {
            bar.updateTraitsIfNeeded()
        }
        bar.layoutIfNeeded()
        assertColor(try title(button(bar, 1)), UIColor(red: 0.25, green: 0.75, blue: 0, alpha: 1))
        XCTAssertEqual(bar.selectedIndex, 0)
    }

    func testCustomFallbackReorderAndStyleResetKeepCorrectColors() throws {
        let bar = mount()
        let source = ColorContentSource()
        bar.contentDelegate = source
        bar.contentStyle = .custom
        bar.visualStyle = .colorTransition
        bar.layoutIfNeeded()
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.25)
        assertColor(try title(button(bar, 1)), UIColor(red: 0.75, green: 0, blue: 0.25, alpha: 1))
        let calls = source.calls
        bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        XCTAssertEqual(source.calls, calls)
        let selected = bar.items[0]
        bar.items = Array(bar.items.reversed())
        bar.layoutIfNeeded()
        XCTAssertTrue(bar.selectedItem === selected)
        XCTAssertEqual(bar.selectedIndex, 2)
        assertColor(try title(button(bar, 1)), .red)
        bar.contentStyle = .standard
        bar.visualStyle = .standard
        bar.layoutIfNeeded()
        assertColor(try title(button(bar, 2)), .blue)
        assertColor(try title(button(bar, 1)), .red)
        withExtendedLifetime(source) {}
    }

    func testColorInterpolationPreservesAllChannelsAndClampsInvalidProgress() throws {
        let from = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.2)
        let to = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        let pair = SPTabColorTransition(from: from, to: to, traits: UITraitCollection(userInterfaceStyle: .light))
        assertColor(try XCTUnwrap(pair.color(at: 0.25)), UIColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 0.4))
        XCTAssertEqual(pair.color(at: -1), from)
        XCTAssertEqual(pair.color(at: 2), to)
        XCTAssertEqual(pair.color(at: .nan), from)
        XCTAssertEqual(pair.color(at: .infinity), from)
    }

    func testColorConversionPreservesEndpointsAndRejectsPattern() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        let wide = UIColor(displayP3Red: 0.8, green: 0.2, blue: 0.3, alpha: 0.4)
        let pair = SPTabColorTransition(from: .red, to: wide, traits: traits)
        XCTAssertEqual(pair.color(at: 0), .red)
        XCTAssertEqual(pair.color(at: 1), wide)
        XCTAssertNotNil(pair.color(at: 0.5))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in
            UIColor.red.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let pattern = SPTabColorTransition(from: UIColor(patternImage: image), to: .blue, traits: traits)
        XCTAssertNil(pattern.color(at: 0.5))
    }
}

@MainActor
private final class ColorContentSource: SPTabBarContentDelegate {
    var calls = 0
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        calls += 1
        guard item.title == "频道 0" else {
            return nil
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        configuration.textProperties.color = .purple
        return SPTabBarContent(configuration: configuration, size: CGSize(width: 100, height: 50))
    }
}
