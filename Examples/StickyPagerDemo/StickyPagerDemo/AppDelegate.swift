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
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
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
        let button = UIButton(type: .system)
        button.setTitle("打开演示", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .title2)
        button.accessibilityIdentifier = "demo.open"
        button.addAction(UIAction { [weak self] _ in self?.navigationController?.pushViewController(DemoPager(), animated: true) }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([button.centerXAnchor.constraint(equalTo: view.centerXAnchor), button.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
}

@MainActor
final class DemoPager: SPPageViewController, SPPageViewControllerDataSource, SPPageViewControllerDelegate {
    private var pageIDs = ["grid", "list", "short", "empty", "plain", "async",
                           "hot", "recommended", "following", "weekly", "saved", "topics"]
    private let names = ["grid": "网格", "list": "列表", "short": "短列表", "empty": "空列表",
                         "plain": "普通页", "async": "异步页", "hot": "热", "recommended": "推荐内容",
                         "following": "关注", "weekly": "本周热门精选", "saved": "收藏", "topics": "更多专题与活动"]
    private let status = RegressionStatusLabel()
    private var controllerHeader = false
    private var generation = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "StickyPagerKit"
        if ProcessInfo.processInfo.arguments.contains("--rtl") { view.semanticContentAttribute = .forceRightToLeft }
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
        headerView = DemoHeaderView()
        layout = SPPageLayout(headerHeight: 220)
        let header = UIBarButtonItem(title: "Header", primaryAction: UIAction { [weak self] _ in self?.toggleHeader() })
        header.accessibilityIdentifier = "demo.header"
        let height = UIBarButtonItem(title: "高度", primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.layout.headerHeight = self.layout.headerHeight == 220 ? 300 : 220
            self.updateStatus()
        })
        height.accessibilityIdentifier = "demo.height"
        let pages = UIBarButtonItem(title: "页面", menu: UIMenu(children: [
            UIAction(title: "重排页面") { [weak self] _ in guard let self else { return }; self.pageIDs.reverse(); self.reloadData(); self.updateStatus() },
            UIAction(title: "删除当前页") { [weak self] _ in guard let self, let i = self.selectedIndex else { return }; self.pageIDs.remove(at: i); self.reloadData(); self.updateStatus() },
            UIAction(title: "添加页面") { [weak self] _ in guard let self else { return }; self.generation += 1; self.pageIDs.append("new\(self.generation)"); self.reloadData() },
            UIAction(title: "清空页面") { [weak self] _ in self?.pageIDs = []; self?.reloadData(); self?.updateStatus() }
        ]))
        pages.accessibilityIdentifier = "demo.pages"
        navigationItem.rightBarButtonItems = [pages, height, header]
        status.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        status.accessibilityIdentifier = "demo.status"
        status.textAlignment = .center
        toolbarItems = [UIBarButtonItem(customView: status)]
        reloadData()
        updateStatus()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderContentClip()
    }
    private func updateHeaderContentClip() {
        guard let header = (headerView ?? headerViewController?.view) as? DemoHeaderView else { return }
        if #available(iOS 26.0, *) { header.clipContent(below: 0); return }
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
        if controllerHeader { headerViewController = DemoHeaderController() }
        else { headerView = DemoHeaderView() }
        updateStatus()
    }
    private func updateStatus(progress: CGFloat? = nil) {
        let page = selectedIndex.map { pageIDs[$0] } ?? "none"
        let oldProgress = status.accessibilityValue?.components(separatedBy: "progress=").last ?? "0.00"
        status.text = "\(names[page] ?? page) · \(controllerHeader ? "Controller" : "View") · H\(Int(layout.headerHeight))"
        status.accessibilityValue = "direction=\(view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? "rtl" : "ltr");page=\(page);header=\(controllerHeader ? "controller" : "view");height=\(Int(layout.headerHeight));progress=\(progress.map { String(format: "%.2f", Double($0)) } ?? oldProgress)"
        status.sizeToFit()
    }
    func numberOfPages(in pageViewController: SPPageViewController) -> Int { pageIDs.count }
    func pageViewController(_ pageViewController: SPPageViewController, identifierForPageAt index: Int) -> AnyHashable { pageIDs[index] }
    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem { SPTabBarItem(title: names[pageIDs[index]] ?? "新增") }
    func pageViewController(_ pageViewController: SPPageViewController, viewControllerAt index: Int) -> UIViewController {
        switch pageIDs[index] {
        case "grid": return DemoGrid()
        case "list":
            if ProcessInfo.processInfo.arguments.contains("--mixed-page") { return DemoMixedPage() }
            return DemoList(count: 80)
        case "short": return DemoList(count: 3)
        case "empty": return DemoList(count: 0)
        case "plain": return DemoPlain()
        case "async":
            let page = DemoAsync()
            page.onReplace = { [weak self, weak page] in
                guard let self, let page, let index = self.pageIDs.firstIndex(of: "async"), page.parent === self else { return }
                self.rediscoverScrollView(forPageAt: index)
            }
            return page
        default: return DemoList(count: 10)
        }
    }
    func pageViewController(_ pageViewController: SPPageViewController, didSelectPageAt index: Int) { updateStatus() }
    func pageViewController(_ pageViewController: SPPageViewController, didChangeHeaderState state: SPHeaderState, progress: CGFloat) {
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
    required init?(coder: NSCoder) { fatalError() }
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
            guard ProcessInfo.processInfo.arguments.contains("--window-regression") else { return super.accessibilityValue }
            let orientation: UIInterfaceOrientation
            if #available(iOS 26.0, *) {
                orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
            } else {
                orientation = window?.windowScene?.interfaceOrientation ?? .unknown
            }
            return "interfaceOrientation=\(orientation.rawValue);\(super.accessibilityValue ?? "")"
        }
        set { super.accessibilityValue = newValue }
    }
}

