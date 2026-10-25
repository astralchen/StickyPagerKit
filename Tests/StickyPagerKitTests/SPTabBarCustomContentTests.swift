import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarCustomContentTests: XCTestCase {
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

    private func mount(_ provider: CustomContentSource? = nil) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 320, height: 80))
        // 此夹具显式验证 automatic 分配；频道型默认组合由专门用例覆盖。
        bar.layoutConfiguration.itemSizing = .balanced
        // 此夹具显式使用零留白，隔离 Item 宽度与间距算法；默认留白由附件布局测试覆盖。
        bar.layoutConfiguration.contentInsets = .zero
        bar.items = [SPTabBarItem(title: "第一项"), SPTabBarItem(title: "第二项")]
        bar.selectedItem = bar.items[0]
        window.rootViewController!.view.addSubview(bar)
        bar.contentDelegate = provider
        bar.contentStyle = .custom
        bar.layoutIfNeeded()
        return bar
    }

    private func collection(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }

    private func cell(_ bar: SPTabBar, _ index: Int = 0) -> UICollectionViewCell {
        bar.layoutIfNeeded()
        collection(bar).layoutIfNeeded()
        return collection(bar).cellForItem(at: IndexPath(item: index, section: 0))!
    }

    private func button(_ bar: SPTabBar, _ index: Int = 0) -> UIButton {
        cell(bar, index).contentView.subviews.compactMap { $0 as? UIButton }.first!
    }

    private func probe(_ bar: SPTabBar, _ index: Int = 0) -> CustomProbeView? {
        cell(bar, index).contentView.subviews.compactMap { $0 as? CustomProbeView }.first
    }

    private func scrollable(_ provider: CustomContentSource, rtl: Bool = false) -> SPTabBar {
        let bar = mount(provider)
        bar.items = (0 ..< 10).map { SPTabBarItem(title: "标签 \($0)") }
        bar.indicatorStyle = .underline
        // 滚动与动画用例保留 Item 两侧内缩 12 pt 的显式几何；文字预设由频道测试覆盖。
        var indicatorLayout = SPTabBarIndicatorLayout()
        indicatorLayout.height = 3
        indicatorLayout.verticalAlignment = .bottom
        indicatorLayout.horizontalInset = 12
        indicatorLayout.limitsSizeToReference = true
        bar.standardAppearance.indicatorLayout = indicatorLayout
        bar.standardAppearance.indicatorColor = nil
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        return bar
    }

    private func indicator(_ bar: SPTabBar) -> UIView {
        collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.indicator" }!
    }

    private func itemFrame(_ bar: SPTabBar, _ index: Int) -> CGRect {
        collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))!.frame
    }

    func testModeAndFallbackChangesReuseContainerAndActivationButton() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let container = cell(bar).contentView
        let control = button(bar)
        let spy = SelectionSpy()
        bar.delegate = spy
        for _ in 0 ..< 3 {
            bar.items[0].badgeValue = "旧角标"
            bar.items[0].largeContentSizeImage = UIImage(systemName: "star")
            control.isHighlighted = true
            weak var previousCustom = probe(bar)
            bar.contentStyle = .default
            XCTAssertTrue(cell(bar).contentView === container)
            XCTAssertTrue(button(bar) === control)
            XCTAssertNil(previousCustom?.superview, "离开自定义模式应移除业务内容")
            XCTAssertFalse(control.isHighlighted)
            XCTAssertEqual(control.configuration?.title, "第一项")
            XCTAssertNotNil(control.largeContentImage)
            bar.contentStyle = .custom
            XCTAssertTrue(cell(bar).contentView === container)
            XCTAssertTrue(button(bar) === control)
            XCTAssertNil(control.configuration?.title)
            XCTAssertNil(control.image(for: .normal))
            XCTAssertNil(control.largeContentImage)
            XCTAssertEqual(control.largeContentImageInsets, .zero)
            XCTAssertTrue(container.subviews.compactMap { $0 as? UILabel }.allSatisfy(\.isHidden))
            XCTAssertNotNil(probe(bar))
            provider.size = .zero
            bar.reloadContent()
            XCTAssertTrue(cell(bar).contentView === container)
            XCTAssertTrue(button(bar) === control)
            XCTAssertEqual(control.configuration?.title, "第一项")
            provider.size = CGSize(width: 150, height: 80)
            bar.reloadContent()
            XCTAssertTrue(cell(bar).contentView === container)
            XCTAssertTrue(button(bar) === control)
            XCTAssertNotNil(probe(bar))
        }
        control.sendActions(for: .touchUpInside)
        XCTAssertEqual(spy.selected.count, 1, "模式切换不能重复安装 action")
        XCTAssertTrue(spy.selected.first === bar.items[0])
    }

    func testCompatibleRefreshKeepsContentIdentityAndCreationCount() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let container = cell(bar).contentView
        let control = button(bar)
        let content = probe(bar)!
        let creations = provider.creations
        for index in 0 ..< 5 {
            provider.textSuffix = "刷新 \(index)"
            bar.reloadContent()
            bar.items[0].isEnabled = true
            control.isHighlighted = true
            XCTAssertTrue(content.value.highlighted)
            control.isHighlighted = false
            bar.items[0].isEnabled.toggle()
            bar.setSelectedIndex(index % 2, animated: false)
            bar.tintColor = index.isMultiple(of: 2) ? .systemRed : .systemBlue
            bar.layoutIfNeeded()
            XCTAssertTrue(cell(bar).contentView === container)
            XCTAssertTrue(button(bar) === control)
            XCTAssertTrue(probe(bar) === content)
            XCTAssertEqual(provider.creations, creations)
            XCTAssertEqual(content.value.disabled, !bar.items[0].isEnabled)
        }
    }

    func testIncompatibleBusinessConfigurationOnlyReplacesInnerView() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let container = cell(bar).contentView
        let control = button(bar)
        weak var original = probe(bar)
        provider.useListConfiguration = true
        bar.reloadContent()
        XCTAssertTrue(cell(bar).contentView === container)
        XCTAssertTrue(button(bar) === control)
        XCTAssertNil(original?.superview)
        let list = container.subviews.compactMap { $0 as? UIListContentView }.first!
        bar.reloadContent()
        XCTAssertTrue(container.subviews.contains { $0 === list })
        provider.useListConfiguration = false
        let creations = provider.creations
        bar.reloadContent()
        XCTAssertTrue(cell(bar).contentView === container)
        XCTAssertTrue(button(bar) === control)
        XCTAssertNil(list.superview)
        XCTAssertNotNil(probe(bar))
        XCTAssertEqual(provider.creations - creations, 2, "只有两项业务内容需要重新创建")
    }

    func testBusinessSupportsCanRejectSameConfigurationType() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("supports(_:) 需要 iOS 16+")
        }
        let provider = CustomContentSource()
        let bar = mount(provider)
        let container = cell(bar).contentView
        let control = button(bar)
        weak var previous = probe(bar)
        let creations = provider.creations
        provider.compatibilityKey = 1
        bar.reloadContent()
        XCTAssertNil(previous?.superview)
        XCTAssertTrue(cell(bar).contentView === container)
        XCTAssertTrue(button(bar) === control)
        XCTAssertEqual(probe(bar)?.value.compatibilityKey, 1)
        XCTAssertEqual(provider.creations - creations, 2)
        let current = probe(bar)
        bar.reloadContent()
        XCTAssertTrue(probe(bar) === current)
        XCTAssertEqual(provider.creations - creations, 2)
    }

    func testLeavingCustomModeReleasesBusinessViewAfterAutoreleasePool() {
        weak var content: UIView?
        autoreleasepool {
            let provider = CustomContentSource()
            let bar = mount(provider)
            content = probe(bar)
            XCTAssertNotNil(content)
            bar.contentStyle = .default
            XCTAssertNil(content?.superview)
            bar.layoutIfNeeded()
        }
        XCTAssertNil(content, "Cell 仍挂载时也不能强持有已移除的业务内容")
    }

    func testReloadSameSizePreservesManualOffsetAndUpdatesVisibleContent() {
        for rtl in [false, true] {
            let provider = CustomContentSource()
            let bar = scrollable(provider, rtl: rtl)
            collection(bar).contentOffset.x = 130
            let frame = indicator(bar).frame
            provider.textSuffix = "已刷新"
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(collection(bar).contentOffset.x, 130, accuracy: 0.01)
            XCTAssertEqual(indicator(bar).frame, frame)
            let visible = collection(bar).indexPathsForVisibleItems.first!.item
            XCTAssertTrue(probe(bar, visible)!.value.title.hasSuffix("已刷新"))
            XCTAssertEqual(bar.selectedIndex, 0)
        }
    }

    func testReloadSameSizePreservesSelectionAnimation() {
        for rtl in [false, true] {
            let provider = CustomContentSource()
            let bar = scrollable(provider, rtl: rtl)
            bar.setSelectedIndex(6, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            let frame = indicator(bar).frame
            let offset = collection(bar).contentOffset.x
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator(bar).frame, frame)
            XCTAssertEqual(collection(bar).contentOffset.x, offset, accuracy: 0.01)
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(indicator(bar).frame.minX, itemFrame(bar, 6).minX + 12, accuracy: 0.01)
            XCTAssertEqual(collection(bar).contentOffset.x, itemFrame(bar, 6).midX - 160, accuracy: 0.01)
        }
    }

    func testReloadSameSizePreservesPagingProgress() {
        for rtl in [false, true] {
            let provider = CustomContentSource()
            let bar = scrollable(provider, rtl: rtl)
            bar.setSelectedIndex(3, animated: false)
            bar.setTransitionProgress(from: 3, to: 4, progress: 0.4)
            let frame = indicator(bar).frame
            let offset = collection(bar).contentOffset.x
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator(bar).frame, frame)
            XCTAssertEqual(collection(bar).contentOffset.x, offset, accuracy: 0.01)
            bar.setTransitionProgress(from: 3, to: 4, progress: 0.8)
            XCTAssertEqual(
                indicator(bar).frame.minX,
                itemFrame(bar, 3).minX * 0.2 + itemFrame(bar, 4).minX * 0.8 + 12,
                accuracy: 0.01
            )
            XCTAssertEqual(bar.selectedIndex, 3, "刷新不提交分页选择")
        }
    }

    func testSameSizeEnvironmentRefreshPreservesScrollAnimationAndPaging() {
        for rtl in [false, true] {
            let provider = CustomContentSource()
            let bar = scrollable(provider, rtl: rtl)
            bar.overrideUserInterfaceStyle = .light
            bar.layoutIfNeeded()
            collection(bar).contentOffset.x = 130
            bar.overrideUserInterfaceStyle = .dark
            bar.layoutIfNeeded()
            XCTAssertEqual(provider.context?.state.traitCollection.userInterfaceStyle, .dark)
            XCTAssertEqual(collection(bar).contentOffset.x, 130, accuracy: 0.01)
            bar.setSelectedIndex(6, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            let animatedFrame = indicator(bar).frame
            let animatedOffset = collection(bar).contentOffset.x
            bar.overrideUserInterfaceStyle = .light
            bar.layoutIfNeeded()
            XCTAssertEqual(indicator(bar).frame, animatedFrame)
            XCTAssertEqual(collection(bar).contentOffset.x, animatedOffset, accuracy: 0.01)
            bar.advanceSelectionAnimation(to: 1)
            bar.setTransitionProgress(from: 6, to: 5, progress: 0.4)
            let pagingFrame = indicator(bar).frame
            let pagingOffset = collection(bar).contentOffset.x
            bar.overrideUserInterfaceStyle = .dark
            bar.tintColor = .systemPurple
            bar.layoutIfNeeded()
            XCTAssertEqual(provider.context?.tintColor, .systemPurple)
            XCTAssertEqual(indicator(bar).frame, pagingFrame)
            XCTAssertEqual(collection(bar).contentOffset.x, pagingOffset, accuracy: 0.01)
        }
    }

    func testDefaultModeProviderChangesDoNotDisturbPresentation() {
        let provider = CustomContentSource()
        let bar = scrollable(provider)
        bar.contentStyle = .default
        bar.layoutIfNeeded()
        let replacement = CustomContentSource()
        collection(bar).contentOffset.x = 70
        bar.contentDelegate = replacement
        bar.reloadContent()
        bar.layoutIfNeeded()
        XCTAssertEqual(collection(bar).contentOffset.x, 70, accuracy: 0.01)
        XCTAssertEqual(replacement.calls, 0)
        bar.setSelectedIndex(6, animated: true)
        bar.advanceSelectionAnimation(to: 0.5)
        let frame = indicator(bar).frame
        let offset = collection(bar).contentOffset.x
        bar.contentDelegate = nil
        bar.reloadContent()
        bar.layoutIfNeeded()
        XCTAssertEqual(indicator(bar).frame, frame)
        XCTAssertEqual(collection(bar).contentOffset.x, offset, accuracy: 0.01)
        bar.advanceSelectionAnimation(to: 1)
        XCTAssertEqual(indicator(bar).frame.minX, itemFrame(bar, 6).minX + 12, accuracy: 0.01)
    }

    func testProposedSizeDoesNotCommitContentOrLayoutUntilActualResize() {
        let provider = CustomContentSource()
        provider.usesAvailableWidth = true
        let bar = mount(provider)
        let frame = itemFrame(bar, 0)
        let content = probe(bar)!
        let title = content.value.title
        let indicatorFrame = indicator(bar).frame
        let offset = collection(bar).contentOffset
        let creations = provider.creations
        for width: CGFloat in [600, 100, 600] {
            XCTAssertEqual(bar.sizeThatFits(CGSize(width: width, height: 0)).height, width / 4)
            let calls = provider.calls
            _ = bar.sizeThatFits(CGSize(width: width, height: 0))
            XCTAssertEqual(provider.calls, calls)
            collection(bar).layoutIfNeeded()
            XCTAssertEqual(itemFrame(bar, 0), frame)
            XCTAssertEqual(content.value.title, title)
            XCTAssertEqual(indicator(bar).frame, indicatorFrame)
            XCTAssertEqual(collection(bar).contentOffset, offset)
            XCTAssertEqual(provider.creations, creations)
        }
        bar.frame.size = CGSize(width: 360, height: 90)
        bar.layoutIfNeeded()
        XCTAssertEqual(itemFrame(bar, 0).width, 180, accuracy: 0.01)
        XCTAssertEqual(probe(bar)!.value.title, "第一项360")
        XCTAssertEqual(bar.sizeThatFits(CGSize(width: 360, height: 0)).height, 90)
    }

    func testChangedContentSizeClampsManualOffsetAndRebasesPaging() {
        for rtl in [false, true] {
            let provider = CustomContentSource()
            let bar = scrollable(provider, rtl: rtl)
            collection(bar).contentOffset.x = 130
            provider.size.width = 180
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(collection(bar).contentOffset.x, 130, accuracy: 0.01)
            collection(bar).contentOffset.x = 340
            provider.size.width = 44
            bar.reloadContent()
            bar.layoutIfNeeded()
            XCTAssertEqual(collection(bar).contentOffset.x, 120, accuracy: 0.01)
            provider.size.width = 150
            bar.reloadContent()
            bar.layoutIfNeeded()
            bar.setSelectedIndex(3, animated: false)
            bar.setTransitionProgress(from: 3, to: 4, progress: 0.4)
            provider.size = CGSize(width: 180, height: 100)
            bar.reloadContent()
            bar.frame.size.height = bar.sizeThatFits(bar.bounds.size).height
            bar.layoutIfNeeded()
            XCTAssertEqual(
                indicator(bar).frame.minX,
                itemFrame(bar, 3).minX * 0.6 + itemFrame(bar, 4).minX * 0.4 + 12,
                accuracy: 0.01
            )
            XCTAssertEqual(
                collection(bar).contentOffset.x,
                itemFrame(bar, 3).midX * 0.6 + itemFrame(bar, 4).midX * 0.4 - 160,
                accuracy: 0.01
            )
            XCTAssertEqual(bar.selectedIndex, 3)
            bar.setSelectedIndex(6, animated: true)
            bar.advanceSelectionAnimation(to: 0.5)
            provider.size.width = 200
            bar.reloadContent()
            bar.layoutIfNeeded()
            let settled = indicator(bar).frame
            bar.advanceSelectionAnimation(to: 1)
            XCTAssertEqual(indicator(bar).frame, settled)
            XCTAssertEqual(settled.minX, itemFrame(bar, 6).minX + 12, accuracy: 0.01)
        }
    }

    func testMissingInvalidAndReleasedProviderFallBackToDefault() {
        let bar = mount()
        XCTAssertEqual(button(bar).configuration?.title, "第一项")
        var provider: CustomContentSource? = CustomContentSource()
        bar.contentDelegate = provider
        XCTAssertNotNil(probe(bar))
        for size in [
            CGSize.zero,
            CGSize(width: CGFloat.nan, height: 60),
            CGSize(width: 100, height: CGFloat.infinity),
            CGSize(width: -1, height: 60),
            CGSize(width: 2_000_000, height: 60)
        ] {
            provider!.size = size
            bar.reloadContent()
            XCTAssertNil(probe(bar))
            XCTAssertEqual(button(bar).configuration?.title, "第一项")
            XCTAssertTrue(bar.sizeThatFits(.zero).height.isFinite)
        }
        provider!.size = CGSize(width: 150, height: 80)
        provider!.omittedIndex = 1
        bar.reloadContent()
        XCTAssertNotNil(probe(bar))
        XCTAssertNil(probe(bar, 1))
        weak var released = provider
        provider = nil
        XCTAssertNil(released)
        bar.setNeedsLayout()
        bar.layoutIfNeeded()
        XCTAssertEqual(button(bar).configuration?.title, "第一项")
    }

    func testCustomMeasurementsAreCachedAndIncludeOwnPadding() {
        let provider = CustomContentSource()
        provider.size = CGSize(width: 190, height: 92)
        let bar = mount(provider)
        let count = provider.calls
        let creations = provider.creations
        for _ in 0 ..< 5 {
            XCTAssertEqual(bar.sizeThatFits(CGSize(width: 320, height: 0)).height, 92)
            bar.setNeedsLayout()
            bar.layoutIfNeeded()
        }
        XCTAssertEqual(provider.calls, count)
        XCTAssertEqual(provider.creations, creations, "测量不应创建额外内容视图")
        XCTAssertEqual(
            collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame
                .width,
            190
        )
        provider.size = CGSize(width: 1, height: 1)
        bar.reloadContent()
        XCTAssertEqual(bar.sizeThatFits(.zero).height, 1)
        XCTAssertGreaterThanOrEqual(button(bar).bounds.width, 44)
    }

    func testShortItemClipsMeasuredContentAndPreservesActivationAcrossRestore() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 0, bottom: 5, trailing: 0)
        let spy = SelectionSpy()
        bar.delegate = spy
        for height: CGFloat in [32, 60, 108, 32, 88] {
            bar.frame.size.height = height
            bar.layoutIfNeeded()
            let content = probe(bar)!
            let container = cell(bar).contentView
            container.layoutIfNeeded()
            XCTAssertTrue(container.clipsToBounds)
            XCTAssertEqual(content.frame.minY, 0)
            XCTAssertEqual(content.bounds.height, max(80, height - 8))
            XCTAssertEqual(button(bar).bounds.height, height - 8)
            XCTAssertEqual(bar.sizeThatFits(bar.bounds.size).height, 88)
            XCTAssertTrue(button(bar).accessibilityActivate())
            XCTAssertEqual(bar.selectedIndex, 0)
            XCTAssertFalse(bar.point(inside: CGPoint(x: 10, y: height + 1), with: nil))
        }
        XCTAssertEqual(spy.selected.count, 5)
        bar.contentStyle = .default
        XCTAssertNil(probe(bar))
        XCTAssertFalse(cell(bar).contentView.clipsToBounds, "默认图文恢复原有布局")
        bar.contentStyle = .custom
        XCTAssertEqual(probe(bar)?.bounds.height, 80)
        XCTAssertTrue(cell(bar).contentView.clipsToBounds)
    }

    func testStateHighlightActivationAndDisabledSelectionStayCoordinated() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let spy = SelectionSpy()
        bar.delegate = spy
        let view = probe(bar)!
        let control = button(bar)
        XCTAssertTrue(view.value.selected)
        let calls = provider.calls
        control.isHighlighted = true
        XCTAssertTrue(view.value.highlighted)
        XCTAssertEqual(provider.calls, calls, "按压只更新配置，不重新测量")
        control.isHighlighted = false
        XCTAssertFalse(view.value.highlighted)
        XCTAssertTrue(button(bar, 1).accessibilityActivate())
        XCTAssertTrue(bar.selectedItem === bar.items[1])
        XCTAssertEqual(spy.selected.count, 1)
        XCTAssertTrue(probe(bar, 1)!.value.selected)
        spy.allowed = false
        XCTAssertTrue(button(bar).accessibilityActivate())
        XCTAssertEqual(bar.selectedIndex, 1)
        bar.items[0].isEnabled = false
        XCTAssertFalse(button(bar).accessibilityActivate())
        XCTAssertTrue(probe(bar)!.value.disabled)
        bar.selectedItem = bar.items[0]
        XCTAssertTrue(probe(bar)!.value.selected)
        XCTAssertEqual(spy.selected.count, 1, "程序化选择不发送标签代理事件")
        XCTAssertTrue(collection(bar).touchesShouldCancel(in: button(bar)))
    }

    func testCustomPresentationPreviewsPagingAndRestoresAfterCancellation() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let spy = SelectionSpy()
        bar.delegate = spy
        for rtl in [false, true] {
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            bar.setSelectedIndex(0, animated: false)
            for progress: CGFloat in [0.2, 0.5, 1, 0.2, 0] {
                bar.setTransitionProgress(from: 0, to: 1, progress: progress)
                XCTAssertEqual(probe(bar, 0)!.value.selected, progress < 0.5)
                XCTAssertEqual(probe(bar, 1)!.value.selected, progress >= 0.5)
                XCTAssertEqual(bar.selectedIndex, 0)
                XCTAssertTrue(button(bar, 0).accessibilityTraits.contains(.selected))
                XCTAssertFalse(button(bar, 1).accessibilityTraits.contains(.selected))
            }
            bar.setSelectedIndex(0, animated: false)
            bar.beginUserSelection(bar.items[1])
            XCTAssertTrue(probe(bar, 1)!.value.selected)
            bar.reloadContent()
            XCTAssertTrue(probe(bar, 1)!.value.selected, "刷新不能丢失点击预览")
            bar.cancelUserSelection()
            XCTAssertTrue(probe(bar, 0)!.value.selected)
            XCTAssertFalse(probe(bar, 1)!.value.selected)
            bar.setTransitionProgress(from: 0, to: 1, progress: 1)
            XCTAssertTrue(probe(bar, 1)!.value.selected)
            bar.synchronizeSelection(bar.items[0], animated: false)
            XCTAssertTrue(probe(bar, 0)!.value.selected, "取消转场恢复提交项")
            XCTAssertFalse(probe(bar, 1)!.value.selected)
        }
        XCTAssertTrue(spy.selected.isEmpty)
    }

    func testAccessibilityAndNestedControlsHaveSingleActivationEntry() {
        let provider = CustomContentSource()
        provider.customAccessibility = true
        let bar = mount(provider)
        let view = probe(bar)!
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertTrue(view.accessibilityElementsHidden)
        let control = button(bar)
        XCTAssertEqual(control.accessibilityLabel, "自定义标题")
        XCTAssertEqual(control.accessibilityHint, "自定义提示")
        XCTAssertEqual(control.accessibilityValue, "自定义值")
        XCTAssertTrue(control.accessibilityTraits.contains(.selected))
        let spy = SelectionSpy()
        bar.delegate = spy
        for _ in 0 ..< 4 {
            bar.reloadContent()
        }
        XCTAssertTrue(probe(bar) === view)
        control.sendActions(for: .touchUpInside)
        XCTAssertEqual(spy.selected.count, 1)
    }

    func testModeConfigurationTypeAndItemReplacementClearStaleContent() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        let original = probe(bar)!
        provider.useListConfiguration = true
        bar.reloadContent()
        XCTAssertNil(probe(bar))
        XCTAssertTrue(cell(bar).contentView.subviews.contains { $0 is UIListContentView })
        provider.useListConfiguration = false
        bar.reloadContent()
        XCTAssertNotNil(probe(bar))
        XCTAssertFalse(probe(bar) === original)
        let replacement = SPTabBarItem(title: "新对象")
        bar.items = [replacement]
        let spy = SelectionSpy()
        bar.delegate = spy
        button(bar).sendActions(for: .touchUpInside)
        XCTAssertTrue(spy.selected.first === replacement)
        bar.contentStyle = .default
        XCTAssertNil(probe(bar))
        XCTAssertEqual(button(bar).configuration?.title, "新对象")
        bar.contentStyle = .custom
        XCTAssertEqual(probe(bar)?.value.title, "新对象")
        XCTAssertTrue(bar.selectedItem === replacement)
    }

    func testContextTracksWidthDirectionTraitsTintAndModelUpdates() {
        let provider = CustomContentSource()
        let bar = mount(provider)
        bar.items[0].title = "更新内容"
        XCTAssertEqual(probe(bar)?.value.title, "更新内容")
        bar.tintColor = .systemPurple
        XCTAssertEqual(provider.context?.tintColor, .systemPurple)
        bar.standardAppearance.itemAppearance.selected.titleColor = .systemOrange
        XCTAssertEqual(provider.context?.appearance.itemAppearance.selected.titleColor, .systemOrange)
        provider.context?.appearance.itemAppearance.selected.titleColor = .systemRed
        XCTAssertEqual(bar.standardAppearance.itemAppearance.selected.titleColor, .systemOrange)
        bar.semanticContentAttribute = .forceRightToLeft
        bar.frame.size.width = 260
        bar.layoutIfNeeded()
        XCTAssertEqual(provider.context?.availableWidth, collection(bar).bounds.width)
        XCTAssertEqual(provider.context?.layoutDirection, .rightToLeft)
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
        bar.layoutIfNeeded()
        XCTAssertEqual(
            provider.context?.state.traitCollection.preferredContentSizeCategory,
            .accessibilityExtraExtraExtraLarge
        )
        // 自定义 UI 还可能依赖水平尺寸类；即使字体和颜色没有改变，也必须刷新上下文。
        let nextSizeClass: UIUserInterfaceSizeClass = bar.traitCollection
            .horizontalSizeClass == .regular ? .compact : .regular
        host.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
            UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
            UITraitCollection(horizontalSizeClass: nextSizeClass)
        ]), forChild: child)
        child.view.layoutIfNeeded()
        bar.layoutIfNeeded()
        XCTAssertEqual(provider.context?.state.traitCollection.horizontalSizeClass, nextSizeClass)
    }
}

