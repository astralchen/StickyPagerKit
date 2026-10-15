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
    private var needsSelectionAlignment = true
    private var previousSize: CGSize = .zero
    private var previousDirection: UIUserInterfaceLayoutDirection?
    private var titleFont: UIFont { .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection) }

    public override init(frame: CGRect) {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: tabLayout)
        super.init(frame: frame)
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

    open func setItems(_ items: [SPTabBarItem]) {
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        self.items = items
        if let selectedIndex, !items.indices.contains(selectedIndex) { self.selectedIndex = nil }
        transition = nil
        updateMetrics()
        collectionView.reloadData()
        needsSelectionAlignment = true
        setNeedsLayout()
    }

    open func setSelectedIndex(_ index: Int?, animated: Bool) {
        selectedIndex = index.flatMap { items.indices.contains($0) ? $0 : nil }
        transition = nil
        // 先完成待处理的尺寸和数据更新，再执行本次选择的滚动动画。
        needsSelectionAlignment = false
        layoutIfNeeded()
        collectionView.layoutIfNeeded()
        updateVisibleCells()
        updateIndicator()
        alignSelection(animated: animated)
    }

    open func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        guard items.indices.contains(fromIndex), items.indices.contains(toIndex), progress.isFinite else { return }
        transition = (fromIndex, toIndex, min(1, max(0, progress)))
        layoutIfNeeded()
        collectionView.layoutIfNeeded()
        updateIndicator()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        let direction = effectiveUserInterfaceLayoutDirection
        let geometryChanged = previousSize != bounds.size || previousDirection != direction
        previousSize = bounds.size
        previousDirection = direction
        tabLayout.isRightToLeft = direction == .rightToLeft
        collectionView.frame = bounds
        collectionView.layoutIfNeeded()
        updateIndicator()
        if geometryChanged || needsSelectionAlignment {
            needsSelectionAlignment = false
            alignSelection(animated: false)
        }
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateMetrics()
            updateVisibleCells()
            needsSelectionAlignment = true
            setNeedsLayout()
        }
    }

    private func updateMetrics() {
        let font = titleFont
        tabLayout.minimumItemWidth = max(72, items.map {
            ceil(($0.title as NSString).size(withAttributes: [.font: font]).width) + 32
        }.max() ?? 72)
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

    private func alignSelection(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else {
            needsSelectionAlignment = true
            return
        }
        let maximumOffset = max(0, tabLayout.collectionViewContentSize.width - collectionView.bounds.width)
        let target: CGFloat
        if let selectedIndex, let frame = tabLayout.layoutAttributesForItem(at: IndexPath(item: selectedIndex, section: 0))?.frame {
            target = min(maximumOffset, max(0, frame.midX - collectionView.bounds.width / 2))
        } else {
            target = tabLayout.isRightToLeft ? maximumOffset : 0
        }
        // 取消上一次滚动或减速，连续选择始终以最新目标为准。
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        collectionView.setContentOffset(CGPoint(x: target, y: 0), animated: animated)
    }

    private func updateIndicator() {
        if let transition {
            let a = indicatorFrame(transition.from), b = indicatorFrame(transition.to)
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

    private final class TabAdapter: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        weak var owner: SPTabBar?
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
