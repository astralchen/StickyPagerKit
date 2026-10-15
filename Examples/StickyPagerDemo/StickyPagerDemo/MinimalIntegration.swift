import UIKit
import StickyPagerKit

/// 可直接用作导航栈入口的最小接入示例。
@MainActor
final class MinimalIntegration: UIViewController, SPPageViewControllerDataSource {
    private let pager = SPPageViewController()
    private let identifiers = ["first", "second"]

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(pager)
        view.addSubview(pager.view)
        pager.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pager.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pager.view.topAnchor.constraint(equalTo: view.topAnchor),
            pager.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pager.didMove(toParent: self)
        let header = UILabel()
        header.text = "我的页面"
        header.textAlignment = .center
        pager.headerView = header
        pager.layout = SPPageLayout(headerHeight: 220)
        pager.dataSource = self
        pager.reloadData()
    }
    func numberOfPages(in pageViewController: SPPageViewController) -> Int { identifiers.count }
    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable { identifiers[index] }
    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem { SPTabBarItem(title: "页面 \(index + 1)") }
    func pageViewController(_ pageViewController: SPPageViewController, viewControllerAt index: Int) -> UIViewController {
        let controller = UIViewController()
        let scroll = UIScrollView()
        scroll.contentSize = CGSize(width: 1, height: 1500)
        scroll.backgroundColor = index == 0 ? .secondarySystemBackground : .tertiarySystemBackground
        controller.view = scroll
        return controller
    }
}
