import UIKit

/// 使用系统容器传递安全区域，不在 Demo 中补偿系统栏高度。
@MainActor
final class DemoSystemContainer: UITabBarController {
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        if ProcessInfo.processInfo.arguments.contains("--rtl") {
            view.semanticContentAttribute = .forceRightToLeft
        }
        tabBar.accessibilityIdentifier = "demo.systemTabBar"
        let pager = DemoPager()
        pager.usesSystemContainer = true
        let demo = UINavigationController(rootViewController: pager)
        demo.tabBarItem = UITabBarItem(title: "联动演示", image: UIImage(systemName: "rectangle.stack"), tag: 0)
        demo.tabBarItem.accessibilityIdentifier = "demo.systemTab.pager"
        let info = UINavigationController(rootViewController: DemoContainerInfo())
        info.tabBarItem = UITabBarItem(title: "布局说明", image: UIImage(systemName: "info.circle"), tag: 1)
        info.tabBarItem.accessibilityIdentifier = "demo.systemTab.info"
        setViewControllers([demo, info], animated: false)
    }

    static func closeItem(for controller: UIViewController) -> UIBarButtonItem {
        let item = UIBarButtonItem(title: "关闭", primaryAction: UIAction { [weak controller] _ in
            controller?.tabBarController?.dismiss(animated: true)
        })
        item.accessibilityIdentifier = "demo.systemContainer.close"
        return item
    }
}

@MainActor
private final class DemoContainerInfo: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "布局说明"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = DemoSystemContainer.closeItem(for: self)
        let text = UITextView()
        text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        text.text = """
        系统容器层级

        UITabBarController → UINavigationController → DemoPager（UIViewController）

        顶部安全区域

        Header 背景从容器顶部铺开。向上滚动后，组件标签栏停在顶部安全区域下缘；导航栏的实际布局决定该位置。

        底部安全区域

        子页面背景延伸至容器底边。列表通过 UIKit 的 adjustedContentInset 避让系统 Tab Bar，普通页面中的控件使用 safeAreaLayoutGuide。

        观察方式

        在「联动演示」中上下滚动折叠或展开 Header，点击标签或横向滑动切页，将列表滚动到末项，并旋转设备对照布局。系统 Tab Bar 与内容上方的组件标签栏彼此独立。

        「页面」菜单可切换 Header 类型与高度。切换底部系统标签后返回，可继续观察原页面的滚动位置。
        """
        text.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            text.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            text.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
