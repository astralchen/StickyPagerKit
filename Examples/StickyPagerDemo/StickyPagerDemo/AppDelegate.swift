import UIKit
import StickyPagerKit

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@MainActor
final class DemoLauncher: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "StickyPagerKit"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "标签外观", primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(TabBarGallery(), animated: true)
        })
        let button = UIButton(type: .system)
        button.setTitle("打开演示", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        button.accessibilityIdentifier = "demo.open"
        button.addAction(
            UIAction { [weak self] _ in self?.navigationController?.pushViewController(DemoPager(), animated: true) },
            for: .touchUpInside
        )
        let systemButton = UIButton(type: .system)
        systemButton.setTitle("系统容器演示", for: .normal)
        systemButton.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        systemButton.accessibilityIdentifier = "demo.openSystemContainer"
        systemButton.addAction(UIAction { [weak self] _ in
            self?.present(DemoSystemContainer(), animated: true)
        }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [button, systemButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for entry in [button, systemButton] {
            entry.titleLabel?.adjustsFontForContentSizeCategory = true
            entry.titleLabel?.numberOfLines = 0
            entry.titleLabel?.textAlignment = .center
            entry.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }
}

@MainActor
final class DemoPager: SPPageViewController, SPPageViewControllerDataSource, SPPageViewControllerDelegate {
    /// 由入口在加载视图前设置；系统容器场景只保留 UITabBar 的底部遮挡。
    var usesSystemContainer = false
    private var pageIDs = [
        "grid",
        "list",
        "short",
        "empty",
        "plain",
        "async",
        "hot",
        "recommended",
        "following",
        "weekly",
        "saved",
        "compositional",
        "topics"
    ]
    private let names = [
        "grid": "网格",
        "list": "列表",
        "short": "短列表",
        "empty": "空列表",
        "plain": "普通页",
        "async": "异步页",
        "hot": "热",
        "recommended": "推荐内容",
        "following": "关注",
        "weekly": "本周热门精选",
        "saved": "收藏",
        "topics": "更多专题与活动",
        "compositional": "组合布局"
    ]
    private let status = RegressionStatusLabel()
    private let indicatorProvider = DemoIndicatorProvider()
    private let customTabProvider = DemoTabContentProvider()
    private var controllerHeader = false
    private var generation = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = usesSystemContainer ? "联动演示" : "StickyPagerKit"
        if ProcessInfo.processInfo.arguments.contains("--rtl") {
            view.semanticContentAttribute = .forceRightToLeft
        }
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        // iOS 26 使用系统透明导航栏和 scroll edge effect，保留原生玻璃外观。
        if #unavailable(iOS 26.0) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance
            navigationItem.compactScrollEdgeAppearance = appearance
        }
        dataSource = self
        delegate = self
        tabBar.contentDelegate = customTabProvider
        if ProcessInfo.processInfo.arguments.contains("--custom-tabs") {
            tabBar.contentStyle = .custom
        }
        headerView = DemoHeaderView()
        layout = SPPageLayout(headerHeight: 220)
        let headerAction = UIAction(title: "切换 Header 类型") { [weak self] _ in self?.toggleHeader() }
        let header = UIBarButtonItem(title: "Header", primaryAction: headerAction)
        header.accessibilityIdentifier = "demo.header"
        let heightAction = UIAction(title: "切换 Header 高度") { [weak self] _ in
            guard let self else {
                return
            }
            self.layout.headerHeight = self.layout.headerHeight == 220 ? 300 : 220
            self.updateStatus()
        }
        let height = UIBarButtonItem(title: "高度", primaryAction: heightAction)
        height.accessibilityIdentifier = "demo.height"
        let pages = UIBarButtonItem(title: "页面", menu: UIMenu(children: [
            indicatorProvider.menu(for: tabBar),
            headerAction,
            heightAction,
            UIAction(title: "切换自定义标签") { [weak self] _ in
                guard let self else {
                    return
                }
                self.tabBar.contentStyle = self.tabBar.contentStyle == .custom ? .default : .custom
            },
            UIAction(title: "切换紧凑标签") { [weak self] _ in
                guard let self else {
                    return
                }
                self.customTabProvider.usesCompactContent.toggle()
                self.tabBar.contentStyle = .custom
                self.tabBar.reloadContent()
            },
            UIMenu(title: "标签间距", children: [0, 8, 16, 24].map { spacing in
                UIAction(title: "项间距 \(spacing)") { [weak self] _ in
                    self?.tabBar.itemSpacing = CGFloat(spacing)
                }
            }),
            UIMenu(title: "标签宽度", children: [
                UIAction(title: "紧凑编号内容") { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.customTabProvider.usesCompactContent = true
                    self.customTabProvider.usesNumberContent = true
                    self.customTabProvider.usesWideContent = false
                    self.tabBar.contentStyle = .custom
                    self.tabBar.reloadContent()
                    self.setSelectedIndex(0, animated: false)
                },
                UIAction(title: "不可压缩宽内容") { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.customTabProvider.usesCompactContent = true
                    self.customTabProvider.usesNumberContent = false
                    self.customTabProvider.usesWideContent = true
                    self.tabBar.contentStyle = .custom
                    self.tabBar.reloadContent()
                    self.setSelectedIndex(0, animated: false)
                }
            ] + [24, 44, 120].map { width in
                UIAction(title: "最小项宽 \(width)") { [weak self] _ in
                    self?.tabBar.minimumItemWidth = CGFloat(width)
                }
            }),
            UIMenu(title: "标签栏最小高度", children: [32, 60, 0, 44].map { height in
                UIAction(title: height == 0 ? "隐藏标签栏" : "最小栏高 \(height)") { [weak self] _ in
                    self?.layout.tabBarHeight = CGFloat(height)
                }
            }),
            UIAction(title: "切换多行副标题") { [weak self] _ in
                guard let self else {
                    return
                }
                self.customTabProvider.subtitle = self.customTabProvider.subtitle.count > 4 ? "浏览专题" : "这段副标题通过内部约束自动换行，标签栏随内容更新高度，无需业务计算宽高。"
                self.tabBar.reloadContent()
            },
            UIAction(title: "刷新自定义内容") { [weak self] _ in
                guard let self else {
                    return
                }
                self.customTabProvider.subtitle = self.customTabProvider.subtitle == "浏览专题" ? "最新内容" : "浏览专题"
                self.tabBar.reloadContent()
            },
            UIAction(title: "组合布局 · 嵌套滚动") { [weak self] _ in
                guard let self, let index = self.pageIDs.firstIndex(of: "compositional") else {
                    return
                }
                self.setSelectedIndex(index, animated: false)
            },
            UIAction(title: "切换图文标签") { [weak self] _ in
                guard let self else {
                    return
                }
                for (index, item) in self.tabBar.items.enumerated() {
                    item.image = item
                        .image == nil ? UIImage(systemName: index.isMultiple(of: 2) ? "star" : "folder") : nil
                    item.selectedImage = item
                        .image == nil ? nil : UIImage(systemName: index.isMultiple(of: 2) ? "star.fill" : "folder.fill")
                }
            },
            UIAction(title: "更新角标和标题") { [weak self] _ in
                guard let item = self?.tabBar.items.first else {
                    return
                }
                item.badgeValue = item.badgeValue == nil ? "99+" : nil
                item.title = item.badgeValue == nil ? "网格" : "新作品"
            },
            UIAction(title: "切换第二项禁用") { [weak self] _ in
                guard let self, self.tabBar.items.count > 1 else {
                    return
                }
                self.tabBar.items[1].isEnabled.toggle()
            },
            UIAction(title: "切换指示器样式") { [weak self] _ in
                guard let self else {
                    return
                }
                self.tabBar.indicatorStyle = self.tabBar.indicatorStyle == .capsule ? .underline : .capsule
                let appearance = self.tabBar.standardAppearance
                appearance.indicatorLayout = nil
                appearance.indicatorColor = nil
            },
            UIAction(title: "重排页面") { [weak self] _ in
                guard let self else {
                    return
                }; self.pageIDs.reverse(); self.reloadData(); self.updateStatus()
            },
            UIAction(title: "删除当前页") { [weak self] _ in
                guard let self,
                      let i = self.selectedIndex else {
                    return
                }; self.pageIDs.remove(at: i); self.reloadData(); self.updateStatus()
            },
            UIAction(title: "添加页面") { [weak self] _ in
                guard let self else {
                    return
                }; self.generation += 1; self.pageIDs.append("new\(self.generation)"); self.reloadData()
            },
            UIAction(title: "清空页面") { [weak self] _ in self?.pageIDs = []; self?.reloadData(); self?.updateStatus() }
        ]))
        pages.accessibilityIdentifier = "demo.pages"
        navigationItem.rightBarButtonItems = usesSystemContainer ? [pages] : [pages, height, header]
        status.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        status.accessibilityIdentifier = "demo.status"
        status.textAlignment = .center
        if usesSystemContainer {
            status.numberOfLines = 2
            status.font = .preferredFont(forTextStyle: .caption1)
            status.adjustsFontForContentSizeCategory = true
            navigationItem.titleView = status
            navigationItem.leftBarButtonItem = DemoSystemContainer.closeItem(for: self)
        } else {
            toolbarItems = [UIBarButtonItem(customView: status)]
        }
        reloadData()
        if ProcessInfo.processInfo.arguments.contains("--compositional"),
           let index = pageIDs.firstIndex(of: "compositional") {
            setSelectedIndex(index, animated: false)
        }
        updateStatus()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(usesSystemContainer, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderContentClip()
    }

    private func updateHeaderContentClip() {
        guard let header = (headerView ?? headerViewController?.view) as? DemoHeaderView else {
            return
        }
        if #available(iOS 26.0, *) {
            header.clipContent(below: 0); return
        }
        // 旧系统没有 scroll edge effect，标题在导航栏下缘裁剪。
        let top = header.convert(CGPoint(x: 0, y: view.safeAreaInsets.top), from: view).y
        header.clipContent(below: top)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    private func toggleHeader() {
        controllerHeader.toggle()
        if controllerHeader {
            headerViewController = DemoHeaderController()
        } else {
            headerView = DemoHeaderView()
        }
        updateStatus()
    }

    private func updateStatus(progress: CGFloat? = nil) {
        let page = selectedIndex.map { pageIDs[$0] } ?? "none"
        let oldProgress = status.accessibilityValue?.components(separatedBy: "progress=").last ?? "0.00"
        status.text = "\(names[page] ?? page) · \(controllerHeader ? "Controller" : "View") · H\(Int(layout.headerHeight))"
        if usesSystemContainer {
            status.text = "系统容器演示\n\(names[page] ?? page) · H\(Int(layout.headerHeight))"
        }
        status.accessibilityValue = "direction=\(view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? "rtl" : "ltr");page=\(page);header=\(controllerHeader ? "controller" : "view");height=\(Int(layout.headerHeight));progress=\(progress.map { String(format: "%.2f", Double($0)) } ?? oldProgress)"
        status.sizeToFit()
    }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        pageIDs.count
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        identifierForPageAt index: Int
    ) -> AnyHashable {
        pageIDs[index]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        tabBarItemAt index: Int
    ) -> SPTabBarItem {
        SPTabBarItem(title: names[pageIDs[index]] ?? "新增")
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        switch pageIDs[index] {
        case "grid": return DemoGrid()
        case "compositional": return DemoCompositional()
        case "list":
            if ProcessInfo.processInfo.arguments.contains("--mixed-page") {
                return DemoMixedPage()
            }
            return DemoList(count: 80)
        case "short": return DemoList(count: 3)
        case "empty": return DemoList(count: 0)
        case "plain": return DemoPlain()
        case "async":
            let page = DemoAsync()
            page.onReplace = { [weak self, weak page] in
                guard let self, let page, let index = self.pageIDs.firstIndex(of: "async"),
                      page.parent === self else {
                    return
                }
                self.rediscoverScrollView(forPageAt: index)
            }
            return page
        default: return DemoList(count: 10)
        }
    }

    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) {
        updateStatus()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        (view.window as? PagingTraceWindow)?.recordRelease(
            scrollView,
            velocity: velocity,
            target: targetContentOffset.pointee
        )
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        didChangeHeaderState state: SPHeaderState,
        progress: CGFloat
    ) {
        updateHeaderContentClip()
        updateStatus(progress: progress)
    }
}

