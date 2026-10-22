import UIKit

/// 测量与显示共用角标尺寸，包含中文回退字体的实际行高和胶囊内边距。
@MainActor
internal enum SPTabBadgeMetrics {
    static func size(for value: String?, font: UIFont) -> CGSize {
        guard let value else {
            return .zero
        }
        guard !value.isEmpty else {
            return CGSize(width: 8, height: 8)
        }
        let label = UILabel()
        label.font = font
        label.text = value
        let text = label.intrinsicContentSize
        let height = max(18, ceil(text.height) + 4)
        return CGSize(width: max(height, ceil(text.width) + 10), height: height)
    }

    /// 角标向内容内重叠 4 pt，其余向尾端延伸；两侧对称留白保持图文居中。
    static func additionalWidth(for size: CGSize) -> CGFloat {
        2 * max(0, size.width - 4 - 16)
    }
}

/// 已按标签栏选中项、外观和 traits 解析的内容快照，不持有可变的 Item 或 Appearance。
internal struct SPDefaultTabContentConfiguration {
    let buttonConfiguration: UIButton.Configuration
    let layoutDirection: UIUserInterfaceLayoutDirection
    let iconColor: UIColor
    let isEnabled: Bool
    let accessibilityIdentifier: String
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityTraits: UIAccessibilityTraits
    let largeContentImage: UIImage?
    let largeContentImageInsets: UIEdgeInsets
    let badgeValue: String?
    let badgeFont: UIFont
    let badgeTextColor: UIColor
    let badgeBackgroundColor: UIColor
    let onTap: @MainActor () -> Void
}

/// Cell 始终使用同一种配置与内容容器；模式切换只更新内部呈现。
internal enum SPTabContentConfiguration: UIContentConfiguration {
    case standard(SPDefaultTabContentConfiguration)
    case custom(SPCustomTabContentConfiguration)

    var onTap: @MainActor () -> Void {
        switch self {
        case let .standard(value): value.onTap
        case let .custom(value): value.onTap
        }
    }

    func makeContentView() -> UIView & UIContentView {
        SPTabContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        // 选中与禁用由标签栏解析，高亮由激活按钮管理。
        self
    }
}

@MainActor
internal protocol SPTabIndicatorContentGeometry: AnyObject {
    var indicatorContentRect: CGRect { get }
}

@MainActor
private final class SPTabContentView: UIView, UIContentView, SPTabIndicatorContentGeometry {
    private var storedConfiguration: SPTabContentConfiguration
    var configuration: UIContentConfiguration {
        get { storedConfiguration }
        set {
            guard let value = newValue as? SPTabContentConfiguration else {
                return
            }
            let resetHighlight: Bool
            switch (storedConfiguration, value) {
            case let (.custom(old), .custom(new)):
                resetHighlight = old.itemIdentifier != new.itemIdentifier
            case (.standard, .standard):
                resetHighlight = false
            default:
                resetHighlight = true
            }
            storedConfiguration = value
            applyingConfiguration = true
            if resetHighlight {
                button.isHighlighted = false
            }
            applyConfiguration()
            applyingConfiguration = false
        }
    }

    private let button = ActivationButton(type: .system)
    private var customView: (UIView & UIContentView)?
    private var applyingConfiguration = false
    private let badge = UILabel()

    init(configuration: SPTabContentConfiguration) {
        storedConfiguration = configuration
        super.init(frame: .zero)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        // 只安装一次 action，执行时读取最新配置，避免复用时累积回调或引用旧 Item。
        button.addAction(UIAction { [weak self] _ in self?.storedConfiguration.onTap() }, for: .touchUpInside)
        button.highlightDidChange = { [weak self] in
            guard let self, !self.applyingConfiguration else {
                return
            }
            self.updateCustomContent()
        }
        addSubview(button)
        badge.textAlignment = .center
        badge.clipsToBounds = true
        badge.isUserInteractionEnabled = false
        badge.isAccessibilityElement = false
        addSubview(badge)
        applyConfiguration()
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(configuration:)")
    }

    private func applyConfiguration() {
        guard case let .standard(value) = storedConfiguration else {
            applyCustomConfiguration()
            return
        }
        customView?.removeFromSuperview()
        customView = nil
        // 配置可能用于新建、复用或脱离 Collection View 的测量视图，不依赖 UIKit 的内部继承链。
        semanticContentAttribute = value.layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        button.semanticContentAttribute = semanticContentAttribute
        button.tintColor = value.iconColor
        button.configuration = value.buttonConfiguration
        button.isEnabled = value.isEnabled
        button.accessibilityIdentifier = value.accessibilityIdentifier
        button.accessibilityLabel = value.accessibilityLabel
        button.accessibilityHint = value.accessibilityHint
        button.accessibilityTraits = value.accessibilityTraits
        button.accessibilityValue = value.badgeValue.map { $0.isEmpty ? "有新内容" : $0 }
        button.largeContentTitle = value.accessibilityLabel
        button.largeContentImage = value.largeContentImage
        button.largeContentImageInsets = value.largeContentImageInsets
        badge.text = value.badgeValue
        badge.isHidden = value.badgeValue == nil
        badge.font = value.badgeFont
        badge.textColor = value.badgeTextColor
        badge.backgroundColor = value.badgeBackgroundColor
        setNeedsLayout()
    }

