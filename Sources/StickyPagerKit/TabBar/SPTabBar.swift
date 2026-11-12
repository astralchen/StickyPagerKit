import UIKit

/// 支持可滚动图文标签、动态内容和分页进度的标签栏。
@MainActor
open class SPTabBar: UIView {
    // 保留半点阈值；它是滚动呈现容差，不随屏幕像素密度变化。
    private static let scrollOffsetTolerance: CGFloat = 0.5
    private static let maximumEdgeFadeWidth: CGFloat = 16

    public weak var delegate: SPTabBarDelegate?
    /// 指示器展示方式，与 ContentStyle 独立。
    public enum IndicatorStyle: Int, Sendable {
        /// 内置胶囊；默认在标签项四周内缩 4 pt，使用系统填充色。
        case capsule
        /// 内置线条；默认位于 Item 底部，高 3 pt、与标题等宽，颜色跟随标签栏 tintColor。
        case underline
        /// 启用几何代理和自定义视图；缺失的部分独立回退到默认实现。
        case custom
        /// 不使用指示器：跳过几何与渲染，不调用自定义扩展点；标签选择和分页不受影响。
        case none
    }

    public var indicatorStyle: IndicatorStyle = .underline {
        didSet {
            guard oldValue != indicatorStyle else {
                return
            }
            reloadIndicator()
        }
    }

    /// 程序选择的动画方式，默认 standard；交互分页仍直接跟随进度。
    /// 运行中修改会结束程序动画并落到已选项，保留交互分页进度及手动偏移。
    public var selectionAnimationStyle: SPTabBarAnimationStyle = .standard {
        didSet {
            if oldValue != selectionAnimationStyle {
                reloadIndicator()
            }
        }
    }

    private var storedVisualStyle = SPTabBarVisualStyle.standard
    /// 内置视觉预设，默认 standard；适用于内置图文、自定义内容及回退项。
    /// 不重新请求内容或测量。运行中更改会结束程序动画，保留分页进度与手动偏移。
    /// 同一归一化值不触发刷新；与 Appearance 的颜色、字体和指示器布局独立。
    public var visualStyle: SPTabBarVisualStyle {
        get { storedVisualStyle }
        set {
            let value = newValue.normalized
            guard value != storedVisualStyle else {
                return
            }
            let colorsChanged = value.interpolatesDefaultColors != storedVisualStyle.interpolatesDefaultColors
            storedVisualStyle = value
            if colorsChanged {
                updateVisibleCells()
            }
            reloadIndicator()
        }
    }

    private var indicatorMotion: SPTabBarVisualStyle.IndicatorMotion {
        visualStyle.motion(reduceMotion: UIAccessibility.isReduceMotionEnabled)
    }

    /// 内容展示方式，与 indicatorStyle 的指示器展示方式独立。
    public enum ContentStyle: Int, Sendable {
        /// 内置图文内容；不调用内容代理。
        case standard
        /// 由内容代理配置只负责显示的 UI，点击和无障碍仍由标签栏管理。
        case custom
    }

    /// 默认使用内置内容；切换模式保留 Item 身份和当前选择。
    /// 自定义内容缺失或尺寸无效时，逐项回退到内置内容。
    public var contentStyle: ContentStyle = .standard {
        didSet {
            if oldValue != contentStyle {
                itemDidChange()
            }
        }
    }

    private var storedLayoutConfiguration = SPTabBarLayoutConfiguration()
    /// 标签组布局的唯一配置；数值归一化后等值赋值不触发刷新。
    public var layoutConfiguration: SPTabBarLayoutConfiguration {
        get { storedLayoutConfiguration }
        set {
            let value = newValue.normalized
            guard value != storedLayoutConfiguration else {
                return
            }
            storedLayoutConfiguration = value
            refreshContentLayout()
        }
    }

    private var storedDefaultContentLayout = SPTabBarDefaultContentLayout()
    /// 内置内容与自定义内容回退项共用的尺寸规范；不改变业务自定义内容的内部尺寸。
    public var defaultContentLayout: SPTabBarDefaultContentLayout {
        get { storedDefaultContentLayout }
        set {
            let value = newValue.normalized
            guard value != storedDefaultContentLayout else {
                return
            }
            storedDefaultContentLayout = value
            refreshContentLayout()
        }
    }

    private var contentInsets: NSDirectionalEdgeInsets {
        layoutConfiguration.contentInsets
    }

    private let leadingAccessoryHost = SPTabBarAccessoryHost()
    private let trailingAccessoryHost = SPTabBarAccessoryHost()
    private var appliedAccessoryGeometry: AccessoryGeometry?

    /// 固定在逻辑起始端的附件，默认 nil；RTL 下位于右侧，不参与分页索引。
    /// 通过 systemLayoutSizeFitting 获取理想尺寸，需提供固有尺寸或完整约束。
    /// 强持有；同一视图不能同时用于两端，也不能与其他宿主共享。
    public var leadingAccessoryView: UIView? {
        get { leadingAccessoryHost.accessory }
        set { setAccessory(newValue, host: leadingAccessoryHost, other: trailingAccessoryHost) }
    }

