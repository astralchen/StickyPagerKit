import Testing
import UIKit
import StickyPagerKit
@testable import StickyPagerDemo

/// 在真实应用宿主中验证最小示例的接入契约；窗口测试串行执行，避免相互覆盖 key window。
@Suite(.serialized)
@MainActor
struct StickyPagerDemoTests {
    @Test func minimalDataSourceCreatesIndependentPages() throws {
        let integration = MinimalIntegration()
        let pager = SPPageViewController()
        #expect(integration.numberOfPages(in: pager) == 2)
        #expect(integration.pageViewController(pager, identifierForPageAt: 0) == AnyHashable("first"))
        #expect(integration.pageViewController(pager, identifierForPageAt: 1) == AnyHashable("second"))
        #expect(integration.pageViewController(pager, tabBarItemAt: 0).title == "页面 1")
        #expect(integration.pageViewController(pager, tabBarItemAt: 1).title == "页面 2")

        let first = integration.pageViewController(pager, viewControllerAt: 0)
        let second = integration.pageViewController(pager, viewControllerAt: 1)
        #expect(first !== second)
        #expect(first.parent == nil)
        #expect(second.parent == nil)
        let firstScroll = try #require(first.view as? UIScrollView)
        let secondScroll = try #require(second.view as? UIScrollView)
        #expect(firstScroll !== secondScroll)
        #expect(firstScroll.contentSize.height == 1500)
        #expect(secondScroll.contentSize.height == 1500)
        firstScroll.contentOffset.y = 100
        #expect(secondScroll.contentOffset.y == 0)
    }

    @Test func minimalIntegrationInstallsAndLaysOutPager() async throws {
        let integration = MinimalIntegration()
        try await withWindow(root: integration) { window in
            let pager = try pager(in: integration)
            #expect(integration.children.count == 1)
            #expect(pager.parent === integration)
            #expect(pager.view.superview === integration.view)
            #expect(pager.dataSource === integration)
            #expect(pager.view.window === window)
            #expect(pager.view.frame == integration.view.bounds)
            #expect(pager.view.bounds.width > 0)
            #expect(pager.view.bounds.height > 0)
            #expect(!pager.view.hasAmbiguousLayout)
            #expect((pager.headerView as? UILabel)?.text == "我的页面")
            #expect(pager.layout.headerHeight == 220)
            #expect(pager.tabBar.items.map(\.title) == ["页面 1", "页面 2"])
            #expect(pager.selectedIndex == 0)
            #expect(pager.tabBar.selectedIndex == 0)
            let page = try #require(pager.children.first)
            #expect(page.parent === pager)
            #expect(page.view.window === window)
            #expect(page.view is UIScrollView)

            // 重复加载不能重复安装容器；稳定标识重载后保留当前页面实例。
            integration.loadViewIfNeeded()
            pager.reloadData()
            await settle(window)
            #expect(integration.children.count == 1)
            #expect(pager.children.contains { $0 === page })
            #expect(pager.selectedIndex == 0)
        }
    }

    @Test func pageAppearanceFollowsSelectionAndNavigation() async throws {
        let integration = MinimalIntegration()
        let pager = try pager(in: integration)
        let firstPage = try #require(pager.children.first)
        // 旁路观察实际页面的自动 appearance 转发，不替换示例的数据源或页面。
        let probe = AppearanceProbe()
        firstPage.addChild(probe)
        firstPage.view.addSubview(probe.view)
        probe.didMove(toParent: firstPage)
        let navigation = UINavigationController(rootViewController: integration)

        try await withWindow(root: navigation) { window in
            await waitForEvents(probe, count: 2, in: window)
            #expect(probe.events == [.willAppear, .didAppear])
            pager.setSelectedIndex(1, animated: false)
            await settle(window)
            await waitForEvents(probe, count: 4, in: window)
            #expect(pager.selectedIndex == 1)
            #expect(pager.tabBar.selectedIndex == 1)
            #expect(probe.events == [.willAppear, .didAppear, .willDisappear, .didDisappear])
            pager.setSelectedIndex(0, animated: false)
            await settle(window)
            #expect(pager.children.contains { $0 === firstPage })
            await waitForEvents(probe, count: 6, in: window)
            #expect(probe.events == [.willAppear, .didAppear, .willDisappear, .didDisappear, .willAppear, .didAppear])

            probe.events.removeAll()
            navigation.pushViewController(UIViewController(), animated: false)
            await settle(window)
            await waitForEvents(probe, count: 2, in: window)
            #expect(probe.events == [.willDisappear, .didDisappear])
            #expect(integration.view.window == nil)
            navigation.popViewController(animated: false)
            await settle(window)
            #expect(navigation.topViewController === integration)
            #expect(integration.view.window === window)
            await waitForEvents(probe, count: 4, in: window)
            #expect(probe.events == [.willDisappear, .didDisappear, .willAppear, .didAppear])
        }
        #expect(probe.events == [.willDisappear, .didDisappear, .willAppear, .didAppear, .willDisappear, .didDisappear])
    }

