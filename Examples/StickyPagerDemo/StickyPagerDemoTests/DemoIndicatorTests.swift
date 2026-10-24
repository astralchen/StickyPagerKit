import XCTest
import UIKit
import StickyPagerKit
@testable import StickyPagerDemo

@MainActor
final class DemoIndicatorTests: XCTestCase {
    func testGradientUsesConfiguredRadiusDuringPagingAndModeChanges() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        settle(window)
        defer {
            settle(window)
            window.rootViewController = nil
            settle(window)
            window.isHidden = true
            previous?.makeKey()
        }
        let bar = SPTabBar(frame: CGRect(x: 0, y: 120, width: 390, height: 60))
        window.rootViewController!.view.addSubview(bar)
        bar.items = [SPTabBarItem(title: "推荐"), SPTabBarItem(title: "编辑精选与深度阅读")]
        let provider = DemoIndicatorProvider()
        let renderer = DemoIndicatorView()
        bar.indicatorStyle = .custom
        bar.indicatorLayoutDelegate = provider
        bar.indicatorView = renderer
        bar.standardAppearance.indicatorLayout = SPTabBarIndicatorLayout()
        bar.setSelectedIndex(0, animated: false)
        window.layoutIfNeeded()
        bar.layoutIfNeeded()
        let gradient = try XCTUnwrap(renderer.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        for radius: SPTabBarIndicatorLayout.CornerRadius in [.automatic, .fixed(0), .fixed(1), .fixed(99), .automatic] {
            bar.standardAppearance.indicatorLayout?.cornerRadius = radius
            for progress: CGFloat in [0, 0.4, 1, 0] {
                bar.setTransitionProgress(from: 0, to: 1, progress: progress)
                let half = min(renderer.bounds.width, renderer.bounds.height) / 2
                let expected: CGFloat = if case let .fixed(value) = radius { min(value, half) } else { half }
                XCTAssertGreaterThan(half, 0)
                XCTAssertEqual(gradient.cornerRadius, expected, accuracy: 0.01)
                XCTAssertEqual(gradient.frame, renderer.bounds)
            }
        }
        withExtendedLifetime(provider) {}
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        window.layoutIfNeeded()
    }
}