    /// 固定在逻辑末尾端的附件，默认 nil；RTL 下位于左侧，不受标签渐隐影响。
    /// 测量、所有权与 leadingAccessoryView 相同；宽度不足时按比例裁切附件区域。
    public var trailingAccessoryView: UIView? {
        get { trailingAccessoryHost.accessory }
        set { setAccessory(newValue, host: trailingAccessoryHost, other: leadingAccessoryHost) }
    }

    private func setAccessory(_ view: UIView?, host: SPTabBarAccessoryHost, other: SPTabBarAccessoryHost) {
        guard view !== host.accessory else {
            return
        }
        if let view {
            guard view !== other.accessory, view !== self, !isDescendant(of: view), !view.isDescendant(of: self),
                  view !== leadingAccessoryHost, view !== trailingAccessoryHost else {
                return
            }
        }
        host.replace(with: view)
        invalidateAccessoryLayout()
    }

    /// 附件标题、内部约束或 isHidden 变化后调用；重新测量并请求宿主更新栏高。
    /// 同尺寸刷新保留滚动和动画；有效几何变化不发送标签选择回调。
    public func invalidateAccessoryLayout() {
        refreshContentLayout()
    }

    /// 仅在 `.custom` 模式下使用，业务方需自行持有代理。
    /// 赋值会刷新自定义内容；`.standard` 下不影响当前显示或交互。
    /// 弱引用释放不会主动安排布局，在下一次标签栏布局时回退到默认内容。
    public weak var contentDelegate: (any SPTabBarContentDelegate)? {
        didSet { reloadContent() }
    }

    /// 业务自有数据变化后重新获取自定义配置与尺寸；默认模式下不改变显示或交互。
    /// 内容及指示器端点几何不变时保留滚动偏移、选择动画及分页进度，不发送选择回调。
    /// 几何变化时将手动滚动偏移限制到新范围，选择动画落到已选项，分页按原进度重新定位。
    /// Item、选择、外观和环境变化会自动刷新，无需为这些变化额外调用此方法。
    public func reloadContent() {
        guard contentStyle == .custom else {
            invalidateContentMeasurements()
            return
        }
        refreshContentLayout()
    }

    private func refreshContentLayout(invalidating item: SPTabBarItem? = nil) {
        let previous = appliedContentMeasurement
        invalidateContentMeasurements(item: item)
        applyContentMeasurement(width: contentViewport.width)
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
        presentation.discardOrigin()
        updateIndicator()
        setNeedsLayout()
    }

    private struct IndicatorContentKey: Hashable {
        let index: Int
        let prefersTitle: Bool
    }

    // 默认线条的选中态标题与显式 content 的实际内容分开缓存。
    // prepare 前的同步回调仍可能读到旧 Item frame；缓存必须同时校验实际几何。
    private var indicatorContentFrames: [IndicatorContentKey: (itemFrame: CGRect, contentFrame: CGRect)] = [:]
    private var resolvingIndicator = false

    private let contentResolver = SPTabBarContentResolver()
    private var cellConfigurations: UInt = 0
    internal var refreshStatistics: SPTabBarRefreshStatistics {
        SPTabBarRefreshStatistics(
            measurementPasses: contentResolver.measurementPasses,
            contentRequests: contentResolver.contentRequests,
            cellConfigurations: cellConfigurations
        )
    }