    private func applyCustomConfiguration() {
        guard case let .custom(value) = storedConfiguration else {
            return
        }
        // 清除默认模式的视觉和大内容预览，保留同一个点击／无障碍入口。
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.setImage(nil, for: .normal)
        semanticContentAttribute = .unspecified
        button.semanticContentAttribute = .unspecified
        button.largeContentTitle = nil
        button.largeContentImage = nil
        button.largeContentImageInsets = .zero
        badge.text = nil
        badge.isHidden = true
        button.isEnabled = !value.state.isDisabled
        button.accessibilityIdentifier = value.accessibilityIdentifier
        button.accessibilityLabel = value.accessibilityLabel
        button.accessibilityHint = value.accessibilityHint
        button.accessibilityValue = value.accessibilityValue
        button.accessibilityTraits = value.state.isSelected ? [.button, .selected] : .button
        if value.state.isDisabled {
            button.accessibilityTraits.insert(.notEnabled)
        }
        updateCustomContent()
    }

    private func updateCustomContent() {
        guard case let .custom(value) = storedConfiguration else {
            return
        }
        var state = value.state
        state.isHighlighted = button.isHighlighted && button.isEnabled
        let content = value.content.updated(for: state)
        let compatible: Bool
        if let customView {
            if #available(iOS 16, *) {
                compatible = customView.supports(content)
            } else {
                compatible = type(of: customView.configuration) == type(of: content)
            }
        } else {
            compatible = false
        }
        if compatible {
            customView?.configuration = content
        } else {
            customView?.removeFromSuperview()
            let view = content.makeContentView()
            customView = view
            insertSubview(view, belowSubview: button)
        }
        customView?.isUserInteractionEnabled = false
        customView?.accessibilityElementsHidden = true
        customView?.frame = bounds
        setNeedsLayout()
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        guard case let .custom(value) = storedConfiguration else {
            // 默认图文也由标签布局分配尺寸；手动布局视图不能交给无约束的 Auto Layout 求解。
            return bounds.size
        }
        // 业务内容已独立测量，Cell 的 fitting 查询不再次求解内部业务约束。
        return CGSize(
            width: bounds.width > 0 ? bounds.width : value.measuredSize.width,
            height: bounds.height > 0 ? bounds.height : value.measuredSize.height
        )
    }

    private final class ActivationButton: UIButton {
        var highlightDidChange: (() -> Void)?
        override var isHighlighted: Bool {
            didSet {
                if oldValue != isHighlighted {
                    highlightDidChange?()
                }
            }
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled else {
                return false
            }
            sendActions(for: .touchUpInside)
            return true
        }
    }

    var indicatorContentRect: CGRect {
        layoutIfNeeded()
        button.layoutIfNeeded()
        let frames = [button.titleLabel, button.imageView].compactMap { view -> CGRect? in
            guard let view, !view.isHidden, !view.bounds.isEmpty else {
                return nil
            }
            return view.convert(view.bounds, to: self)
        }
        return frames.reduce(CGRect.null) { $0.union($1) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = bounds
        button.layoutIfNeeded()
        customView?.frame = bounds
        guard case let .standard(value) = storedConfiguration else {
            badge.frame = .zero
            return
        }
        let size = SPTabBadgeMetrics.size(for: value.badgeValue, font: value.badgeFont)
        guard size != .zero else {
            badge.frame = .zero
            return
        }
        // 上下图文跟随图标；纯文字与横向图文跟随整体内容。尾端角标在 RTL 下镜像到左上角。
        var anchor = CGRect.null
        if let title = button.titleLabel, !(button.configuration?.title ?? "").isEmpty {
            anchor = title.convert(title.bounds, to: self)
        }
        if let icon = button.imageView, button.configuration?.image != nil {
            let imageFrame = icon.convert(icon.bounds, to: self)
            anchor = button.configuration?.imagePlacement == .top ? imageFrame : anchor.union(imageFrame)
        }
        if anchor.isNull || anchor.isEmpty {
            anchor = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        }
        let x = value.layoutDirection == .rightToLeft ? anchor.minX + 4 - size.width : anchor.maxX - 4
        badge.frame = CGRect(
            x: max(0, min(x, bounds.width - size.width)),
            y: max(0, min(anchor.minY - size.height / 2, bounds.height - size.height)),
            width: size.width,
            height: size.height
        )
        badge.layer.cornerRadius = size.height / 2
    }
}