@MainActor
final class DemoHeaderView: UIView {
    private let contentClip = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemIndigo
        accessibilityIdentifier = "demo.headerView"
        let title = UILabel()
        title.text = "StickyPagerKit\n纵向联动 · 横向分页"
        title.numberOfLines = 0
        title.font = .preferredFont(forTextStyle: .title1)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .white
        title.accessibilityIdentifier = "demo.headerTitle"
        title.translatesAutoresizingMaskIntoConstraints = false
        contentClip.clipsToBounds = true
        addSubview(contentClip)
        contentClip.addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            title.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    func clipContent(below top: CGFloat) {
        let y = max(0, top)
        contentClip.frame = CGRect(x: 0, y: y, width: bounds.width, height: max(0, bounds.height - y))
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

@MainActor
final class DemoHeaderController: UIViewController {
    override func loadView() {
        let header = DemoHeaderView()
        header.backgroundColor = .systemTeal
        view = header
    }
}

/// UI 回归直接读取窗口场景方向，避免将设备旋转请求误认为界面已旋转。
@MainActor
private final class RegressionStatusLabel: UILabel {
    override var accessibilityValue: String? {
        get {
            guard ProcessInfo.processInfo.arguments.contains("--window-regression") else {
                return super.accessibilityValue
            }
            let orientation: UIInterfaceOrientation
            if #available(iOS 26.0, *) {
                orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
            } else {
                orientation = window?.windowScene?.interfaceOrientation ?? .unknown
            }
            let trace = (window as? PagingTraceWindow).map { "gesture=\($0.pagingTrace);" } ?? ""
            return "\(trace)interfaceOrientation=\(orientation.rawValue);\(super.accessibilityValue ?? "")"
        }
        set { super.accessibilityValue = newValue }
    }
}

/// UI 回归仅在指定启动参数下读取原生滚动坐标及安全区域，不改变可见内容或生产无障碍描述。
@MainActor
private final class RegressionTableView: UITableView {
    override var accessibilityValue: String? {
        get {
            guard ProcessInfo.processInfo.arguments.contains("--window-regression") else {
                return super.accessibilityValue
            }
            var geometry: [String: Double] = [
                "position": Double(contentOffset.y + adjustedContentInset.top),
                "safeLeft": Double(safeAreaInsets.left),
                "safeRight": Double(safeAreaInsets.right),
                "safeTop": Double(safeAreaInsets.top),
                "safeBottom": Double(safeAreaInsets.bottom),
                "insetTop": Double(contentInset.top),
                "insetBottom": Double(contentInset.bottom),
                "adjustedTop": Double(adjustedContentInset.top),
                "adjustedBottom": Double(adjustedContentInset.bottom),
                "indicatorTop": Double(verticalScrollIndicatorInsets.top),
                "indicatorBottom": Double(verticalScrollIndicatorInsets.bottom),
                "automaticIndicators": automaticallyAdjustsScrollIndicatorInsets ? 1 : 0,
                "showsIndicator": showsVerticalScrollIndicator ? 1 : 0,
                "offsetY": Double(contentOffset.y)
            ]
            if let first = indexPathsForVisibleRows?.sorted().first, let cell = cellForRow(at: first) {
                geometry["firstRow"] = Double(first.row)
                geometry["firstRowY"] = Double(convert(cell.frame, to: window).minY)
                geometry["firstRowHeight"] = Double(cell.bounds.height)
                geometry["estimatedRowHeight"] = Double(estimatedRowHeight)
                geometry["contentHeight"] = Double(contentSize.height)
            }
            guard let data = try? JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys]) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        set { super.accessibilityValue = newValue }
    }
}

