import UIKit

/// 提供共享折叠 Header、标签栏与横向分页的 UIKit 容器。
@MainActor
open class SPPageViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public weak var dataSource: (any SPPageViewControllerDataSource)?
    public weak var delegate: (any SPPageViewControllerDelegate)?
    public private(set) var selectedIndex: Int?
    public var isPagingEnabled = true { didSet { pagingView.isScrollEnabled = isPagingEnabled } }
    public var maximumCachedPageCount = 3 { didSet { evictPages() } }
    public var layout = SPPageLayout() { didSet { updateLayoutConfiguration() } }

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
            guard newValue !== storedTabBar else { return }
            stopAnimation()
            storedTabBar.onSelect = nil
            storedTabBar.removeFromSuperview()
            storedTabBar = newValue
            if isViewLoaded { configureTabBar(); view.setNeedsLayout() }
        }
    }

    internal let pagingView = SPPagingScrollView()
    internal private(set) var collapseOffset: CGFloat = 0
    internal private(set) var records: [AnyHashable: SPPageRecord] = [:]
    internal var currentScrollView: UIScrollView? { currentRecord?.binding?.scrollView }
    private var identifiers: [AnyHashable] = []
    private var items: [SPTabBarItem] = []
    private var positions: [AnyHashable: CGFloat] = [:]
    private let headerHost = UIScrollView()
    private var storedHeaderView: UIView?
    private var storedHeaderController: UIViewController?
    private var storedTabBar = SPTabBar()
    private var isVisible = false
    private var parentAppearance: [UIViewController] = []
    private var parentIsAppearing: Bool?
    private var transitionTarget: Int?
    private var transitionAppearance = false
    private var indicatorsHiddenForPaging = false {
        didSet {
            guard oldValue != indicatorsHiddenForPaging else { return }
            for record in records.values { record.binding?.indicatorsHiddenForPaging = indicatorsHiddenForPaging }
        }
    }
    private var suppressPaging = false
    private var previousSize: CGSize = .zero
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
        guard let selectedIndex, identifiers.indices.contains(selectedIndex) else { return nil }
        return records[identifiers[selectedIndex]]
    }
    private var effectiveLayout: SPPageLayout {
        var value = layout.normalized
        // 配置高度作为下限；辅助字号需要更高的标签栏，0 仍表示隐藏。
        if value.tabBarHeight > 0 {
            value.tabBarHeight = max(value.tabBarHeight, storedTabBar.sizeThatFits(.zero).height)
        }
        if storedHeaderView == nil && storedHeaderController == nil { value.headerHeight = 0; value.minimumHeaderHeight = 0 }
        // Header 从容器顶部铺开，标签栏仍在安全区域下方吸顶。
        // 高度不足时补足吸顶基线，避免标签栏进入导航栏或产生负折叠距离。
        value.minimumHeaderHeight += isViewLoaded ? view.safeAreaInsets.top : 0
        value.headerHeight = max(value.headerHeight, value.minimumHeaderHeight)
        return value
    }
    private var isRTL: Bool { view.effectiveUserInterfaceLayoutDirection == .rightToLeft }

    open override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        pagingView.isPagingEnabled = true
        pagingView.bounces = false
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
        if #available(iOS 26.0, *) { headerHost.topEdgeEffect.style = .soft }
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
        parentAppearance.forEach { $0.beginAppearanceTransition(true, animated: animated) }
    }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        endParentAppearance()
        isVisible = true
    }
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelPaging()
        stopAnimation()
        isVisible = false
        endParentAppearance()
        parentIsAppearing = false
        parentAppearance = [storedHeaderController, currentRecord?.controller].compactMap { $0 }
        parentAppearance.forEach { $0.beginAppearanceTransition(false, animated: animated) }
    }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        endParentAppearance()
    }
    open override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        sizeTransitionGeneration &+= 1
        let generation = sizeTransitionGeneration
        isTransitioningSize = true
        super.viewWillTransition(to: size, with: coordinator)
        let queued = coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self, self.sizeTransitionGeneration == generation else { return }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            for record in self.records.values { self.align(record) }
            self.isTransitioningSize = false
        }
        if !queued { isTransitioningSize = false }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let l = effectiveLayout
        isLayingOutPages = true
        previousBoundsSize = view.bounds.size
        defer { isLayingOutPages = false }
        let rangeChanged = previousCollapseRange != l.collapseRange
        if rangeChanged {
            // 旋转、导航栏显隐或安全区域变化时，已吸顶的页面继续吸顶。
            let wasCollapsed = previousCollapseRange.map { $0 > 0 && collapseOffset >= $0 } ?? false
            collapseOffset = wasCollapsed ? l.collapseRange : min(collapseOffset, l.collapseRange)
            previousCollapseRange = l.collapseRange
            stopAnimation()
        }
        // 页面铺满容器宽度并延伸至底边；安全区域由子页面的布局或自动滚动 inset 处理。
        let pageFrame = CGRect(x: 0, y: l.minimumHeaderHeight + l.tabBarHeight,
                               width: view.bounds.width,
                               height: max(0, view.bounds.height - l.minimumHeaderHeight - l.tabBarHeight))
        let sizeChanged = pageFrame.size != previousSize
        if sizeChanged {
            cancelPaging()
            stopAnimation()
            previousSize = pageFrame.size
        }
        suppressPaging = true
        pagingView.frame = pageFrame
        pagingView.contentSize = CGSize(width: pageFrame.width * CGFloat(identifiers.count), height: pageFrame.height)
        // 先对齐分页视口，再布局子页，避免 RTL 尺寸变化时按旧偏移计算子页安全区域。
        if !pagingView.isDragging && !pagingView.isDecelerating && transitionTarget == nil { alignPaging() }
        for (id, record) in records {
            guard let index = identifiers.firstIndex(of: id) else { continue }
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
        suppressPaging = false
        if rangeChanged { publishHeader() } else { layoutHeader() }
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
        records.values.forEach { $0.binding?.detach() }
    }

    /// 同步更新页面快照。重复标识拒绝整次更新；相同标识复用已有控制器。
    public func reloadData() {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        loadViewIfNeeded()
        let count = max(0, dataSource?.numberOfPages(in: self) ?? 0)
        var newIDs: [AnyHashable] = [], newItems: [SPTabBarItem] = []
        for index in 0..<count {
            guard let source = dataSource else { return }
            newIDs.append(source.pageViewController(self, identifierForPageAt: index))
            newItems.append(source.pageViewController(self, tabBarItemAt: index))
        }
        guard Set(newIDs).count == newIDs.count else {
            NSLog("StickyPagerKit: reloadData 拒绝重复页面标识")
            return
        }
        cancelPaging()
        stopAnimation()
        let oldIndex = selectedIndex
        let oldID = oldIndex.flatMap { identifiers.indices.contains($0) ? identifiers[$0] : nil }
        let next = SPScrollGeometry.selectedIndex(oldID: oldID, oldIndex: oldIndex, identifiers: newIDs)
        let nextID = next.map { newIDs[$0] }
        if oldID != nextID, let old = currentRecord { appear(old.controller, false) }
        for id in Array(records.keys) where !newIDs.contains(id) { removeRecord(id) }
        positions = positions.filter { newIDs.contains($0.key) }
        identifiers = newIDs
        items = newItems
        selectedIndex = next
        storedTabBar.setItems(items)
        if let next {
            let record = loadPage(next)
            align(record)
            if oldID != nextID, let record { appear(record.controller, true) }
        }
        storedTabBar.setSelectedIndex(next, animated: false)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        evictPages()
        if let next, oldID != nextID || oldIndex != next { delegate?.pageViewController(self, didSelectPageAt: next) }
    }

    /// 越界请求不改变状态。新请求取消尚未完成的旧转场。
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard identifiers.indices.contains(index) else { return }
        loadViewIfNeeded()
        cancelPaging()
        guard index != selectedIndex else { return }
        stopAnimation()
        currentRecord?.binding?.stopDeceleration()
        view.layoutIfNeeded()
        let isAdjacent = selectedIndex.map { abs(index - $0) == 1 } ?? false
        let animatePage = animated && isVisible && isAdjacent && pagingView.bounds.width > 0
        beginTransition(to: index, animated: animatePage)
        let point = CGPoint(x: physicalIndex(index) * pagingView.bounds.width, y: 0)
        if animatePage {
            pagingView.setContentOffset(point, animated: true)
        } else {
            suppressPaging = true
            pagingView.setContentOffset(point, animated: false)
            suppressPaging = false
            finishTransition(commit: true, animated: animated && isVisible)
        }
    }

    /// 指定页面内的滚动视图；nil 恢复自动发现。视图必须属于该页面视图树。
    public func setScrollView(_ scrollView: UIScrollView?, forPageAt index: Int) {
        guard let record = loadPage(index) else { return }
        if let scrollView, !scrollView.isDescendant(of: record.controller.view) && scrollView !== record.controller.view { return }
        record.explicitScrollView = scrollView
        bind(record)
    }

    /// 页面异步创建或替换视图后调用。显式指定仍然有效时优先使用它。
    public func rediscoverScrollView(forPageAt index: Int) {
        guard let record = loadPage(index) else { return }
        bind(record)
    }

    private func configureTabBar() {
        view.addSubview(storedTabBar)
        storedTabBar.onSelect = { [weak self] index in self?.setSelectedIndex(index, animated: true) }
        storedTabBar.setItems(items)
        storedTabBar.setSelectedIndex(selectedIndex, animated: false)
        if let tabPan { storedTabBar.addGestureRecognizer(tabPan) }
    }

    private func replaceHeader(view newView: UIView?, controller newController: UIViewController?) {
        if newView === storedHeaderView && newController === storedHeaderController { return }
        if let newController, newController.parent != nil { return }
        if let old = storedHeaderController {
            appear(old, false)
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        storedHeaderView?.removeFromSuperview()
        storedHeaderView = newView
        storedHeaderController = newController
        if isViewLoaded { mountHeader(); updateLayoutConfiguration() }
    }
    private func mountHeader() {
        if let controller = storedHeaderController {
            if controller.parent == nil { addChild(controller); headerHost.addSubview(controller.view); controller.didMove(toParent: self); appear(controller, true) }
        } else if let storedHeaderView { headerHost.addSubview(storedHeaderView) }
    }
    private func updateLayoutConfiguration() {
        guard isViewLoaded else { return }
        cancelPaging()
        stopAnimation()
        collapseOffset = min(collapseOffset, effectiveLayout.collapseRange)
        previousCollapseRange = effectiveLayout.collapseRange
        for record in records.values {
            record.binding?.setRange(effectiveLayout.collapseRange)
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
            guard let index = identifiers.firstIndex(of: id) else { continue }
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
                x: self.physicalIndex(index) * self.pagingView.bounds.width, y: inset,
                width: self.pagingView.bounds.width, height: max(0, self.pagingView.bounds.height - inset))
            record.controller.view.layoutIfNeeded()
        }
        if let binding = record.binding {
            binding.layoutPage(range: layout.collapseRange, collapse: collapseOffset, updates: updates)
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

    @discardableResult private func loadPage(_ index: Int) -> SPPageRecord? {
        guard identifiers.indices.contains(index) else { return nil }
        let id = identifiers[index]
        accessCounter &+= 1
        if let record = records[id] { record.access = accessCounter; return record }
        guard let controller = dataSource?.pageViewController(self, viewControllerAt: index), controller.parent == nil else { return nil }
        let record = SPPageRecord(identifier: id, controller: controller)
        record.access = accessCounter
        records[id] = record
        addChild(controller)
        pagingView.addSubview(controller.view)
        layoutPage(record, at: index, layout: effectiveLayout)
        controller.didMove(toParent: self)
        bind(record)
        // 首次绑定后同步页面位移和滚动 inset，所有页面均紧接当前标签栏。
        layoutHeader()
        return record
    }
    private func bind(_ record: SPPageRecord) {
        let root = record.controller.view!
        let explicit = record.explicitScrollView
        let validExplicit = explicit.flatMap { $0 === root || $0.isDescendant(of: root) ? $0 : nil }
        let scroll = validExplicit ?? SPScrollViewDiscovery.find(in: root)
        if scroll === record.binding?.scrollView { return }
        if record === currentRecord { stopAnimation() }
        record.binding?.detach()
        record.binding = scroll.map(SPScrollBinding.init)
        record.binding?.indicatorsHiddenForPaging = indicatorsHiddenForPaging
        record.binding?.setRange(effectiveLayout.collapseRange)
        record.binding?.onScroll = { [weak self, weak record] binding in
            guard let self, let record, !self.isLayingOutPages, !self.isTransitioningSize, record === self.currentRecord, self.transitionTarget == nil else { return }
            // 系统尺寸变化可能先发送旧绑定的偏移回调；新几何完成布局前不能改写历史位置。
            guard self.previousBoundsSize == self.view.bounds.size,
                  self.previousCollapseRange == self.effectiveLayout.collapseRange else { return }
            if #available(iOS 26.0, *), self.view.window?.windowScene?.effectiveGeometry.isInteractivelyResizing == true {
                // 持续拖动窗口时，单次尺寸转换会在帧间结束；原生状态仍需保护保存位移。
                self.align(record)
                return
            }
            self.stopAnimation()
            self.consume(binding)
        }
        layoutHeader()
        align(record)
        view.setNeedsLayout()
    }
    private func align(_ record: SPPageRecord?) {
        guard let record, let binding = record.binding else { return }
        if binding.isRefreshing {
            // 后台刷新页和转场候选页不能改变当前共享 Header。
            if record === currentRecord {
                collapseOffset = 0
                if binding.position > 0 { binding.setPosition(0) }
                publishHeader()
            }
            return
        }
        let position = SPScrollGeometry.position(collapse: collapseOffset, content: positions[record.identifier] ?? 0,
                                                 range: effectiveLayout.collapseRange)
        binding.setPosition(min(binding.maximumPosition, position))
    }
    private func consume(_ binding: SPScrollBinding) {
        let range = effectiveLayout.collapseRange
        collapseOffset = binding.isRefreshing ? 0 : SPScrollGeometry.collapse(binding.position, range: range)
        if binding.isRefreshing && binding.position > 0 { binding.setPosition(0) }
        if let id = currentRecord?.identifier { positions[id] = SPScrollGeometry.content(binding.position, range: range) }
        publishHeader()
    }
    private func removeRecord(_ id: AnyHashable) {
        guard let record = records.removeValue(forKey: id) else { return }
        // 内容位置由当前页的 consume 记录；后台页的临时对齐不覆盖历史位置。
        record.binding?.detach()
        // 父级 appearance 尚未结束时，先在 containment 有效期间完成子级回调。
        if parentAppearance.contains(where: { $0 === record.controller }) { appear(record.controller, false) }
        record.controller.willMove(toParent: nil)
        record.controller.view.removeFromSuperview()
        record.controller.removeFromParent()
    }
    private func evictPages(limit: Int? = nil) {
        let capacity = max(1, limit ?? maximumCachedPageCount)
        var protectedIndices = [selectedIndex, transitionTarget].compactMap { $0 }
        if transitionTarget != nil || pagingView.isDragging || pagingView.isDecelerating {
            let position = logicalPosition()
            protectedIndices += [Int(floor(position)), Int(ceil(position))]
        }
        let protected = protectedIndices.filter { identifiers.indices.contains($0) }.map { identifiers[$0] }
        let candidates = records.values.filter { !protected.contains($0.identifier) }.sorted { $0.access < $1.access }
        for record in candidates where records.count > capacity { removeRecord(record.identifier) }
    }

    private func physicalIndex(_ logical: Int) -> CGFloat { CGFloat(isRTL ? identifiers.count - 1 - logical : logical) }
    private func logicalPosition() -> CGFloat {
        guard pagingView.bounds.width > 0 else { return CGFloat(selectedIndex ?? 0) }
        let physical = pagingView.contentOffset.x / pagingView.bounds.width
        return isRTL ? CGFloat(identifiers.count - 1) - physical : physical
    }
    private func alignPaging() {
        pagingView.contentOffset = CGPoint(x: selectedIndex.map { physicalIndex($0) * pagingView.bounds.width } ?? 0, y: 0)
    }
    private func endParentAppearance() {
        parentAppearance.forEach { $0.endAppearanceTransition() }
        parentAppearance.removeAll()
        parentIsAppearing = nil
    }
    private func appear(_ controller: UIViewController, _ appearing: Bool) {
        if let index = parentAppearance.firstIndex(where: { $0 === controller }) {
            parentAppearance.remove(at: index)
            controller.endAppearanceTransition()
            if !appearing && parentIsAppearing == true {
                controller.beginAppearanceTransition(false, animated: false)
                controller.endAppearanceTransition()
            }
            return
        }
        if isVisible {
            controller.beginAppearanceTransition(appearing, animated: false)
            controller.endAppearanceTransition()
        } else if appearing && parentIsAppearing == true {
            controller.beginAppearanceTransition(true, animated: false)
            parentAppearance.append(controller)
        }
    }
    private func beginTransition(to index: Int, animated: Bool = true) {
        guard index != selectedIndex, identifiers.indices.contains(index) else { return }
        if transitionTarget == index { return }
        if transitionTarget != nil { finishTransition(commit: false, continuingPaging: true) }
        guard let incoming = loadPage(index) else { return }
        indicatorsHiddenForPaging = true
        currentRecord?.binding?.stopDeceleration()
        align(incoming)
        transitionTarget = index
        transitionAppearance = isVisible
        if transitionAppearance {
            currentRecord?.controller.beginAppearanceTransition(false, animated: animated)
            incoming.controller.beginAppearanceTransition(true, animated: animated)
        }
    }
    private func finishTransition(commit: Bool, animated: Bool = true, continuingPaging: Bool = false) {
        guard let target = transitionTarget else {
            if !continuingPaging { indicatorsHiddenForPaging = false }
            return
        }
        let old = currentRecord?.controller
        let incoming = records[identifiers[target]]?.controller
        if transitionAppearance {
            old?.endAppearanceTransition()
            incoming?.endAppearanceTransition()
            if !commit {
                old?.beginAppearanceTransition(true, animated: false); old?.endAppearanceTransition()
                incoming?.beginAppearanceTransition(false, animated: false); incoming?.endAppearanceTransition()
            }
        }
        if commit && !transitionAppearance && parentIsAppearing == true {
            if let old { appear(old, false) }
            if let incoming { appear(incoming, true) }
        }
        transitionTarget = nil
        transitionAppearance = false
        if commit {
            selectedIndex = target
            align(currentRecord)
        }
        storedTabBar.setSelectedIndex(selectedIndex, animated: commit && animated)
        evictPages()
        // 中途改变候选页仍属于同一次分页，保持隐藏；结束后按业务偏好恢复。
        if !continuingPaging { indicatorsHiddenForPaging = false }
        if commit { delegate?.pageViewController(self, didSelectPageAt: target) }
    }
    private func cancelPaging() {
        guard isViewLoaded else { return }
        suppressPaging = true
        pagingView.setContentOffset(pagingView.contentOffset, animated: false)
        finishTransition(commit: false)
        alignPaging()
        suppressPaging = false
    }
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        indicatorsHiddenForPaging = true
        stopAnimation()
        currentRecord?.binding?.stopDeceleration()
    }
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !suppressPaging, let selectedIndex, !identifiers.isEmpty else { return }
        let position = min(CGFloat(identifiers.count - 1), max(0, logicalPosition()))
        // 手势或相邻切页期间按需准备可见页；非相邻选择直接定位，不进入此路径。
        // 只保留当前、目标及最多两个可见页。
        for index in Set([Int(floor(position)), Int(ceil(position))]) {
            if records[identifiers[index]] == nil { loadPage(index) }
        }
        evictPages()
        let delta = position - CGFloat(selectedIndex)
        if abs(delta) > 0.001 {
            let target = delta > 0 ? Int(ceil(position)) : Int(floor(position))
            if pagingView.isDragging || pagingView.isDecelerating { beginTransition(to: target) }
            let end = transitionTarget ?? target
            let denominator = abs(CGFloat(end - selectedIndex))
            let progress = denominator == 0 ? 0 : min(1, abs(delta) / denominator)
            storedTabBar.setTransitionProgress(from: selectedIndex, to: end, progress: progress)
            delegate?.pageViewController(self, didScrollFrom: selectedIndex, to: end, progress: progress)
        }
    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { settlePaging() }
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { if !decelerate { settlePaging() } }
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { settlePaging() }
    private func settlePaging() {
        let index = Int(logicalPosition().rounded())
        if index == selectedIndex { finishTransition(commit: false) }
        else { beginTransition(to: index); finishTransition(commit: true) }
        suppressPaging = true; alignPaging(); suppressPaging = false
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let record = currentRecord,
              record.binding?.isRefreshing != true, transitionTarget == nil else { return false }
        if let dragPan, dragPan !== pan { return false }
        if gestureRecognizer === plainPagePan && record.binding != nil { return false }
        if record.binding == nil && effectiveLayout.collapseRange <= 0 { return false }
        let v = pan.velocity(in: view)
        return abs(v.y) > abs(v.x)
    }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let candidate = target, candidate !== gestureRecognizer.view {
            // 默认标签按钮允许父级纵向拖动，其他 Header 控件保留自身交互。
            if gestureRecognizer === headerPan || gestureRecognizer === plainPagePan {
                if candidate is UIControl || candidate is UITextView { return false }
                if candidate.gestureRecognizers?.contains(where: { $0.isEnabled && $0 !== gestureRecognizer && !($0 is UITapGestureRecognizer) }) == true { return false }
            }
            target = candidate.superview
        }
        return true
    }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === tabPan && otherGestureRecognizer.view?.isDescendant(of: storedTabBar) == true
    }
    @objc internal func handleHeaderPan(_ pan: UIPanGestureRecognizer) {
        guard let record = currentRecord, transitionTarget == nil,
              record.binding?.isRefreshing != true else { return }
        let binding = record.binding
        // 切页、重新绑定或布局变化后，旧触摸不能继续驱动新的滚动状态。
        if pan.state == .began {
            if let dragPan, dragPan !== pan { return }
        } else if dragPan !== pan || dragRecord !== record || dragBinding !== binding { return }
        switch pan.state {
        case .began:
            stopAnimation(); binding?.stopDeceleration()
            dragRecord = record; dragBinding = binding; dragPan = pan
            dragStart = binding?.position ?? collapseOffset
        case .changed:
            let raw = dragStart - pan.translation(in: view).y
            if let binding {
                let bound = min(max(0, raw), binding.maximumPosition)
                binding.setPosition(bound + (raw - bound) * 0.35)
                consume(binding)
            } else {
                // 普通页面只消耗 Header 范围，不生成内容位移或越界回弹。
                collapseOffset = SPScrollGeometry.collapse(raw, range: effectiveLayout.collapseRange)
                publishHeader()
            }
        case .ended:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = -pan.velocity(in: view).y
            startAnimation()
        case .cancelled, .failed:
            dragRecord = nil; dragBinding = nil; dragPan = nil
            animationVelocity = 0
            if binding != nil { startAnimation() } else { stopAnimation() }
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
        displayLink?.invalidate(); displayLink = nil
        dragRecord = nil; dragBinding = nil; dragPan = nil
    }
    private func stepAnimation(_ link: CADisplayLink) {
        guard let record = currentRecord, transitionTarget == nil,
              record.binding?.isRefreshing != true else { stopAnimation(); return }
        let dt = min(1.0 / 30, max(1.0 / 240, link.targetTimestamp - link.timestamp))
        guard let binding = record.binding else {
            animationVelocity *= pow(UIScrollView.DecelerationRate.normal.rawValue, dt * 1000)
            let raw = collapseOffset + animationVelocity * dt
            collapseOffset = SPScrollGeometry.collapse(raw, range: effectiveLayout.collapseRange)
            publishHeader()
            if abs(animationVelocity) < 2 || collapseOffset <= 0 || collapseOffset >= effectiveLayout.collapseRange { stopAnimation() }
            return
        }
        var position = binding.position
        let target = min(max(0, position), binding.maximumPosition)
        if abs(position - target) > 0.1 {
            animationVelocity += (-180 * (position - target) - 26 * animationVelocity) * dt
        } else {
            animationVelocity *= pow(binding.scrollView.decelerationRate.rawValue, dt * 1000)
        }
        position += animationVelocity * dt
        if abs(animationVelocity) < 2 && abs(position - target) < 0.5 {
            binding.setPosition(target); consume(binding); stopAnimation(); return
        }
        binding.setPosition(position)
        consume(binding)
    }
}