    @Test func poppingMinimalIntegrationReleasesControllerTree() async throws {
        let navigation = UINavigationController(rootViewController: UIViewController())
        weak var releasedIntegration: MinimalIntegration?
        weak var releasedPager: SPPageViewController?
        weak var releasedPage: UIViewController?
        weak var releasedScroll: UIScrollView?
        weak var releasedHeader: UIView?

        try await withWindow(root: navigation) { window in
            try autoreleasepool {
                let integration = MinimalIntegration()
                navigation.pushViewController(integration, animated: false)
                settleSynchronously(window)
                let pager = try pager(in: integration)
                let page = try #require(pager.children.first)
                releasedIntegration = integration
                releasedPager = pager
                releasedPage = page
                releasedScroll = try #require(page.view as? UIScrollView)
                let header: UIView = try #require(pager.headerView)
                releasedHeader = header
                #expect(integration.view.window === window)
                #expect(navigation.popViewController(animated: false) === integration)
                settleSynchronously(window)
                #expect(integration.parent == nil)
                #expect(integration.view.window == nil)
                #expect(navigation.viewControllers.count == 1)
            }
            await settle(window)
            #expect(releasedIntegration == nil)
            #expect(releasedPager == nil)
            #expect(releasedPage == nil)
            #expect(releasedScroll == nil)
            #expect(releasedHeader == nil)
        }
    }

    private func pager(in integration: MinimalIntegration) throws -> SPPageViewController {
        integration.loadViewIfNeeded()
        return try #require(integration.children.compactMap { $0 as? SPPageViewController }.first)
    }

    private func withWindow(root: UIViewController, body: (UIWindow) async throws -> Void) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        await settle(window)
        do {
            try await body(window)
        } catch {
            await close(window, restoring: previousKeyWindow)
            throw error
        }
        await close(window, restoring: previousKeyWindow)
    }

    private func close(_ window: UIWindow, restoring previousKeyWindow: UIWindow?) async {
        // 在窗口仍可见时拆除根控制器，让 UIKit 完整发送消失回调。
        window.rootViewController = nil
        await settle(window)
        window.isHidden = true
        previousKeyWindow?.makeKey()
    }

    private func waitForEvents(_ probe: AppearanceProbe, count: Int, in window: UIWindow) async {
        let deadline = Date(timeIntervalSinceNow: 2)
        while probe.events.count < count, Date() < deadline {
            await settle(window)
        }
        // 调用处继续比较完整序列，缺少、重复和乱序回调都会失败。
    }

    private func settle(_ window: UIWindow) async {
        window.layoutIfNeeded()
        CATransaction.flush()
        // 让出主 actor，允许 UIKit 提交事务并交付异步 appearance 回调。
        try? await Task.sleep(nanoseconds: 50_000_000)
        window.layoutIfNeeded()
    }

    private func settleSynchronously(_ window: UIWindow) {
        // 仅用于 autoreleasepool 内的非动画 push/pop；离开作用域后再异步等待释放。
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        window.layoutIfNeeded()
    }
}

@MainActor
private final class AppearanceProbe: UIViewController {
    enum Event: Equatable {
        case willAppear, didAppear, willDisappear, didDisappear
    }

    var events: [Event] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        events.append(.willAppear)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        events.append(.didAppear)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        events.append(.willDisappear)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        events.append(.didDisappear)
    }
}