@MainActor
final class DemoMixedPage: UIViewController, UITableViewDataSource {
    private let label = UILabel()
    private let table = RegressionTableView(frame: .zero, style: .plain)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.text = "固定说明 · 始终位于标签栏下方"
        label.accessibilityIdentifier = "demo.mixed.label"
        label.translatesAutoresizingMaskIntoConstraints = false
        table.accessibilityIdentifier = "demo.list"
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.rowHeight = 60
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(label)
        view.addSubview(table)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            label.heightAnchor.constraint(equalToConstant: 28),
            table.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        80
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "混合页面内容 \(indexPath.row + 1)"
        return cell
    }
}

@MainActor
final class DemoList: UITableViewController {
    override func loadView() {
        tableView = RegressionTableView(frame: .zero, style: .plain)
    }

    let count: Int
    private var refreshCount = 0
    init(count: Int) {
        self.count = count; super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = "demo.list"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        let refresh = UIRefreshControl()
        refresh.accessibilityIdentifier = "demo.refresh"
        refresh.addTarget(self, action: #selector(refreshContent), for: .valueChanged)
        refreshControl = refresh
        if count == 0 {
            let label = UILabel(); label.text = "暂无内容 · 仍可折叠 Header"; label.textAlignment = .center
            tableView.backgroundView = label
        }
    }

    @objc private func refreshContent() {
        refreshCount += 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self else {
                return
            }
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = "内容 \(indexPath.row + 1)"
        content.secondaryText = "原生 UITableView · 已刷新 \(refreshCount) 次"
        cell.contentConfiguration = content
        return cell
    }
}

@MainActor
final class DemoGrid: UICollectionViewController {
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8; layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        layout.sectionInsetReference = .fromSafeArea
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .systemBackground
        collectionView.accessibilityIdentifier = "demo.grid"
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateItemSize()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateItemSize()
    }