@MainActor
final class CustomContentSource: SPTabBarContentDelegate {
    var size = CGSize(width: 150, height: 80)
    var textSuffix = ""
    var usesAvailableWidth = false
    var omittedIndex: Int?
    var customAccessibility = false
    var useListConfiguration = false
    var compatibilityKey = 0
    var calls = 0
    var creations = 0
    var context: SPTabBarContentContext?
    func tabBar(
        _ tabBar: SPTabBar,
        contentFor item: SPTabBarItem,
        at index: Int,
        context: SPTabBarContentContext
    ) -> SPTabBarContent? {
        calls += 1
        self.context = context
        if index == omittedIndex {
            return nil
        }
        let configuration: any UIContentConfiguration
        if useListConfiguration {
            var list = UIListContentConfiguration.cell()
            list.text = item.title
            configuration = list
        } else {
            configuration = CustomProbeConfiguration(
                title: (item.title ?? "") + textSuffix + (usesAvailableWidth ? "\(Int(context.availableWidth))" : ""),
                compatibilityKey: compatibilityKey,
                made: { [weak self] in self?.creations += 1 }
            )
        }
        var result = SPTabBarContent(
            configuration: configuration,
            size: usesAvailableWidth ? CGSize(width: context.availableWidth / 2, height: context.availableWidth / 4) :
                size
        )
        if customAccessibility {
            result.accessibilityLabel = "自定义标题"
            result.accessibilityHint = "自定义提示"
            result.accessibilityValue = "自定义值"
        }
        return result
    }
}

private struct CustomProbeConfiguration: UIContentConfiguration {
    var title: String
    var selected = false
    var highlighted = false
    var disabled = false
    var compatibilityKey = 0
    let made: @MainActor () -> Void
    func makeContentView() -> UIView & UIContentView {
        made()
        return CustomProbeView(value: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        guard let state = state as? UICellConfigurationState else {
            return self
        }
        var value = self
        value.selected = state.isSelected
        value.highlighted = state.isHighlighted
        value.disabled = state.isDisabled
        return value
    }
}

@MainActor
private final class CustomProbeView: UIView, UIContentView {
    var value: CustomProbeConfiguration
    var configuration: any UIContentConfiguration {
        get { value }
        set {
            if let value = newValue as? CustomProbeConfiguration {
                self.value = value
            }
        }
    }

    @available(iOS 16.0, *)
    func supports(_ configuration: any UIContentConfiguration) -> Bool {
        (configuration as? CustomProbeConfiguration)?.compatibilityKey == value.compatibilityKey
    }

    init(value: CustomProbeConfiguration) {
        self.value = value
        super.init(frame: .zero)
        addSubview(UIButton(type: .system))
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
