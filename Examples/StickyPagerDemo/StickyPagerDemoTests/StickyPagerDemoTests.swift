import Testing
import UIKit
import StickyPagerKit
@testable import StickyPagerDemo

/// 在真实应用宿主中验证最小示例的接入契约；窗口测试串行执行，避免相互覆盖 key window。
@Suite(.serialized)
@MainActor
struct StickyPagerDemoTests {
    @available(iOS 16, *)
    @Test(.enabled { await UIDevice.current.userInterfaceIdiom == .phone })
    func pinnedShortTableIndicatorFollowsRotation() async throws {
        // 真机测试宿主可在场景激活前开始执行，等应用窗口就绪后再驱动旋转。
        func activeWindow() -> UIWindow? {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?.keyWindow
        }
        let deadline = Date(timeIntervalSinceNow: 5)
        while activeWindow() == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let window = try #require(activeWindow())
        let scene = try #require(window.windowScene)
        let navigation = try #require(window.rootViewController as? UINavigationController)
        let pager = DemoPager()
        navigation.pushViewController(pager, animated: false)
        defer {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            navigation.popViewController(animated: false)
        }
        await settle(window)
        pager.setSelectedIndex(2, animated: false)
        await settle(window)
        let page = try #require(pager.children.compactMap { $0 as? DemoList }.first { $0.count == 3 })
        let table = try #require(page.tableView)
        #expect(table.numberOfRows(inSection: 0) == 3)
        for _ in 0 ..< 2 {
            table.contentOffset.y = table.contentSize.height + table.adjustedContentInset.bottom - table.bounds.height
            await settle(window)
        }
        func currentDirection() -> UIInterfaceOrientation {
            if #available(iOS 26, *) {
                return scene.effectiveGeometry.interfaceOrientation
            }
            return scene.interfaceOrientation
        }
        for direction: UIInterfaceOrientation in [.portrait, .landscapeRight, .landscapeLeft, .portrait] {
            let mask = UIInterfaceOrientationMask(rawValue: 1 << direction.rawValue)
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                Issue.record("场景旋转失败：\(error)")
            }
            for _ in 0 ..< 80 {
                await settle(window)
                if currentDirection() == direction, navigation.transitionCoordinator == nil {
                    break
                }
            }
            try #require(currentDirection() == direction)
            table.flashScrollIndicators()
            await settle(window)
            let thumb = try verticalThumbFrame(in: table, window: window)
            let safe = table.convert(table.safeAreaLayoutGuide.layoutFrame, to: window)
            let tabs = pager.tabBar.convert(pager.tabBar.bounds, to: window)
            let nav = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: window)
            print("短列表方向 \(direction.rawValue)，安全区 \(safe)，滑块 \(thumb)，标签栏 \(tabs)，导航栏 \(nav)")
            let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).pngData { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            Attachment.record(Array(screenshot), named: "短列表-方向\(direction.rawValue).png")
            #expect(abs(tabs.minY - nav.maxY) <= 1)
            #expect(thumb.minX >= safe.minX - 1)
            #expect(thumb.maxX <= safe.maxX + 1)
            #expect(thumb.minY >= tabs.maxY - 1)
            #expect(thumb.maxY <= safe.maxY + 1)
        }
    }

    @Test func bounceListIndicatorStaysInsideVisibleContent() async throws {
        let pager = BounceDemoPager()
        let navigation = UINavigationController(rootViewController: pager)
        try await withWindow(root: navigation) { window in
            let page = try #require(pager.children.first)
            let scroll = try #require(page.view.subviews.compactMap { $0 as? UIScrollView }.first)
            for atBottom in [false, true] {
                if atBottom {
                    // 先折叠 Header，再按吸顶后的视口高度滚到底。
                    scroll.contentOffset.y = scroll.contentSize.height / 2
                    await settle(window)
                    scroll.contentOffset.y = scroll.contentSize.height + scroll.adjustedContentInset.bottom
                        - scroll.bounds.height
                }
                scroll.flashScrollIndicators()
                await settle(window)
                // 读取列表中实际显示的纵向滑块，避免把 inset 的配置值当作 UIKit 的绘制位置。
                let frame = try verticalThumbFrame(in: scroll, window: window)
                let top = pager.tabBar.convert(pager.tabBar.bounds, to: window).maxY
                let bottom = window.safeAreaLayoutGuide.layoutFrame.maxY
                print("滚动指示器：到底 \(atBottom)，滑块 \(frame)，可见范围 \(top)...\(bottom)")
                if atBottom {
                    if #available(iOS 26, *) {
                        // 新系统按设备圆角布局轨道，用同一窗口中原生滚动视图的底端作参照。
                        let reference = UIScrollView(frame: scroll.convert(scroll.bounds, to: window))
                        window.addSubview(reference)
                        defer { reference.removeFromSuperview() }
                        reference.contentSize = scroll.contentSize
                        await settle(window)
                        reference.contentOffset.y = reference.contentSize.height + reference.adjustedContentInset.bottom
                            - reference.bounds.height
                        reference.flashScrollIndicators()
                        await settle(window)
                        let native = try verticalThumbFrame(in: reference, window: window)
                        print("原生滑块 \(native)，滚动视口 \(reference.frame)")
                        #expect(abs(frame.maxY - native.maxY) <= 1)
                    } else {
                        #expect(abs(frame.maxY - bottom) <= 5)
                    }
                } else {
                    #expect(abs(frame.minY - top) <= 5)
                }
            }
        }
    }

    @Test func explicitlyBoundListHonorsBusinessIndicatorInsets() async throws {
        let integration = MinimalIntegration()
        try await withWindow(root: integration) { window in
            let pager = try pager(in: integration)
            let scroll = try #require(pager.children.first?.view as? UIScrollView)
            pager.setScrollViewBinding(.unbound, forPageAt: 0)
            let base = UIEdgeInsets(top: 0, left: 0, bottom: 11, right: 0)
            scroll.verticalScrollIndicatorInsets = base
            let horizontal = scroll.horizontalScrollIndicatorInsets
            pager.setScrollView(scroll, forPageAt: 0)
            scroll.contentOffset.y = scroll.contentSize.height / 2
            await settle(window)
            scroll.contentOffset.y = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset
                .bottom
            scroll.flashScrollIndicators()
            await settle(window)
            let custom = try verticalThumbFrame(in: scroll, window: window)
            scroll.verticalScrollIndicatorInsets.bottom = 0
            scroll.flashScrollIndicators()
            await settle(window)
            let automatic = try verticalThumbFrame(in: scroll, window: window)
            print("显式绑定：业务 11 pt 时滑块底端 \(custom.maxY)，业务归零后 \(automatic.maxY)")
            if #unavailable(iOS 26) {
                #expect(abs(automatic.maxY - window.safeAreaLayoutGuide.layoutFrame.maxY) <= 5)
                #expect(abs(automatic.maxY - custom.maxY - base.bottom) <= 1)
            }
            #expect(scroll.automaticallyAdjustsScrollIndicatorInsets)
            scroll.verticalScrollIndicatorInsets.left = 7
            pager.setScrollViewBinding(.unbound, forPageAt: 0)
            #expect(scroll.verticalScrollIndicatorInsets == UIEdgeInsets(top: 0, left: 7, bottom: 0, right: 0))
            #expect(scroll.horizontalScrollIndicatorInsets == horizontal)
        }
    }

    private func verticalThumbFrame(in scroll: UIScrollView, window: UIWindow) throws -> CGRect {
        let thumb = try #require(scroll.subviews.first {
            $0.alpha > 0 && !$0.isHidden && $0.bounds.width > 0
                && $0.bounds.width < 10 && $0.bounds.height > $0.bounds.width
        })
        return thumb.convert(thumb.bounds, to: window)
    }

    @Test func firstListSelectionKeepsCellsAlignedDuringAnimation() async throws {
        let pager = DemoPager()
        let navigation = UINavigationController(rootViewController: pager)
        try await withWindow(root: navigation) { window in
            pager.setSelectedIndex(1, animated: true)
            let page = try #require(pager.children.compactMap { $0 as? DemoList }.first)
            let table = try #require(page.tableView)
            var gaps: [CGFloat] = []
            for _ in 0 ..< 35 {
                try await Task.sleep(nanoseconds: 16_000_000)
                let frame = table.convert(table.rectForRow(at: IndexPath(row: 0, section: 0)), to: window)
                let tabFrame = pager.tabBar.convert(pager.tabBar.bounds, to: window)
                if frame.maxX > window.bounds.minX, frame.minX < window.bounds.maxX {
                    gaps.append(frame.minY - tabFrame.maxY)
                }
            }
            #expect(pager.selectedIndex == 1)
            #expect(gaps.count > 5)
            #expect(gaps.allSatisfy { abs($0) < 1 }, "首行在横向进入期间应始终贴齐标签栏底边：\(gaps)")
        }
    }

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