    private func updateItemSize() {
        guard isViewLoaded, let layout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        // 根视图保持全宽；Cell 与 section 共用安全区域边界，避免横屏遮挡或三列换行。
        // 与 fromSafeArea 一致：若业务调整后的 content inset 更大，则尊重该边界。
        let safe = collectionView.safeAreaInsets
        let adjusted = collectionView.adjustedContentInset
        let left = max(safe.left + layout.sectionInset.left, adjusted.left)
        let right = max(safe.right + layout.sectionInset.right, adjusted.right)
        let width = collectionView.bounds.width - left - right - layout.minimumInteritemSpacing * 2
        let side = max(1, floor(width / 3))
        let size = CGSize(width: side, height: side * 1.25)
        if layout.itemSize != size {
            layout.itemSize = size
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        90
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundColor = [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink][indexPath.item % 4]
            .withAlphaComponent(0.7)
        var content = UIListContentConfiguration.cell()
        content.text = "\(indexPath.item + 1)"
        cell.contentConfiguration = content
        cell.accessibilityLabel = "作品 \(indexPath.item + 1)"
        cell.accessibilityIdentifier = "demo.grid.cell.\(indexPath.item)"
        return cell
    }
}

@MainActor
final class DemoPlain: UIViewController {
    override func loadView() {
        let label = UILabel()
        label.text = "普通 UIViewController\n没有 UIScrollView\n上下拖动可折叠 / 展开 Header"
        label.numberOfLines = 0; label.textAlignment = .center
        label.backgroundColor = .secondarySystemBackground
        label.accessibilityIdentifier = "demo.plain"
        view = label
    }
}

@MainActor
final class DemoAsync: UIViewController {
    var onReplace: (() -> Void)?
    private var scroll: UIScrollView?
    private let button = UIButton(type: .system)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        button.setTitle("创建或替换滚动视图", for: .normal)
        button.accessibilityIdentifier = "demo.replaceScroll"
        button.addAction(UIAction { [weak self] _ in self?.replaceScroll() }, for: .touchUpInside)
        view.addSubview(button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scroll?.frame = view.bounds
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        button.frame = CGRect(
            x: safeFrame.minX + 20,
            y: max(safeFrame.minY + 24, safeFrame.maxY - 64),
            width: max(0, safeFrame.width - 40),
            height: 44
        )
    }

    private func replaceScroll() {
        scroll?.removeFromSuperview()
        let scroll = UIScrollView(frame: view.bounds)
        scroll.contentSize = CGSize(width: view.bounds.width, height: 1600)
        scroll.accessibilityIdentifier = "demo.asyncScroll"
        let label = UILabel(frame: CGRect(x: 24, y: 24, width: 260, height: 60))
        label.text = "已重新发现 UIScrollView"
        scroll.addSubview(label)
        view.insertSubview(scroll, belowSubview: button)
        self.scroll = scroll
        onReplace?()
    }
}
