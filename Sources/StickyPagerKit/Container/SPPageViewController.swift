import UIKit

/// 提供共享折叠 Header、标签栏与横向分页的 UIKit 容器。
@MainActor
open class SPPageViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public weak var dataSource: (any SPPageViewControllerDataSource)?
    public weak var delegate: (any SPPageViewControllerDelegate)?
    public private(set) var selectedIndex: Int?
    public var isPagingEnabled = true {
        didSet { pagingView.isScrollEnabled = isPagingEnabled }
    }

    /// 默认在分页期间临时隐藏业务列表的指示器；可显式选择 preserve 保留业务配置。
    /// 分页中切换策略立即生效，不改变当前分页或 Header 状态。
    public var scrollIndicatorVisibilityPolicy: SPScrollIndicatorVisibilityPolicy = .hideDuringPaging {
        didSet {
            if oldValue != scrollIndicatorVisibilityPolicy {
                selection.updateScrollIndicatorVisibility()
            }
        }
    }

    public var maximumCachedPageCount = 3 {
        didSet { evictPages() }
    }

    public var layout = SPPageLayout() {
        didSet { pageLayout.updateLayoutConfiguration() }
    }

    public var headerView: UIView? {
        get { storedHeaderView }
        set { replaceHeader(view: newValue, controller: nil) }
    }

    public var headerViewController: UIViewController? {
        get { storedHeaderController }
        set { replaceHeader(view: nil, controller: newValue) }
    }

    public var tabBar: SPTabBar {
        get { storedTabBar }
        set {
            guard newValue !== storedTabBar else {
                return
            }
            vertical.stopAnimation()
            storedTabBar.cancelUserSelection()
            storedTabBar.selectionRequest = nil
            storedTabBar.removeFromSuperview()
            storedTabBar = newValue
            if isViewLoaded {
                configureTabBar(); view.setNeedsLayout()
            }
        }
    }

    internal let pagingView = SPPagingScrollView()
    internal var records: [AnyHashable: SPPageRecord] {
        store.records
    }

    internal let store = SPPageStore()
    internal var currentScrollView: UIScrollView? {
        currentRecord?.binding?.scrollView
    }

    internal var identifiers: [AnyHashable] {
        store.snapshot.identifiers
    }

    internal var items: [SPTabBarItem] {
        store.snapshot.items
    }

    internal let headerHost = UIScrollView()
    internal var storedHeaderView: UIView?
    internal var storedHeaderController: UIViewController?
    internal var storedTabBar = SPTabBar()
    internal weak var returnGesture: UIGestureRecognizer?

    internal var currentRecord: SPPageRecord? {
        guard let selectedIndex, identifiers.indices.contains(selectedIndex) else {
            return nil
        }
        return records[identifiers[selectedIndex]]
    }

    internal var isRTL: Bool {
        view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    open override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        pagingView.isPagingEnabled = true
        pagingView.bounces = false
        // 横向宿主不参与点状态栏回顶部，避免干扰业务正文列表。
        pagingView.scrollsToTop = false
        pagingView.showsHorizontalScrollIndicator = false
        pagingView.showsVerticalScrollIndicator = false
        pagingView.contentInsetAdjustmentBehavior = .never
        pagingView.delegate = self
        pagingView.isScrollEnabled = isPagingEnabled
        pagingView.accessibilityIdentifier = "sp.pages"
        view.addSubview(pagingView)
        headerHost.clipsToBounds = true
        // Header 的位移仍由共享折叠逻辑驱动；原生滚动宿主为导航栏提供边缘效果。
        headerHost.isScrollEnabled = false
        headerHost.scrollsToTop = false
        headerHost.contentInsetAdjustmentBehavior = .never
        headerHost.showsHorizontalScrollIndicator = false
        headerHost.showsVerticalScrollIndicator = false
        if #available(iOS 26.0, *) {
            headerHost.topEdgeEffect.style = .soft
        }
        view.addSubview(headerHost)
        setContentScrollView(headerHost, for: .top)
        configureTabBar()
        mountHeader()
        vertical.headerPan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        vertical.tabPan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        vertical.plainPagePan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        for (host, pan) in [
            (headerHost, vertical.headerPan!),
            (storedTabBar, vertical.tabPan!),
            (pagingView, vertical.plainPagePan!)
        ] {
            pan.delegate = self
            host.addGestureRecognizer(pan)
        }
        vertical.configureAnimation()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selection.operationDepth += 1
        defer { selection.endOperation() }
        if let gesture = navigationController?.interactivePopGestureRecognizer, gesture !== returnGesture {
            pagingView.panGestureRecognizer.require(toFail: gesture)
            vertical.headerPan.require(toFail: gesture)
            vertical.tabPan.require(toFail: gesture)
            vertical.plainPagePan.require(toFail: gesture)
            returnGesture = gesture
        }
        selection.endParentAppearance()
        selection.parentIsAppearing = true
        selection.parentAppearance = [storedHeaderController, currentRecord?.controller].compactMap { $0 }
        selection.withAppearanceUpdates { selection.parentAppearance.forEach { $0.beginAppearanceTransition(
            true,
            animated: animated
        ) } }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        selection.operationDepth += 1
        defer { selection.endOperation() }
        selection.endParentAppearance()
        selection.isVisible = true
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        selection.operationDepth += 1
        defer { selection.endOperation() }
        selection.cancelPaging()
        vertical.stopAnimation()
        selection.isVisible = false
        selection.endParentAppearance()
        selection.parentIsAppearing = false
        selection.parentAppearance = [storedHeaderController, currentRecord?.controller].compactMap { $0 }
        selection.withAppearanceUpdates { selection.parentAppearance.forEach { $0.beginAppearanceTransition(
            false,
            animated: animated
        ) } }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        selection.operationDepth += 1
        defer { selection.endOperation() }
        selection.endParentAppearance()
    }

    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    open override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        evictPages(limit: 1)
    }

    isolated deinit {
        // 未使用纵向协调器的容器也可以直接释放；析构期间不能创建新的 weak self。
        verticalStorage?.stopAnimation()
        records.values.forEach {
            $0.binding?.detach()
            $0.safeArea.detach()
        }
    }

    /// 越界请求不改变状态。新请求取消尚未完成的旧转场。
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        selection.selectPage(at: index, animated: animated, userItem: nil)
    }

    /// 指定页面内的滚动视图；nil 恢复自动发现。视图必须属于该页面视图树。
    public func setScrollView(_ scrollView: UIScrollView?, forPageAt index: Int) {
        setScrollViewBinding(scrollView.map(SPScrollViewBinding.explicit) ?? .automatic, forPageAt: index)
    }

    /// 设置页面绑定选择；未加载页面在首次绑定前应用。越界或外部视图请求被忽略。
    /// 选择按页面标识保留，删除标识时清除。显式列表弱引用失效后不会回退自动发现。
    public func setScrollViewBinding(_ selection: SPScrollViewBinding, forPageAt index: Int) {
        guard identifiers.indices.contains(index) else {
            return
        }
        let wasLoaded = records[identifiers[index]] != nil
        guard let record = loadPage(index, initialBindingSelection: selection), wasLoaded else {
            // 新页面已在首次绑定前应用请求；不能再覆盖加载回调中更新的选择。
            return
        }
        if case let .explicit(scroll) = selection,
           scroll !== record.controller.view, !scroll.isDescendant(of: record.controller.view) {
            return
        }
        let stored = SPScrollViewBindingSelection(selection)
        store.setBindingSelection(stored, for: record.identifier)
        record.scrollViewSelection = stored
        // 即使新旧均没有绑定，改变选择也应废弃原来的正文兜底拖动。
        if record === currentRecord {
            vertical.stopAnimation()
        }
        vertical.bind(record)
    }

    /// 页面异步创建或替换视图后调用。不改变绑定选择；显式列表失效时保持未绑定。
    public func rediscoverScrollView(forPageAt index: Int) {
        guard let record = loadPage(index) else {
            return
        }
        vertical.bind(record)
    }

    internal func configureTabBar() {
        view.addSubview(storedTabBar)
        storedTabBar.selectionRequest = { [weak self] item in
            guard let self, let index = self.items.firstIndex(where: { $0 === item }) else {
                return
            }
            self.selection.selectPage(at: index, animated: true, userItem: item)
        }
        storedTabBar.setItems(items)
        storedTabBar.setSelectedItem(selectedIndex.map { items[$0] }, animated: false)
        if let tabPan = vertical.tabPan {
            storedTabBar.addGestureRecognizer(tabPan)
        }
    }

    internal func replaceHeader(view newView: UIView?, controller newController: UIViewController?) {
        if newView === storedHeaderView && newController === storedHeaderController {
            return
        }
        if let newController, newController.parent != nil {
            return
        }
        if let old = storedHeaderController {
            selection.appear(old, false)
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        storedHeaderView?.removeFromSuperview()
        storedHeaderView = newView
        storedHeaderController = newController
        if isViewLoaded {
            mountHeader(); pageLayout.updateLayoutConfiguration()
        }
    }

    internal func mountHeader() {
        if let controller = storedHeaderController {
            if controller
                .parent ==
                nil {
                addChild(controller); headerHost.addSubview(controller.view); controller
                    .didMove(toParent: self); selection.appear(
                        controller,
                        true
                    )
            }
        } else if let storedHeaderView {
            headerHost.addSubview(storedHeaderView)
        }
    }

    @discardableResult internal func loadPage(
        _ index: Int,
        initialBindingSelection: SPScrollViewBinding? = nil
    ) -> SPPageRecord? {
        guard identifiers.indices.contains(index) else {
            return nil
        }
        let id = identifiers[index]
        store.advanceAccess()
        if let record = store.accessRecord(id) {
            return record
        }
        guard selection.loadingIdentifiers.insert(id).inserted else {
            return nil
        }
        selection.operationDepth += 1
        defer { selection.loadingIdentifiers.remove(id); selection.endOperation() }
        guard let controller = dataSource?.pageViewController(self, viewControllerAt: index),
              controller.parent == nil, identifiers.contains(id) else {
            return nil
        }
        if let existing = records[id] {
            return existing
        }
        let record = SPPageRecord(identifier: id, controller: controller)
        store.insert(record)
        let selectionBeforeLoading = store.bindingSelection(for: id)
        var mounted = false
        defer {
            if !mounted {
                if records[id] === record {
                    removeRecord(id)
                } else if controller.parent === self,
                          !records.values.contains(where: { $0.controller === controller }) {
                    // addChild 的 willMove 回调可能先删除记录，随后 UIKit 才完成 parent 写入。
                    controller.willMove(toParent: nil)
                    controller.viewIfLoaded?.removeFromSuperview()
                    controller.removeFromParent()
                    record.safeArea.detach()
                }
            }
        }
        addChild(controller)
        guard records[id] === record, identifiers.contains(id), controller.parent === self else {
            return nil
        }
        let root = controller.view!
        guard records[id] === record, let layoutIndex = store.snapshot.index(of: id) else {
            return nil
        }
        // viewDidLoad 等加载回调中的选择更新比外层初始请求更新，不可被覆盖。
        if let selection = initialBindingSelection, store.bindingSelection(for: id) === selectionBeforeLoading {
            if case let .explicit(scroll) = selection,
               scroll !== controller.view, !scroll.isDescendant(of: controller.view) {
                // 非页面视图不改变原配置。
            } else {
                store.setBindingSelection(SPScrollViewBindingSelection(selection), for: id)
            }
        }
        pagingView.addSubview(root)
        pageLayout.layoutPage(record, at: layoutIndex, layout: pageLayout.effectiveLayout)
        guard records[id] === record else {
            return nil
        }
        controller.didMove(toParent: self)
        // 挂载回调可重排或移除页面：只查询仍有效的记录，并传递当前快照中的索引。
        guard records[id] === record, let bindingIndex = store.snapshot.index(of: id) else {
            return nil
        }
        if let stored = store.bindingSelection(for: id) {
            record.scrollViewSelection = stored
        } else {
            let proposed = dataSource?
                .pageViewController(self, scrollViewBindingFor: controller, at: bindingIndex) ?? .automatic
            // 数据源回调允许业务显式设置选择，回调返回值不能覆盖更新后的运行时意图。
            record.scrollViewSelection = store.bindingSelection(for: id) ?? SPScrollViewBindingSelection(proposed)
        }
        guard records[id] === record else {
            return nil
        }
        record.isPreparingBinding = false
        vertical.bind(record)
        // 首次绑定后同步页面位移和滚动 inset；根视图与标签栏顶部对齐，内容避让标签栏。
        pageLayout.layoutHeader()
        guard records[id] === record, identifiers.contains(id) else {
            return nil
        }
        mounted = true
        return record
    }

    internal func removeRecord(_ id: AnyHashable) {
        guard let record = store.remove(id) else {
            return
        }
        // 内容位置由当前页的 consume 记录；后台页的临时对齐不覆盖历史位置。
        record.binding?.detach()
        // 父级 appearance 尚未结束时，先在 containment 有效期间完成子级回调。
        if selection.parentAppearance.contains(where: { $0 === record.controller }) {
            selection.appear(record.controller, false)
        }
        record.controller.willMove(toParent: nil)
        record.controller.view.removeFromSuperview()
        record.controller.removeFromParent()
        record.safeArea.detach()
    }

    internal func evictPages(limit: Int? = nil) {
        let capacity = max(1, limit ?? maximumCachedPageCount)
        var protectedIndices = [selectedIndex, selection.transitionTarget].compactMap { $0 }
        if selection.transitionTarget != nil || pagingView.isDragging || pagingView.isDecelerating {
            let position = selection.logicalPosition()
            protectedIndices += [Int(floor(position)), Int(ceil(position))]
        }
        let protected = protectedIndices.filter { identifiers.indices.contains($0) }.map { identifiers[$0] }
        let candidates = store
            .evictionCandidates(protecting: Set(protected).union(selection.loadingIdentifiers)
                .union(selection.finishingIdentifiers))
        for record in candidates where records.count > capacity {
            removeRecord(record.identifier)
        }
    }

    internal lazy var selection = SPPageSelectionCoordinator(host: self)
    private var verticalStorage: SPVerticalScrollCoordinator?
    internal var vertical: SPVerticalScrollCoordinator {
        if let verticalStorage {
            return verticalStorage
        }
        let coordinator = SPVerticalScrollCoordinator(host: self)
        verticalStorage = coordinator
        return coordinator
    }

    internal lazy var pageLayout = SPPageLayoutCoordinator(host: self)
    internal var collapseOffset: CGFloat {
        vertical.collapseOffset
    }

    internal func commitSelection(_ index: Int?) {
        selectedIndex = index
    }

    open override func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        pageLayout.willTransition(to: size, with: coordinator)
    }

    internal func forwardSizeTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageLayout.layoutSubviews()
    }

    /// 同步更新页面快照。重复标识拒绝整次更新；相同标识复用已有控制器。
    public func reloadData() {
        selection.reloadData()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        selection.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        selection.scrollViewDidScroll(scrollView)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        selection.scrollViewDidEndDecelerating(scrollView)
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        selection.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        selection.scrollViewDidEndScrollingAnimation(scrollView)
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        vertical.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        vertical.gestureRecognizer(gestureRecognizer, shouldReceive: touch)
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        vertical.gestureRecognizer(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer)
    }

    @objc internal func handleHeaderPan(_ pan: UIPanGestureRecognizer) {
        vertical.handleHeaderPan(pan)
    }
}
