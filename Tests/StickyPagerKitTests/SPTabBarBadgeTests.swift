import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarBadgeTests: XCTestCase {
    private var window: UIWindow!
    private var host: UIViewController!

    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        host = UIViewController()
        window.rootViewController = host
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window.rootViewController = nil
        window = nil
        host = nil
    }

    private func mount(
        _ item: SPTabBarItem,
        rtl: Bool = false,
        category: UIContentSizeCategory = .large
    ) -> SPTabBar {
        window.showForTesting()
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: child)
        let bar = SPTabBar()
        bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        child.view.addSubview(bar)
        bar.items = [item]
        layout(bar)
        return bar
    }

    private func layout(_ bar: SPTabBar, width: CGFloat = 320) {
        bar.frame = CGRect(x: 0, y: 80, width: width, height: bar.sizeThatFits(CGSize(width: width, height: 0)).height)
        bar.setNeedsLayout()
        bar.layoutIfNeeded()
    }

    private func views(_ bar: SPTabBar) throws -> (UIView, UIButton, UILabel) {
        let collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        collection.layoutIfNeeded()
        let content = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0))).contentView
        content.layoutIfNeeded()
        let button = try XCTUnwrap(content.subviews.compactMap { $0 as? UIButton }.first)
        button.layoutIfNeeded()
        return (content, button, try XCTUnwrap(content.subviews.compactMap { $0 as? UILabel }.first))
    }

    func testBadgeAnchorsToContentTopTrailingAndKeepsTitleCentered() throws {
        for rtl in [false, true] {
            for stacked in [false, true] {
                for image in [nil, UIImage(systemName: "star")] {
                    let item = SPTabBarItem(title: "中文标题", image: image)
                    let bar = mount(item, rtl: rtl)
                    bar.standardAppearance.itemAppearance.layout = stacked ? .stacked : .inline
                    layout(bar)
                    let (_, initialButton, _) = try views(bar)
                    let initialTitle = try XCTUnwrap(initialButton.titleLabel).frame
                    for value in ["8", "12", "99+", "新", "上新", "جديد"] {
                        item.badgeValue = value
                        layout(bar)
                        let (content, button, badge) = try views(bar)
                        let title = try XCTUnwrap(button.titleLabel)
                        XCTAssertEqual(title.frame.midX, initialTitle.midX, accuracy: 0.5)
                        var anchor = title.convert(title.bounds, to: content)
                        if let icon = button.imageView, image != nil {
                            let iconFrame = icon.convert(icon.bounds, to: content)
                            anchor = stacked ? iconFrame : anchor.union(iconFrame)
                        }
                        if rtl {
                            XCTAssertLessThan(badge.frame.midX, anchor.minX)
                        } else {
                            XCTAssertGreaterThan(badge.frame.midX, anchor.maxX)
                        }
                        XCTAssertLessThan(badge.frame.minY, anchor.minY)
                        XCTAssertLessThanOrEqual(badge.frame.midY, anchor.minY + 1)
                        XCTAssertTrue(content.bounds.contains(badge.frame))
                        XCTAssertEqual(badge.textAlignment, .center)
                        XCTAssertGreaterThanOrEqual(badge.bounds.width, ceil(badge.intrinsicContentSize.width) + 10)
                        XCTAssertGreaterThanOrEqual(badge.bounds.height, ceil(badge.intrinsicContentSize.height) + 4)
                    }
                    bar.removeFromSuperview()
                }
            }
        }
    }

    func testChineseBadgeFitsAccessibilitySizeAndNarrowViewport() throws {
        for rtl in [false, true] {
            let item = SPTabBarItem(title: "更多专题与活动", image: UIImage(systemName: "bell"))
            item.badgeValue = "待更新"
            let bar = mount(item, rtl: rtl, category: .accessibilityExtraExtraExtraLarge)
            for width: CGFloat in [180, 390] {
                layout(bar, width: width)
                let (content, button, badge) = try views(bar)
                XCTAssertTrue(content.bounds.contains(badge.frame))
                XCTAssertGreaterThanOrEqual(badge.bounds.width, badge.bounds.height)
                XCTAssertGreaterThanOrEqual(badge.bounds.height, ceil(badge.intrinsicContentSize.height) + 4)
                XCTAssertGreaterThanOrEqual(badge.bounds.width, ceil(badge.intrinsicContentSize.width) + 10)
                XCTAssertEqual(button.accessibilityValue, "待更新")
                XCTAssertFalse(badge.isAccessibilityElement)
                XCTAssertFalse(badge.isUserInteractionEnabled)
                XCTAssertTrue(content.hitTest(badge.center, with: nil) === button)
            }
        }
    }

    func testBadgeUpdatesSelectionDotAndHiddenState() throws {
        let item = SPTabBarItem(title: "消息")
        let bar = mount(item)
        for value: String? in ["上新", "99+", "", nil, "新"] {
            item.badgeValue = value
            bar.selectedItem = item
            layout(bar)
            let (_, button, badge) = try views(bar)
            XCTAssertEqual(badge.isHidden, value == nil)
            XCTAssertEqual(button.accessibilityValue, value.map { $0.isEmpty ? "有新内容" : $0 })
            if value == "" {
                XCTAssertEqual(badge.bounds.size, CGSize(width: 8, height: 8))
            }
        }
        item.isEnabled = false
        layout(bar)
        let (_, button, badge) = try views(bar)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(badge.text, "新")
    }

    func testIconOnlyAndSystemTabBarVisualReference() throws {
        host.view.backgroundColor = .systemBackground
        let item = SPTabBarItem(title: nil, image: UIImage(systemName: "bell"))
        item.badgeValue = "上新"
        let bar = mount(item)
        let (content, button, badge) = try views(bar)
        let icon = try XCTUnwrap(button.imageView)
        let imageFrame = icon.convert(icon.bounds, to: content)
        XCTAssertLessThan(badge.frame.minY, imageFrame.minY)
        XCTAssertGreaterThan(badge.frame.midX, imageFrame.maxX)
        XCTAssertTrue(content.bounds.contains(badge.frame))

        // 同一 UIWindow 留存实际系统 UITabBar 作为视觉参照，不依赖系统私有子视图结构。
        let reference = UITabBar(frame: CGRect(x: 0, y: 240, width: 320, height: 64))
        let systemItem = UITabBarItem(title: nil, image: UIImage(systemName: "bell"), tag: 0)
        systemItem.badgeValue = "上新"
        reference.items = [systemItem]
        host.view.addSubview(reference)
        reference.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 330))
        let snapshot = renderer.image { context in
            host.view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "上方 StickyPagerKit 与下方系统 UITabBar 中文角标"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // 系统内部可能同时保留旧版与新版角标副本；这里只留存视觉参考，
    // 不把内部 UILabel 数量或其坐标作为框架契约。框架 RTL 几何由上面的用例直接断言。
    func testSystemBadgeDirectionVisualReference() {
        window.showForTesting()
        host.view.backgroundColor = .systemBackground
        var observations: [String] = []
        for (row, rtl) in [false, true].enumerated() {
            let reference = UITabBar(frame: CGRect(x: 0, y: 80 + row * 130, width: 390, height: 64))
            reference.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            reference.items = ["8", "جديد", "上新"].enumerated().map { index, value in
                let item = UITabBarItem(title: "\(index)", image: UIImage(systemName: "bell"), tag: index)
                item.badgeValue = value
                return item
            }
            host.view.addSubview(reference)
            reference.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            func record(_ view: UIView) {
                guard !view.isHidden, view.alpha > 0.01 else {
                    return
                }
                if let label = view as? UILabel, let text = label.text {
                    let frame = view.convert(view.bounds, to: reference)
                    observations.append("rtl=\(rtl) text=\(text) frame=\(frame)")
                }
                for child in view.subviews {
                    record(child)
                }
            }
            record(reference)
        }
        let snapshot = UIGraphicsImageRenderer(size: CGSize(width: 390, height: 330)).image { context in
            host.view.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "系统 UITabBar 上方 LTR 下方 RTL"
        attachment.lifetime = .keepAlways
        add(attachment)
        let geometry = XCTAttachment(string: observations.joined(separator: "\n"))
        geometry.name = "系统角标 LTR 与 RTL 实际坐标"
        geometry.lifetime = .keepAlways
        add(geometry)
    }
}
