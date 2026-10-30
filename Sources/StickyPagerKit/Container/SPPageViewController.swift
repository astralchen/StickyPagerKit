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
                updateScrollIndicatorVisibility()
            }
        }
    }

    public var maximumCachedPageCount = 3 {
        didSet { evictPages() }
    }

    public var layout = SPPageLayout() {
        didSet { updateLayoutConfiguration() }
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
            stopAnimation()
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
    internal private(set) var collapseOffset: CGFloat = 0
    internal private(set) var records: [AnyHashable: SPPageRecord] = [:]
    internal var currentScrollView: UIScrollView? {
        currentRecord?.binding?.scrollView
    }

    private var identifiers: [AnyHashable] = []
    private var items: [SPTabBarItem] = []
    private var positions: [AnyHashable: CGFloat] = [:]
    // 运行时选择按稳定标识保存，缓存淘汰不恢复自动发现；删除标识才清除。
    private var scrollViewSelections: [AnyHashable: SPScrollViewBindingSelection] = [:]
    private let headerHost = UIScrollView()
    private var storedHeaderView: UIView?
    private var storedHeaderController: UIViewController?
    private var storedTabBar = SPTabBar()
    private var isVisible = false
    private var parentAppearance: [UIViewController] = []
    private var parentIsAppearing: Bool?
    /// 转场保存实际记录，避免回调重排快照后按旧索引结束另一页的 appearance。
    private final class PageTransition {
        let generation: UInt
        let outgoing: SPPageRecord?
        let incoming: SPPageRecord
        var outgoingBegan = false
        var incomingBegan = false
        init(generation: UInt, outgoing: SPPageRecord?, incoming: SPPageRecord) {
            self.generation = generation
            self.outgoing = outgoing
            self.incoming = incoming
        }
    }

    private var transition: PageTransition?
    private var transitionTarget: Int? {
        transition.flatMap { identifiers.firstIndex(of: $0.incoming.identifier) }
    }

    private var snapshotGeneration: UInt = 0
    private var selectionGeneration: UInt = 0
    private var interactionGeneration: UInt = 0
    private var loadingIdentifiers: Set<AnyHashable> = []
    private var finishingIdentifiers: Set<AnyHashable> = []
    private var operationDepth = 0
    private var appearanceDepth = 0
    private var isDrainingRequests = false
    private var pendingRequests: [() -> Void] = []

    private func endOperation() {
        operationDepth -= 1
        drainRequests()
    }

    private func drainRequests() {
        guard operationDepth == 0, appearanceDepth == 0, !isReloading,
              loadingIdentifiers.isEmpty, !isDrainingRequests else {
            return
        }
        isDrainingRequests = true
        defer { isDrainingRequests = false }
        while !pendingRequests.isEmpty {
            let request = pendingRequests.removeFirst()
            request()
        }
    }

    private func withAppearanceUpdates(_ updates: () -> Void) {
        operationDepth += 1
        appearanceDepth += 1
        defer { appearanceDepth -= 1; endOperation() }
        updates()
    }

    // 横向手势开始即保护纵向历史，覆盖候选页尚未建立及取消回原页的阶段。
    private var isPaging = false {
        didSet {
            guard oldValue != isPaging else {
                return
            }
            updateScrollIndicatorVisibility()
        }
    }

    private func updateScrollIndicatorVisibility() {
        for record in records.values {
            // 显隐写入可触发业务回调并改变策略，后续页面必须读取最新状态。
            record.binding?.indicatorsHiddenForPaging = isPaging && scrollIndicatorVisibilityPolicy == .hideDuringPaging
        }
    }

    private var suppressPaging = false
    private var previousSize: CGSize = .zero
    private var previousTabBarHeight: CGFloat = 0
    private var previousBoundsSize: CGSize = .zero
    private var sizeTransitionGeneration: UInt = 0
    private var isTransitioningSize = false
    private var accessCounter: UInt = 0
    private var isReloading = false
    private var previousCollapseRange: CGFloat?
    private var isLayingOutPages = false
    private var headerPan: UIPanGestureRecognizer!
    private var tabPan: UIPanGestureRecognizer!
    private var plainPagePan: UIPanGestureRecognizer!
    private weak var dragRecord: SPPageRecord?
    private weak var dragBinding: SPScrollBinding?
    private weak var dragPan: UIPanGestureRecognizer?
    private var dragStart: CGFloat = 0
    private var animationVelocity: CGFloat = 0
    private var displayLink: CADisplayLink?
    private let displayTarget = SPDisplayLinkTarget()
    private weak var returnGesture: UIGestureRecognizer?

    private var currentRecord: SPPageRecord? {
        guard let selectedIndex, identifiers.indices.contains(selectedIndex) else {
            return nil
        }
        return records[identifiers[selectedIndex]]
    }

    private var effectiveLayout: SPPageLayout {
        var value = layout.normalized
        // 只有内容策略参与测量；固定高度和隐藏不会被内容需求撑开。
        if case let .content(minimum) = value.tabBarSizing {
            value.tabBarSizing = .fixed(max(minimum, storedTabBar.sizeThatFits(view.bounds.size).height))
        }
        if storedHeaderView == nil && storedHeaderController ==
            nil {
            value.headerHeight = 0; value.minimumHeaderHeight = 0
        }
        // Header 从容器顶部铺开，标签栏仍在安全区域下方吸顶。
        // 高度不足时补足吸顶基线，避免标签栏进入导航栏或产生负折叠距离。
        value.minimumHeaderHeight += isViewLoaded ? view.safeAreaInsets.top : 0
        value.headerHeight = max(value.headerHeight, value.minimumHeaderHeight)
        return value
    }

    private var isRTL: Bool {
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
        headerPan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        tabPan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        plainPagePan = UIPanGestureRecognizer(target: self, action: #selector(handleHeaderPan(_:)))
        for (host, pan) in [(headerHost, headerPan!), (storedTabBar, tabPan!), (pagingView, plainPagePan!)] {
            pan.delegate = self
            host.addGestureRecognizer(pan)
        }
        displayTarget.tick = { [weak self] link in self?.stepAnimation(link) }
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        operationDepth += 1
        defer { endOperation() }
        if let gesture = navigationController?.interactivePopGestureRecognizer, gesture !== returnGesture {
            pagingView.panGestureRecognizer.require(toFail: gesture)
            headerPan.require(toFail: gesture)
            tabPan.require(toFail: gesture)
            plainPagePan.require(toFail: gesture)
            returnGesture = gesture
        }
        endParentAppearance()
        parentIsAppearing = true
        parentAppearance = [storedHeaderController, currentRecord?.controller].compactMap { $0 }
        withAppearanceUpdates { parentAppearance.forEach { $0.beginAppearanceTransition(true, animated: animated) } }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        operationDepth += 1
        defer { endOperation() }
        endParentAppearance()
        isVisible = true
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        operationDepth += 1
        defer { endOperation() }
        cancelPaging()
        stopAnimation()
        isVisible = false
        endParentAppearance()
        parentIsAppearing = false
        parentAppearance = [storedHeaderController, currentRecord?.controller].compactMap { $0 }
        withAppearanceUpdates { parentAppearance.forEach { $0.beginAppearanceTransition(false, animated: animated) } }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        operationDepth += 1
        defer { endOperation() }
        endParentAppearance()
    }

    open override func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        sizeTransitionGeneration &+= 1
        let generation = sizeTransitionGeneration
        isTransitioningSize = true
        super.viewWillTransition(to: size, with: coordinator)
        let queued = coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, self.sizeTransitionGeneration == generation else {
                return
            }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            for record in self.records.values {
                self.align(record)
                // 恢复 offset 可能触发自适应列表再次布局；在转场保护结束前消化回写。
                record.controller.view.setNeedsLayout()
                record.controller.view.layoutIfNeeded()
                if let binding = record.binding {
                    // 延迟行高结算也可能缩短范围；保存新底部，避免下次缩放恢复过期位置。
                    self.positions[record.identifier] = min(
                        self.positions[record.identifier] ?? 0,
                        max(0, binding.maximumPosition - self.effectiveLayout.collapseRange)
                    )
                }
                self.align(record)
            }
            // 事务结束后立即交还原生定位；不依据空闲期行高／offset 的相关性回滚业务写入。
            self.isTransitioningSize = false
        }
        if !queued {
            isTransitioningSize = false
        }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let l = effectiveLayout
        let wasLayingOut = isLayingOutPages
        isLayingOutPages = true
        previousBoundsSize = view.bounds.size
        // 子页布局可能重入容器；内层返回时不能撤销外层仍在使用的保护。
        defer { isLayingOutPages = wasLayingOut }
        let rangeChanged = previousCollapseRange != l.collapseRange
        if rangeChanged {
            // 旋转、导航栏显隐或安全区域变化时，已吸顶的页面继续吸顶。
            let wasCollapsed = previousCollapseRange.map { $0 > 0 && collapseOffset >= $0 } ?? false
            collapseOffset = wasCollapsed ? l.collapseRange : min(collapseOffset, l.collapseRange)
            previousCollapseRange = l.collapseRange
            stopAnimation()
        }
        // 页面铺满容器宽度并延伸至底边；安全区域由子页面的布局或自动滚动 inset 处理。
        let pageFrame = CGRect(
            x: 0,
            y: l.minimumHeaderHeight,
            width: view.bounds.width,
            height: max(0, view.bounds.height - l.minimumHeaderHeight)
        )
        let sizeChanged = pageFrame.size != previousSize || l.tabBarHeight != previousTabBarHeight
        if sizeChanged {
            cancelPaging()
            stopAnimation()
            previousSize = pageFrame.size
            previousTabBarHeight = l.tabBarHeight
        }
        let wasSuppressing = suppressPaging
        suppressPaging = true
        pagingView.frame = pageFrame
        pagingView.contentSize = CGSize(width: pageFrame.width * CGFloat(identifiers.count), height: pageFrame.height)
        // 先对齐分页视口，再布局子页，避免 RTL 尺寸变化时按旧偏移计算子页安全区域。
        if !pagingView.isDragging && !pagingView.isDecelerating && transitionTarget == nil {
            alignPaging()
        }
        for (id, record) in records {
            guard let index = identifiers.firstIndex(of: id) else {
                continue
            }
            layoutPage(record, at: index, layout: l)
            if rangeChanged || sizeChanged {
                align(record)
                // inset 与定位会触发 UITableView 的行高结算；完成布局后再恢复契约中的内容位移。
                record.binding?.scrollView.setNeedsLayout()
                record.binding?.scrollView.layoutIfNeeded()
                if sizeChanged, let binding = record.binding {
                    // 放大视口可能缩短可滚动范围；同步保存位置，避免切页后恢复到旧底部以外。
                    positions[id] = min(positions[id] ?? 0, max(0, binding.maximumPosition - l.collapseRange))
                }
                align(record)
            }
        }
        suppressPaging = wasSuppressing
        if rangeChanged {
            publishHeader()
        } else {
            layoutHeader()
        }
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
        displayLink?.invalidate()
        records.values.forEach {
            $0.binding?.detach()
            $0.safeArea.detach()
        }
    }

    /// 同步更新页面快照。重复标识拒绝整次更新；相同标识复用已有控制器。
    public func reloadData() {
        guard !isReloading else {
            return
        }
        isReloading = true
        operationDepth += 1
        defer { isReloading = false; endOperation() }
        loadViewIfNeeded()
        let count = max(0, dataSource?.numberOfPages(in: self) ?? 0)
        var newIDs: [AnyHashable] = [], newItems: [SPTabBarItem] = []
        for index in 0 ..< count {
            guard let source = dataSource else {
                return
            }
            newIDs.append(source.pageViewController(self, identifierForPageAt: index))
            newItems.append(source.pageViewController(self, tabBarItemAt: index))
        }
        guard Set(newItems.map(ObjectIdentifier.init)).count == newItems.count else {
            NSLog("StickyPagerKit: reloadData 拒绝重复标签对象")
            return
        }
        guard Set(newIDs).count == newIDs.count else {
            NSLog("StickyPagerKit: reloadData 拒绝重复页面标识")
            return
        }
        // 只有完整且合法的快照才使旧选择失效；拒绝更新不触碰已有转场。
        snapshotGeneration &+= 1
        selectionGeneration &+= 1
        let generation = snapshotGeneration
        if appearanceDepth > 0 {
            pendingRequests.append { [weak self] in
                self?.applySnapshot(newIDs, items: newItems, generation: generation)
            }
        } else {
            applySnapshot(newIDs, items: newItems, generation: generation)
        }
    }

    private func applySnapshot(_ newIDs: [AnyHashable], items newItems: [SPTabBarItem], generation: UInt) {
        guard generation == snapshotGeneration else {
            return
        }
        operationDepth += 1
        // 应用快照期间的选择在完整状态建立后执行；沿用嵌套 reload 忽略的既有约定。
        let wasReloading = isReloading
        isReloading = true
        defer { isReloading = wasReloading; endOperation() }
        cancelPaging(invalidatingRequest: false)
        stopAnimation()
        let oldIndex = selectedIndex
        let oldID = oldIndex.flatMap { identifiers.indices.contains($0) ? identifiers[$0] : nil }
        let next = SPScrollGeometry.selectedIndex(oldID: oldID, oldIndex: oldIndex, identifiers: newIDs)
        let nextID = next.map { newIDs[$0] }
        if oldID != nextID, let old = currentRecord {
            appear(old.controller, false)
        }
        for id in Array(records.keys) where !newIDs.contains(id) {
            removeRecord(id)
        }
        positions = positions.filter { newIDs.contains($0.key) }
        scrollViewSelections = scrollViewSelections.filter { newIDs.contains($0.key) }
        identifiers = newIDs
        items = newItems
        selectedIndex = next
        storedTabBar.setItems(items)
        if let next {
            let record = loadPage(next)
            align(record)
            if oldID != nextID, let record {
                appear(record.controller, true)
            }
        }
        storedTabBar.setSelectedItem(
            selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil },
            animated: false
        )
        view.setNeedsLayout()
        view.layoutIfNeeded()
        evictPages()
        if let next, oldID != nextID || oldIndex != next {
            delegate?.pageViewController(self, didSelectPageAt: next)
        }
    }

    /// 越界请求不改变状态。新请求取消尚未完成的旧转场。
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        selectPage(at: index, animated: animated, userItem: nil)
    }

    private func selectPage(at index: Int, animated: Bool, userItem: SPTabBarItem?) {
        guard identifiers.indices.contains(index) else {
            return
        }
        let id = identifiers[index]
        selectionGeneration &+= 1
        let generation = selectionGeneration
        if appearanceDepth > 0 || isReloading || loadingIdentifiers.contains(id) {
            pendingRequests.append { [weak self] in
                self?.performSelection(id, animated: animated, userItem: userItem, generation: generation)
            }
            return
        }
        performSelection(id, animated: animated, userItem: userItem, generation: generation)
    }

    private func performSelection(_ id: AnyHashable, animated: Bool, userItem: SPTabBarItem?, generation: UInt) {
        guard generation == selectionGeneration, identifiers.contains(id) else {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        loadViewIfNeeded()
        cancelPaging(invalidatingRequest: false)
        guard generation == selectionGeneration, let index = identifiers.firstIndex(of: id) else {
            return
        }
        if let userItem {
            storedTabBar.beginUserSelection(userItem)
        }
        guard generation == selectionGeneration else {
            return
        }
        guard index != selectedIndex else {
            withAppearanceUpdates { storedTabBar.completeUserSelection() }
            return
        }
        stopAnimation()
        view.layoutIfNeeded()
        guard generation == selectionGeneration, let index = identifiers.firstIndex(of: id) else {
            return
        }
        let isAdjacent = selectedIndex.map { abs(index - $0) == 1 } ?? false
        let animatePage = animated && isVisible && isAdjacent && pagingView.bounds.width > 0
        beginTransition(to: index, animated: animatePage)
        guard generation == selectionGeneration, transition?.incoming.identifier == id,
              let index = identifiers.firstIndex(of: id) else {
            return
        }
        let point = CGPoint(x: physicalIndex(index) * pagingView.bounds.width, y: 0)
        if animatePage {
            pagingView.setContentOffset(point, animated: true)
        } else {
            let wasSuppressing = suppressPaging
            suppressPaging = true
            pagingView.setContentOffset(point, animated: false)
            suppressPaging = wasSuppressing
            guard generation == selectionGeneration else {
                return
            }
            finishTransition(commit: true, animated: animated && isVisible)
        }
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
        scrollViewSelections[record.identifier] = stored
        record.scrollViewSelection = stored
        // 即使新旧均没有绑定，改变选择也应废弃原来的正文兜底拖动。
        if record === currentRecord {
            stopAnimation()
        }
        bind(record)
    }

    /// 页面异步创建或替换视图后调用。不改变绑定选择；显式列表失效时保持未绑定。
    public func rediscoverScrollView(forPageAt index: Int) {
        guard let record = loadPage(index) else {
            return
        }
        bind(record)
    }

    private func configureTabBar() {
        view.addSubview(storedTabBar)
        storedTabBar.selectionRequest = { [weak self] item in
            guard let self, let index = self.items.firstIndex(where: { $0 === item }) else {
                return
            }
            self.selectPage(at: index, animated: true, userItem: item)
        }
        storedTabBar.setItems(items)
        storedTabBar.setSelectedItem(selectedIndex.map { items[$0] }, animated: false)
        if let tabPan {
            storedTabBar.addGestureRecognizer(tabPan)
        }
    }

    private func replaceHeader(view newView: UIView?, controller newController: UIViewController?) {
        if newView === storedHeaderView && newController === storedHeaderController {
            return
        }
        if let newController, newController.parent != nil {
            return
        }
        if let old = storedHeaderController {
            appear(old, false)
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        storedHeaderView?.removeFromSuperview()
        storedHeaderView = newView
        storedHeaderController = newController
        if isViewLoaded {
            mountHeader(); updateLayoutConfiguration()
        }
    }

    private func mountHeader() {
        if let controller = storedHeaderController {
            if controller
                .parent ==
                nil {
                addChild(controller); headerHost.addSubview(controller.view); controller
                    .didMove(toParent: self); appear(
                        controller,
                        true
                    )
            }
        } else if let storedHeaderView {
            headerHost.addSubview(storedHeaderView)
        }
    }

    private func updateLayoutConfiguration() {
        guard isViewLoaded else {
            return
        }
        cancelPaging()
        stopAnimation()
        let range = effectiveLayout.collapseRange
        let wasCollapsed = previousCollapseRange.map { $0 > 0 && collapseOffset >= $0 } ?? false
        // 内容自适应导致 Header 增高时，沿用安全区域变化的吸顶契约，保留正文位置。
        collapseOffset = wasCollapsed ? range : min(collapseOffset, range)
        previousCollapseRange = range
        for record in records.values {
            record.binding?.setRange(range)
            align(record)
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        publishHeader()
    }

    private func layoutHeader() {
        let l = effectiveLayout
        headerHost.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: max(0, l.headerHeight - collapseOffset))
        headerHost.contentSize = CGSize(width: view.bounds.width, height: l.headerHeight)
        headerHost.contentOffset = CGPoint(x: 0, y: collapseOffset)
        let contentFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: l.headerHeight)
        storedHeaderView?.frame = contentFrame
        storedHeaderController?.view.frame = contentFrame
        // 背景铺满容器，标签栏内部负责交互内容的左右安全区域避让。
        storedTabBar.frame = CGRect(x: 0, y: headerHost.frame.maxY, width: view.bounds.width, height: l.tabBarHeight)
        let wasLayingOut = isLayingOutPages
        isLayingOutPages = true
        for (id, record) in records {
            guard let index = identifiers.firstIndex(of: id) else {
                continue
            }
            layoutPage(record, at: index, layout: l)
        }
        isLayingOutPages = wasLayingOut
        view.bringSubviewToFront(headerHost)
        view.bringSubviewToFront(storedTabBar)
    }

    private func layoutPage(_ record: SPPageRecord, at index: Int, layout: SPPageLayout) {
        let inset = max(0, layout.collapseRange - collapseOffset)
        let updates = {
            record.controller.view.frame = CGRect(
                x: self.physicalIndex(index) * self.pagingView.bounds.width,
                y: inset,
                width: self.pagingView.bounds.width,
                height: max(0, self.pagingView.bounds.height - inset)
            )
            record.safeArea.setTopContribution(layout.tabBarHeight)
            record.controller.view.layoutIfNeeded()
        }
        if let binding = record.binding {
            binding.layoutPage(
                range: layout.collapseRange,
                collapse: collapseOffset,
                root: record.controller.view,
                topOcclusion: layout.tabBarHeight,
                updates: updates
            )
        } else {
            updates()
        }
    }

    private func publishHeader() {
        layoutHeader()
        let range = effectiveLayout.collapseRange
        let progress = range == 0 ? 0 : collapseOffset / range
        let state: SPHeaderState = progress <= 0 ? .expanded : (progress >= 1 ? .collapsed : .collapsing)
        delegate?.pageViewController(self, didChangeHeaderState: state, progress: progress)
    }

    @discardableResult private func loadPage(
        _ index: Int,
        initialBindingSelection: SPScrollViewBinding? = nil
    ) -> SPPageRecord? {
        guard identifiers.indices.contains(index) else {
            return nil
        }
        let id = identifiers[index]
        accessCounter &+= 1
        if let record = records[id] {
            record.access = accessCounter; return record
        }
        guard loadingIdentifiers.insert(id).inserted else {
            return nil
        }
        operationDepth += 1
        defer { loadingIdentifiers.remove(id); endOperation() }
        guard let controller = dataSource?.pageViewController(self, viewControllerAt: index),
              controller.parent == nil, identifiers.contains(id) else {
            return nil
        }
        if let existing = records[id] {
            return existing
        }
        let record = SPPageRecord(identifier: id, controller: controller)
        record.access = accessCounter
        records[id] = record
        let selectionBeforeLoading = scrollViewSelections[id]
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
        guard records[id] === record, let layoutIndex = identifiers.firstIndex(of: id) else {
            return nil
        }
        // viewDidLoad 等加载回调中的选择更新比外层初始请求更新，不可被覆盖。
        if let selection = initialBindingSelection, scrollViewSelections[id] === selectionBeforeLoading {
            if case let .explicit(scroll) = selection,
               scroll !== controller.view, !scroll.isDescendant(of: controller.view) {
                // 非页面视图不改变原配置。
            } else {
                scrollViewSelections[id] = SPScrollViewBindingSelection(selection)
            }
        }
        pagingView.addSubview(root)
        layoutPage(record, at: layoutIndex, layout: effectiveLayout)
        guard records[id] === record else {
            return nil
        }
        controller.didMove(toParent: self)
        // 挂载回调可重排或移除页面：只查询仍有效的记录，并传递当前快照中的索引。
        guard records[id] === record, let bindingIndex = identifiers.firstIndex(of: id) else {
            return nil
        }
        if let stored = scrollViewSelections[id] {
            record.scrollViewSelection = stored
        } else {
            let proposed = dataSource?
                .pageViewController(self, scrollViewBindingFor: controller, at: bindingIndex) ?? .automatic
            // 数据源回调允许业务显式设置选择，回调返回值不能覆盖更新后的运行时意图。
            record.scrollViewSelection = scrollViewSelections[id] ?? SPScrollViewBindingSelection(proposed)
        }
        guard records[id] === record else {
            return nil
        }
        record.isPreparingBinding = false
        bind(record)
        // 首次绑定后同步页面位移和滚动 inset；根视图与标签栏顶部对齐，内容避让标签栏。
        layoutHeader()
        guard records[id] === record, identifiers.contains(id) else {
            return nil
        }
        mounted = true
        return record
    }

    private func bind(_ record: SPPageRecord) {
        // inset 还原和布局可同步回调业务。等待当前解绑完成后再应用最新选择，
        // 避免新绑定读取旧贡献，或旧操作覆盖回调中设置的选择。
        record.needsBinding = true
        guard !record.isPreparingBinding, !record.isBinding else {
            return
        }
        record.isBinding = true
        defer { record.isBinding = false }
        while record.needsBinding, records[record.identifier] === record {
            record.needsBinding = false
            applyBinding(record)
        }
    }

    private func applyBinding(_ record: SPPageRecord) {
        let root = record.controller.view!
        let scroll: UIScrollView?
        switch record.scrollViewSelection.mode {
        case .automatic:
            scroll = SPScrollViewDiscovery.find(in: root)
        case .unbound:
            scroll = nil
        case .explicit:
            scroll = record.scrollViewSelection.scrollView.flatMap {
                $0 === root || $0.isDescendant(of: root) ? $0 : nil
            }
        }
        if scroll === record.binding?.scrollView {
            return
        }
        if record === currentRecord {
            stopAnimation()
        }
        let previous = record.binding
        record.binding = nil
        previous?.detach()
        guard !record.needsBinding, records[record.identifier] === record else {
            return
        }
        if positions[record.identifier] == nil, let scroll {
            // 尚未叠加框架滚动 inset：此时归一化位移就是业务正文位置。
            // 已有记录（包括 0）继续按页面标识恢复，不被替换列表的初始值覆盖。
            positions[record.identifier] = max(0, scroll.contentOffset.y + scroll.adjustedContentInset.top)
        }
        record.binding = scroll.map(SPScrollBinding.init)
        record.binding?.onScrollDisabled = { [weak self, weak record] binding in
            guard let self, let record, record === self.currentRecord, record.binding === binding else {
                return
            }
            // 关闭后立即废弃旧交互，即使同一帧重新开启也不续接原来的拖动或惯性。
            self.stopAnimation()
        }
        record.binding?.onScroll = { [weak self, weak record] binding in
            guard let self, let record, !self.isLayingOutPages, !self.isTransitioningSize, !self.isPaging,
                  record === self.currentRecord, self.transitionTarget == nil else {
                return
            }
            // 系统尺寸变化可能先发送旧绑定的偏移回调；新几何完成布局前不能改写历史位置。
            guard self.previousBoundsSize == self.view.bounds.size,
                  self.previousCollapseRange == self.effectiveLayout.collapseRange else {
                return
            }
            if #available(iOS 26.0, *),
               self.view.window?.windowScene?.effectiveGeometry.isInteractivelyResizing == true {
                // 持续拖动窗口时，单次尺寸转换会在帧间结束；原生状态仍需保护保存位移。
                self.align(record)
                return
            }
            self.stopAnimation()
            self.consume(binding, for: record)
        }
        record.binding?.indicatorsHiddenForPaging = isPaging && scrollIndicatorVisibilityPolicy == .hideDuringPaging
        record.binding?.setRange(effectiveLayout.collapseRange)
        guard !record.needsBinding, records[record.identifier] === record else {
            return
        }
        layoutHeader()
        align(record)
        view.setNeedsLayout()
    }

    private func align(_ record: SPPageRecord?) {
        guard let record, let binding = record.binding else {
            return
        }
        let position = SPScrollGeometry.position(
            collapse: collapseOffset,
            content: positions[record.identifier] ?? 0,
            range: effectiveLayout.collapseRange
        )
        binding.setPosition(min(binding.maximumPosition, position))
    }

    private func consume(_ binding: SPScrollBinding, for record: SPPageRecord) {
        guard record === currentRecord, record.binding === binding,
              records[record.identifier] === record else {
            return
        }
        let range = effectiveLayout.collapseRange
        collapseOffset = SPScrollGeometry.collapse(binding.position, range: range)
        positions[record.identifier] = SPScrollGeometry.content(binding.position, range: range)
        publishHeader()
    }

    private func removeRecord(_ id: AnyHashable) {
        guard let record = records.removeValue(forKey: id) else {
            return
        }
        // 内容位置由当前页的 consume 记录；后台页的临时对齐不覆盖历史位置。
        record.binding?.detach()
        // 父级 appearance 尚未结束时，先在 containment 有效期间完成子级回调。
        if parentAppearance.contains(where: { $0 === record.controller }) {
            appear(record.controller, false)
        }
        record.controller.willMove(toParent: nil)
        record.controller.view.removeFromSuperview()
        record.controller.removeFromParent()
        record.safeArea.detach()
    }

    private func evictPages(limit: Int? = nil) {
        let capacity = max(1, limit ?? maximumCachedPageCount)
        var protectedIndices = [selectedIndex, transitionTarget].compactMap { $0 }
        if transitionTarget != nil || pagingView.isDragging || pagingView.isDecelerating {
            let position = logicalPosition()
            protectedIndices += [Int(floor(position)), Int(ceil(position))]
        }
        let protected = protectedIndices.filter { identifiers.indices.contains($0) }.map { identifiers[$0] }
        let candidates = records.values.filter {
            !protected.contains($0.identifier) && !loadingIdentifiers.contains($0.identifier)
                && !finishingIdentifiers.contains($0.identifier)
        }.sorted { $0.access < $1.access }
        for record in candidates where records.count > capacity {
            removeRecord(record.identifier)
        }
    }

    private func physicalIndex(_ logical: Int) -> CGFloat {
        CGFloat(isRTL ? identifiers.count - 1 - logical : logical)
    }

    private func logicalPosition() -> CGFloat {
        guard pagingView.bounds.width > 0 else {
            return CGFloat(selectedIndex ?? 0)
        }
        let physical = pagingView.contentOffset.x / pagingView.bounds.width
        return isRTL ? CGFloat(identifiers.count - 1) - physical : physical
    }

    private func alignPaging() {
        pagingView.contentOffset = CGPoint(
            x: selectedIndex.map { physicalIndex($0) * pagingView.bounds.width } ?? 0,
            y: 0
        )
    }

    private func endParentAppearance() {
        let controllers = parentAppearance
        parentAppearance.removeAll()
        parentIsAppearing = nil
        withAppearanceUpdates { controllers.forEach { $0.endAppearanceTransition() } }
    }

    private func appear(_ controller: UIViewController, _ appearing: Bool) {
        withAppearanceUpdates {
            if let index = parentAppearance.firstIndex(where: { $0 === controller }) {
                parentAppearance.remove(at: index)
                let wasAppearing = parentIsAppearing == true
                controller.endAppearanceTransition()
                if !appearing && wasAppearing {
                    controller.beginAppearanceTransition(false, animated: false)
                    controller.endAppearanceTransition()
                }
                return
            }
            if isVisible {
                controller.beginAppearanceTransition(appearing, animated: false)
                controller.endAppearanceTransition()
            } else if appearing && parentIsAppearing == true {
                parentAppearance.append(controller)
                controller.beginAppearanceTransition(true, animated: false)
            }
        }
    }

    private func beginTransition(to index: Int, animated: Bool = true) {
        guard index != selectedIndex, identifiers.indices.contains(index) else {
            return
        }
        let id = identifiers[index]
        if transition?.incoming.identifier == id {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        let generation = selectionGeneration
        if transition != nil {
            finishTransition(commit: false, continuingPaging: true)
        }
        guard generation == selectionGeneration, let currentIndex = identifiers.firstIndex(of: id),
              let incoming = loadPage(currentIndex), generation == selectionGeneration,
              records[id] === incoming else {
            return
        }
        beginPaging()
        guard generation == selectionGeneration, records[id] === incoming else {
            return
        }
        align(incoming)
        guard generation == selectionGeneration, records[id] === incoming else {
            return
        }
        let context = PageTransition(generation: generation, outgoing: currentRecord, incoming: incoming)
        transition = context
        withAppearanceUpdates {
            if isVisible {
                context.outgoingBegan = context.outgoing != nil
                context.outgoing?.controller.beginAppearanceTransition(false, animated: animated)
                context.incomingBegan = true
                incoming.controller.beginAppearanceTransition(true, animated: animated)
            }
            if generation != selectionGeneration, transition === context {
                finishTransition(commit: false)
            }
        }
    }

    private func finishTransition(commit: Bool, animated: Bool = true, continuingPaging: Bool = false) {
        guard let context = transition else {
            if !continuingPaging {
                if isPaging {
                    align(currentRecord)
                }
                isPaging = false
            }
            return
        }
        operationDepth += 1
        defer { endOperation() }
        // 先移走活动上下文，再调用 UIKit；回调不能递归结束同一转场。
        transition = nil
        let previousFinishing = finishingIdentifiers
        finishingIdentifiers.formUnion([context.outgoing?.identifier, context.incoming.identifier].compactMap { $0 })
        defer { finishingIdentifiers = previousFinishing; evictPages() }
        withAppearanceUpdates {
            let hadAppearance = context.outgoingBegan || context.incomingBegan
            if context.outgoingBegan {
                context.outgoingBegan = false
                context.outgoing?.controller.endAppearanceTransition()
            }
            if context.incomingBegan {
                context.incomingBegan = false
                context.incoming.controller.endAppearanceTransition()
            }
            let canCommit = commit && context.generation == selectionGeneration
                && records[context.incoming.identifier] === context.incoming
                && identifiers.contains(context.incoming.identifier)
            if !canCommit, hadAppearance {
                context.outgoing?.controller.beginAppearanceTransition(true, animated: false)
                context.outgoing?.controller.endAppearanceTransition()
                context.incoming.controller.beginAppearanceTransition(false, animated: false)
                context.incoming.controller.endAppearanceTransition()
            }
            if canCommit && !hadAppearance && parentIsAppearing == true {
                if let old = context.outgoing {
                    appear(old.controller, false)
                }
                if context.generation == selectionGeneration {
                    appear(context.incoming.controller, true)
                }
                if context.generation != selectionGeneration {
                    // 父级仍在出现时，撤销候选页并恢复旧页的待完成 appearance。
                    // 后续请求必须从完整的旧状态接管，不能留下两张待出现页面。
                    if parentAppearance.contains(where: { $0 === context.incoming.controller }) {
                        appear(context.incoming.controller, false)
                    }
                    if let old = context.outgoing {
                        appear(old.controller, true)
                    }
                }
            }
            let didCommit = canCommit && context.generation == selectionGeneration
            if didCommit {
                selectedIndex = identifiers.firstIndex(of: context.incoming.identifier)
                align(currentRecord)
            } else if !continuingPaging {
                align(currentRecord)
            }
            storedTabBar.synchronizeSelection(
                selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil },
                animated: didCommit && animated
            )
            if !continuingPaging {
                isPaging = false
            }
            if didCommit, let target = selectedIndex {
                // 已提交事件在队列中的下一次选择之前发送，保持提交顺序。
                storedTabBar.completeUserSelection()
                delegate?.pageViewController(self, didSelectPageAt: target)
            } else {
                storedTabBar.cancelUserSelection()
            }
        }
    }

    private func cancelPaging(invalidatingRequest: Bool = true) {
        if invalidatingRequest {
            selectionGeneration &+= 1
        }
        operationDepth += 1
        defer { endOperation() }
        storedTabBar.cancelUserSelection()
        guard isViewLoaded else {
            return
        }
        let wasSuppressing = suppressPaging
        suppressPaging = true
        defer { suppressPaging = wasSuppressing }
        pagingView.setContentOffset(pagingView.contentOffset, animated: false)
        finishTransition(commit: false)
        alignPaging()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        storedTabBar.cancelUserSelection()
        // 每次真实分页输入都取消框架旧交互；只对业务原生减速交接去重。
        stopAnimation()
        beginPaging()
        pagingView.preserveAcceptedPanDisplacement()
    }

    private func beginPaging() {
        guard !isPaging else {
            return
        }
        // 手势开始、候选页建立及候选页变化共用一次交接。
        isPaging = true
        stopAnimation()
        currentRecord?.binding?.stopDeceleration()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !suppressPaging, let selectedIndex, !identifiers.isEmpty else {
            return
        }
        operationDepth += 1
        defer { endOperation() }
        let snapshot = snapshotGeneration
        let selection = selectionGeneration
        let position = min(CGFloat(identifiers.count - 1), max(0, logicalPosition()))
        // 手势或相邻切页期间按需准备可见页；非相邻选择直接定位，不进入此路径。
        // 只保留当前、目标及最多两个可见页。
        let visibleIndices = Set([Int(floor(position)), Int(ceil(position))])
        for index in visibleIndices {
            if records[identifiers[index]] == nil {
                loadPage(index)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
        }
        // 页面加载可能更新标签内容；准备完成后只测量一次，两张可见页共用当前布局。
        let pageLayout = effectiveLayout
        for index in visibleIndices {
            // 页面横向进入视口时，UIKit 才会更新其自动安全区域 inset。
            // 同步撤销离屏时的标签栏补偿，避免首次切页期间重复避让、结束时正文上跳。
            if let record = records[identifiers[index]] {
                layoutPage(record, at: index, layout: pageLayout)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
        }
        evictPages()
        guard snapshot == snapshotGeneration, selection == selectionGeneration else {
            return
        }
        let delta = position - CGFloat(selectedIndex)
        if abs(delta) > 0.001 {
            let target = delta > 0 ? Int(ceil(position)) : Int(floor(position))
            if pagingView.isDragging || pagingView.isDecelerating {
                beginTransition(to: target)
                guard snapshot == snapshotGeneration, selection == selectionGeneration else {
                    return
                }
            }
            let end = transitionTarget ?? target
            let denominator = abs(CGFloat(end - selectedIndex))
            let progress = denominator == 0 ? 0 : min(1, abs(delta) / denominator)
            storedTabBar.setTransitionProgress(from: selectedIndex, to: end, progress: progress)
            delegate?.pageViewController(self, didScrollFrom: selectedIndex, to: end, progress: progress)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settlePaging()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 原生 pan 取消不是松手选页；即便已越过半页，也恢复原页和未提交的 appearance。
        if scrollView.panGestureRecognizer.state == .cancelled {
            cancelPaging()
            return
        }
        if !decelerate {
            settlePaging()
        }
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settlePaging()
    }

    private func settlePaging() {
        operationDepth += 1
        defer { endOperation() }
        let index = Int(logicalPosition().rounded())
        if index == selectedIndex {
            finishTransition(commit: false)
        } else {
            beginTransition(to: index); finishTransition(commit: true)
        }
        let wasSuppressing = suppressPaging
        suppressPaging = true; alignPaging(); suppressPaging = wasSuppressing
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let record = currentRecord,
              transitionTarget == nil else {
            return false
        }
        if record.binding?.scrollView.isScrollEnabled == false {
            return false
        }
        if let dragPan, dragPan !== pan {
            return false
        }
        if gestureRecognizer === plainPagePan &&
            (record.binding != nil || record.scrollViewSelection.mode != .automatic) {
            return false
        }
        if record.binding == nil && effectiveLayout.collapseRange <= 0 {
            return false
        }
        let v = pan.velocity(in: view)
        return abs(v.y) > abs(v.x)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let candidate = target, candidate !== gestureRecognizer.view {
            // 默认标签按钮允许父级纵向拖动，其他 Header 控件保留自身交互。
            if gestureRecognizer === headerPan || gestureRecognizer === plainPagePan {
                if candidate is UIControl || candidate is UITextView {
                    return false
                }
                if candidate.gestureRecognizers?
                    .contains(where: { $0.isEnabled && $0 !== gestureRecognizer && !($0 is UITapGestureRecognizer) }) ==
                    true {
                    return false
                }
            }
            target = candidate.superview
        }
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === tabPan && otherGestureRecognizer.view?.isDescendant(of: storedTabBar) == true
    }

    @objc internal func handleHeaderPan(_ pan: UIPanGestureRecognizer) {
        guard let record = currentRecord, transitionTarget == nil else {
            return
        }
        let binding = record.binding
        // 业务禁用列表滚动时暂停整次纵向联动；保留布局及切页使用的程序化协调。
        guard binding?.scrollView.isScrollEnabled != false else {
            stopAnimation()
            return
        }
        // 切页、重新绑定或布局变化后，旧触摸不能继续驱动新的滚动状态。
        if pan.state == .began {
            if let dragPan, dragPan !== pan {
                return
            }
        } else if dragPan !== pan || dragRecord !== record || dragBinding !== binding {
            return
        }
        switch pan.state {
        case .began:
            stopAnimation()
            dragRecord = record; dragBinding = binding; dragPan = pan
            // 先登记交互，让停止原生减速时的同步业务回调也能取消本次拖动。
            binding?.stopDeceleration()
            guard dragPan === pan, dragRecord === record, dragBinding === binding else {
                return
            }
            dragStart = binding?.position ?? collapseOffset
        case .changed:
            let translation = pan.translation(in: view).y
            let raw = dragStart - translation
            let maximum = binding?.maximumPosition ?? effectiveLayout.collapseRange
            let bound = min(max(0, raw), maximum)
            // 丢弃越界距离并同步手势基准，反向拖动立即生效，不积累边界外的空行程。
            dragStart = bound + translation
            if let binding {
                // 框架拖动仅协调合法范围，列表原生回弹由业务配置和 UIKit 管理。
                let generation = interactionGeneration
                binding.setPosition(bound)
                guard generation == interactionGeneration, dragPan === pan,
                      dragRecord === record, dragBinding === binding else {
                    return
                }
                consume(binding, for: record)
            } else {
                // 普通页面只消耗 Header 范围，不生成内容位移或越界回弹。
                collapseOffset = bound
                publishHeader()
            }
        case .ended:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = -pan.velocity(in: view).y
            startAnimation()
        case .cancelled, .failed:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = 0
            if binding != nil {
                startAnimation()
            } else {
                stopAnimation()
            }
        default: break
        }
    }

    private func startAnimation() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: displayTarget, selector: #selector(SPDisplayLinkTarget.step(_:)))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    private func stopAnimation() {
        interactionGeneration &+= 1
        displayLink?.invalidate(); displayLink = nil
        dragRecord = nil; dragBinding = nil; dragPan = nil
    }

    private func stepAnimation(_ link: CADisplayLink) {
        guard let record = currentRecord, transitionTarget == nil else {
            stopAnimation(); return
        }
        let dt = min(1.0 / 30, max(1.0 / 240, link.targetTimestamp - link.timestamp))
        guard let binding = record.binding else {
            animationVelocity *= pow(UIScrollView.DecelerationRate.normal.rawValue, dt * 1000)
            let raw = collapseOffset + animationVelocity * dt
            collapseOffset = SPScrollGeometry.collapse(raw, range: effectiveLayout.collapseRange)
            publishHeader()
            if abs(animationVelocity) < 2 || collapseOffset <= 0 || collapseOffset >= effectiveLayout
                .collapseRange {
                stopAnimation()
            }
            return
        }
        guard binding.scrollView.isScrollEnabled else {
            stopAnimation()
            return
        }
        animationVelocity *= pow(binding.scrollView.decelerationRate.rawValue, dt * 1000)
        let position = min(max(0, binding.position + animationVelocity * dt), binding.maximumPosition)
        let generation = interactionGeneration
        binding.setPosition(position)
        guard generation == interactionGeneration, displayLink === link,
              record === currentRecord, record.binding === binding else {
            return
        }
        consume(binding, for: record)
        guard generation == interactionGeneration, displayLink === link else {
            return
        }
        // 到达边界即停止，不为业务列表制造越界位移或弹簧回弹。
        if abs(animationVelocity) < 2 || position <= 0 || position >= binding.maximumPosition {
            stopAnimation()
        }
    }
}
