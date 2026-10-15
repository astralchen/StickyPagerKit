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
    private let scroller = UIScrollView()
    private let stack = UIStackView()
    private let indicator = UIView()
    private var buttons: [UIButton] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        scroller.showsHorizontalScrollIndicator = false
        scroller.contentInsetAdjustmentBehavior = .never
        addSubview(scroller)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        scroller.addSubview(stack)
        indicator.backgroundColor = .label
        scroller.addSubview(indicator)
    }
    public required init?(coder: NSCoder) { fatalError("请使用 init(frame:)") }

    open func setItems(_ items: [SPTabBarItem]) {
        self.items = items
        buttons.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        buttons = items.enumerated().map { index, item in
            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.accessibilityIdentifier = "sp.tab.\(index)"
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(index) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
            return button
        }
        setNeedsLayout()
    }

    open func setSelectedIndex(_ index: Int?, animated: Bool) {
        selectedIndex = index
        for (i, button) in buttons.enumerated() {
            button.tintColor = i == index ? .label : .secondaryLabel
            button.accessibilityTraits = i == index ? [.button, .selected] : .button
        }
        layoutIfNeeded()
        if let index, buttons.indices.contains(index) {
            indicator.frame = indicatorFrame(index)
            scroller.scrollRectToVisible(buttons[index].frame, animated: animated)
        } else { indicator.frame = .zero }
    }

    open func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        guard buttons.indices.contains(fromIndex), buttons.indices.contains(toIndex) else { return }
        let a = indicatorFrame(fromIndex), b = indicatorFrame(toIndex)
        let p = min(1, max(0, progress))
        indicator.frame = CGRect(x: a.minX + (b.minX - a.minX) * p, y: a.minY, width: a.width + (b.width - a.width) * p, height: 3)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        scroller.frame = bounds
        let itemWidth = max(72, buttons.map { $0.intrinsicContentSize.width + 32 }.max() ?? 72)
        stack.frame = CGRect(x: 0, y: 0, width: max(bounds.width, itemWidth * CGFloat(buttons.count)), height: bounds.height)
        stack.layoutIfNeeded()
        scroller.contentSize = stack.bounds.size
        if let index = selectedIndex, buttons.indices.contains(index) { indicator.frame = indicatorFrame(index) }
    }

    private func indicatorFrame(_ index: Int) -> CGRect {
        let frame = buttons[index].frame
        return CGRect(x: frame.minX + 12, y: max(0, bounds.height - 3), width: max(0, frame.width - 24), height: 3)
    }
}
