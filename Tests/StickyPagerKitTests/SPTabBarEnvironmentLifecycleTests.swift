import XCTest
import UIKit
@testable import StickyPagerKit

/// 使用自然显示时钟和真实窗口；不手动推进动画，也不将 trait 注入冒充系统设置端到端。
@MainActor
final class SPTabBarEnvironmentLifecycleTests: XCTestCase {
    private weak var lastProvider: EnvironmentContentSource?
    private func waitUntil(_ predicate: () -> Bool, timeout: TimeInterval = 2) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        return predicate()
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    private func scale(_ bar: SPTabBar, index: Int) -> CGFloat? {
        let list = bar.subviews.compactMap { $0 as? UICollectionView }.first
        return list?.cellForItem(at: IndexPath(item: index, section: 0))?.contentView.subviews
            .first { $0.accessibilityIdentifier == "sp.tab.visualHost" }?.transform.a
    }

    private func withBar(custom: Bool, body: (SPTabBar, UIWindow, UIViewController) throws -> Void) rethrows {
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        let root = UIViewController(), child = UIViewController()
        window.rootViewController = root
        window.showForTesting()
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        child.view.frame = root.view.bounds
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 360, height: 72))
        let provider = EnvironmentContentSource()
        lastProvider = provider
        child.view.addSubview(bar)
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        bar.layoutConfiguration.itemSizing = .equal
        bar.visualStyle = .scale
        bar.visualStyle.interpolatesDefaultColors = true
        bar.selectionAnimationStyle = .spring
        bar.contentDelegate = provider
        if custom {
            bar.contentStyle = .custom
        }
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        defer { window.closeForTesting(); withExtendedLifetime(provider) {} }
        try body(bar, window, child)
    }

    func testNaturalSpringHandlesTraitResizeAndRetargetInBothContentModes() throws {
        for custom in [false, true] {
            try withBar(custom: custom) { bar, _, child in
                let initial = try XCTUnwrap(scale(bar, index: 2))
                bar.setSelectedIndex(2, animated: true)
                XCTAssertTrue(waitUntil { abs((self.scale(bar, index: 2) ?? initial) - initial) > 0.001 })
                XCTAssertNotEqual(try XCTUnwrap(scale(bar, index: 2)), 1, accuracy: 0.0001)
                child.parent?.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
                    UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
                    UITraitCollection(userInterfaceStyle: .dark)
                ]), forChild: child)
                bar.frame.size.width = 480
                bar.frame.size.height = bar.sizeThatFits(CGSize(width: 480, height: 400)).height
                bar.layoutIfNeeded()
                bar.setSelectedIndex(1, animated: true)
                XCTAssertTrue(waitUntil { self.scale(bar, index: 1) == 1 })
                XCTAssertEqual(bar.selectedIndex, 1)
                XCTAssertEqual(bar.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge)
                XCTAssertEqual(bar.traitCollection.userInterfaceStyle, .dark)
                let controls = descendants(bar).compactMap { $0 as? UIButton }
                    .filter { $0.accessibilityIdentifier == "sp.tab.1" && !$0.accessibilityElementsHidden }
                XCTAssertTrue(controls.contains { $0.accessibilityTraits.contains(.selected) })
                let list = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
                for cell in list.visibleCells {
                    XCTAssertTrue(cell.frame.width.isFinite && cell.frame.height.isFinite)
                    XCTAssertGreaterThan(cell.frame.height, 0)
                }
            }
        }
    }

    func testNaturalDefaultColorsResolveNewTraitEndpoints() throws {
        try withBar(custom: false) { bar, _, _ in
            bar.overrideUserInterfaceStyle = .light
            bar.standardAppearance.itemAppearance.normal
                .titleColor = UIColor { $0.userInterfaceStyle == .dark ? .green : .red }
            bar.standardAppearance.itemAppearance.selected
                .titleColor = UIColor { $0.userInterfaceStyle == .dark ? .yellow : .blue }
            bar.layoutIfNeeded()
            let initial = try XCTUnwrap(scale(bar, index: 1))
            bar.setSelectedIndex(1, animated: true)
            XCTAssertTrue(waitUntil { abs((self.scale(bar, index: 1) ?? initial) - initial) > 0.001 })
            bar.overrideUserInterfaceStyle = .dark
            bar.layoutIfNeeded()
            XCTAssertTrue(waitUntil { self.scale(bar, index: 1) == 1 })
            let list = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
            let cell = try XCTUnwrap(list.cellForItem(at: IndexPath(item: 1, section: 0)))
            let button = try XCTUnwrap(descendants(cell).compactMap { $0 as? UIButton }
                .first { $0.titleLabel?.text == "标签 1" })
            XCTAssertEqual(button.titleLabel?.textColor.resolvedColor(with: bar.traitCollection), UIColor.yellow)
            bar.setSelectedIndex(0, animated: true)
            XCTAssertTrue(waitUntil { self.scale(bar, index: 0) == 1 })
            XCTAssertEqual(bar.selectedIndex, 0)
        }
    }

    func testRepeatedActiveAnimationDetachReleasesBarsItemsAndProviders() {
        for custom in [false, true] {
            for cycle in 0 ..< 20 {
                weak var weakBar: SPTabBar?
                weak var weakItem: SPTabBarItem?
                // 每轮独立排空 UIKit 临时对象；不把整个 XCTest 方法的自动释放池当成对象泄漏。
                autoreleasepool {
                    withBar(custom: custom) { bar, _, _ in
                        weakBar = bar
                        weakItem = bar.items[1]
                        bar.setSelectedIndex(2, animated: true)
                        bar.setSelectedIndex(1, animated: true)
                        bar.removeFromSuperview()
                    }
                    print(
                        "TAB_RELEASE_PRE_DRAIN custom=\(custom) cycle=\(cycle) bar=\(weakBar != nil) item=\(weakItem != nil) provider=\(lastProvider != nil)"
                    )
                }
                XCTAssertTrue(
                    waitUntil { weakBar == nil && weakItem == nil && self.lastProvider == nil },
                    "custom=\(custom) cycle=\(cycle) bar=\(weakBar != nil) item=\(weakItem != nil) provider=\(lastProvider != nil)"
                )
                print(
                    "TAB_RELEASE_POST_DRAIN custom=\(custom) cycle=\(cycle) bar=\(weakBar != nil) item=\(weakItem != nil) provider=\(lastProvider != nil)"
                )
            }
        }
    }

    func testActiveCoordinatorReleasesAndStopsDeliveringFrames() {
        weak var weakCoordinator: SPTabBarPresentationCoordinator?
        var frames = 0
        autoreleasepool {
            let coordinator = SPTabBarPresentationCoordinator()
            weakCoordinator = coordinator
            coordinator.onFrame = { _ in frames += 1 }
            coordinator.startAnimation(
                .init(
                    fromIndex: 0,
                    toIndex: 1,
                    fromIndicator: CGRect(x: 0, y: 0, width: 40, height: 3),
                    toIndicator: CGRect(x: 80, y: 0, width: 40, height: 3),
                    fromGeometry: .zero,
                    fromOffset: 0,
                    toOffset: 80,
                    startTime: CACurrentMediaTime()
                ),
                contentOrigin: [0: 1],
                indicatorMotion: .linear,
                style: .spring,
                spring: nil
            )
            XCTAssertTrue(waitUntil { frames > 1 })
        }
        XCTAssertNil(weakCoordinator)
        let finalFrames = frames
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        XCTAssertEqual(frames, finalFrames)
    }
}

@MainActor
private final class EnvironmentContentSource: SPTabBarContentDelegate {
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(configuration: configuration, size: CGSize(width: 120, height: 64))
    }
}