/// UI 回归仅在指定启动参数下读取原生滚动坐标及安全区域，不改变可见内容或生产无障碍描述。
@MainActor
private final class RegressionTableView: UITableView {
    override var accessibilityValue: String? {
        get {
            guard ProcessInfo.processInfo.arguments.contains("--window-regression") else { return super.accessibilityValue }
            let geometry: [String: Double] = [
                "position": Double(contentOffset.y + adjustedContentInset.top),
                "safeLeft": Double(safeAreaInsets.left),
                "safeRight": Double(safeAreaInsets.right)
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: geometry, options: [.sortedKeys]) else { return nil }
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 80 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "混合页面内容 \(indexPath.row + 1)"
        return cell
    }
}

@MainActor
final class DemoList: UITableViewController {
    override func loadView() { tableView = RegressionTableView(frame: .zero, style: .plain) }
    let count: Int
    private var refreshCount = 0
    init(count: Int) { self.count = count; super.init(style: .plain) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = "demo.list"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
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
            guard let self else { return }
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { count }
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
    required init?(coder: NSCoder) { fatalError() }
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
        guard isViewLoaded, let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return }
        // 根视图保持全宽；Cell 与 section 共用安全区域边界，避免横屏遮挡或三列换行。
        // 与 fromSafeArea 一致：若业务调整后的 content inset 更大，则尊重该边界。
        let safe = collectionView.safeAreaInsets
        let adjusted = collectionView.adjustedContentInset
        let left = max(safe.left + layout.sectionInset.left, adjusted.left)
        let right = max(safe.right + layout.sectionInset.right, adjusted.right)
        let width = collectionView.bounds.width - left - right - layout.minimumInteritemSpacing * 2
        let side = max(1, floor(width / 3))
        let size = CGSize(width: side, height: side * 1.25)
        if layout.itemSize != size { layout.itemSize = size }
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 90 }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.backgroundColor = [UIColor.systemIndigo, .systemTeal, .systemOrange, .systemPink][indexPath.item % 4].withAlphaComponent(0.7)
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
        button.frame = CGRect(x: safeFrame.minX + 20, y: max(safeFrame.minY + 24, safeFrame.maxY - 64),
                              width: max(0, safeFrame.width - 40), height: 44)
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
