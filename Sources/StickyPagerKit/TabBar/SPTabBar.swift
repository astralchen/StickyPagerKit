import UIKit

/// 支持可滚动图文标签、动态内容和分页进度的标签栏。
@MainActor
open class SPTabBar: UIView {
    public weak var delegate: SPTabBarDelegate?
    /// 指示器展示方式，与 ContentStyle 独立。
    public enum IndicatorStyle: Int, Sendable {
        /// 内置胶囊；默认在标签项四周内缩 4 pt，使用系统填充色。
        case capsule
        /// 内置线条；默认位于底部，高 3 pt，跟随选中文字颜色。
        case underline
        /// 启用几何代理和自定义视图；缺失的部分独立回退到默认实现。
        case custom
        /// 不使用指示器：跳过几何与渲染，不调用自定义扩展点；标签选择和分页不受影响。
        case none
    }

    public var indicatorStyle: IndicatorStyle = .capsule {
        didSet {
            guard oldValue != indicatorStyle else {
                return
            }
            reloadIndicator()
        }
    }

    /// 内容展示方式，与 indicatorStyle 的指示器展示方式独立。
    public enum ContentStyle: Int, Sendable {
        /// 内置图文内容；不调用内容代理。
        case `default`
        /// 由内容代理配置只负责显示的 UI，点击和无障碍仍由标签栏管理。
        case custom
    }

    /// 默认使用内置内容；切换模式保留 Item 身份和当前选择。
    /// 自定义内容缺失或尺寸无效时，逐项回退到内置内容。
    public var contentStyle: ContentStyle = .default {
        didSet {
            if oldValue != contentStyle {
                itemDidChange()
            }
        }
    }

    /// 每项 Cell 的最小布局宽度，默认 44 pt；适用于默认内容、自定义内容和回退项。
    /// 内容需要更多空间时使用内容所需宽度，其余空间尽量等宽分配；超出视口时横向滚动。
    /// 0 表示不额外设置宽度下限；负数归零，非有限值恢复为 44，大于 1,000,000 pt 时截到该上限。
    /// 不改变内容的理想尺寸，不扩大 Cell 之外的点击区域；实际几何不变时保留滚动和转场。
    public var minimumItemWidth: CGFloat {
        get { storedMinimumItemWidth }
        set {
            let value = newValue.isFinite ? min(1_000_000, max(0, newValue)) : 44
            guard value != storedMinimumItemWidth else {
                return
            }
            storedMinimumItemWidth = value
            refreshContentLayout()
        }
    }

    private var storedMinimumItemWidth: CGFloat = 44

    /// 相邻 Item 布局区域之间的固定水平间距，默认 0；首尾不额外留白。
    /// 不计入 Item 的内容测量或 minimumItemWidth；宽度分配和滚动范围包含总间距。
    /// 负数及非有限值归零，大于 1,000,000 pt 时截到该上限；空列表或单项不产生间距。
    /// 运行时修改保留选择与分页进度；几何变化时沿用内容布局的滚动与动画更新策略。
    public var itemSpacing: CGFloat {
        get { storedItemSpacing }
        set {
            let value = newValue.isFinite ? min(1_000_000, max(0, newValue)) : 0
            guard value != storedItemSpacing else {
                return
            }
            storedItemSpacing = value
            refreshContentLayout()
        }
    }

    private var storedItemSpacing: CGFloat = 0

    /// 仅在 `.custom` 模式下使用，业务方需自行持有代理。
    /// 赋值会刷新自定义内容；`.default` 下不影响当前显示或交互。
    /// 弱引用释放不会主动安排布局，在下一次标签栏布局时回退到默认内容。
    public weak var contentDelegate: (any SPTabBarContentDelegate)? {
        didSet { reloadContent() }
    }

    /// 业务自有数据变化后重新获取自定义配置与尺寸；默认模式下不改变显示或交互。
    /// 尺寸不变时保留滚动偏移、选择动画及分页进度，不发送选择回调。
    /// 尺寸变化时将手动滚动偏移限制到新范围，选择动画落到已选项，分页按原进度重新定位。
    /// Item、选择、外观和环境变化会自动刷新，无需为这些变化额外调用此方法。
    public func reloadContent() {
        guard contentStyle == .custom else {
            invalidateContentMeasurements()
            return
        }
        refreshContentLayout()
    }