    private var customViewsNeedUpdate = false
    private var contentGeometryChanged = false
    private var appliedContentMeasurement: SPTabBarContentResolver.Measurement? {
        contentResolver.applied
    }

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
    // 已提交索引归公开容器所有；预览和待提交点击由呈现协调器统一解释。
    private var presentationSelectedIndex: Int? {
        presentation.presentationIndex(items: items, selectedIndex: selectedIndex)
    }

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
        let generation = presentation.beginRequest()
        guard delegate?.tabBar(self, shouldSelect: item) ?? true,
              generation == presentation.requestGeneration, items.contains(where: { $0 === item }),
              item.isEnabled else {
            return
        }
        presentation.setPendingSelection(nil)
        if let selectionRequest {
            selectionRequest(item)
        } else {
            setSelectedItem(item, animated: true)
            delegate?.tabBar(self, didSelect: item)
        }
    }

    internal func beginUserSelection(_ item: SPTabBarItem) {
        let previous = presentationSelectedIndex
        presentation.setPendingSelection(item)
        if previous != presentationSelectedIndex {
            updateVisibleCells()
        }
    }

    internal func cancelUserSelection() {
        let previous = presentationSelectedIndex
        presentation.cancelRequest()
        if previous != presentationSelectedIndex {
            updateVisibleCells()
        }
    }

    internal func completeUserSelection() {
        let item = presentation.takePendingSelection()
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
        let pending = presentation.pendingSelection
        setSelectedItem(item, animated: animated)
        presentation.setPendingSelection(pending)
    }

    internal func itemDidChange(
        _ item: SPTabBarItem? = nil,
        reason: SPTabBarChange = .content,
        affectsEnvironment: Bool = false
    ) {
        if contentStyle == .custom {
            // 快照契约只允许单项和显式环境依赖；选中项外观仍是整栏环境。
            refreshContentLayout(invalidating: affectsEnvironment && item === selectedItem ? nil : item)
            updateAppearance()
            if reason == .indicatorGeometry {
                reloadIndicator()
            }
            return
        }
        switch reason {
        case .indicatorAppearance:
            renderIndicator()
        case .indicatorGeometry:
            reloadIndicator()
        case .decoration where contentStyle == .standard:
            updateAppearance()
            // 阴影图片高度及业务指示器几何仍可能变化，不使内容测量失效。
            setNeedsLayout()
        case .accessibility where contentStyle == .standard,
             .itemPresentation where contentStyle == .standard:
            // Item 的描述、角标颜色等不影响内置内容尺寸；不重配其他可见项。
            if let item, let index = items.firstIndex(where: { $0 === item }),
               let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) {
                configure(cell, item: item, at: index)
            }
            // 自定义指示器代理可读取 Item 属性，保留端点几何校验与呈现更新。
            setNeedsLayout()
        default:
            refreshContentLayout()
            updateAppearance()
        }
    }

    internal func indicatorAppearanceDidChange() {
        itemDidChange(reason: .indicatorAppearance)
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

    private func renderIndicator(from: Int? = nil, to: Int? = nil, progress: CGFloat? = nil) {
        guard !isPreparingSelection, !isCommittingLayout else {
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
            presentation.renderedTransition = (from, to, progress)
        } else if let transition {
            presentation.renderedTransition = (transition.from, transition.to, transition.progress)
        } else if selectionAnimation == nil {
            presentation.renderedTransition = (selectedIndex, selectedIndex, 1)
        }
        let state = presentation.renderedTransition ?? (selectedIndex, selectedIndex, CGFloat(1))
        let value = appearance
        let layout = value.indicatorLayout ?? (indicatorStyle == .underline ? .underline : .capsule)
        let attributes = selectedItem?.titleTextAttributes(for: .selected) ?? selectedItem?
            .titleTextAttributes(for: .normal)
        let selectedColor: UIColor = (attributes?[.foregroundColor] as? UIColor)
            ?? value.itemAppearance.selected.titleColor ?? tintColor ?? .systemBlue
        let defaultColor: UIColor
        switch indicatorStyle {
        case .capsule: defaultColor = .tertiarySystemFill
        case .underline: defaultColor = tintColor ?? .systemBlue
        case .custom, .none: defaultColor = selectedColor
        }
        let color = value.indicatorColor ?? defaultColor
        let maximumRadius = min(indicator.bounds.width, indicator.bounds.height) / 2
        let radius: CGFloat
        switch layout.cornerRadius {
        case .automatic: radius = maximumRadius
        case let .fixed(value): radius = min(maximumRadius, max(0, SPTabBarIndicatorLayout.finite(value)))
        }
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

    @objc private func accessibilitySettingsChanged(_ notification: Notification) {
        if notification.name == UIAccessibility.reduceMotionStatusDidChangeNotification, selectionAnimation != nil {
            // 动态效果设置改变时及时结束程序动画；分页进度及普通外观通知仍保留。
            stopSelectionAnimation()
            needsSelectionAlignment = true
        }
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
    private let presentation = SPTabBarPresentationCoordinator()
    private var transition: SPTabBarPresentationCoordinator.Transition? {
        presentation.transition
    }

    private var transitionOrigin: SPTabBarPresentationCoordinator.Origin? {
        presentation.origin
    }

    private var selectionAnimation: SPTabBarPresentationCoordinator.Animation? {
        presentation.animation
    }

    // 选择提交期间先准备外观和几何；应用统一帧时抑制滚动回调的重复指示器更新。
    private var isPreparingSelection = false
    private var isApplyingPresentationFrame = false
    private var isCommittingLayout = false
    private var needsSelectionAlignment = true
    private var previousViewport: CGRect = .zero
    private var previousDirection: UIUserInterfaceLayoutDirection?
    private var titleFont: UIFont {
        .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
    }

    public override init(frame: CGRect) {
        collectionView = TabCollectionView(frame: .zero, collectionViewLayout: tabLayout)
        super.init(frame: frame)
        presentation.onFrame = { [weak self] frame in
            self?.applyPresentationFrame(frame)
        }
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        // 标签栏只负责横向导航，回顶部由业务正文列表处理。
        collectionView.scrollsToTop = false
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
        leadingAccessoryHost.accessibilityIdentifier = "sp.tabBar.leadingAccessory"
        trailingAccessoryHost.accessibilityIdentifier = "sp.tabBar.trailingAccessory"
        addSubview(leadingAccessoryHost)
        addSubview(trailingAccessoryHost)
        addSubview(shadowView)
        contentResolver.measurementHost.isHidden = true
        contentResolver.measurementHost.isUserInteractionEnabled = false
        contentResolver.measurementHost.accessibilityElementsHidden = true
        addSubview(contentResolver.measurementHost)
        storedAppearance.attach(self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged(_:)),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged(_:)),
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

    nonisolated deinit { NotificationCenter.default.removeObserver(self) }

    private struct AccessoryGeometry: Equatable {
        let leadingSize: CGSize
        let trailingSize: CGSize
        let leadingFrame: CGRect
        let trailingFrame: CGRect
        let viewport: CGRect
    }

    /// 候选宽度只计算几何，不设置附件或滚动视图的 frame。
    private func accessoryGeometry(in rect: CGRect) -> AccessoryGeometry {
        let width = max(0, rect.width)
        let left = min(width, max(0, safeAreaInsets.left))
        let right = min(width - left, max(0, safeAreaInsets.right))
        let safeWidth = max(0, width - left - right)
        let leading = leadingAccessoryHost.measuredSize()
        let trailing = trailingAccessoryHost.measuredSize()
        let sum = leading.width + trailing.width
        let scale = sum > safeWidth && sum > 0 ? safeWidth / sum : 1
        let leadingWidth = leading.width * scale
        let trailingWidth = min(max(0, safeWidth - leadingWidth), trailing.width * scale)
        let rtl = contentDirection == .rightToLeft
        let start = rect.minX + left
        let leftWidth = rtl ? trailingWidth : leadingWidth
        let rightWidth = rtl ? leadingWidth : trailingWidth
        let leftFrame = CGRect(x: start, y: rect.minY, width: leftWidth, height: max(0, rect.height))
        let rightFrame = CGRect(
            x: start + safeWidth - rightWidth,
            y: rect.minY,
            width: rightWidth,
            height: max(0, rect.height)
        )
        return AccessoryGeometry(
            leadingSize: leading,
            trailingSize: trailing,
            leadingFrame: rtl ? rightFrame : leftFrame,
            trailingFrame: rtl ? leftFrame : rightFrame,
            viewport: CGRect(
                x: start + leftWidth,
                y: rect.minY,
                width: max(0, safeWidth - leftWidth - rightWidth),
                height: max(0, rect.height)
            )
        )
    }

    /// 背景铺满；文字和指示器使用扣除附件后的安全视口。
    private var contentViewport: CGRect {
        accessoryGeometry(in: bounds).viewport
    }

    private func applyAccessories(_ geometry: AccessoryGeometry) {
        for (host, frame, size, right) in [
            (leadingAccessoryHost, geometry.leadingFrame, geometry.leadingSize, contentDirection == .rightToLeft),
            (trailingAccessoryHost, geometry.trailingFrame, geometry.trailingSize, contentDirection != .rightToLeft)
        ] {
            host.frame = frame
            host.idealSize = size
            host.alignsRight = right
            host.isHidden = size == .zero
            host.setNeedsLayout()
            host.layoutIfNeeded()
        }
    }

    open override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event) else {
            return false
        }
        if collectionView.bounds.width > 0, collectionView.bounds.height > 0,
           collectionView.frame.contains(point) {
            return true
        }
        return [leadingAccessoryHost, trailingAccessoryHost].contains {
            !$0.isHidden && $0.bounds.width > 0 && $0.bounds.height > 0 && $0.frame.contains(point)
        }
    }

    /// 测量建议宽度对应的高度，不改变当前配置、Cell 布局、滚动偏移或指示器。
    /// 正宽度扣除左右安全区域、附件及水平留白后用于内容测量；非正宽度使用当前栏宽。
    /// 上下留白加入内容高度，再与附件理想高度取最大值。
    /// 内置内容使用 defaultContentLayout（默认上下各 11 pt、至少 44 pt）；自定义内容使用自身理想高度。
    /// 容器通过 SPPageLayout.tabBarSizing 选择高度策略；独立使用时由宿主设置最终高度。
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let proposedWidth = size.width.isFinite && size.width > 0 ? size.width : bounds.width
        let geometry = accessoryGeometry(in: CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: proposedWidth,
            height: bounds.height
        ))
        let measurement = measureContents(width: geometry.viewport.width)
        let contentHeight = measurement?.height ?? appliedContentMeasurement?.height ??
            defaultContentLayout.height(for: ceil(titleFont.lineHeight))
        return CGSize(
            width: size.width,
            height: max(
                contentHeight + contentInsets.top + contentInsets.bottom,
                geometry.leadingSize.height,
                geometry.trailingSize.height
            )
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
        let previousAppearance = appearance
        cancelUserSelection()
        stopSelectionAnimation()
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        storedItems.forEach { $0.detach(self) }
        storedItems = items
        items.forEach { $0.attach(self) }
        selectedIndex = oldSelection.flatMap { old in items.firstIndex { $0 === old } }
        presentation.resetMotion()
        updateAppearance()
        updateMetrics(preservingContentCache: previousAppearance === appearance)
        collectionView.reloadData()
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
        needsSelectionAlignment = true
        setNeedsLayout()
    }

    /// nil 清空选择；越界索引忽略且保留当前动画与分页进度。程序化选择不发送点击代理事件。
    open func setSelectedIndex(_ index: Int?, animated: Bool) {
        if let index, !items.indices.contains(index) {
            return
        }
        cancelUserSelection()
        synchronizeLayoutBeforeTransition()
        let previousAppearance = appearance
        let contentOrigin = presentation.contentWeights(selectedIndex: selectedIndex)
        let springOrigin = presentation.springSnapshot
        isPreparingSelection = true
        // 中断时从当前实际呈现的位置继续，不回跳到上次动画的起点或终点。
        stopSelectionAnimation()
        let fromIndex = selectedIndex
        let fromIndicator = indicator.frame
        let fromOffset = collectionView.contentOffset.x
        selectedIndex = index.flatMap { items.indices.contains($0) ? $0 : nil }
        presentation.resetMotion()
        presentation.prepareContentProgress(contentOrigin, spring: springOrigin)
        needsSelectionAlignment = false
        updateMetrics(preservingContentCache: previousAppearance === appearance)
        updateAppearance()
        synchronizeCollectionLayout()
        superview?.setNeedsLayout()
        updateVisibleCells()
        let targetIndicator = selectedIndex.map(indicatorFrame) ?? .zero
        let targetOffset = centeredOffset(for: selectedIndex)
        isPreparingSelection = false
        let canInterpolateIndicator = !fromIndicator.isEmpty && !targetIndicator.isEmpty
        let animatesContent = (visualStyle.unselectedAlpha < 1 || visualStyle.unselectedScale < 1 || visualStyle
            .interpolatesDefaultColors || appliedContentMeasurement?.contents
            .contains { $0?.tracksSelectionProgress == true } == true)
            && contentOrigin != (selectedIndex.map { [$0: CGFloat(1)] } ?? [:])
        if animated, !UIAccessibility.isReduceMotionEnabled, window != nil, bounds.width > 0, bounds.height > 0,
           animatesContent || (canInterpolateIndicator && fromIndicator != targetIndicator) ||
           abs(fromOffset - targetOffset) > Self
           .scrollOffsetTolerance {
            presentation.startAnimation(
                SPTabBarPresentationCoordinator.Animation(
                    fromIndex: fromIndex,
                    toIndex: selectedIndex,
                    // 没有可插值的指示器时，内容偏移仍独立执行动画。
                    fromIndicator: canInterpolateIndicator ? fromIndicator : targetIndicator,
                    toIndicator: targetIndicator,
                    fromGeometry: fromIndex.map(indicatorFrame) ?? .zero,
                    fromOffset: fromOffset,
                    toOffset: targetOffset,
                    startTime: CACurrentMediaTime()
                ),
                contentOrigin: contentOrigin,
                indicatorMotion: indicatorMotion,
                style: selectionAnimationStyle,
                spring: springOrigin
            )
        } else {
            presentation.prepareContentProgress(nil)
            updateIndicator()
            alignSelection()
        }
    }

    open func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        guard items.indices.contains(fromIndex), items.indices.contains(toIndex), progress.isFinite else {
            return
        }
        // 先应用待完成的属性刷新，避免把旧动画呈现位置与新端点几何一起保存为接管起点。
        synchronizeLayoutBeforeTransition()
        let previous = presentationSelectedIndex
        let origin = selectionAnimation == nil ? nil : SPTabBarPresentationCoordinator.Origin(
            indicator: indicator.frame,
            offset: collectionView.contentOffset.x,
            fromGeometry: indicatorFrame(fromIndex),
            toGeometry: indicatorFrame(toIndex)
        )
        presentation.setTransition(from: fromIndex, to: toIndex, progress: progress, takeoverOrigin: origin)
        if previous != presentationSelectedIndex {
            updateVisibleCells()
        }
        let frame = SPTabBarPresentationCoordinator.frame(
            from: fromIndex,
            to: toIndex,
            progress: min(1, max(0, progress)),
            fromIndicator: transitionOrigin?.indicator ?? indicatorFrame(fromIndex),
            toIndicator: indicatorFrame(toIndex),
            fromOffset: transitionOrigin?.offset ?? centeredOffset(for: fromIndex),
            toOffset: centeredOffset(for: toIndex),
            indicatorMotion: indicatorMotion
        )
        applyPresentationFrame(frame)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        guard !isCommittingLayout else {
            // 同步布局中的嵌套请求留给后续布局遍次，不能提交半完成的几何。
            setNeedsLayout()
            return
        }
        commitLayoutGeometry()
        updateIndicator()
        updateEdgeMask()
    }

    /// 切页入口需要当前实际几何；保留同步边界及公开 layoutSubviews 的动态分发。
    private func synchronizeLayoutBeforeTransition() {
        layoutIfNeeded()
        synchronizeCollectionLayout()
    }

    private func synchronizeCollectionLayout() {
        tabLayout.prepareGeometry(itemCount: items.count, size: collectionView.bounds.size)
        collectionView.layoutIfNeeded()
    }

    private struct LayoutInput {
        let bounds: CGRect
        let direction: UIUserInterfaceLayoutDirection
        let accessories: AccessoryGeometry
    }

    private struct LayoutChanges {
        let viewportWidth: CGFloat
        let viewportChanged: Bool
        let accessoryChanged: Bool
        let previousOffset: CGFloat
    }

    /// 一次布局先应用视口与内容，再处理运动状态；滚动代理不在这些阶段之间呈现指示器。
    private func commitLayoutGeometry() {
        isCommittingLayout = true
        defer { isCommittingLayout = false }
        let input = LayoutInput(bounds: bounds, direction: contentDirection, accessories: accessoryGeometry(in: bounds))
        let changes = applyViewportLayout(input)
        applyContentLayout(changes)
        resolvePresentationAfterLayout(changes)
    }

    private func applyViewportLayout(_ input: LayoutInput) -> LayoutChanges {
        let accessories = input.accessories
        let viewport = accessories.viewport
        // 附件变化采用内容刷新策略；旋转、布局方向变化继续使用原有选中对齐策略。
        let accessoryChanged = appliedAccessoryGeometry.map {
            $0.leadingSize != accessories.leadingSize || $0.trailingSize != accessories.trailingSize
        } ?? false
        contentGeometryChanged = contentGeometryChanged || accessoryChanged
        appliedAccessoryGeometry = accessories
        applyAccessories(accessories)
        let geometryChanged = previousViewport != viewport || previousDirection != input.direction
        if geometryChanged {
            indicatorContentFrames.removeAll()
        }
        previousViewport = viewport
        previousDirection = input.direction
        tabLayout.isRightToLeft = input.direction == .rightToLeft
        materialView.frame = input.bounds
        backgroundImageView.frame = input.bounds
        let shadowHeight = appearance.shadowImage?.size.height ?? (1 / max(1, traitCollection.displayScale))
        shadowView.frame = CGRect(
            x: input.bounds.minX,
            y: input.bounds.maxY - shadowHeight,
            width: input.bounds.width,
            height: shadowHeight
        )
        let previousOffset = collectionView.contentOffset.x
        collectionView.frame = viewport
        return LayoutChanges(
            viewportWidth: viewport.width,
            viewportChanged: geometryChanged,
            accessoryChanged: accessoryChanged,
            previousOffset: previousOffset
        )
    }

    private func applyContentLayout(_ changes: LayoutChanges) {
        let previousMeasurement = appliedContentMeasurement
        if applyContentMeasurement(width: changes.viewportWidth), !changes.viewportChanged {
            contentGeometryChanged = contentGeometryChanged || metricsDiffer(from: previousMeasurement)
        }
        if customViewsNeedUpdate || changes.accessoryChanged {
            updateVisibleCells()
            invalidateIntrinsicContentSize()
            superview?.setNeedsLayout()
        }
        synchronizeCollectionLayout()
    }

    private func resolvePresentationAfterLayout(_ changes: LayoutChanges) {
        // Item 宽度可能被最小宽度固定，内容区域或新 Appearance 的指示器仍会改变。
        // 核对转场端点的真实几何，避免保留动画或分页接管时使用旧矩形。
        contentGeometryChanged = contentGeometryChanged || indicatorTransitionGeometryChanged()
        guard contentGeometryChanged || changes.viewportChanged || needsSelectionAlignment else {
            return
        }
        // 内容几何变化优先于视口变化：没有动画或对齐请求时，保留并限制手动偏移。
        let shouldAlign = needsSelectionAlignment || selectionAnimation != nil
            || (!contentGeometryChanged && changes.viewportChanged)
        contentGeometryChanged = false
        stopSelectionAnimation()
        presentation.discardOrigin()
        needsSelectionAlignment = false
        if let transition {
            let from = centeredOffset(for: transition.from), to = centeredOffset(for: transition.to)
            collectionView.setContentOffset(
                CGPoint(x: from + (to - from) * transition.progress, y: 0),
                animated: false
            )
        } else if shouldAlign {
            alignSelection()
        } else {
            let maximum = max(0, tabLayout.collectionViewContentSize.width - changes.viewportWidth)
            collectionView.setContentOffset(
                CGPoint(x: min(maximum, max(0, changes.previousOffset)), y: 0),
                animated: false
            )
        }
    }

    private func indicatorTransitionGeometryChanged() -> Bool {
        if let animation = selectionAnimation {
            let from = animation.fromIndex.map(indicatorFrame) ?? .zero
            let to = animation.toIndex.map(indicatorFrame) ?? .zero
            return animation.fromGeometry != from || animation.toIndicator != to
        }
        if let transition, let origin = transitionOrigin {
            return origin.fromGeometry != indicatorFrame(transition.from)
                || origin.toGeometry != indicatorFrame(transition.to)
        }
        return false
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
        let metricsChanged = previousTraitCollection?.preferredContentSizeCategory != traitCollection
            .preferredContentSizeCategory
            || previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass
            || previousTraitCollection?.displayScale != traitCollection.displayScale
        if contentStyle == .custom {
            // 菜单等临时系统 UI 也会改变环境；同尺寸刷新不应重新定位标签或清空转场。
            reloadContent()
            updateAppearance()
        } else if metricsChanged
            || previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) != false {
            itemDidChange()
            // 字体与图文方向的环境变化沿用选中项对齐策略；纯外观变化保留手动偏移。
            if metricsChanged, contentGeometryChanged {
                needsSelectionAlignment = true
            }
        }
    }

    private var contentDirection: UIUserInterfaceLayoutDirection {
        UIView.userInterfaceLayoutDirection(
            for: semanticContentAttribute,
            relativeTo: superview?.effectiveUserInterfaceLayoutDirection ?? effectiveUserInterfaceLayoutDirection
        )
    }

    private var contentEnvironment: SPTabBarContentEnvironment {
        SPTabBarContentEnvironment(
            items: items,
            selectedIndex: selectedIndex,
            contentStyle: contentStyle,
            layoutConfiguration: layoutConfiguration,
            defaultContentLayout: defaultContentLayout,
            appearance: appearance,
            traitCollection: traitCollection,
            tintColor: tintColor,
            contentDirection: contentDirection,
            delegateIdentity: contentDelegate.map(ObjectIdentifier.init)
        )
    }

    private func measureContents(width: CGFloat) -> SPTabBarContentResolver.Measurement? {
        // 回调只在本次解析中使用；解析器不持有代理或公开容器。
        let provider = contentDelegate
        return contentResolver.measure(width: width, environment: contentEnvironment) { item, context in
            provider?.content(for: item, context: context)
        }
    }

    @discardableResult
    private func applyContentMeasurement(width: CGFloat) -> Bool {
        guard let measurement = measureContents(width: width), contentResolver.apply(measurement) else {
            return false
        }
        tabLayout.itemWidths = measurement.itemWidths
        tabLayout.configuration = measurement.layoutConfiguration
        customViewsNeedUpdate = true
        return true
    }

    private func metricsDiffer(from previous: SPTabBarContentResolver.Measurement?) -> Bool {
        contentResolver.metricsDiffer(from: previous)
    }

    private func invalidateContentMeasurements(item: SPTabBarItem? = nil, preservingContentCache: Bool = false) {
        indicatorContentFrames.removeAll()
        contentResolver.invalidate(item: item, preservingContentCache: preservingContentCache)
    }

    private func customContent(at index: Int) -> SPTabBarContent? {
        contentStyle == .custom ? contentResolver.content(at: index) : nil
    }

    private func updateMetrics(preservingContentCache: Bool = false) {
        invalidateContentMeasurements(preservingContentCache: preservingContentCache)
        applyContentMeasurement(width: contentViewport.width)
    }

    private func configure(_ cell: UICollectionViewCell, item: SPTabBarItem, at index: Int, selected: Bool? = nil) {
        cellConfigurations &+= 1
        cell.contentConfiguration = contentEnvironment.configuration(
            for: item,
            at: index,
            selected: selected ?? (index == presentationSelectedIndex),
            content: customContent(at: index),
            selectionProgress: selected.map { $0 ? 1 : 0 }
                ?? presentation.contentWeights(selectedIndex: selectedIndex)[index, default: 0],
            interpolatesDefaultColors: visualStyle.interpolatesDefaultColors
        ) { [weak self, weak item] in
            guard let item else {
                return
            }
            self?.requestSelection(of: item)
        }
        updateContentScale(
            cell.contentView,
            at: index,
            progress: selected.map { $0 ? 1 : 0 }
                ?? presentation.contentWeights(selectedIndex: selectedIndex)[index, default: 0]
        )
        cell.contentView.alpha = visualStyle.alpha(
            progress: selected.map { $0 ? 1 : 0 }
                ?? presentation.contentWeights(selectedIndex: selectedIndex)[index, default: 0],
            enabled: item.isEnabled,
            reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
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
        guard !isCommittingLayout else {
            return
        }
        let viewport = collectionView.bounds
        let overflow = max(0, collectionView.contentSize.width - viewport.width)
        guard viewport.width > 0, viewport.height > 0, !items.isEmpty, overflow > Self.scrollOffsetTolerance else {
            collectionView.layer.mask = nil
            return
        }
        let fadeWidth = min(Self.maximumEdgeFadeWidth, viewport.width / 2)
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
        presentation.stopAnimation()
    }

    /// 指示器和内容偏移使用同一帧、同一进度；也允许测试确定性采样动画中间态。
    internal func advanceSelectionAnimation(to progress: CGFloat) {
        presentation.advance(to: progress)
    }

    private func applyPresentationFrame(_ frame: SPTabBarPresentationCoordinator.Frame, updatesOffset: Bool = true) {
        isApplyingPresentationFrame = true
        defer { isApplyingPresentationFrame = false }
        indicator.frame = frame.indicator
        if updatesOffset {
            collectionView.setContentOffset(CGPoint(x: frame.offset, y: 0), animated: false)
        }
        updateContentProgress()
        renderIndicator(from: frame.from, to: frame.to, progress: frame.progress)
    }

    private func updateContentScale(_ view: UIView, at index: Int, progress: CGFloat) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        (view as? SPTabContentProgressDisplaying)?.updateContentScale(
            visualStyle.scale(progress: progress, enabled: items[index].isEnabled, reduceMotion: reduceMotion)
                + (items[index].isEnabled && !reduceMotion ? (1 - visualStyle.unselectedScale)
                    * (presentation.scaleWeight(at: index, fallback: progress) - progress) : 0),
            enabled: visualStyle.unselectedScale < 1 && items[index].isEnabled && !reduceMotion
        )
    }

    private func updateContentProgress() {
        let weights = presentation.contentWeights(selectedIndex: selectedIndex)
        for path in collectionView.indexPathsForVisibleItems {
            guard items.indices.contains(path.item), let cell = collectionView.cellForItem(at: path) else {
                continue
            }
            let progress = weights[path.item, default: 0]
            cell.contentView.alpha = visualStyle.alpha(
                progress: progress,
                enabled: items[path.item].isEnabled,
                reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
            )
            updateContentScale(cell.contentView, at: path.item, progress: progress)
            (cell.contentView as? SPTabContentProgressDisplaying)?.updateSelectionProgress(progress)
        }
    }

    private func updateIndicator() {
        guard !isPreparingSelection, !isCommittingLayout, !isApplyingPresentationFrame, selectionAnimation == nil else {
            return
        }
        let frame: SPTabBarPresentationCoordinator.Frame
        if let transition {
            frame = SPTabBarPresentationCoordinator.frame(
                from: transition.from,
                to: transition.to,
                progress: transition.progress,
                fromIndicator: transitionOrigin?.indicator ?? indicatorFrame(transition.from),
                toIndicator: indicatorFrame(transition.to),
                fromOffset: collectionView.contentOffset.x,
                toOffset: collectionView.contentOffset.x,
                indicatorMotion: indicatorMotion
            )
        } else {
            // 静止状态只解析一次端点，保持几何代理的既有调用语义。
            frame = .init(
                indicator: selectedIndex.map(indicatorFrame) ?? .zero,
                offset: collectionView.contentOffset.x,
                from: selectedIndex,
                to: selectedIndex,
                progress: 1
            )
        }
        applyPresentationFrame(frame, updatesOffset: false)
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
            contentFrame: layout.reference != .item || (indicatorStyle == .custom && indicatorLayoutDelegate != nil)
                ? indicatorContentFrame(at: index, itemFrame: frame, prefersTitle: layout.reference == .title) : frame,
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

    private func indicatorContentFrame(at index: Int, itemFrame: CGRect, prefersTitle: Bool = false) -> CGRect {
        let key = IndicatorContentKey(index: index, prefersTitle: prefersTitle)
        if let cached = indicatorContentFrames[key], cached.itemFrame == itemFrame {
            return cached.contentFrame
        }
        let local: CGRect
        if let content = customContent(at: index) {
            local = content.indicatorContentRect.flatMap { SPTabBarIndicatorLayout.valid($0) ? $0 : nil }
                ?? CGRect(origin: .zero, size: itemFrame.size)
        } else {
            // 独立布局副本避免依赖屏幕外 Cell，也不改变当前显示或交互状态。
            // 默认线条按选中态测量两个端点，避免分页提交后再随加粗字体伸缩。
            let cell = UICollectionViewCell(frame: CGRect(origin: .zero, size: itemFrame.size))
            contentResolver.measurementHost.addSubview(cell)
            cell.semanticContentAttribute = tabLayout.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
            // 指示器端点独立于可见项的视觉预览，避免过半切换字体时端点跳变。
            configure(cell, item: items[index], at: index, selected: prefersTitle || index == selectedIndex)
            cell.layoutIfNeeded()
            let geometry = cell.contentView as? SPTabIndicatorContentGeometry
            let title = prefersTitle ? geometry?.indicatorTitleRect : nil
            let rect = title.flatMap { SPTabBarIndicatorLayout.valid($0) && !$0.isEmpty ? $0 : nil }
                ?? geometry?.indicatorContentRect
            local = rect.flatMap { SPTabBarIndicatorLayout.valid($0) ? $0 : nil }
                ?? CGRect(origin: .zero, size: itemFrame.size)
            cell.removeFromSuperview()
        }
        let result = local.offsetBy(dx: itemFrame.minX, dy: itemFrame.minY)
        indicatorContentFrames[key] = (itemFrame, result)
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
