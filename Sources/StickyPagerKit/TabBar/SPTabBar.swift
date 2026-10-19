import UIKit

/// 支持可滚动图文标签、动态内容和分页进度的标签栏。
@MainActor
open class SPTabBar: UIView {
    public weak var delegate: SPTabBarDelegate?
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
        updateIndicatorColor()
        indicator.isHidden = value.selectionStyle == .none
    }

    private func updateIndicatorColor() {
        let value = appearance
        let attributes = selectedItem?.titleTextAttributes(for: .selected) ?? selectedItem?
            .titleTextAttributes(for: .normal)
        let selectedColor = attributes?[.foregroundColor] as? UIColor ?? value.itemAppearance.selected
            .titleColor ?? tintColor
        indicator.backgroundColor = value
            .selectionColor ?? (value.selectionStyle == .underline ? selectedColor : .tertiarySystemFill)
    }

    @objc private func accessibilitySettingsChanged() {
        itemDidChange()
    }

    open override func tintColorDidChange() {
        super.tintColorDidChange()
        // 包括继承自父视图的 tint 变化；仅刷新颜色，不中断选中动画与手动滚动。
        updateVisibleCells()
        updateIndicatorColor()
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
        let fromIndicator: CGRect
        let toIndicator: CGRect
        let fromOffset: CGFloat
        let toOffset: CGFloat
        let startTime: CFTimeInterval
    }

    private var selectionAnimation: SelectionAnimation?
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
        indicator.layer.zPosition = -1
        indicator.accessibilityIdentifier = "sp.tabBar.selection"
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

    /// 标题保持垂直居中；上下各留 11 pt，底部扣除 3 pt 指示器后仍有 8 pt。
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(
            width: size.width,
            height: max(44, items.map { measuredSize($0).height + 22 }.max() ?? ceil(titleFont.lineHeight) + 22)
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
        updateAppearance()
        transition = nil
        transitionOrigin = nil
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
        // 中断时从当前实际呈现的位置继续，不回跳到上次动画的起点或终点。
        stopSelectionAnimation()
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
        if animated, !UIAccessibility.isReduceMotionEnabled, window != nil, bounds.width > 0, bounds.height > 0,
           !fromIndicator.isEmpty, !targetIndicator.isEmpty,
           fromIndicator != targetIndicator || abs(fromOffset - targetOffset) > 0.5 {
            collectionView.setContentOffset(collectionView.contentOffset, animated: false)
            selectionAnimation = SelectionAnimation(
                fromIndicator: fromIndicator,
                toIndicator: targetIndicator,
                fromOffset: fromOffset,
                toOffset: targetOffset,
                startTime: CACurrentMediaTime()
            )
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
        collectionView.frame = viewport
        collectionView.layoutIfNeeded()
        if geometryChanged || needsSelectionAlignment {
            transitionOrigin = nil
            stopSelectionAnimation()
            needsSelectionAlignment = false
            alignSelection()
        }
        updateIndicator()
        updateEdgeMask()
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
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

    private func updateMetrics() {
        tabLayout.itemWidths = items.map { max(44, measuredSize($0).width + 32) }
    }

    private func configure(_ cell: UICollectionViewCell, item: SPTabBarItem, at index: Int) {
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
        indicator.layer.cornerRadius = indicator.bounds.height / 2
        if p == 1 {
            stopSelectionAnimation()
        }
    }

    private func updateIndicator() {
        guard selectionAnimation == nil else {
            return
        }
        if let transition {
            let a = transitionOrigin?.indicator ?? indicatorFrame(transition.from), b = indicatorFrame(transition.to)
            let p = transition.progress
            indicator.frame = CGRect(
                x: a.minX + (b.minX - a.minX) * p,
                y: a.minY,
                width: a.width + (b.width - a.width) * p,
                height: a.height
            )
        } else if let selectedIndex {
            indicator.frame = indicatorFrame(selectedIndex)
        } else {
            indicator.frame = .zero
        }
        indicator.layer.cornerRadius = indicator.bounds.height / 2
    }

    private func indicatorFrame(_ index: Int) -> CGRect {
        guard let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame else {
            return .zero
        }
        if appearance.selectionStyle == .capsule {
            return frame.insetBy(dx: 4, dy: 4)
        }
        return CGRect(x: frame.minX + 12, y: max(0, bounds.height - 3), width: max(0, frame.width - 24), height: 3)
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
