import XCTest
import UIKit
@testable import StickyPagerDemo

/// 大字号下同时验证实际文字高度、可用宽度和 Header 容器，避免只检查外层 frame。
@MainActor
final class DemoHeaderTests: XCTestCase {
    func testHeaderFitsDynamicTypeAndRestoresForViewAndController() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let pager = DemoPager()
        let navigation = UINavigationController(rootViewController: pager)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        settle(window)
        defer {
            window.rootViewController = nil
            settle(window)
            window.isHidden = true
            previous?.makeKey()
        }
        for controller in [false, true] {
            if controller {
                pager.headerViewController = DemoHeaderController()
            }
            let pendingHeader = try XCTUnwrap(pager.headerView ?? pager.headerViewController?.view)
            pendingHeader.frame.size.width = 0
            pendingHeader.setNeedsLayout()
            pendingHeader.layoutIfNeeded()
            pager.view.setNeedsLayout()
            settle(window)
            for rtl in [false, true] {
                pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                var normalHeight: CGFloat?
                for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge, .large] {
                    navigation.setOverrideTraitCollection(
                        UITraitCollection(preferredContentSizeCategory: category),
                        forChild: pager
                    )
                    pager.view.setNeedsLayout()
                    settle(window)
                    let header =
                        try XCTUnwrap((pager.headerView ?? pager.headerViewController?.view) as? DemoHeaderView)
                    for identifier in ["demo.headerTitle", "demo.headerSubtitle"] {
                        let text = try XCTUnwrap(label(in: header, identifier: identifier))
                        let rect = text.convert(text.bounds, to: pager.view)
                        let required = text.sizeThatFits(CGSize(
                            width: text.bounds.width,
                            height: .greatestFiniteMagnitude
                        ))
                        XCTAssertGreaterThanOrEqual(text.bounds.height + 1, required.height)
                        XCTAssertGreaterThanOrEqual(rect.minY, pager.view.safeAreaInsets.top - 1)
                        XCTAssertLessThanOrEqual(rect.maxY, pager.tabBar.frame.minY + 1)
                        XCTAssertGreaterThanOrEqual(rect.minX, pager.view.safeAreaInsets.left + 23)
                        XCTAssertLessThanOrEqual(
                            rect.maxX,
                            pager.view.bounds.width - pager.view.safeAreaInsets.right - 23
                        )
                        XCTAssertFalse(text.hasAmbiguousLayout)
                        if identifier == "demo.headerTitle" {
                            XCTAssertLessThanOrEqual(text.bounds.height, ceil(text.font.lineHeight) + 1, "品牌名保持单行")
                        }
                    }
                    XCTAssertEqual(pager.selectedIndex, 0)
                    if category.isAccessibilityCategory {
                        XCTAssertGreaterThan(pager.layout.headerHeight, 220)
                    } else if let normalHeight {
                        XCTAssertEqual(pager.layout.headerHeight, normalHeight, accuracy: 1)
                    } else {
                        normalHeight = pager.layout.headerHeight
                    }
                    let height = pager.layout.headerHeight
                    settle(window)
                    XCTAssertEqual(pager.layout.headerHeight, height, "重复布局不应因 Header 位置产生高度反馈")
                }
            }
        }
    }

    private func label(in view: UIView, identifier: String) -> UILabel? {
        if let label = view as? UILabel, label.accessibilityIdentifier == identifier {
            return label
        }
        return view.subviews.lazy.compactMap { self.label(in: $0, identifier: identifier) }.first
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        window.layoutIfNeeded()
    }
}
