import UIKit
import StickyPagerKit

/// 独立标签栏：无需分页容器即可选择，并观察 Item 的运行时变化。
@MainActor
final class TabBarGallery: UIViewController, SPTabBarDelegate {
    private let bar = SPTabBar()
    private let indicatorProvider = DemoIndicatorProvider()
    private let contentProvider = DemoTabContentProvider()
    private let status = RegressionStatusLabel()
    private let tabs = [
        SPTabBarItem(title: "推荐"),
        SPTabBarItem(title: "收藏", image: UIImage(systemName: "star"), selectedImage: UIImage(systemName: "star.fill")),
        SPTabBarItem(title: "", image: UIImage(systemName: "bell")),
        SPTabBarItem(title: "暂不可用", image: UIImage(systemName: "lock")),
        SPTabBarItem(title: "更多专题与活动", image: UIImage(systemName: "folder"))
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "标签外观"
        view.backgroundColor = .systemBackground
        tabs[1].badgeValue = "12"
        tabs[2].badgeValue = ""
        tabs[2].accessibilityLabel = "通知"
        tabs[3].isEnabled = false
        if ProcessInfo.processInfo.arguments.contains("--chinese-badges") {
            tabs[0].badgeValue = "新"
            tabs[1].badgeValue = "上新"
            tabs[4].badgeValue = "待更新"
        }
        if ProcessInfo.processInfo.arguments.contains("--rtl") {
            bar.semanticContentAttribute = .forceRightToLeft
        }
        bar.items = tabs
        bar.selectedItem = tabs[0]
        bar.delegate = self
        bar.contentDelegate = contentProvider
        indicatorProvider.contentProvider = contentProvider
        view.addSubview(bar)
        if ProcessInfo.processInfo.arguments.contains("--accessories") {
            bar.items += (1 ... 8).map { SPTabBarItem(title: "专题频道 \($0)") }
            DemoTabBarAccessories.install(on: bar, owner: self, leading: true, trailing: true)
            bar.layoutConfiguration.contentInsets = NSDirectionalEdgeInsets(
                top: 6,
                leading: 16,
                bottom: 6,
                trailing: 16
            )
        }
        status.numberOfLines = 0
        status.accessibilityIdentifier = "demo.gallery.status"
        status.font = .preferredFont(forTextStyle: .body)
        status.adjustsFontForContentSizeCategory = true
        status.text = "独立使用：点击标签可选择；拖动可浏览更多标签。右上角可切换布局、样式和动态内容。"
        view.addSubview(status)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "配置", menu: UIMenu(children: [
            DemoTabBarPositioning.menu(for: bar),
            DemoTabBarPositioning.contentMenu(for: bar),
            DemoTabBarAccessories.menu(for: bar, owner: self),
            indicatorProvider.menu(for: bar),
            UIMenu(title: "标签间距", children: [0, 8, 16, 24].map { spacing in
                UIAction(title: "项间距 \(spacing)") { [weak self] _ in
                    self?.bar.layoutConfiguration.itemSpacing = CGFloat(spacing)
                }
            }),
            UIAction(title: "默认内容") { [weak self] _ in self?.bar.contentStyle = .default },
            UIAction(title: "自定义卡片") { [weak self] _ in
                guard let self else {
                    return
                }
                self.contentProvider.usesCompactContent = false
                self.contentProvider.showCustomContent(on: self.bar)
            },
            UIAction(title: "紧凑编号内容") { [weak self] _ in
                guard let self else {
                    return
                }
                self.contentProvider.usesCompactContent = true
                self.contentProvider.usesNumberContent = true
                self.contentProvider.showCustomContent(on: self.bar)
            },
            UIAction(title: "自动图文排列") { [weak self] _ in
                self?.bar.defaultContentLayout.imagePlacement = .automatic
            },
            UIAction(title: "上下图文") { [weak self] _ in self?.bar.defaultContentLayout.imagePlacement = .stacked },
            UIAction(title: "横向图文") { [weak self] _ in self?.bar.defaultContentLayout.imagePlacement = .inline },
            UIAction(title: "胶囊") { [weak self] _ in
                guard let self else {
                    return
                }
                self.indicatorProvider.selectStyle(.capsule, on: self.bar)
            },
            UIAction(title: "下划线") { [weak self] _ in
                guard let self else {
                    return
                }
                self.indicatorProvider.selectStyle(.underline, on: self.bar)
            },
            UIAction(title: "隐藏指示器") { [weak self] _ in
                guard let self else {
                    return
                }
                self.indicatorProvider.selectStyle(.none, on: self.bar)
            },
            UIAction(title: "更新内容") { [weak self] _ in
                guard let self else {
                    return
                }
                self.tabs[1].badgeValue = self.tabs[1].badgeValue == "12" ? "99+" : "12"
                self.tabs[0].title = self.tabs[0].title == "推荐" ? "为你推荐的新内容" : "推荐"
            },
            UIAction(title: "启用或禁用第四项") { [weak self] _ in self?.tabs[3].isEnabled.toggle() }
        ]))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        indicatorProvider.updateContentStyle(on: bar)
        let safe = view.safeAreaInsets
        let barWidth = ProcessInfo.processInfo.arguments.contains("--narrow-tabs") ? min(240, view.bounds.width) : view
            .bounds.width
        bar.frame = CGRect(
            x: 0,
            y: safe.top + 20,
            width: barWidth,
            height: bar.sizeThatFits(CGSize(width: barWidth, height: view.bounds.height)).height
        )
        let width = max(0, view.bounds.width - safe.left - safe.right - 40)
        status.frame = CGRect(
            x: safe.left + 20,
            y: bar.frame.maxY + 24,
            width: width,
            height: status.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        )
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        status.text = "已选择：\(item.accessibilityLabel ?? item.title ?? "未命名")\n角标：\(item.badgeValue ?? "无")"
        view.setNeedsLayout()
    }
}
