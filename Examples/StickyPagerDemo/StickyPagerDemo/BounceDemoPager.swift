import UIKit
import StickyPagerKit

/// 顶部回弹演示；显示帧指标仅用于真实触摸回归，不驱动被测交互。
@MainActor
final class BounceDemoPager: SPPageViewController, SPPageViewControllerDataSource {
    private let names = ["整体长列表", "页面刷新", "短列表", "空列表", "普通页", "固定控件"]
    private let metrics = BounceMetricsLabel()
    private var link: CADisplayLink?
    private let frameTarget = BounceFrameTarget()
    private var peakContainer: CGFloat = 0
    private var peakList: CGFloat = 0
    private var maximumMismatch: CGFloat = 0
    private var frames = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        if ProcessInfo.processInfo.arguments.contains("--rtl") {
            view.semanticContentAttribute = .forceRightToLeft
        }
        title = "顶部回弹"
        dataSource = self
        let header = UILabel()
        header.text = "下拉体验整体回弹"
        header.textAlignment = .center
        header.backgroundColor = .secondarySystemBackground
        header.accessibilityIdentifier = "bounce.header"
        headerView = header
        layout = SPPageLayout(headerHeight: 260)
        metrics.accessibilityIdentifier = "bounce.metrics"
        metrics.isAccessibilityElement = true
        metrics.font = .preferredFont(forTextStyle: .caption1)
        metrics.numberOfLines = 2
        metrics.textAlignment = .center
        navigationItem.titleView = metrics
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "切换模式", primaryAction: UIAction { [weak self] _ in
            guard let self else {
                return
            }
            self.topBounceBehavior = self.topBounceBehavior == .container ? .page : .container
            self.peakContainer = 0; self.peakList = 0; self.maximumMismatch = 0; self.frames = 0
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "bounce.mode"
        reloadData()
        frameTarget.owner = self
        let link = CADisplayLink(target: frameTarget, selector: #selector(BounceFrameTarget.tick))
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    isolated deinit { link?.invalidate() }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        names.count
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        identifierForPageAt index: Int
    ) -> AnyHashable {
        index
    }

    func pageViewController(_ pageViewController: SPPageViewController, tabBarItemAt index: Int) -> SPTabBarItem {
        SPTabBarItem(title: names[index])
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        topBounceBehaviorForPageAt index: Int
    ) -> SPTopBounceBehavior? {
        index == 1 ? .page : nil
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        BounceDemoPage(index: index)
    }

    fileprivate func sample() {
        guard let headerView else {
            return
        }
        let delta = headerView.convert(.zero, to: view).y
        let page = children.compactMap { $0 as? BounceDemoPage }.first { $0.index == selectedIndex }
        let q = page?.scroll.map { $0.contentOffset.y + $0.adjustedContentInset.top } ?? 0
        peakContainer = max(peakContainer, delta)
        peakList = max(peakList, -q)
        if delta > 1 {
            frames += 1
            let tabDelta = tabBar.convert(.zero, to: view).y - layout.headerHeight
            maximumMismatch = max(maximumMismatch, abs(tabDelta - delta), abs(q))
        }
        let values: [String: Double] = [
            "container": Double(delta),
            "position": Double(q),
            "peakContainer": Double(peakContainer),
            "peakList": Double(peakList),
            "mismatch": Double(maximumMismatch),
            "frames": Double(frames)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]) {
            metrics.accessibilityValue = String(decoding: data, as: UTF8.self)
        }
        metrics.text = topBounceBehavior == .container ? "默认：容器回弹\n页面刷新页独立覆盖" : "默认：页面回弹\n遵循列表原生配置"
        metrics.sizeToFit()
    }
}

@MainActor
private final class BounceFrameTarget: NSObject {
    weak var owner: BounceDemoPager?
    @objc func tick() {
        owner?.sample()
    }
}

@MainActor
private final class BounceMetricsLabel: UILabel {}

@MainActor
private final class BounceDemoPage: UIViewController {
    let index: Int
    var scroll: UIScrollView?
    init(index: Int) {
        self.index = index; super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(index:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let fixed = UILabel()
        fixed.text = index == 4 ? "普通页面也支持容器回弹" : "页面固定内容"
        fixed.textAlignment = .center
        fixed.accessibilityIdentifier = "bounce.fixed"
        fixed.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fixed)
        NSLayoutConstraint.activate([
            fixed.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fixed.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fixed.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fixed.heightAnchor.constraint(equalToConstant: 50)
        ])
        guard index != 4 else {
            return
        }
        let scroll = UIScrollView()
        self.scroll = scroll
        scroll.accessibilityIdentifier = "bounce.scroll"
        scroll.alwaysBounceVertical = true
        if ProcessInfo.processInfo.arguments.contains("--bounce-disabled") {
            scroll.bounces = false
        }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: index == 5 ? fixed.bottomAnchor : view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        for row in 0 ..< (index == 3 ? 0 : index == 2 ? 3 : 45) {
            let label = UILabel()
            label.text = "第 \(row + 1) 行 · 下拉观察回弹归属"
            label.backgroundColor = row.isMultiple(of: 2) ? .tertiarySystemBackground : .systemBackground
            label.heightAnchor.constraint(equalToConstant: 52).isActive = true
            stack.addArrangedSubview(label)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        if index == 1 {
            let refresh = UIRefreshControl()
            scroll.refreshControl = refresh
            refresh.addAction(UIAction { [weak refresh] _ in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    refresh?.endRefreshing()
                }
            }, for: .valueChanged)
        }
    }
}
