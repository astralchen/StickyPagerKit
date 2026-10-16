import UIKit

public struct SPTabBarItem: Equatable, Sendable {
    public var title: String
    public init(title: String) { self.title = title }
}

/// 可替换的标签栏。子类可重写三个更新方法，并调用 onSelect 通知用户选择。
@MainActor
open class SPTabBar: UIView {
    public var onSelect: (@MainActor (Int) -> Void)?
    public private(set) var items: [SPTabBarItem] = []
    public private(set) var selectedIndex: Int?
    private let tabLayout = SPTabBarLayout()
    private let indicator = UIView()
    private let collectionAdapter = TabAdapter()
    private let collectionView: UICollectionView
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
    private var titleFont: UIFont { .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection) }

    public override init(frame: CGRect) {
        collectionView = TabCollectionView(frame: .zero, collectionViewLayout: tabLayout)
        super.init(frame: frame)
        displayTarget.tick = { [weak self] link in
            guard let self, let animation = self.selectionAnimation else { return }
            self.advanceSelectionAnimation(to: CGFloat((link.timestamp - animation.startTime) / 0.25))
        }
        backgroundColor = .secondarySystemBackground
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.allowsSelection = false
        collectionView.accessibilityIdentifier = "sp.tabBar.collection"
        collectionView.register(TabCell.self, forCellWithReuseIdentifier: "tab")
        collectionAdapter.owner = self
        collectionView.dataSource = collectionAdapter
        collectionView.delegate = collectionAdapter
        addSubview(collectionView)
        indicator.backgroundColor = .label
        indicator.isUserInteractionEnabled = false
        indicator.layer.zPosition = 1
        collectionView.addSubview(indicator)
    }
    public required init?(coder: NSCoder) { fatalError("请使用 init(frame:)") }

    isolated deinit { displayLink?.invalidate() }

    /// 背景可延伸至屏幕边缘，文字、指示器和触摸使用同一安全视口。
    private var contentViewport: CGRect {
        let left = min(bounds.width, max(0, safeAreaInsets.left))
        let right = min(bounds.width - left, max(0, safeAreaInsets.right))
        return CGRect(x: bounds.minX + left, y: bounds.minY,
                      width: max(0, bounds.width - left - right), height: bounds.height)
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
        CGSize(width: size.width, height: max(44, ceil(titleFont.lineHeight) + 22))
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
        stopSelectionAnimation()
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        self.items = items
        if let selectedIndex, !items.indices.contains(selectedIndex) { self.selectedIndex = nil }
        transition = nil
        transitionOrigin = nil
        updateMetrics()
        collectionView.reloadData()
        needsSelectionAlignment = true
        setNeedsLayout()
    }

    open func setSelectedIndex(_ index: Int?, animated: Bool) {
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
        updateVisibleCells()
        let targetIndicator = selectedIndex.map(indicatorFrame) ?? .zero
        let targetOffset = centeredOffset(for: selectedIndex)
        if animated, window != nil, bounds.width > 0, bounds.height > 0,
           !fromIndicator.isEmpty, !targetIndicator.isEmpty,
           fromIndicator != targetIndicator || abs(fromOffset - targetOffset) > 0.5 {
            collectionView.setContentOffset(collectionView.contentOffset, animated: false)
            selectionAnimation = SelectionAnimation(fromIndicator: fromIndicator, toIndicator: targetIndicator,
                                                    fromOffset: fromOffset, toOffset: targetOffset,
                                                    startTime: CACurrentMediaTime())
            let link = CADisplayLink(target: displayTarget, selector: #selector(SPDisplayLinkTarget.step(_:)))
            displayLink = link
            link.add(to: .main, forMode: .common)
        } else {
            updateIndicator()
            alignSelection()
        }
    }

    open func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        guard items.indices.contains(fromIndex), items.indices.contains(toIndex), progress.isFinite else { return }
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
        collectionView.frame = viewport
        collectionView.layoutIfNeeded()
        if geometryChanged || needsSelectionAlignment {
            transitionOrigin = nil
            stopSelectionAnimation()
            needsSelectionAlignment = false
            alignSelection()
        }
        updateIndicator()
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateMetrics()
            updateVisibleCells()
            needsSelectionAlignment = true
            setNeedsLayout()
            superview?.setNeedsLayout()
        }
    }

    private func updateMetrics() {
        let font = titleFont
        tabLayout.itemWidths = items.map {
            max(44, ceil(($0.title as NSString).size(withAttributes: [.font: font]).width) + 32)
        }
    }

    private func configure(_ cell: TabCell, at index: Int) {
        cell.button.setTitle(items[index].title, for: .normal)
        cell.button.titleLabel?.font = titleFont
        cell.button.tintColor = index == selectedIndex ? .label : .secondaryLabel
        cell.button.accessibilityIdentifier = "sp.tab.\(index)"
        cell.button.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
        cell.onTap = { [weak self] in self?.onSelect?(index) }
    }

    private func updateVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            if items.indices.contains(indexPath.item), let cell = collectionView.cellForItem(at: indexPath) as? TabCell {
                configure(cell, at: indexPath.item)
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

    private func centeredOffset(for index: Int?) -> CGFloat {
        let maximumOffset = max(0, tabLayout.collectionViewContentSize.width - collectionView.bounds.width)
        guard let index, let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame else {
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
        guard let animation = selectionAnimation, progress.isFinite else { return }
        let p = min(1, max(0, progress))
        let eased = p * p * (3 - 2 * p)
        let a = animation.fromIndicator, b = animation.toIndicator
        indicator.frame = CGRect(x: a.minX + (b.minX - a.minX) * eased,
                                 y: a.minY + (b.minY - a.minY) * eased,
                                 width: a.width + (b.width - a.width) * eased,
                                 height: a.height + (b.height - a.height) * eased)
        collectionView.setContentOffset(CGPoint(x: animation.fromOffset + (animation.toOffset - animation.fromOffset) * eased, y: 0), animated: false)
        if p == 1 { stopSelectionAnimation() }
    }

    private func updateIndicator() {
        guard selectionAnimation == nil else { return }
        if let transition {
            let a = transitionOrigin?.indicator ?? indicatorFrame(transition.from), b = indicatorFrame(transition.to)
            let p = transition.progress
            indicator.frame = CGRect(x: a.minX + (b.minX - a.minX) * p, y: a.minY,
                                     width: a.width + (b.width - a.width) * p, height: a.height)
        } else if let selectedIndex {
            indicator.frame = indicatorFrame(selectedIndex)
        } else {
            indicator.frame = .zero
        }
    }

    private func indicatorFrame(_ index: Int) -> CGRect {
        guard let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame else { return .zero }
        return CGRect(x: frame.minX + 12, y: max(0, bounds.height - 3), width: max(0, frame.width - 24), height: 3)
    }

    private final class TabCollectionView: UICollectionView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            // 标签按钮已开始跟踪时，后续拖动仍应交给滚动视图；单击继续由按钮处理。
            if view is UIButton { return true }
            return super.touchesShouldCancel(in: view)
        }
    }

    private final class TabAdapter: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        weak var owner: SPTabBar?
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            owner?.stopSelectionAnimation()
            owner?.updateIndicator()
        }
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            owner?.items.count ?? 0
        }
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tab", for: indexPath) as! TabCell
            owner?.configure(cell, at: indexPath.item)
            return cell
        }
        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let owner, owner.items.indices.contains(indexPath.item), let cell = cell as? TabCell else { return }
            // 预取的 Cell 可能早于最近一次选择或字体变化创建，显示前重新同步状态。
            owner.configure(cell, at: indexPath.item)
        }
    }

    private final class TabCell: UICollectionViewCell {
        let button = UIButton(type: .system)
        var onTap: (() -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
            contentView.addSubview(button)
        }
        required init?(coder: NSCoder) { fatalError("请使用 init(frame:)") }
        override func layoutSubviews() {
            super.layoutSubviews()
            button.frame = contentView.bounds
        }
    }
}
