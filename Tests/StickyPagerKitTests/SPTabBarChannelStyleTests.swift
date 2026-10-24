import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarChannelStyleTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() async throws {
        window?.closeForTesting()
        window?.rootViewController = nil
        window = nil
    }

    private func mount(rtl: Bool = false, width: CGFloat = 400) -> (SPTabBar, UICollectionView, UIView) {
        window?.closeForTesting()
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        window.rootViewController = UIViewController()
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: width, height: 60))
        window.rootViewController!.view.addSubview(bar)
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.items = ["推荐", "关注", "热点资讯"].map { SPTabBarItem(title: $0) }
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

    private func button(_ index: Int, _ collection: UICollectionView) throws -> UIButton {
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
        cell.layoutIfNeeded()
        let button = try XCTUnwrap(cell.contentView.subviews.compactMap { $0 as? UIButton }.first)
        button.layoutIfNeeded()
        return button
    }

    private func titleFrame(_ index: Int, _ collection: UICollectionView) throws -> CGRect {
        let title = try XCTUnwrap(try button(index, collection).titleLabel)
        return title.convert(title.bounds, to: collection)
    }

    private func weight(_ font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return (traits?[.weight] as? NSNumber)?.doubleValue ?? 0
    }

    func testDefaultsKeepNaturalWidthsAndLeadingPaddingInBothDirections() {
        for rtl in [false, true] {
            let (bar, collection, _) = mount(rtl: rtl)
            XCTAssertEqual(bar.itemPositioning, .leading)
            XCTAssertEqual(bar.indicatorStyle, .underline)
            XCTAssertEqual(bar.contentInsets.leading, 16)
            XCTAssertEqual(bar.contentInsets.trailing, 16)
            let before = bar.items.indices.map { frame($0, collection) }
            let first = before[0]
            XCTAssertEqual(
                rtl ? collection.bounds.maxX - first.maxX : first.minX - collection.bounds.minX,
                16,
                accuracy: 0.01
            )
            XCTAssertLessThan(before.reduce(0) { $0 + $1.width }, collection.bounds.width - 32)
            bar.setSelectedIndex(2, animated: false)
            XCTAssertEqual(bar.items.indices.map { frame($0, collection) }, before)
            XCTAssertEqual(bar.selectedIndex, 2)
        }
    }

    func testSelectedTitleIsSemiboldWithoutChangingPointSizeOrItemFrames() throws {
        let (bar, collection, indicator) = mount()
        let selectedFont = try XCTUnwrap(try button(0, collection).titleLabel?.font)
        let normalFont = try XCTUnwrap(try button(1, collection).titleLabel?.font)
        XCTAssertEqual(selectedFont.pointSize, normalFont.pointSize, accuracy: 0.01)
        XCTAssertEqual(weight(selectedFont), UIFont.Weight.semibold.rawValue, accuracy: 0.01)
        XCTAssertLessThan(weight(normalFont), weight(selectedFont))
        let frames = bar.items.indices.map { frame($0, collection) }
        bar.setSelectedIndex(1, animated: false)
        XCTAssertEqual(weight(try XCTUnwrap(try button(0, collection).titleLabel?.font)), weight(normalFont))
        XCTAssertEqual(weight(try XCTUnwrap(try button(1, collection).titleLabel?.font)), weight(selectedFont))
        XCTAssertEqual(bar.items.indices.map { frame($0, collection) }, frames)
        XCTAssertEqual(indicator.frame.width, try titleFrame(1, collection).width, accuracy: 0.01)
    }

    func testUnderlineTracksTitleExcludingImageBadgeAndItemPadding() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            bar.items[0].image = UIImage(systemName: "star.fill")
            bar.items[0].badgeValue = "99+"
            for layout: SPTabBarItemAppearance.Layout in [.stacked, .inline] {
                bar.standardAppearance.itemAppearance.layout = layout
                bar.layoutIfNeeded()
                let title = try titleFrame(0, collection)
                XCTAssertEqual(indicator.frame.minX, title.minX, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.width, title.width, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.maxY, frame(0, collection).maxY, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.height, 3)
                XCTAssertLessThan(indicator.frame.width, frame(0, collection).width)
            }
        }
    }

    func testIconOnlyUnderlineUsesImageAndExplicitLayoutStillOverrides() throws {
        let (bar, collection, indicator) = mount()
        bar.items[0].title = nil
        bar.items[0].image = UIImage(systemName: "star.fill")
        bar.layoutIfNeeded()
        let image = try XCTUnwrap(try button(0, collection).imageView)
        let imageFrame = image.convert(image.bounds, to: collection)
        XCTAssertEqual(indicator.frame.minX, imageFrame.minX, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.width, imageFrame.width, accuracy: 0.01)
        bar.standardAppearance.indicatorLayout = .underline
        XCTAssertEqual(indicator.frame.width, imageFrame.width, accuracy: 0.01)
        bar.standardAppearance.indicatorLayout = .underline(width: .fixed(20))
        XCTAssertEqual(indicator.frame.width, 20)
        XCTAssertEqual(indicator.frame.midX, imageFrame.midX, accuracy: 0.01)
        bar.standardAppearance.indicatorLayout = nil
        XCTAssertEqual(indicator.frame.width, imageFrame.width, accuracy: 0.01)
    }

    func testExplicitSelectedFontsAndItemAttributesRetainPriority() throws {
        let (bar, collection, _) = mount()
        let selected = UIFont.systemFont(ofSize: 20, weight: .light)
        bar.standardAppearance.itemAppearance.selected.font = selected
        bar.layoutIfNeeded()
        let expected = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: selected,
            compatibleWith: bar.traitCollection
        )
        XCTAssertEqual(try button(0, collection).titleLabel?.font, expected)
        let itemFont = UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        bar.items[0].setTitleTextAttributes([.font: itemFont], for: .selected)
        bar.layoutIfNeeded()
        XCTAssertEqual(
            try button(0, collection).titleLabel?.font,
            UIFontMetrics(forTextStyle: .subheadline).scaledFont(
                for: itemFont,
                compatibleWith: bar.traitCollection
            )
        )
    }

    func testUnderlineRefreshesForDynamicTypeTitleAndViewportChanges() throws {
        let (bar, collection, indicator) = mount()
        let originalWidth = indicator.frame.width
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
        bar.frame.size.height = 100
        child.view.layoutIfNeeded()
        bar.setNeedsLayout()
        bar.layoutIfNeeded()
        XCTAssertGreaterThan(indicator.frame.width, originalWidth)
        XCTAssertEqual(
            weight(try XCTUnwrap(try button(0, collection).titleLabel?.font)),
            UIFont.Weight.semibold.rawValue,
            accuracy: 0.01
        )
        XCTAssertEqual(indicator.frame.width, try titleFrame(0, collection).width, accuracy: 0.01)
        bar.items[0].title = "最新推荐资讯"
        bar.frame.size.width = 600
        bar.layoutIfNeeded()
        let title = try titleFrame(0, collection)
        XCTAssertEqual(indicator.frame.minX, title.minX, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.width, title.width, accuracy: 0.01)
    }

    func testOffscreenSelectionAndPagingInterpolationUseTitleGeometry() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl, width: 240)
            bar.items = (0 ..< 12).map { SPTabBarItem(title: "频道 \($0)") }
            bar.setSelectedIndex(0, animated: false)
            bar.layoutIfNeeded()
            let from = indicator.frame
            bar.setTransitionProgress(from: 0, to: 11, progress: 1)
            let endpoint = indicator.frame
            XCTAssertGreaterThan(endpoint.width, 0)
            bar.setTransitionProgress(from: 0, to: 11, progress: 0.4)
            XCTAssertEqual(indicator.frame.minX, from.minX + (endpoint.minX - from.minX) * 0.4, accuracy: 0.01)
            XCTAssertEqual(indicator.frame.width, from.width + (endpoint.width - from.width) * 0.4, accuracy: 0.01)
            bar.setSelectedIndex(11, animated: false)
            bar.layoutIfNeeded()
            let title = try titleFrame(11, collection)
            XCTAssertEqual(indicator.frame.minX, title.minX, accuracy: 0.01)
            XCTAssertEqual(indicator.frame.width, title.width, accuracy: 0.01)
            let last = frame(11, collection)
            XCTAssertEqual(
                rtl ? last.minX - collection.bounds.minX : collection.bounds.maxX - last.maxX,
                16,
                accuracy: 0.01
            )
        }
    }

    func testCustomContentUnderlineUsesDeclaredHorizontalRegion() {
        let (bar, collection, indicator) = mount()
        let provider = ChannelContentProvider()
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.layoutIfNeeded()
        let item = frame(0, collection)
        XCTAssertEqual(indicator.frame, CGRect(x: item.minX + 20, y: item.maxY - 3, width: 40, height: 3))
        provider.rect = nil
        bar.reloadContent()
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, CGRect(x: item.minX, y: item.maxY - 3, width: item.width, height: 3))
    }

    func testPagingCompletionKeepsSelectedTitleEndpointWithoutSecondAnimation() throws {
        for layout: SPTabBarIndicatorLayout? in [nil, .underline] {
            for rtl in [false, true] {
                let (bar, collection, indicator) = mount(rtl: rtl, width: 600)
                bar.standardAppearance.indicatorLayout = layout
                bar.items = ["Recommended Stories", "Technology and Development"].map { SPTabBarItem(title: $0) }
                bar.setSelectedIndex(0, animated: false)
                let normalWidth = try titleFrame(1, collection).width
                let normalWeight = weight(try XCTUnwrap(try button(1, collection).titleLabel?.font))
                let frames = bar.items.indices.map { frame($0, collection) }
                bar.setTransitionProgress(from: 0, to: 1, progress: 1)
                let endpoint = indicator.frame
                XCTAssertEqual(bar.selectedIndex, 0, "测量目标选中态不能提前提交选择")
                XCTAssertEqual(weight(try XCTUnwrap(try button(1, collection).titleLabel?.font)), normalWeight)
                bar.setSelectedIndex(1, animated: true)
                for progress: CGFloat in [0, 0.5, 1] {
                    bar.advanceSelectionAnimation(to: progress)
                    XCTAssertEqual(indicator.frame, endpoint, "完成后不应再补一段宽度动画")
                }
                XCTAssertGreaterThan(endpoint.width, normalWidth)
                XCTAssertEqual(indicator.frame.width, try titleFrame(1, collection).width, accuracy: 0.01)
                XCTAssertEqual(bar.items.indices.map { frame($0, collection) }, frames)
            }
        }
    }

    func testPagingCancellationRestoresSelectedTitleWithoutChangingSelection() throws {
        for layout: SPTabBarIndicatorLayout? in [nil, .underline] {
            for rtl in [false, true] {
                let (bar, collection, indicator) = mount(rtl: rtl, width: 600)
                bar.standardAppearance.indicatorLayout = layout
                bar.items = ["Recommended Stories", "Technology and Development"].map { SPTabBarItem(title: $0) }
                for source in [0, 1] {
                    let target = 1 - source
                    bar.setSelectedIndex(source, animated: false)
                    let original = indicator.frame
                    let offset = collection.contentOffset
                    let targetFont = try XCTUnwrap(try button(target, collection).titleLabel?.font)
                    bar.setTransitionProgress(from: source, to: target, progress: 0.65)
                    bar.setNeedsLayout()
                    bar.layoutIfNeeded()
                    XCTAssertNotEqual(indicator.frame, original)
                    XCTAssertEqual(bar.selectedIndex, source)
                    XCTAssertEqual(try button(target, collection).titleLabel?.font, targetFont)
                    bar.setTransitionProgress(from: source, to: target, progress: 0)
                    XCTAssertEqual(indicator.frame, original)
                    // 容器取消分页时按非动画路径恢复原选择。
                    bar.setSelectedIndex(source, animated: false)
                    XCTAssertEqual(indicator.frame, original)
                    XCTAssertEqual(collection.contentOffset, offset)
                    XCTAssertEqual(indicator.frame.width, try titleFrame(source, collection).width, accuracy: 0.01)
                }
            }
        }
    }

    func testFixedUnderlineKeepsWidthThroughPagingCompletion() throws {
        for rtl in [false, true] {
            for width: CGFloat in [20, 80] {
                let (bar, collection, indicator) = mount(rtl: rtl, width: 600)
                bar.items = ["I", "Technology and Development"].map { SPTabBarItem(title: $0) }
                bar.standardAppearance.indicatorLayout = .underline(width: .fixed(width))
                for source in [0, 1] {
                    let target = 1 - source
                    bar.setSelectedIndex(target, animated: false)
                    let endpoint = indicator.frame
                    XCTAssertEqual(endpoint.midX, try titleFrame(target, collection).midX, accuracy: 0.01)
                    bar.setSelectedIndex(source, animated: false)
                    let original = indicator.frame
                    let frames = bar.items.indices.map { frame($0, collection) }
                    for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
                        bar.setTransitionProgress(from: source, to: target, progress: progress)
                        XCTAssertEqual(indicator.frame.width, width, accuracy: 0.01)
                        XCTAssertEqual(
                            indicator.frame.midX,
                            original.midX + (endpoint.midX - original.midX) * progress,
                            accuracy: 0.01
                        )
                        XCTAssertEqual(bar.selectedIndex, source)
                    }
                    bar.setSelectedIndex(target, animated: true)
                    for progress: CGFloat in [0, 0.5, 1] {
                        bar.advanceSelectionAnimation(to: progress)
                        XCTAssertEqual(indicator.frame.minX, endpoint.minX, accuracy: 0.001, "完成后不能再偏移")
                        XCTAssertEqual(indicator.frame.width, endpoint.width, accuracy: 0.001, "完成后不能再伸缩")
                        XCTAssertEqual(indicator.frame.minY, endpoint.minY, accuracy: 0.001)
                        XCTAssertEqual(indicator.frame.height, endpoint.height, accuracy: 0.001)
                    }
                    XCTAssertEqual(bar.selectedIndex, target)
                    XCTAssertEqual(bar.items.indices.map { frame($0, collection) }, frames)
                }
            }
        }
    }

    func testFixedUnderlineCancellationRestoresPositionAndSelection() {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl, width: 600)
            bar.items = ["I", "Technology and Development"].map { SPTabBarItem(title: $0) }
            bar.standardAppearance.indicatorLayout = .underline(width: .fixed(20))
            for source in [0, 1] {
                bar.setSelectedIndex(source, animated: false)
                let original = indicator.frame
                let offset = collection.contentOffset
                for progress: CGFloat in [0.6, 0.3, 0] {
                    bar.setTransitionProgress(from: source, to: 1 - source, progress: progress)
                    bar.layoutIfNeeded()
                    XCTAssertEqual(indicator.frame.width, 20, accuracy: 0.01)
                    XCTAssertEqual(bar.selectedIndex, source)
                }
                bar.setSelectedIndex(source, animated: false)
                XCTAssertEqual(indicator.frame, original)
                XCTAssertEqual(collection.contentOffset, offset)
            }
        }
    }

    func testFixedUnderlineTracksTitleCenterWithImageBadgeAndOffscreenSelection() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl, width: 240)
            bar.items = (0 ..< 10).map { SPTabBarItem(title: "Channel \($0)", image: UIImage(systemName: "star")) }
            bar.standardAppearance.itemAppearance.layout = .inline
            bar.standardAppearance.indicatorLayout = .underline(width: .fixed(20))
            bar.items[9].badgeValue = "99+"
            bar.setSelectedIndex(9, animated: false)
            bar.layoutIfNeeded()
            for fontSize: CGFloat in [17, 28] {
                bar.items[9].setTitleTextAttributes([.font: UIFont.systemFont(ofSize: fontSize)], for: .selected)
                bar.layoutIfNeeded()
                XCTAssertEqual(indicator.frame.width, 20)
                XCTAssertEqual(indicator.frame.midX, try titleFrame(9, collection).midX, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.maxY, frame(9, collection).maxY, accuracy: 0.01)
            }
        }
    }

    func testUnderlinePresetRemainsCustomizableAndSurvivesAppearanceArchiving() throws {
        let (bar, collection, indicator) = mount()
        var layout = SPTabBarIndicatorLayout.underline(width: .fixed(20))
        layout.height = 4
        layout.cornerRadius = .fixed(1)
        layout.offset = CGPoint(x: 2, y: -3)
        layout.placement = .foreground
        let appearance = SPTabBarAppearance()
        appearance.indicatorLayout = layout
        bar.standardAppearance = appearance
        appearance.indicatorLayout?.width = .fixed(99)
        XCTAssertEqual(bar.standardAppearance.indicatorLayout, layout, "Appearance 赋值仍复制")
        let data = try NSKeyedArchiver.archivedData(withRootObject: bar.standardAppearance, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        XCTAssertEqual(decoded.indicatorLayout, layout)
        bar.standardAppearance = decoded
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, 20)
        XCTAssertEqual(indicator.frame.height, 4)
        XCTAssertEqual(indicator.frame.midX, try titleFrame(0, collection).midX + 2, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.maxY, frame(0, collection).maxY - 3)
        XCTAssertEqual(indicator.layer.cornerRadius, 1)
        XCTAssertEqual(indicator.layer.zPosition, 1)
        for (radius, expected): (SPTabBarIndicatorLayout.CornerRadius, CGFloat) in [
            (.automatic, 2),
            (.fixed(0), 0),
            (.fixed(1), 1),
            (.fixed(99), 2)
        ] {
            bar.standardAppearance.indicatorLayout?.cornerRadius = radius
            XCTAssertEqual(indicator.layer.cornerRadius, expected)
            XCTAssertEqual(indicator.frame.width, 20)
        }
        bar.standardAppearance.indicatorLayout?.width = .fixed(32)
        XCTAssertEqual(indicator.frame.width, 32, "通过宿主修改立即生效")
        let itemAppearance = SPTabBarAppearance()
        itemAppearance.indicatorLayout = .underline(width: .fixed(12))
        bar.items[0].standardAppearance = itemAppearance
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, 12, "Item 布局优先")
        bar.items[0].standardAppearance = nil
        bar.standardAppearance.indicatorLayout = nil
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, try titleFrame(0, collection).width, accuracy: 0.01)
    }

    func testFixedUnderlineNormalizesInvalidWidthsAndUsesCustomContentCenter() {
        let (bar, collection, indicator) = mount()
        let provider = ChannelContentProvider()
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.layoutIfNeeded()
        for width: CGFloat in [-20, 0, .nan, .infinity, 80] {
            bar.standardAppearance.indicatorLayout = .underline(width: .fixed(width))
            XCTAssertEqual(indicator.frame.width, width.isFinite ? max(0, width) : 40)
            XCTAssertEqual(indicator.frame.midX, frame(0, collection).minX + 40, accuracy: 0.01)
        }
    }

    func testWidthModeSwitchPreservesCustomizationAndMatchesPreset() throws {
        for rtl in [false, true] {
            let (bar, collection, indicator) = mount(rtl: rtl)
            bar.items = [SPTabBarItem(title: "I"), SPTabBarItem(title: "Technology")]
            bar.setSelectedIndex(0, animated: false)
            var layout = SPTabBarIndicatorLayout.underline
            layout.width = .fixed(20)
            XCTAssertEqual(layout, .underline(width: .fixed(20)))
            layout.width = .automatic
            XCTAssertEqual(layout, .underline)
            layout.height = 4
            layout.offset = CGPoint(x: 2, y: -3)
            layout.cornerRadius = .fixed(1)
            layout.placement = .foreground
            bar.standardAppearance.indicatorLayout = layout
            bar.layoutIfNeeded()
            let title = try titleFrame(0, collection)
            XCTAssertLessThan(title.width, 20)
            for width: SPTabBarIndicatorLayout.Width in [.fixed(20), .automatic, .fixed(32), .automatic] {
                bar.standardAppearance.indicatorLayout?.width = width
                let expected: CGFloat = if case let .fixed(value) = width { value } else { title.width }
                XCTAssertEqual(indicator.frame.width, expected, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.midX, title.midX + 2, accuracy: 0.01)
                XCTAssertEqual(indicator.frame.height, 4)
                XCTAssertEqual(indicator.frame.maxY, frame(0, collection).maxY - 3)
                XCTAssertEqual(indicator.layer.cornerRadius, 1)
                XCTAssertEqual(indicator.layer.zPosition, 1)
                var expectedLayout = layout
                expectedLayout.width = width
                XCTAssertEqual(bar.standardAppearance.indicatorLayout, expectedLayout)
            }
        }
    }

    func testWidthModeSwitchDuringPagingPreservesProgressOnCompletionAndCancellation() {
        for rtl in [false, true] {
            for completes in [false, true] {
                for source in [0, 1] {
                    let (bar, _, indicator) = mount(rtl: rtl, width: 600)
                    bar.items = ["I", "Technology and Development"].map { SPTabBarItem(title: $0) }
                    let target = 1 - source
                    bar.setSelectedIndex(target, animated: false)
                    let targetFrame = indicator.frame
                    bar.setSelectedIndex(source, animated: false)
                    let sourceFrame = indicator.frame
                    bar.standardAppearance.indicatorLayout = .underline
                    bar.setTransitionProgress(from: source, to: target, progress: 0.4)
                    for mode: SPTabBarIndicatorLayout.Width in [.fixed(20), .automatic, .fixed(32), .automatic] {
                        bar.standardAppearance.indicatorLayout?.width = mode
                        let expected: CGFloat = if case let .fixed(width) = mode { width } else {
                            sourceFrame.width + (targetFrame.width - sourceFrame.width) * 0.4
                        }
                        XCTAssertEqual(indicator.frame.width, expected, accuracy: 0.01)
                        XCTAssertEqual(
                            indicator.frame.midX,
                            sourceFrame.midX + (targetFrame.midX - sourceFrame.midX) * 0.4,
                            accuracy: 0.01
                        )
                        XCTAssertEqual(bar.selectedIndex, source)
                    }
                    bar.setTransitionProgress(from: source, to: target, progress: completes ? 1 : 0)
                    bar.setSelectedIndex(completes ? target : source, animated: completes)
                    if completes {
                        for progress: CGFloat in [0, 0.5, 1] {
                            bar.advanceSelectionAnimation(to: progress)
                            XCTAssertEqual(indicator.frame.minX, targetFrame.minX, accuracy: 0.001)
                            XCTAssertEqual(indicator.frame.width, targetFrame.width, accuracy: 0.001)
                            XCTAssertEqual(indicator.frame.minY, targetFrame.minY, accuracy: 0.001)
                            XCTAssertEqual(indicator.frame.height, targetFrame.height, accuracy: 0.001)
                        }
                    } else {
                        XCTAssertEqual(indicator.frame, sourceFrame)
                    }
                }
            }
        }
    }

    func testWidthModesRespectReferenceAndExplicitSizeLimit() {
        let (bar, collection, indicator) = mount()
        let provider = ChannelContentProvider()
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.layoutIfNeeded()
        for reference: SPTabBarIndicatorLayout.Reference in [.item, .content, .title] {
            var layout = SPTabBarIndicatorLayout()
            layout.reference = reference
            layout.height = 3
            layout.horizontalInset = 2
            bar.standardAppearance.indicatorLayout = layout
            let referenceWidth: CGFloat = reference == .item ? frame(0, collection).width : 40
            XCTAssertEqual(indicator.frame.width, referenceWidth - 4, accuracy: 0.01)
            bar.standardAppearance.indicatorLayout?.width = .fixed(200)
            XCTAssertEqual(indicator.frame.width, 200)
            bar.standardAppearance.indicatorLayout?.limitsSizeToReference = true
            XCTAssertEqual(indicator.frame.width, referenceWidth, accuracy: 0.01)
            bar.standardAppearance.indicatorLayout?.width = .automatic
            XCTAssertEqual(indicator.frame.width, referenceWidth - 4, accuracy: 0.01)
        }
    }

    func testWidthReadsLegacyNumericNullAndMissingArchiveFields() throws {
        let layout = SPTabBarIndicatorLayout.underline
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(layout)) as? [String: Any])
        for value: Any? in [20, NSNull(), nil] {
            legacy["width"] = value
            let decoded = try JSONDecoder().decode(
                SPTabBarIndicatorLayout.self,
                from: JSONSerialization.data(withJSONObject: legacy)
            )
            XCTAssertEqual(decoded.width, value is Int ? .fixed(20) : .automatic)
            let appearance = SPTabBarAppearance()
            appearance.indicatorLayout = decoded
            let data = try NSKeyedArchiver.archivedData(withRootObject: appearance, requiringSecureCoding: true)
            let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(
                ofClass: SPTabBarAppearance.self,
                from: data
            ))
            XCTAssertEqual(restored.indicatorLayout, decoded)
            let encoded = try XCTUnwrap(JSONSerialization
                .jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any])
            if value is Int {
                XCTAssertEqual(encoded["width"] as? Int, 20, "继续编码为旧版数值字段")
            } else {
                XCTAssertNil(encoded["width"])
            }
        }
    }

    func testCornerRadiusReadsLegacyNumericAndMissingArchiveFields() throws {
        var layout = SPTabBarIndicatorLayout()
        layout.height = 3
        layout.verticalAlignment = .bottom
        layout.horizontalInset = 12
        layout.limitsSizeToReference = true
        let encoded = try JSONEncoder().encode(layout)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy["cornerRadius"] = 1.25
        let numeric = try JSONDecoder().decode(
            SPTabBarIndicatorLayout.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        XCTAssertEqual(numeric.cornerRadius, .fixed(1.25))
        XCTAssertEqual(numeric.reference, .item)
        XCTAssertEqual(numeric.horizontalInset, 12)
        legacy.removeValue(forKey: "cornerRadius")
        let automatic = try JSONDecoder().decode(
            SPTabBarIndicatorLayout.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        XCTAssertEqual(automatic.cornerRadius, .automatic)
        XCTAssertEqual(automatic, layout)
    }

    func testSelectedTitleMeasurementDoesNotReplaceExplicitContentGeometry() throws {
        let (bar, collection, indicator) = mount(width: 600)
        bar.items = ["Stories", "Developer News"].map { SPTabBarItem(title: $0) }
        bar.items[1].setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 14)], for: .normal)
        bar.items[1].setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 26, weight: .bold)], for: .selected)
        bar.setSelectedIndex(0, animated: false)
        let normal = try titleFrame(1, collection)
        bar.setTransitionProgress(from: 0, to: 1, progress: 1)
        let selectedEndpoint = indicator.frame
        var layout = SPTabBarIndicatorLayout()
        layout.reference = .content
        layout.height = 3
        layout.verticalAlignment = .bottom
        bar.standardAppearance.indicatorLayout = layout
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame.width, normal.width, accuracy: 0.01)
        XCTAssertEqual(indicator.frame.minX, normal.minX, accuracy: 0.01)
        bar.standardAppearance.indicatorLayout = nil
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator.frame, selectedEndpoint)
        XCTAssertGreaterThan(selectedEndpoint.width, normal.width)
        bar.setSelectedIndex(1, animated: false)
        XCTAssertEqual(indicator.frame, selectedEndpoint)
        XCTAssertEqual(indicator.frame.width, try titleFrame(1, collection).width, accuracy: 0.01)
    }
}

@MainActor
private final class ChannelContentProvider: SPTabBarContentDelegate {
    var rect: CGRect? = CGRect(x: 20, y: 5, width: 40, height: 20)

    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        var config = UIListContentConfiguration.cell()
        config.text = item.title
        var content = SPTabBarContent(configuration: config, size: CGSize(width: 100, height: 44))
        content.indicatorContentRect = rect
        return content
    }
}