    private func refreshContentLayout() {
        let previous = appliedContentMeasurement
        invalidateContentMeasurements()
        resolveCustomContents(width: contentViewport.width)
        contentGeometryChanged = contentGeometryChanged || metricsDiffer(from: previous)
        updateVisibleCells()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    /// 仅在 `.custom` 模式下调用，优先于 Appearance 的布局配置；业务方须自行持有。
    public weak var indicatorLayoutDelegate: (any SPTabBarIndicatorLayoutDelegate)? {
        didSet { reloadIndicator() }
    }

    /// 仅在 `.custom` 模式下显示，强持有自定义装饰视图；nil 恢复内置绘制。替换时移除旧视图。
    /// 视图不能与其他宿主共享；框架管理其 frame，不参与标签测量或安全归档。
    public var indicatorView: SPTabBarIndicatorView? {
        didSet {
            guard oldValue !== indicatorView else {
                return
            }
            oldValue?.removeFromSuperview()
            if let indicatorView {
                indicatorView.isUserInteractionEnabled = false
                indicatorView.accessibilityElementsHidden = true
                indicator.addSubview(indicatorView)
            }
            reloadIndicator()
        }
    }

    /// 外部几何数据变化后调用。保留分页进度和手动滚动；程序动画落到当前选中项。
    /// 回调内不得调用；代理释放后下一次布局或刷新自动回退。
    public func reloadIndicator() {
        stopSelectionAnimation()
        transitionOrigin = nil
        updateIndicator()
        setNeedsLayout()
    }

    private var indicatorContentFrames: [Int: CGRect] = [:]
    private var resolvingIndicator = false

    private let contentMeasurementHost = UIView()
    private var customContents: [SPTabBarContent?] = []
    private var customViewsNeedUpdate = false
    private var contentGeometryChanged = false
    // 显示快照与候选宽度快照分开；测量不提交配置或使 Collection View 布局失效。
    private struct ContentMeasurement {
        let revision: UInt
        let width: CGFloat
        let direction: UIUserInterfaceLayoutDirection
        let delegateIdentity: ObjectIdentifier?
        let contents: [SPTabBarContent?]
        let itemWidths: [CGFloat]
        let itemSpacing: CGFloat
        let height: CGFloat
    }

    private var appliedContentMeasurement: ContentMeasurement?
    private var candidateContentMeasurement: ContentMeasurement?
    private var contentRevision: UInt = 0
    private var resolvingCustomContents = false
    private var storedItems: [SPTabBarItem] = []
    public var items: [SPTabBarItem] {
        get { storedItems }
        set { setItems(newValue) }
    }

    public var selectedItem: SPTabBarItem? {
        get { selectedIndex.flatMap { items.indices.contains($0) ? items[$0] : nil } }
        set { setSelectedItem(newValue, animated: false) }
    }

    private var storedAppearance = SPTabBarAppearance()
    /// 赋值时复制；通过 getter 修改当前外观会实时刷新。
    public var standardAppearance: SPTabBarAppearance {
        get { storedAppearance }
        set {
            storedAppearance.detach(self)
            storedAppearance = SPTabBarAppearance(barAppearance: newValue)
            storedAppearance.attach(self)
            itemDidChange()
        }
    }

    internal var selectionRequest: ((SPTabBarItem) -> Void)?
    private var pendingSelection: SPTabBarItem?
    private var requestGeneration: UInt = 0
    private let materialView = UIVisualEffectView()
    private let backgroundImageView = UIImageView()
    private let shadowView = UIImageView()
    private var appearance: SPTabBarAppearance {
        selectedItem?.standardAppearance ?? standardAppearance
    }

    /// 自定义标签栏应从此入口发送点击或无障碍激活请求。
    public func requestSelection(of item: SPTabBarItem) {
        guard items.contains(where: { $0 === item }), item.isEnabled else {
            return
        }
        requestGeneration &+= 1
        let generation = requestGeneration
        guard delegate?.tabBar(self, shouldSelect: item) ?? true,
              generation == requestGeneration, items.contains(where: { $0 === item }), item.isEnabled else {
            return
        }
        pendingSelection = nil
        if let selectionRequest {
            selectionRequest(item)
        } else {
            setSelectedItem(item, animated: true)
            delegate?.tabBar(self, didSelect: item)
        }
    }

    internal func beginUserSelection(_ item: SPTabBarItem) {
        pendingSelection = item
    }

    internal func cancelUserSelection() {
        pendingSelection = nil; requestGeneration &+= 1
    }

    internal func completeUserSelection() {
        let item = pendingSelection
        pendingSelection = nil
        if let item, item === selectedItem {
            delegate?.tabBar(self, didSelect: item)
        }
    }

    open func setSelectedItem(_ item: SPTabBarItem?, animated: Bool) {
        if let item, !items.contains(where: { $0 === item }) {
            return
        }
        cancelUserSelection()
        setSelectedIndex(item.flatMap { target in items.firstIndex { $0 === target } }, animated: animated)
    }

    internal func synchronizeSelection(_ item: SPTabBarItem?, animated: Bool) {
        let pending = pendingSelection
        setSelectedItem(item, animated: animated)
        pendingSelection = pending
    }

    internal func itemDidChange() {
        contentGeometryChanged = false
        stopSelectionAnimation()
        transition = nil
        transitionOrigin = nil
        updateMetrics()
        updateVisibleCells()
        updateAppearance()
        needsSelectionAlignment = true
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    private func updateAppearance() {
        let value = appearance
        materialView.effect = UIAccessibility.isReduceTransparencyEnabled ? nil : value.backgroundEffect
        materialView.backgroundColor = UIAccessibility.isReduceTransparencyEnabled ? .secondarySystemBackground : .clear
        materialView.contentView.backgroundColor = value.backgroundColor
        backgroundImageView.image = value.backgroundImage
        backgroundImageView.contentMode = value.backgroundImageContentMode == .redraw ? .scaleToFill : value
            .backgroundImageContentMode
        shadowView.image = value.shadowImage
        shadowView.tintColor = value.shadowColor
        shadowView.backgroundColor = value.shadowImage == nil ? value.shadowColor : .clear
        shadowView
            .isHidden = (value.shadowImage == nil || value.shadowImage?.renderingMode == .alwaysTemplate) &&
            (value.shadowColor == nil || value.shadowColor == .clear)
        renderIndicator()
    }

    private var renderedIndicatorTransition: (from: Int?, to: Int?, progress: CGFloat)?

    private func renderIndicator(from: Int? = nil, to: Int? = nil, progress: CGFloat? = nil) {
        guard !isPreparingSelection else {
            return
        }
        guard indicatorStyle != .none else {
            indicator.frame = .zero
            indicator.isHidden = true
            indicatorView?.isHidden = true
            return
        }
        if let progress {
            // nil 是未选中的有效端点，不能用当前已提交的选择替代。
            renderedIndicatorTransition = (from, to, progress)
        } else if let transition {
            renderedIndicatorTransition = (transition.from, transition.to, transition.progress)
        } else if selectionAnimation == nil {
            renderedIndicatorTransition = (selectedIndex, selectedIndex, 1)
        }
        let state = renderedIndicatorTransition ?? (selectedIndex, selectedIndex, CGFloat(1))
        let value = appearance
        let layout = value.indicatorLayout ?? (indicatorStyle == .underline ? .underline : .capsule)
        let attributes = selectedItem?.titleTextAttributes(for: .selected) ?? selectedItem?
            .titleTextAttributes(for: .normal)
        let selectedColor: UIColor = (attributes?[.foregroundColor] as? UIColor)
            ?? value.itemAppearance.selected.titleColor ?? tintColor ?? .systemBlue
        let color: UIColor = value.indicatorColor ?? (indicatorStyle == .capsule ? .tertiarySystemFill : selectedColor)
        let radius = layout.cornerRadius.map {
            min(min(indicator.bounds.width, indicator.bounds.height) / 2, max(0, SPTabBarIndicatorLayout.finite($0)))
        } ?? indicator.bounds.height / 2
        indicator.isHidden = indicator.frame.isEmpty
        indicator.layer.zPosition = layout.placement == .background ? -1 : 1
        let customView = indicatorStyle == .custom ? indicatorView : nil
        indicatorView?.isHidden = indicatorStyle != .custom
        indicator.backgroundColor = customView == nil ? color : .clear
        indicator.layer.cornerRadius = radius
        customView?.frame = indicator.bounds
        customView?.update(SPTabBarIndicatorState(
            fromIndex: state.0,
            toIndex: state.1,
            progress: state.2,
            frame: indicator.frame,
            color: color,
            cornerRadius: radius
        ))
    }

    @objc private func accessibilitySettingsChanged() {
        itemDidChange()
    }

    open override func tintColorDidChange() {
        super.tintColorDidChange()
        // 包括继承自父视图的 tint 变化；自定义内容可依赖 tint 重新生成配置与尺寸。
        if contentStyle == .custom {
            reloadContent()
        } else {
            updateVisibleCells()
        }
        renderIndicator()
    }

    public private(set) var selectedIndex: Int?
    private let tabLayout = SPTabBarLayout()
    private let indicator = UIView()
    private let collectionAdapter = TabAdapter()
    private let collectionView: UICollectionView
    private let edgeMask = CAGradientLayer()
    private var transition: (from: Int, to: Int, progress: CGFloat)?
    private var transitionOrigin: (indicator: CGRect, offset: CGFloat)?
    private struct SelectionAnimation {
        let fromIndex: Int?
        let toIndex: Int?
        let fromIndicator: CGRect
        let toIndicator: CGRect
        let fromOffset: CGFloat
        let toOffset: CGFloat
        let startTime: CFTimeInterval
    }

    private var selectionAnimation: SelectionAnimation?
    // 选择提交期间先准备外观和几何，端点与动画状态就绪后再向指示器发送渲染状态。
    private var isPreparingSelection = false
    private var displayLink: CADisplayLink?
    private let displayTarget = SPDisplayLinkTarget()
    private var needsSelectionAlignment = true
    private var previousViewport: CGRect = .zero
    private var previousDirection: UIUserInterfaceLayoutDirection?
    private var titleFont: UIFont {
        .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
    }

    public override init(frame: CGRect) {
        collectionView = TabCollectionView(frame: .zero, collectionViewLayout: tabLayout)
        super.init(frame: frame)
        displayTarget.tick = { [weak self] link in
            guard let self, let animation = self.selectionAnimation else {
                return
            }
            self.advanceSelectionAnimation(to: CGFloat((link.timestamp - animation.startTime) / 0.25))
        }
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.allowsSelection = false
        collectionView.accessibilityIdentifier = "sp.tabBar.collection"
        edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
        collectionAdapter.owner = self
        collectionView.dataSource = collectionAdapter
        collectionView.delegate = collectionAdapter
        materialView.isUserInteractionEnabled = false
        addSubview(materialView)
        backgroundImageView.clipsToBounds = true
        backgroundImageView.isUserInteractionEnabled = false
        shadowView.isUserInteractionEnabled = false
        addSubview(backgroundImageView)
        addSubview(collectionView)
        addSubview(shadowView)
        contentMeasurementHost.isHidden = true
        contentMeasurementHost.isUserInteractionEnabled = false
        contentMeasurementHost.accessibilityElementsHidden = true
        addSubview(contentMeasurementHost)
        storedAppearance.attach(self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        indicator.backgroundColor = .label
        indicator.isUserInteractionEnabled = false
        indicator.accessibilityElementsHidden = true
        indicator.layer.zPosition = -1
        indicator.accessibilityIdentifier = "sp.tabBar.indicator"
        collectionView.addSubview(indicator)
        updateAppearance()
    }

    public required init?(coder: NSCoder) {
        fatalError("请使用 init(frame:)")
    }

    isolated deinit { displayLink?.invalidate(); NotificationCenter.default.removeObserver(self) }

    /// 背景可延伸至屏幕边缘，文字、指示器和触摸使用同一安全视口。
    private var contentViewport: CGRect {
        let left = min(bounds.width, max(0, safeAreaInsets.left))
        let right = min(bounds.width - left, max(0, safeAreaInsets.right))
        return CGRect(
            x: bounds.minX + left,
            y: bounds.minY,
            width: max(0, bounds.width - left - right),
            height: bounds.height
        )
    }

    open override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event) && contentViewport.contains(point)
    }

    /// 测量建议宽度对应的高度，不改变当前配置、Cell 布局、滚动偏移或指示器。
    /// 正宽度扣除左右安全区域后用于测量；非正宽度使用当前视口。
    /// 默认图文上下各留 11 pt、至少 44 pt 高；自定义内容使用其理想高度，不额外设高度下限。
    /// 容器通过 SPPageLayout.tabBarHeight 设置最小栏高；独立使用时由宿主设置最终高度。
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width > 0 ? max(0, size.width - safeAreaInsets.left - safeAreaInsets.right) : contentViewport
            .width
        let measurement = measureContents(width: width)
        return CGSize(
            width: size.width,
            height: measurement?.height ?? appliedContentMeasurement?.height ?? max(44, ceil(titleFont.lineHeight) + 22)
        )
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopSelectionAnimation()
            updateIndicator()
            needsSelectionAlignment = true
        }
        setNeedsLayout()
    }

    open func setItems(_ items: [SPTabBarItem]) {
        guard Set(items.map(ObjectIdentifier.init)).count == items.count else {
            return
        }
        let oldSelection = selectedItem
        cancelUserSelection()
        stopSelectionAnimation()
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        storedItems.forEach { $0.detach(self) }
        storedItems = items
        items.forEach { $0.attach(self) }
        selectedIndex = oldSelection.flatMap { old in items.firstIndex { $0 === old } }
        transition = nil
        transitionOrigin = nil
        updateAppearance()
        updateMetrics()
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
        needsSelectionAlignment = true
        setNeedsLayout()
    }

    open func setSelectedIndex(_ index: Int?, animated: Bool) {
        cancelUserSelection()
        layoutIfNeeded()
        collectionView.layoutIfNeeded()
        isPreparingSelection = true
        // 中断时从当前实际呈现的位置继续，不回跳到上次动画的起点或终点。
        stopSelectionAnimation()
        let fromIndex = selectedIndex
        let fromIndicator = indicator.frame
        let fromOffset = collectionView.contentOffset.x
        selectedIndex = index.flatMap { items.indices.contains($0) ? $0 : nil }
        transition = nil
        transitionOrigin = nil
        needsSelectionAlignment = false
        updateMetrics()
        updateAppearance()
        collectionView.layoutIfNeeded()
        superview?.setNeedsLayout()
        updateVisibleCells()
        let targetIndicator = selectedIndex.map(indicatorFrame) ?? .zero
        let targetOffset = centeredOffset(for: selectedIndex)
        isPreparingSelection = false
        let canInterpolateIndicator = !fromIndicator.isEmpty && !targetIndicator.isEmpty
        if animated, !UIAccessibility.isReduceMotionEnabled, window != nil, bounds.width > 0, bounds.height > 0,
           (canInterpolateIndicator && fromIndicator != targetIndicator) || abs(fromOffset - targetOffset) > 0.5 {
            selectionAnimation = SelectionAnimation(
                fromIndex: fromIndex,
                toIndex: selectedIndex,
                // 没有可插值的指示器时，内容偏移仍独立执行动画。
                fromIndicator: canInterpolateIndicator ? fromIndicator : targetIndicator,
                toIndicator: targetIndicator,
                fromOffset: fromOffset,
                toOffset: targetOffset,
                startTime: CACurrentMediaTime()
            )
            advanceSelectionAnimation(to: 0)
            let link = CADisplayLink(target: displayTarget, selector: #selector(SPDisplayLinkTarget.step(_:)))
            displayLink = link
            link.add(to: .main, forMode: .common)
        } else {
            updateIndicator()
            alignSelection()
        }
    }

    open func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        guard items.indices.contains(fromIndex), items.indices.contains(toIndex), progress.isFinite else {
            return
        }
        if transition?.from != fromIndex || transition?.to != toIndex {
            // 分页接管尚未完成的标签动画时，保留当前呈现位置，避免突然跳到旧目标。
            transitionOrigin = selectionAnimation == nil ? nil : (indicator.frame, collectionView.contentOffset.x)
        }
        stopSelectionAnimation()
        transition = (fromIndex, toIndex, min(1, max(0, progress)))
        layoutIfNeeded()
        collectionView.layoutIfNeeded()
        updateIndicator()
        let p = min(1, max(0, progress))
        let from = transitionOrigin?.offset ?? centeredOffset(for: fromIndex), to = centeredOffset(for: toIndex)
        collectionView.setContentOffset(CGPoint(x: from + (to - from) * p, y: 0), animated: false)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        let direction = UIView.userInterfaceLayoutDirection(
            for: semanticContentAttribute,
            relativeTo: superview?.effectiveUserInterfaceLayoutDirection ?? effectiveUserInterfaceLayoutDirection
        )
        let viewport = contentViewport
        let geometryChanged = previousViewport != viewport || previousDirection != direction
        if geometryChanged {
            indicatorContentFrames.removeAll()
        }
        previousViewport = viewport
        previousDirection = direction
        tabLayout.isRightToLeft = direction == .rightToLeft
        materialView.frame = bounds
        backgroundImageView.frame = bounds
        let shadowHeight = appearance.shadowImage?.size.height ?? (1 / max(1, traitCollection.displayScale))
        shadowView.frame = CGRect(
            x: bounds.minX,
            y: bounds.maxY - shadowHeight,
            width: bounds.width,
            height: shadowHeight
        )
        let previousOffset = collectionView.contentOffset.x
        collectionView.frame = viewport
        let previousMeasurement = appliedContentMeasurement
        if resolveCustomContents(width: viewport.width), !geometryChanged {
            contentGeometryChanged = contentGeometryChanged || metricsDiffer(from: previousMeasurement)
        }
        if customViewsNeedUpdate {
            updateVisibleCells()
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
        }
        collectionView.layoutIfNeeded()
        if contentGeometryChanged {
            contentGeometryChanged = false
            let wasAnimating = selectionAnimation != nil
            stopSelectionAnimation()
            transitionOrigin = nil
            needsSelectionAlignment = false
            if let transition {
                let from = centeredOffset(for: transition.from)
                let to = centeredOffset(for: transition.to)
                collectionView.setContentOffset(
                    CGPoint(x: from + (to - from) * transition.progress, y: 0),
                    animated: false
                )
            } else if wasAnimating {
                alignSelection()
            } else {
                let maximum = max(0, tabLayout.collectionViewContentSize.width - viewport.width)
                collectionView.setContentOffset(CGPoint(x: min(maximum, max(0, previousOffset)), y: 0), animated: false)
            }
        } else if geometryChanged || needsSelectionAlignment {
            transitionOrigin = nil
            stopSelectionAnimation()
            needsSelectionAlignment = false
            if let transition {
                let from = centeredOffset(for: transition.from), to = centeredOffset(for: transition.to)
                collectionView.setContentOffset(
                    CGPoint(x: from + (to - from) * transition.progress, y: 0),
                    animated: false
                )
            } else {
                alignSelection()
            }
        }
        updateIndicator()
        updateEdgeMask()
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if contentStyle == .custom {
            // 菜单等临时系统 UI 也会改变环境；同尺寸刷新不应重新定位标签或清空转场。
            reloadContent()
            updateAppearance()
        } else if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
            || previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass
            || previousTraitCollection?.displayScale != traitCollection.displayScale
            || previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) != false {
            itemDidChange()
        }
    }

    private var stacked: Bool {
        switch appearance.itemAppearance.layout {
        case .automatic: return traitCollection.verticalSizeClass != .compact
        case .stacked: return true
        case .inline: return false
        }
    }

    private func font(_ state: SPTabBarItemStateAppearance) -> UIFont {
        state.font
            .map { UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: $0, compatibleWith: traitCollection) } ??
            titleFont
    }

    private func itemFont(_ item: SPTabBarItem, style: SPTabBarItemStateAppearance, state: UIControl.State) -> UIFont {
        let attributes = item.titleTextAttributes(for: state) ?? item.titleTextAttributes(for: .normal)
        guard let base = attributes?[.font] as? UIFont else {
            return font(style)
        }
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: base, compatibleWith: traitCollection)
    }

    private func measuredSize(_ item: SPTabBarItem) -> CGSize {
        let styles = appearance.itemAppearance
        let titleText = item.title ?? ""
        let titleSizes = [
            (styles.normal, UIControl.State.normal),
            (styles.selected, .selected),
            (styles.disabled, .disabled)
        ].map { style, state in
            (titleText as NSString).size(withAttributes: [.font: itemFont(item, style: style, state: state)])
        }
        let title = CGSize(
            width: ceil(titleSizes.map(\.width).max() ?? 0),
            height: (item.title ?? "").isEmpty ? 0 : ceil(titleSizes.map(\.height).max() ?? 0)
        )
        let icon: CGFloat = item.image != nil || item.selectedImage != nil || item.landscapeImagePhone != nil ? 24 : 0
        let gap: CGFloat = icon > 0 && !(item.title ?? "").isEmpty ? 4 : 0
        let width = stacked ? max(title.width, icon) : title.width + icon + gap
        let height = stacked ? title.height + icon + gap : max(title.height, icon)
        let badgeWidth: CGFloat = item.badgeValue.map { $0.isEmpty ? 8 : max(
            18,
            ceil(($0 as NSString).size(withAttributes: [.font: UIFont.preferredFont(
                forTextStyle: .caption2,
                compatibleWith: traitCollection
            )]).width) + 10
        ) } ?? 0
        return CGSize(
            width: width + (badgeWidth > 0 ? badgeWidth + 4 : 0),
            height: max(
                height,
                badgeWidth > 0 ?
                    ceil(UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traitCollection).lineHeight) +
                    2 :
                    0
            )
        )
    }

    private var contentDirection: UIUserInterfaceLayoutDirection {
        UIView.userInterfaceLayoutDirection(
            for: semanticContentAttribute,
            relativeTo: superview?.effectiveUserInterfaceLayoutDirection ?? effectiveUserInterfaceLayoutDirection
        )
    }

    private func measureContents(width: CGFloat) -> ContentMeasurement? {
        guard !resolvingCustomContents else {
            return nil
        }
        let width = width.isFinite ? max(0, width) : 0
        let identity = contentDelegate.map(ObjectIdentifier.init)
        let direction = contentDirection
        for snapshot in [appliedContentMeasurement, candidateContentMeasurement] {
            if let snapshot, snapshot.revision == contentRevision, snapshot.width == width,
               snapshot.direction == direction, snapshot.delegateIdentity == identity {
                return snapshot
            }
        }
        resolvingCustomContents = true
        defer { resolvingCustomContents = false }
        let revision = contentRevision
        let provider = contentStyle == .custom ? contentDelegate : nil
        contentMeasurementHost
            .semanticContentAttribute = direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        if #available(iOS 17, *) {
            contentMeasurementHost.updateTraitsIfNeeded()
        }
        var measuringViews: [Int: UIView] = [:]
        var measuringContainers: [UIView] = []
        defer { measuringContainers.forEach { $0.removeFromSuperview() } }
        var result = items.enumerated().map { index, item -> SPTabBarContent? in
            guard let provider else {
                return nil
            }
            var state = UICellConfigurationState(traitCollection: traitCollection)
            state.isSelected = index == selectedIndex
            state.isDisabled = !item.isEnabled
            let context = SPTabBarContentContext(
                state: state,
                tintColor: tintColor,
                layoutDirection: direction,
                availableWidth: width,
                appearance: SPTabBarAppearance(barAppearance: appearance)
            )
            guard var content = provider.tabBar(self, contentFor: item, at: index, context: context) else {
                return nil
            }
            if let size = content.size {
                guard validContentSize(size) else {
                    return nil
                }
            } else {
                let view = content.configuration.updated(for: state).makeContentView()
                view.translatesAutoresizingMaskIntoConstraints = false
                view.semanticContentAttribute = contentMeasurementHost.semanticContentAttribute
                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false
                contentMeasurementHost.addSubview(container)
                container.addSubview(view)
                measuringContainers.append(container)
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    view.topAnchor.constraint(equalTo: container.topAnchor),
                    view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
                // 新系统延迟传播 traits；测量必须在配置与视图环境一致后进行。
                if #available(iOS 17, *) {
                    view.updateTraitsIfNeeded()
                }
                let natural = view.systemLayoutSizeFitting(
                    UIView.layoutFittingCompressedSize,
                    withHorizontalFittingPriority: .fittingSizeLevel,
                    verticalFittingPriority: .fittingSizeLevel
                )
                guard natural.width.isFinite, natural.width > 0, natural.width <= 1_000_000 else {
                    view.removeFromSuperview()
                    return nil
                }
                // 部分系统内容视图重写 fitting，不采用外加的软宽度约束。
                // 通过普通 Auto Layout 宿主求可行首选宽度，999 优先级让业务 required 最小宽度优先。
                let preferredWidth = width > 0 ? min(natural.width, width) : natural.width
                let constrained = container.systemLayoutSizeFitting(
                    CGSize(width: preferredWidth, height: 0),
                    withHorizontalFittingPriority: UILayoutPriority(999),
                    verticalFittingPriority: .fittingSizeLevel
                )
                guard constrained.width.isFinite, constrained.width > 0, constrained.width <= 1_000_000 else {
                    view.removeFromSuperview()
                    return nil
                }
                measuringViews[index] = view
                content.size = CGSize(width: ceil(constrained.width), height: 0)
            }
            return content
        }
        let defaultSizes = items.map { measuredSize($0) }
        var widths: [CGFloat] = []
        // 某项测量失败回退后，宽度分配可能改变，需要重新测量其余自动内容的高度。
        while true {
            widths = result.indices.map {
                max(minimumItemWidth, result[$0]?.size?.width ?? (defaultSizes[$0].width + 32))
            }
            let allocated = SPTabBarLayout.resolvedWidths(widths, viewportWidth: width, itemSpacing: itemSpacing)
            var failed = false
            for index in measuringViews.keys.sorted() {
                guard let view = measuringViews[index] else {
                    continue
                }
                let fitted = view.systemLayoutSizeFitting(
                    CGSize(width: allocated[index], height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                guard validContentSize(fitted) else {
                    view.removeFromSuperview()
                    measuringViews[index] = nil
                    result[index] = nil
                    failed = true
                    continue
                }
                result[index]?.size?.height = ceil(fitted.height)
            }
            if !failed {
                break
            }
        }
        guard revision == contentRevision else {
            return nil
        }
        let measurement = ContentMeasurement(
            revision: revision,
            width: width,
            direction: direction,
            delegateIdentity: identity,
            contents: result,
            itemWidths: widths,
            itemSpacing: itemSpacing,
            // 只对默认图文保留原有高度规则；自定义内容不承担容器的最小栏高策略。
            height: result.indices.map { result[$0]?.size?.height ?? max(44, defaultSizes[$0].height + 22) }
                .max() ?? max(44, ceil(titleFont.lineHeight) + 22)
        )
        candidateContentMeasurement = measurement
        return measurement
    }

    private func validContentSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
            && size.width <= 1_000_000 && size.height <= 1_000_000
    }

    @discardableResult
    private func resolveCustomContents(width: CGFloat) -> Bool {
        guard let measurement = measureContents(width: width) else {
            return false
        }
        if let previous = appliedContentMeasurement, previous.revision == measurement.revision,
           previous.width == measurement.width, previous.direction == measurement.direction,
           previous.delegateIdentity == measurement.delegateIdentity {
            return false
        }
        appliedContentMeasurement = measurement
        customContents = measurement.contents
        tabLayout.itemWidths = measurement.itemWidths
        tabLayout.itemSpacing = measurement.itemSpacing
        customViewsNeedUpdate = true
        return true
    }

    private func metricsDiffer(from previous: ContentMeasurement?) -> Bool {
        guard let previous, let current = appliedContentMeasurement else {
            return false
        }
        return (current.itemWidths.count > 1 && previous.itemSpacing != current.itemSpacing) ||
            SPTabBarLayout.resolvedWidths(
                previous.itemWidths,
                viewportWidth: previous.width,
                itemSpacing: previous.itemSpacing
            ) != SPTabBarLayout.resolvedWidths(
                current.itemWidths,
                viewportWidth: current.width,
                itemSpacing: current.itemSpacing
            ) ||
            previous.height != current.height
    }

    private func invalidateContentMeasurements() {
        indicatorContentFrames.removeAll()
        contentRevision &+= 1
        candidateContentMeasurement = nil
    }

    private func customContent(at index: Int) -> SPTabBarContent? {
        guard contentStyle == .custom, customContents.indices.contains(index) else {
            return nil
        }
        return customContents[index]
    }

    private func updateMetrics() {
        invalidateContentMeasurements()
        resolveCustomContents(width: contentViewport.width)
    }

    private func configure(_ cell: UICollectionViewCell, item: SPTabBarItem, at index: Int) {
        if let content = customContent(at: index) {
            var state = UICellConfigurationState(traitCollection: traitCollection)
            state.isSelected = index == selectedIndex
            state.isDisabled = !item.isEnabled
            cell.contentConfiguration = SPCustomTabContentConfiguration(
                content: content.configuration,
                measuredSize: content.size ?? CGSize(width: 44, height: 44),
                state: state,
                itemIdentifier: ObjectIdentifier(item),
                accessibilityIdentifier: "sp.tab.\(index)",
                accessibilityLabel: content.accessibilityLabel ?? item.accessibilityLabel ?? item.title,
                accessibilityHint: content.accessibilityHint ?? item.accessibilityHint,
                accessibilityValue: content.accessibilityValue ?? item.badgeValue.map { $0.isEmpty ? "有新内容" : $0 },
                onTap: { [weak self, weak item] in
                    guard let item else {
                        return
                    }
                    self?.requestSelection(of: item)
                }
            )
            return
        }
        let styles = appearance.itemAppearance
        let state = !item.isEnabled ? styles.disabled : (index == selectedIndex ? styles.selected : styles.normal)
        let defaultColor: UIColor = !item
            .isEnabled ? .tertiaryLabel : (index == selectedIndex ? tintColor : .secondaryLabel)
        let iconColor = state.iconColor ?? defaultColor
        let titleColor = state.titleColor ?? defaultColor
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        configuration.title = item.title
        let baseImage = traitCollection.verticalSizeClass == .compact ? (item.landscapeImagePhone ?? item.image) : item
            .image
        configuration.image = index == selectedIndex ? (item.selectedImage ?? baseImage) : baseImage
        let imageInsets = traitCollection.verticalSizeClass == .compact && item
            .landscapeImagePhone != nil && (index != selectedIndex || item.selectedImage == nil) ? item
            .landscapeImagePhoneInsets : item.imageInsets
        configuration.image = configuration.image.map { image in
            let ratio = min(24 / max(1, image.size.width), 24 / max(1, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            // 符号光栅化后不再携带 isSymbolImage；显式保留其默认模板语义。
            let mode: UIImage.RenderingMode = image.isSymbolImage && image
                .renderingMode == .automatic ? .alwaysTemplate : image.renderingMode
            return UIGraphicsImageRenderer(size: size)
                .image { _ in image.draw(in: CGRect(origin: .zero, size: size).inset(by: imageInsets)) }
                .withRenderingMode(mode)
        }
        configuration.imagePlacement = stacked ? .top : .leading
        configuration.imagePadding = 4
        configuration.baseForegroundColor = iconColor
        let controlState: UIControl.State = !item.isEnabled ? .disabled : (index == selectedIndex ? .selected : .normal)
        let titleAttributes = item.titleTextAttributes(for: controlState) ?? item
            .titleTextAttributes(for: .normal) ?? [:]
        let resolvedFont = itemFont(item, style: state, state: controlState)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var result = attributes
            result.font = resolvedFont
            result.foregroundColor = titleAttributes[.foregroundColor] as? UIColor ?? titleColor
            if let shadow = titleAttributes[.shadow] as? NSShadow {
                result.merge(AttributeContainer([.shadow: shadow]))
            }
            return result
        }
        var traits: UIAccessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
        if !item.isEnabled {
            traits.insert(.notEnabled)
        }
        cell.contentConfiguration = SPTabContentConfiguration(
            buttonConfiguration: configuration,
            iconColor: iconColor,
            isEnabled: item.isEnabled,
            accessibilityIdentifier: "sp.tab.\(index)",
            accessibilityLabel: item.accessibilityLabel ?? item.title,
            accessibilityHint: item.accessibilityHint,
            accessibilityTraits: traits,
            largeContentImage: item.largeContentSizeImage ?? configuration.image,
            largeContentImageInsets: item.largeContentSizeImageInsets,
            badgeValue: item.badgeValue,
            badgeFont: .preferredFont(forTextStyle: .caption2, compatibleWith: traitCollection),
            badgeTextColor: state.badgeTextColor,
            badgeBackgroundColor: item.badgeColor ?? state.badgeBackgroundColor,
            onTap: { [weak self, weak item] in
                guard let item else {
                    return
                }
                self?.requestSelection(of: item)
            }
        )
    }

    private func updateVisibleCells() {
        indicatorContentFrames.removeAll()
        customViewsNeedUpdate = false
        for indexPath in collectionView.indexPathsForVisibleItems {
            if items.indices.contains(indexPath.item),
               let cell = collectionView.cellForItem(at: indexPath) {
                configure(cell, item: items[indexPath.item], at: indexPath.item)
            }
        }
    }

    private func alignSelection() {
        guard bounds.width > 0, bounds.height > 0 else {
            needsSelectionAlignment = true
            return
        }
        collectionView.setContentOffset(CGPoint(x: centeredOffset(for: selectedIndex), y: 0), animated: false)
    }

    /// 仅在还有内容的物理边缘渐隐；到达首尾后恢复全不透明，回弹时也不遮住端点。
    private func updateEdgeMask() {
        let viewport = collectionView.bounds
        let overflow = max(0, collectionView.contentSize.width - viewport.width)
        guard viewport.width > 0, overflow > 0.5 else {
            collectionView.layer.mask = nil
            return
        }
        let fadeWidth = min(16, viewport.width / 2)
        // 临近端点时连续减弱，避免首尾渐隐突然开关。
        let left = min(1, max(0, viewport.minX / fadeWidth))
        let right = min(1, max(0, (overflow - viewport.minX) / fadeWidth))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeMask.frame = viewport
        edgeMask.locations = [
            0,
            NSNumber(value: Double(fadeWidth / viewport.width)),
            NSNumber(value: Double(1 - fadeWidth / viewport.width)),
            1
        ]
        edgeMask.colors = [
            UIColor.black.withAlphaComponent(1 - left).cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(1 - right).cgColor
        ]
        collectionView.layer.mask = edgeMask
        CATransaction.commit()
    }

    private func centeredOffset(for index: Int?) -> CGFloat {
        let maximumOffset = max(0, tabLayout.collectionViewContentSize.width - collectionView.bounds.width)
        guard let index,
              let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame else {
            return tabLayout.isRightToLeft ? maximumOffset : 0
        }
        return min(maximumOffset, max(0, frame.midX - collectionView.bounds.width / 2))
    }

    private func stopSelectionAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        selectionAnimation = nil
    }

    /// 指示器和内容偏移使用同一帧、同一进度；也允许测试确定性采样动画中间态。
    internal func advanceSelectionAnimation(to progress: CGFloat) {
        guard let animation = selectionAnimation, progress.isFinite else {
            return
        }
        let p = min(1, max(0, progress))
        let eased = p * p * (3 - 2 * p)
        let a = animation.fromIndicator, b = animation.toIndicator
        indicator.frame = CGRect(
            x: a.minX + (b.minX - a.minX) * eased,
            y: a.minY + (b.minY - a.minY) * eased,
            width: a.width + (b.width - a.width) * eased,
            height: a.height + (b.height - a.height) * eased
        )
        collectionView.setContentOffset(
            CGPoint(x: animation.fromOffset + (animation.toOffset - animation.fromOffset) * eased, y: 0),
            animated: false
        )
        renderIndicator(from: animation.fromIndex, to: animation.toIndex, progress: eased)
        if p == 1 {
            stopSelectionAnimation()
        }
    }

    private func updateIndicator() {
        guard !isPreparingSelection, selectionAnimation == nil else {
            return
        }
        if let transition {
            let a = transitionOrigin?.indicator ?? indicatorFrame(transition.from), b = indicatorFrame(transition.to)
            let p = transition.progress
            indicator.frame = CGRect(
                x: a.minX + (b.minX - a.minX) * p,
                y: a.minY + (b.minY - a.minY) * p,
                width: a.width + (b.width - a.width) * p,
                height: a.height + (b.height - a.height) * p
            )
        } else if let selectedIndex {
            indicator.frame = indicatorFrame(selectedIndex)
        } else {
            indicator.frame = .zero
        }
        renderIndicator(
            from: transition?.from ?? selectedIndex,
            to: transition?.to ?? selectedIndex,
            progress: transition?.progress ?? 1
        )
    }

    private func indicatorFrame(_ index: Int) -> CGRect {
        guard indicatorStyle != .none, items.indices.contains(index),
              let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame else {
            return .zero
        }
        let value = items[index].standardAppearance ?? standardAppearance
        let layout = value.indicatorLayout ?? (indicatorStyle == .underline ? .underline : .capsule)
        let context = SPTabBarIndicatorLayoutContext(
            item: items[index],
            index: index,
            itemFrame: frame,
            contentFrame: layout.reference == .content || (indicatorStyle == .custom && indicatorLayoutDelegate != nil)
                ? indicatorContentFrame(at: index, itemFrame: frame) : frame,
            viewportFrame: collectionView.bounds,
            layoutDirection: tabLayout.isRightToLeft ? .rightToLeft : .leftToRight,
            traitCollection: traitCollection,
            layout: layout
        )
        let fallback = layout.frame(in: context)
        guard indicatorStyle == .custom, !resolvingIndicator else {
            return fallback
        }
        resolvingIndicator = true
        defer { resolvingIndicator = false }
        if let custom = indicatorLayoutDelegate?.tabBar(self, indicatorFrameFor: context),
           SPTabBarIndicatorLayout.valid(custom) {
            return custom
        }
        return fallback
    }

    private func indicatorContentFrame(at index: Int, itemFrame: CGRect) -> CGRect {
        if let cached = indicatorContentFrames[index] {
            return cached
        }
        let local: CGRect
        if let content = customContent(at: index) {
            local = content.indicatorContentRect.flatMap { SPTabBarIndicatorLayout.valid($0) ? $0 : nil }
                ?? CGRect(origin: .zero, size: itemFrame.size)
        } else {
            // 独立布局副本避免依赖屏幕外 Cell，也不改变当前显示或交互状态。
            let cell = UICollectionViewCell(frame: CGRect(origin: .zero, size: itemFrame.size))
            contentMeasurementHost.addSubview(cell)
            cell.semanticContentAttribute = tabLayout.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
            configure(cell, item: items[index], at: index)
            cell.layoutIfNeeded()
            let rect = (cell.contentView as? SPTabIndicatorContentGeometry)?.indicatorContentRect
            local = rect.flatMap { SPTabBarIndicatorLayout.valid($0) ? $0 : nil }
                ?? CGRect(origin: .zero, size: itemFrame.size)
            cell.removeFromSuperview()
        }
        let result = local.offsetBy(dx: itemFrame.minX, dy: itemFrame.minY)
        indicatorContentFrames[index] = result
        return result
    }

    private final class TabCollectionView: UICollectionView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            // 标签按钮已开始跟踪时，后续拖动仍应交给滚动视图；单击继续由按钮处理。
            if view is UIButton {
                return true
            }
            return super.touchesShouldCancel(in: view)
        }
    }

    private final class TabAdapter: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        weak var owner: SPTabBar?
        private lazy var cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, SPTabBarItem?> {
            [weak self] cell, indexPath, item in
            guard let owner = self?.owner, let item else {
                cell.contentConfiguration = nil
                return
            }
            owner.configure(cell, item: item, at: indexPath.item)
        }

        override init() {
            super.init()
            // 提前创建注册对象；首次创建若发生在 cellForItemAt 内，UIKit 会触发断言。
            _ = cellRegistration
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            owner?.updateEdgeMask()
            owner?.updateIndicator()
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            owner?.stopSelectionAnimation()
            owner?.updateIndicator()
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            owner?.items.count ?? 0
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: owner?.items[indexPath.item]
            )
        }

        func collectionView(
            _ collectionView: UICollectionView,
            willDisplay cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            guard let owner, owner.items.indices.contains(indexPath.item) else {
                return
            }
            // 预取的 Cell 可能早于最近一次选择或字体变化创建，显示前重新同步状态。
            owner.configure(cell, item: owner.items[indexPath.item], at: indexPath.item)
        }
    }
}
