import UIKit
import StickyPagerKit

/// 独立标签栏：无需分页容器即可选择，并观察 Item 的运行时变化。
@MainActor
final class TabBarGallery: UIViewController, SPTabBarDelegate {
    private let bar = SPTabBar()
    private let status = UILabel()
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
        bar.items = tabs
        bar.selectedItem = tabs[0]
        bar.delegate = self
        view.addSubview(bar)
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .body)
        status.adjustsFontForContentSizeCategory = true
        status.text = "独立使用：点击标签可选择；拖动可浏览更多标签。右上角可切换布局、样式和动态内容。"
        view.addSubview(status)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "配置", menu: UIMenu(children: [
            UIAction(title: "自动布局") { [weak self] _ in self?.bar.standardAppearance.itemAppearance.layout = .automatic },
            UIAction(title: "上下图文") { [weak self] _ in self?.bar.standardAppearance.itemAppearance.layout = .stacked },
            UIAction(title: "横向图文") { [weak self] _ in self?.bar.standardAppearance.itemAppearance.layout = .inline },
            UIAction(title: "胶囊") { [weak self] _ in self?.bar.standardAppearance.selectionStyle = .capsule },
            UIAction(title: "下划线") { [weak self] _ in
                self?.bar.standardAppearance.selectionStyle = .underline
                self?.bar.standardAppearance.selectionColor = .label
            },
            UIAction(title: "隐藏选中背景") { [weak self] _ in self?.bar.standardAppearance.selectionStyle = .none },
            UIAction(title: "更新内容") { [weak self] _ in
                guard let self else { return }
                self.tabs[1].badgeValue = self.tabs[1].badgeValue == "12" ? "99+" : "12"
                self.tabs[0].title = self.tabs[0].title == "推荐" ? "为你推荐的新内容" : "推荐"
            },
            UIAction(title: "启用或禁用第四项") { [weak self] _ in self?.tabs[3].isEnabled.toggle() }
        ]))
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        bar.frame = CGRect(x: 0, y: safe.top + 20, width: view.bounds.width, height: bar.sizeThatFits(view.bounds.size).height)
        let width = max(0, view.bounds.width - safe.left - safe.right - 40)
        status.frame = CGRect(x: safe.left + 20, y: bar.frame.maxY + 24, width: width, height: status.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        status.text = "已选择：\(item.accessibilityLabel ?? item.title ?? "未命名")\n角标：\(item.badgeValue ?? "无")"
        view.setNeedsLayout()
    }
}
