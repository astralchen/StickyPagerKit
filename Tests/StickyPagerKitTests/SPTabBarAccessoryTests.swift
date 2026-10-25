import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarAccessoryTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.closeForTesting()
        window?.rootViewController = nil
        window = nil
    }

    private func mount(count: Int = 8, rtl: Bool = false) -> (SPTabBar, UICollectionView) {
        window?.closeForTesting()
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = UIViewController()
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 400, height: 60))
        // 此夹具显式验证 automatic 分配；频道型默认组合由专门用例覆盖。
        bar.layoutConfiguration.itemSizing = .balanced
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        window.rootViewController!.view.addSubview(bar)
        bar.items = (0 ..< count).map { SPTabBarItem(title: "频道 \($0)") }
        bar.layoutConfiguration.minimumItemWidth = 100
        bar.setSelectedIndex(count > 0 ? 0 : nil, animated: false)
        bar.layoutIfNeeded()
        return (bar, bar.subviews.compactMap { $0 as? UICollectionView }.first!)
    }

    private func fixed(_ width: CGFloat = 44, _ height: CGFloat = 44) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("更多", for: .normal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
        return button
    }

    private func frame(_ index: Int, _ list: UICollectionView) -> CGRect {
        list.layoutIfNeeded()
        return list.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    func testDefaultInsetsScrollThroughViewportEdgesAndAllowZeroOverride() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            window.rootViewController!.view.layoutIfNeeded()
            for (sizing, alignment): (
                SPTabBarLayoutConfiguration.ItemSizing,
                SPTabBarLayoutConfiguration.Alignment
            ) in [
                (.balanced, .leading),
                (.equal, .leading),
                (.content, .center),
                (.content, .leading)
            ] {
                var layout = bar.layoutConfiguration
                layout.itemSizing = sizing
                layout.alignment = alignment
                bar.layoutConfiguration = layout
                bar.layoutIfNeeded()
                XCTAssertEqual(list.frame.minX, 20, accuracy: 0.01)
                XCTAssertEqual(list.frame.maxX, 370, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width, 832, accuracy: 0.01)
                let left = frame(rtl ? 7 : 0, list)
                let right = frame(rtl ? 0 : 7, list)
                XCTAssertEqual(left.minX, 16, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width - right.maxX, 16, accuracy: 0.01)
                XCTAssertEqual(left.minY, 0)
                XCTAssertEqual(left.height, list.bounds.height)
                list.contentOffset.x = 0
                XCTAssertNil(list.indexPathForItem(at: CGPoint(x: 8, y: 30)))
                list.contentOffset.x = 24
                XCTAssertLessThan(list.convert(left, to: bar).minX, list.frame.minX)
                XCTAssertNotNil(list.indexPathForItem(at: CGPoint(x: list.bounds.minX + 8, y: 30)))
                list.contentOffset.x = list.contentSize.width - list.bounds.width
                XCTAssertEqual(list.frame.maxX - list.convert(right, to: bar).maxX, 16, accuracy: 0.01)
                XCTAssertEqual(bar.selectedIndex, 0)
            }
            bar.layoutConfiguration.contentInsets = .zero
            bar.layoutIfNeeded()
            XCTAssertEqual(frame(rtl ? 7 : 0, list).minX, 0, accuracy: 0.01)
            XCTAssertEqual(list.contentSize.width, 800, accuracy: 0.01)
            XCTAssertEqual(bar.selectedIndex, 0)
        }
    }

    func testDefaultInsetsWithSingleAndEmptyItemsAcrossResize() {
        for rtl in [false, true] {
            let (bar, list) = mount(count: 1, rtl: rtl)
            for width: CGFloat in [400, 240, 400] {
                bar.frame.size.width = width
                bar.layoutIfNeeded()
                XCTAssertEqual(frame(0, list).minX, 16, accuracy: 0.01)
                XCTAssertEqual(frame(0, list).width, width - 32, accuracy: 0.01)
                XCTAssertEqual(list.contentSize.width, width, accuracy: 0.01)
                XCTAssertNil(list.layer.mask)
            }
            bar.items = []
            bar.layoutIfNeeded()
            XCTAssertEqual(list.contentSize.width, list.bounds.width)
            XCTAssertEqual(list.contentOffset.x, 0)
            XCTAssertNil(list.layer.mask)
        }
    }

    func testInitialRTLConfigurationKeepsSelectedFirstItemVisible() {
        _ = mount()
        let bar = SPTabBar()
        bar.semanticContentAttribute = .forceRightToLeft
        bar.items = (0 ..< 12).map { SPTabBarItem(title: "频道 \($0)") }
        bar.selectedItem = bar.items[0]
        window.rootViewController!.view.addSubview(bar)
        bar.leadingAccessoryView = fixed()
        bar.trailingAccessoryView = fixed()
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        bar.frame = CGRect(x: 0, y: 200, width: 400, height: 70)
        bar.layoutIfNeeded()
        let list = bar.subviews.compactMap { $0 as? UICollectionView }.first!
        XCTAssertEqual(list.contentOffset.x, list.contentSize.width - list.bounds.width, accuracy: 0.01)
        XCTAssertTrue(list.bounds.intersects(frame(0, list)))
    }

    func testInsetsScrollWithContentAndDoNotShrinkViewport() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                top: 6,
                leading: 16,
                bottom: 8,
                trailing: 32
            )
            bar.layoutConfiguration.itemSpacing = 10
            bar.layoutIfNeeded()
            XCTAssertEqual(list.frame, bar.bounds)
            XCTAssertEqual(list.contentSize.width, 918, accuracy: 0.01)
            let first = frame(rtl ? 7 : 0, list)
            XCTAssertEqual(first.minX, rtl ? 32 : 16, accuracy: 0.01)
            XCTAssertEqual(first.minY, 6, accuracy: 0.01)
            XCTAssertEqual(first.height, 46, accuracy: 0.01)
            XCTAssertNil(list.indexPathForItem(at: CGPoint(x: 5, y: 30)))
            list.contentOffset.x = 100
            XCTAssertLessThan(list.convert(first, to: bar).minX, 0)
            XCTAssertNotNil(list.layer.mask)
            XCTAssertGreaterThanOrEqual(bar.sizeThatFits(bar.bounds.size).height, 58)
        }
    }

    func testBalancedSingleEmptyAndNormalization() {
        let (bar, list) = mount(count: 1)
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: -1,
            leading: 16,
            bottom: .nan,
            trailing: 24
        )
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.layoutConfiguration.contentInsets.top, 0)
        XCTAssertEqual(bar.layoutConfiguration.contentInsets.bottom, 0)
        XCTAssertEqual(frame(0, list).width, 360, accuracy: 0.01)
        XCTAssertEqual(list.contentSize.width, 400)
        bar.items = []
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: .infinity,
            leading: 2_000_000,
            bottom: 0,
            trailing: 24
        )
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.layoutConfiguration.contentInsets.leading, 1_000_000)
        XCTAssertEqual(list.contentSize.width, list.bounds.width)
        XCTAssertNil(list.layer.mask)
    }

    func testAttachmentsShareSafeAreaMirrorAndHitIndependently() {
        for rtl in [false, true] {
            let (bar, list) = mount(rtl: rtl)
            let leading = fixed(44), trailing = fixed(60)
            window.rootViewController!.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 30)
            window.rootViewController!.view.layoutIfNeeded()
            bar.leadingAccessoryView = leading
            bar.trailingAccessoryView = trailing
            bar.layoutIfNeeded()
            XCTAssertEqual(list.frame.width, 246, accuracy: 0.01)
            XCTAssertEqual(list.frame.minX, rtl ? 80 : 64, accuracy: 0.01)
            let a = leading.convert(leading.bounds, to: bar)
            let b = trailing.convert(trailing.bounds, to: bar)
            XCTAssertEqual(a.minX, rtl ? 326 : 20, accuracy: 0.01)
            XCTAssertEqual(b.minX, rtl ? 20 : 310, accuracy: 0.01)
            XCTAssertTrue(bar.hitTest(CGPoint(x: a.midX, y: a.midY), with: nil) === leading)
            XCTAssertFalse(bar.point(inside: CGPoint(x: 5, y: 30), with: nil))
            list.contentOffset.x = 140
            XCTAssertEqual(leading.convert(leading.bounds, to: bar), a)
            XCTAssertNil(leading.layer.mask)
            XCTAssertEqual(bar.selectedIndex, 0)
        }
    }

    func testSizingInvalidHiddenReplacementAndDuplicateAssignment() {
        let (bar, list) = mount()
        let original = fixed(70, 90)
        bar.leadingAccessoryView = original
        bar.trailingAccessoryView = original
        XCTAssertNil(bar.trailingAccessoryView)
        bar.layoutIfNeeded()
        XCTAssertEqual(list.frame.width, 330)
        XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, 90)
        original.isHidden = true
        bar.invalidateAccessoryLayout()
        bar.layoutIfNeeded()
        XCTAssertEqual(list.frame.width, 400)
        original.isHidden = false
        bar.invalidateAccessoryLayout()
        bar.layoutIfNeeded()
        XCTAssertEqual(list.frame.width, 330)
        bar.leadingAccessoryView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        bar.layoutIfNeeded()
        XCTAssertNil(original.superview)
        XCTAssertTrue(original.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(list.frame.width, 400, "无约束 UIView 不从 frame 推断附件尺寸")
        let label = UILabel()
        label.text = "搜索频道"
        bar.leadingAccessoryView = label
        bar.layoutIfNeeded()
        XCTAssertEqual(list.frame.width, 400 - label.intrinsicContentSize.width, accuracy: 0.01)
        bar.leadingAccessoryView = nil
        bar.layoutIfNeeded()
        XCTAssertEqual(list.frame.width, 400)
    }

    func testConfiguredButtonHonorsMinimumSizeAndDynamicConstraintChanges() {
        let (bar, list) = mount()
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "line.3.horizontal")
        let button = UIButton(configuration: configuration)
        let height = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        NSLayoutConstraint.activate([button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44), height])
        bar.trailingAccessoryView = button
        for value: CGFloat in [44, 80, 44] {
            height.constant = value
            bar.invalidateAccessoryLayout()
            bar.frame.size.height = bar.sizeThatFits(bar.bounds.size).height
            bar.layoutIfNeeded()
            XCTAssertGreaterThanOrEqual(button.bounds.height, value)
            XCTAssertGreaterThanOrEqual(bar.bounds.height, value)
            XCTAssertLessThanOrEqual(list.frame.maxX, button.superview!.frame.minX)
        }
    }

    func testRetainedAccessoryRestoresAutoresizingAndRemovesMeasurementConstraintsOnRelease() {
        let button = fixed()
        autoreleasepool {
            let bar = SPTabBar()
            bar.trailingAccessoryView = button
            XCTAssertFalse(button.translatesAutoresizingMaskIntoConstraints)
            XCTAssertTrue(button.constraints.contains { $0.priority.rawValue == 1 })
        }
        XCTAssertNil(button.superview)
        XCTAssertTrue(button.translatesAutoresizingMaskIntoConstraints)
        XCTAssertFalse(button.constraints.contains { $0.priority.rawValue == 1 })
        XCTAssertEqual(button.constraints.filter { $0.isActive && $0.priority == .required }.count, 2)
    }

    func testInternalConstraintsAndNarrowClippingRecoverWithoutChangingIdealSize() {
        let (bar, list) = mount()
        let container = UIView()
        let label = UILabel()
        label.text = "分类"
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        bar.leadingAccessoryView = container
        bar.layoutIfNeeded()
        XCTAssertEqual(container.bounds.width, label.intrinsicContentSize.width + 24, accuracy: 0.01)
        let leading = fixed(80, 70), trailing = fixed(120, 80)
        bar.leadingAccessoryView = leading
        bar.trailingAccessoryView = trailing
        bar.frame.size = CGSize(width: 100, height: 30)
        bar.layoutIfNeeded()
        XCTAssertEqual(leading.superview!.frame.width, 40, accuracy: 0.01)
        XCTAssertEqual(trailing.superview!.frame.width, 60, accuracy: 0.01)
        XCTAssertEqual(leading.bounds.width, 80)
        XCTAssertEqual(trailing.bounds.width, 120)
        XCTAssertEqual(list.bounds.width, 0, accuracy: 0.01)
        XCTAssertNil(list.layer.mask)
        XCTAssertNil(bar.hitTest(CGPoint(x: 50, y: -1), with: nil))
        bar.frame.size = CGSize(width: 400, height: 90)
        bar.layoutIfNeeded()
        XCTAssertEqual(list.bounds.width, 200)
        XCTAssertEqual(leading.superview!.frame.width, 80)
        XCTAssertEqual(trailing.superview!.frame.width, 120)
        XCTAssertEqual(leading.frame.midY, 45)
    }

    func testRefreshPreservesOffsetProgressAndCandidateMeasurementIsPure() {
        let (bar, list) = mount()
        // 使用胶囊验证附件／留白更新后的 Item 几何插值。
        bar.indicatorStyle = .capsule
        let button = fixed(44)
        bar.trailingAccessoryView = button
        bar.layoutIfNeeded()
        list.contentOffset.x = 140
        let oldFrame = button.frame
        let oldHost = button.superview!.frame
        for width: CGFloat in [180, 900, 40, 400] {
            _ = bar.sizeThatFits(CGSize(width: width, height: 0))
        }
        XCTAssertEqual(button.frame, oldFrame)
        XCTAssertEqual(button.superview!.frame, oldHost)
        XCTAssertEqual(list.contentOffset.x, 140)
        bar.leadingAccessoryView = fixed(60)
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentOffset.x, 140, accuracy: 0.01)
        bar.setTransitionProgress(from: 2, to: 3, progress: 0.4)
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 30, bottom: 8, trailing: 10)
        bar.layoutIfNeeded()
        let a = frame(2, list), b = frame(3, list)
        let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
        XCTAssertEqual(indicator.frame.midX, a.midX + (b.midX - a.midX) * 0.4, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.minY, 9, accuracy: 0.01)
        let maximum = list.contentSize.width - list.bounds.width
        let from = min(maximum, max(0, a.midX - list.bounds.width / 2))
        let to = min(maximum, max(0, b.midX - list.bounds.width / 2))
        XCTAssertEqual(list.contentOffset.x, from + (to - from) * 0.4, accuracy: 0.01)
        XCTAssertEqual(bar.selectedIndex, 0)
    }

    func testUnchangedRefreshKeepsAnimationAndChangedInsetsSettleIt() {
        let (bar, list) = mount()
        bar.trailingAccessoryView = fixed()
        bar.layoutIfNeeded()
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.4)
        let midway = list.contentOffset
        bar.invalidateAccessoryLayout()
        bar.layoutIfNeeded()
        XCTAssertEqual(list.contentOffset, midway)
        bar.advanceSelectionAnimation(to: 0.8)
        XCTAssertGreaterThan(list.contentOffset.x, midway.x)
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        bar.layoutIfNeeded()
        let settled = list.contentOffset
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(list.contentOffset, settled)
        XCTAssertEqual(bar.selectedIndex, 7)
    }

    func testCandidateMeasurementsPreserveSelectionAnimationAndAccessoryConstraints() {
        let (bar, list) = mount()
        let button = fixed(60, 50)
        bar.trailingAccessoryView = button
        bar.layoutIfNeeded()
        bar.setSelectedIndex(7, animated: true)
        bar.advanceSelectionAnimation(to: 0.3)
        let offset = list.contentOffset
        let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
        let indicatorFrame = indicator.frame
        let buttonFrame = button.frame
        let hostFrame = button.superview!.frame
        let constraints = button.constraints.filter { $0.isActive }
        for width: CGFloat in [40, 900, 180, 400] {
            _ = bar.sizeThatFits(CGSize(width: width, height: 0))
            XCTAssertEqual(list.contentOffset, offset)
            XCTAssertEqual(indicator.frame, indicatorFrame)
            XCTAssertEqual(button.frame, buttonFrame)
            XCTAssertEqual(button.superview!.frame, hostFrame)
            XCTAssertEqual(button.constraints.filter { $0.isActive }, constraints)
        }
        bar.advanceSelectionAnimation(to: 0.7)
        XCTAssertGreaterThan(list.contentOffset.x, offset.x)
        XCTAssertGreaterThan(indicator.frame.midX, indicatorFrame.midX)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(bar.selectedIndex, 7)
        XCTAssertEqual(list.contentOffset.x, list.contentSize.width - list.bounds.width, accuracy: 0.01)
    }

    func testZeroAndOversizedAccessoriesRecoverWithoutLosingBusinessConstraints() {
        let (bar, list) = mount()
        let accessory = UIView()
        let width = accessory.widthAnchor.constraint(equalToConstant: 60)
        let height = accessory.heightAnchor.constraint(equalToConstant: 44)
        NSLayoutConstraint.activate([width, height])
        bar.leadingAccessoryView = accessory
        for size in [
            CGSize(width: 0, height: 44),
            CGSize(width: 60, height: 0),
            CGSize(width: 1_000_001, height: 44),
            CGSize(width: 60, height: 1_000_001),
            CGSize(width: 60, height: 44)
        ] {
            width.constant = size.width
            height.constant = size.height
            bar.invalidateAccessoryLayout()
            bar.layoutIfNeeded()
            let valid = size.width > 0 && size.height > 0 && size.width <= 1_000_000 && size.height <= 1_000_000
            XCTAssertEqual(list.bounds.width, valid ? 340 : 400, accuracy: 0.01)
            XCTAssertEqual(accessory.superview!.isHidden, !valid)
            XCTAssertTrue(width.isActive)
            XCTAssertTrue(height.isActive)
            XCTAssertEqual(width.constant, size.width)
            XCTAssertEqual(height.constant, size.height)
        }
        bar.leadingAccessoryView = nil
        XCTAssertNil(accessory.superview)
        XCTAssertTrue(width.isActive)
        XCTAssertTrue(height.isActive)
        XCTAssertTrue(accessory.translatesAutoresizingMaskIntoConstraints)
    }

    func testAutomaticCustomContentUsesReducedWidthAndReflowsHeight() {
        let (bar, list) = mount(count: 2)
        let source = AutomaticTabSource()
        source.text = String(repeating: "自动换行内容", count: 12)
        bar.layoutConfiguration.minimumItemWidth = 0
        bar.contentDelegate = source
        bar.contentStyle = .custom
        let originalHeight = bar.sizeThatFits(bar.bounds.size).height
        bar.leadingAccessoryView = fixed(70)
        bar.trailingAccessoryView = fixed(70)
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 24)
        let measured = bar.sizeThatFits(bar.bounds.size)
        XCTAssertGreaterThan(measured.height, originalHeight + 16)
        bar.frame.size.height = measured.height
        bar.layoutIfNeeded()
        XCTAssertEqual(list.bounds.width, 260, accuracy: 0.01)
        XCTAssertEqual(frame(0, list).width, 220, accuracy: 0.01, "长内容保留所需宽度并滚动，不强制均分")
        XCTAssertEqual(frame(0, list).height, measured.height - 16, accuracy: 0.01)
        let current = frame(0, list)
        _ = bar.sizeThatFits(CGSize(width: 900, height: 0))
        XCTAssertEqual(frame(0, list), current)
        for style: SPTabBar.IndicatorStyle in [.capsule, .underline, .custom, .none] {
            bar.indicatorStyle = style
            bar.layoutIfNeeded()
            let indicator = list.subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
            XCTAssertEqual(indicator.isHidden, style == .none)
            if style == .underline {
                XCTAssertEqual(indicator.frame.maxY, current.maxY, accuracy: 0.01)
            }
        }
    }

    func testFadeEndpointsAndInsetRedistributionWithSameTotal() {
        let (bar, list) = mount()
        bar.trailingAccessoryView = fixed()
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 30)
        bar.layoutIfNeeded()
        let old = frame(0, list)
        list.contentOffset.x = 80
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 10)
        bar.layoutIfNeeded()
        XCTAssertEqual(frame(0, list).minX - old.minX, 20)
        XCTAssertEqual(list.contentOffset.x, 80)
        for (offset, firstAlpha, lastAlpha): (CGFloat, CGFloat, CGFloat) in [
            (0, 1, 0),
            (80, 0, 0),
            (list.contentSize.width - list.bounds.width, 0, 1)
        ] {
            list.contentOffset.x = offset
            let mask = list.layer.mask as! CAGradientLayer
            let colors = mask.colors as! [CGColor]
            XCTAssertEqual(colors.first!.alpha, firstAlpha, accuracy: 0.01)
            XCTAssertEqual(colors.last!.alpha, lastAlpha, accuracy: 0.01)
        }
    }
}
