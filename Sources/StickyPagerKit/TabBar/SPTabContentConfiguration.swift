import UIKit

/// 测量与显示共用角标尺寸，包含中文回退字体的实际行高和胶囊内边距。
@MainActor
internal enum SPTabBadgeMetrics {
    static let contentOverlap: CGFloat = 4
    private static let dotDiameter: CGFloat = 8
    private static let minimumHeight: CGFloat = 18
    private static let horizontalPadding: CGFloat = 5
    private static let verticalPadding: CGFloat = 2

    static func size(for value: String?, font: UIFont) -> CGSize {
        guard let value else {
            return .zero
        }
        guard !value.isEmpty else {
            return CGSize(width: dotDiameter, height: dotDiameter)
        }
        let label = UILabel()
        label.font = font
        label.text = value
        let text = label.intrinsicContentSize
        let height = max(minimumHeight, ceil(text.height) + 2 * verticalPadding)
        return CGSize(width: max(height, ceil(text.width) + 2 * horizontalPadding), height: height)
    }

    /// 角标向内容内重叠，先利用按钮尾端留白，再对称扩宽以保持图文居中。
    static func additionalWidth(for size: CGSize, trailingPadding: CGFloat) -> CGFloat {
        2 * max(0, size.width - contentOverlap - trailingPadding)
    }
}

/// 已按标签栏选中项、外观和 traits 解析的内容快照，不持有可变的 Item 或 Appearance。
internal struct SPDefaultTabContentConfiguration {
    let buttonConfiguration: UIButton.Configuration
    let colors: SPDefaultTabColors?
    let selectionProgress: CGFloat
    let allowsTintOnlyIconUpdates: Bool
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
    var indicatorTitleRect: CGRect? { get }
}

@MainActor
internal protocol SPTabContentProgressDisplaying: AnyObject {
    func updateSelectionProgress(_ progress: CGFloat)
    func updateContentScale(_ scale: CGFloat, enabled: Bool)
}

@MainActor
private final class SPTabContentView: UIView, UIContentView, SPTabIndicatorContentGeometry,
SPTabContentProgressDisplaying, SPTabColorDiagnosing {
    var colorDiagnostics: SPTabColorDiagnostics?
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
            usesTintOnlyIcon = false
            displayedSelectionProgress = nil
            displayedTitleTransformer = nil
            displayedTitleColor = nil
            displayedIconColor = nil
            storedConfiguration = value
            applyingConfiguration = true
            if resetHighlight {
                button.isHighlighted = false
            }
            applyConfiguration()
            synchronizeActivationOverlay()
            applyingConfiguration = false
        }
    }

    private let button = ActivationButton(type: .system)
    private var customView: (UIView & UIContentView)?
    private var applyingConfiguration = false
    private var displayedSelectionProgress: CGFloat?
    // 只复用当前内容快照的呈现结果；重新配置时清空，避免跨 traits、内容或模式复用。
    private var displayedTitleTransformer: UIConfigurationTextAttributesTransformer?
    private var displayedTitleColor: UIColor?
    private var displayedIconColor: UIColor?
    private var hasDefaultTitle = false
    private var hasTemplateIcon = false
    private var usesTintOnlyIcon = false
    private let badge = UILabel()
    private var visualHost: UIView?
    private var activationOverlay: ActivationButton?

    init(configuration: SPTabContentConfiguration) {
        storedConfiguration = configuration
        super.init(frame: .zero)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        // 只安装一次 action，执行时读取最新配置，避免复用时累积回调或引用旧 Item。
        button.addAction(UIAction { [weak self] _ in self?.storedConfiguration.onTap() }, for: .touchUpInside)
        // 高亮／禁用／选中开始前固定当前颜色，避免 nil 前景色延后到下一次自动更新。
        button.controlStateWillChange = { [weak self] in
            guard let self, !self.applyingConfiguration else {
                return
            }
            self.restorePinnedIconConfiguration()
        }
        button.tintEnvironmentDidChange = { [weak self] in
            guard let self, !self.applyingConfiguration, self.button.tintAdjustmentMode == .dimmed else {
                return
            }
            self.restorePinnedIconConfiguration()
        }
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
        clipsToBounds = false
        // 配置可能用于新建、复用或脱离 Collection View 的测量视图，不依赖 UIKit 的内部继承链。
        semanticContentAttribute = value.layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        button.semanticContentAttribute = semanticContentAttribute
        // 可见颜色通道只随内容快照变化，避免逐帧读取并桥接配置中的文本和图片。
        hasDefaultTitle = !(value.buttonConfiguration.title?.isEmpty ?? true)
            || !(value.buttonConfiguration.attributedTitle?.characters.isEmpty ?? true)
        hasTemplateIcon = value.buttonConfiguration.image?.renderingMode == .alwaysTemplate
        button.tintColor = value.iconColor
        colorDiagnostics?.statistics.baseConfigurationAssignments &+= 1
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
        updateDefaultColors(progress: value.selectionProgress)
        setNeedsLayout()
    }

    private func applyCustomConfiguration() {
        guard case let .custom(value) = storedConfiguration else {
            return
        }
        clipsToBounds = true
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
        button.accessibilityTraits = value.isAccessibilitySelected ? [.button, .selected] : .button
        if value.state.isDisabled {
            button.accessibilityTraits.insert(.notEnabled)
        }
        updateCustomContent()
    }

    func updateSelectionProgress(_ progress: CGFloat) {
        if case .standard = storedConfiguration {
            updateDefaultColors(progress: progress)
            return
        }
        guard case let .custom(value) = storedConfiguration, value.tracksSelectionProgress,
              progress != (displayedSelectionProgress ?? value.state.spSelectionProgress) else {
            return
        }
        displayedSelectionProgress = progress
        updateCustomContent()
    }

    /// 连续呈现仅修改颜色；基础配置、图片与布局仍由离散配置持有。
    private func updateDefaultColors(progress: CGFloat) {
        if usesTintOnlyIcon, button.state != .normal || button.tintAdjustmentMode == .dimmed {
            restorePinnedIconConfiguration()
        }
        colorDiagnostics?.statistics.colorUpdateAttempts &+= 1
        guard case let .standard(value) = storedConfiguration, let colors = value.colors,
              progress != displayedSelectionProgress else {
            return
        }
        displayedSelectionProgress = progress
        colorDiagnostics?.statistics.colorPasses &+= 1
        var title: UIColor?
        if hasDefaultTitle {
            colorDiagnostics?.statistics.titleColorEvaluations &+= 1
            title = colors.title.color(at: progress)
        }
        var icon: UIColor?
        if hasTemplateIcon {
            colorDiagnostics?.statistics.iconColorEvaluations &+= 1
            icon = colors.icon.color(at: progress)
        }
        let titleChanged = title != displayedTitleColor
        let iconChanged = icon != displayedIconColor
        guard titleChanged || iconChanged else {
            return
        }
        let canUseTintOnlyIcon = value.allowsTintOnlyIconUpdates && hasDefaultTitle && hasTemplateIcon
            && !titleChanged && button.state == .normal && button.tintAdjustmentMode != .dimmed
        if canUseTintOnlyIcon, usesTintOnlyIcon, let icon {
            if iconChanged {
                button.tintColor = icon
            }
            displayedTitleColor = title
            displayedIconColor = icon
            return
        }
        // 从基础快照重建颜色覆盖，只缓存可复用的 transformer，不保留上一帧完整配置。
        var configuration = value.buttonConfiguration
        if titleChanged, let title {
            // 始终组合原始 transformer，不让连续更新形成嵌套闭包链。
            let base = configuration.titleTextAttributesTransformer
            colorDiagnostics?.statistics.titleTransformerCreations &+= 1
            displayedTitleTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var result = base?(attributes) ?? attributes
                result.foregroundColor = title
                return result
            }
        }
        if let displayedTitleTransformer {
            configuration.titleTextAttributesTransformer = displayedTitleTransformer
        }
        if let icon {
            configuration.baseForegroundColor = canUseTintOnlyIcon ? nil : icon
            if iconChanged {
                button.tintColor = icon
            }
        }
        displayedTitleColor = title
        displayedIconColor = icon
        colorDiagnostics?.statistics.colorConfigurationAssignments &+= 1
        button.configuration = configuration
        usesTintOnlyIcon = canUseTintOnlyIcon
    }

    /// 只从当前快照和已显示颜色恢复；不读取或保存上一帧完整配置。
    private func restorePinnedIconConfiguration() {
        guard usesTintOnlyIcon, case let .standard(value) = storedConfiguration else {
            return
        }
        usesTintOnlyIcon = false
        var configuration = value.buttonConfiguration
        configuration.baseForegroundColor = displayedIconColor ?? value.iconColor
        if let displayedTitleTransformer {
            configuration.titleTextAttributesTransformer = displayedTitleTransformer
        }
        colorDiagnostics?.statistics.colorConfigurationAssignments &+= 1
        button.configuration = configuration
    }

    private func updateCustomContent() {
        guard case let .custom(value) = storedConfiguration else {
            return
        }
        var state = value.state
        state.isHighlighted = button.isHighlighted && button.isEnabled
        if let displayedSelectionProgress {
            state.setSPSelectionProgress(displayedSelectionProgress)
        }
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
            if let visualHost {
                visualHost.insertSubview(view, belowSubview: button)
            } else {
                insertSubview(view, belowSubview: button)
            }
        }
        customView?.isUserInteractionEnabled = false
        customView?.accessibilityElementsHidden = true
        layoutCustomContent()
        setNeedsLayout()
    }

    private func layoutCustomContent() {
        guard case let .custom(value) = storedConfiguration else {
            return
        }
        // 栏高不足时保留测得的内容高度并从顶部裁切，避免强压业务内部 required 约束。
        // 点击与无障碍入口仍使用外层 Item 的 bounds；宽度继续遵循项宽分配。
        let size = CGSize(width: bounds.width, height: max(bounds.height, value.measuredSize.height))
        customView?.bounds = CGRect(origin: .zero, size: size)
        customView?.center = CGPoint(x: bounds.minX + size.width / 2, y: bounds.minY + size.height / 2)
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

    /// 变换仅作用于框架拥有的视觉层；覆盖层继续使用未缩放的 Item bounds。
    func updateContentScale(_ scale: CGFloat, enabled: Bool) {
        if enabled, visualHost == nil {
            let host = UIView()
            host.isUserInteractionEnabled = false
            host.accessibilityElementsHidden = true
            host.accessibilityIdentifier = "sp.tab.visualHost"
            insertSubview(host, at: 0)
            if let customView {
                host.addSubview(customView)
            }
            host.addSubview(button)
            host.addSubview(badge)
            visualHost = host
            let overlay = ActivationButton(type: .custom)
            overlay.addAction(UIAction { [weak self] _ in self?.storedConfiguration.onTap() }, for: .touchUpInside)
            overlay.highlightDidChange = { [weak self, weak overlay] in
                self?.button.isHighlighted = overlay?.isHighlighted ?? false
            }
            addSubview(overlay)
            activationOverlay = overlay
            synchronizeActivationOverlay()
        } else if !enabled, let host = visualHost {
            // 先解除变换再恢复原有层级，避免复用或关闭效果残留呈现状态。
            host.transform = .identity
            if let customView {
                insertSubview(customView, belowSubview: host)
            }
            addSubview(button)
            addSubview(badge)
            button.isHighlighted = false
            activationOverlay?.removeFromSuperview()
            activationOverlay = nil
            host.removeFromSuperview()
            visualHost = nil
        }
        layoutVisualHost()
        visualHost?.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    private func synchronizeActivationOverlay() {
        guard let overlay = activationOverlay else {
            return
        }
        overlay.isEnabled = button.isEnabled
        overlay.accessibilityIdentifier = button.accessibilityIdentifier
        overlay.accessibilityLabel = button.accessibilityLabel
        overlay.accessibilityHint = button.accessibilityHint
        overlay.accessibilityValue = button.accessibilityValue
        overlay.accessibilityTraits = button.accessibilityTraits
        overlay.largeContentTitle = button.largeContentTitle
        overlay.largeContentImage = button.largeContentImage
        overlay.largeContentImageInsets = button.largeContentImageInsets
    }

    private func layoutVisualHost() {
        visualHost?.clipsToBounds = clipsToBounds
        visualHost?.bounds = bounds
        visualHost?.center = CGPoint(x: bounds.midX, y: bounds.midY)
        activationOverlay?.frame = bounds
    }

    private final class ActivationButton: UIButton {
        var highlightDidChange: (() -> Void)?
        var controlStateWillChange: (() -> Void)?
        var tintEnvironmentDidChange: (() -> Void)?
        override var isEnabled: Bool {
            willSet {
                if newValue != isEnabled {
                    controlStateWillChange?()
                }
            }
        }

        override var isSelected: Bool {
            willSet {
                if newValue != isSelected {
                    controlStateWillChange?()
                }
            }
        }

        override func tintColorDidChange() {
            super.tintColorDidChange()
            tintEnvironmentDidChange?()
        }

        override var isHighlighted: Bool {
            willSet {
                if newValue != isHighlighted {
                    controlStateWillChange?()
                }
            }
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

    var indicatorTitleRect: CGRect? {
        layoutIfNeeded()
        button.layoutIfNeeded()
        guard let label = button.titleLabel, !(label.text ?? "").isEmpty,
              !label.isHidden, !label.bounds.isEmpty else {
            return nil
        }
        return label.convert(label.bounds, to: visualHost ?? self)
    }

    var indicatorContentRect: CGRect {
        layoutIfNeeded()
        button.layoutIfNeeded()
        let frames = [button.titleLabel, button.imageView].compactMap { view -> CGRect? in
            guard let view, !view.isHidden, !view.bounds.isEmpty else {
                return nil
            }
            return view.convert(view.bounds, to: visualHost ?? self)
        }
        return frames.reduce(CGRect.null) { $0.union($1) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        colorDiagnostics?.statistics.contentLayoutPasses &+= 1
        layoutVisualHost()
        button.frame = bounds
        button.layoutIfNeeded()
        layoutCustomContent()
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
            anchor = title.convert(title.bounds, to: visualHost ?? self)
        }
        if let icon = button.imageView, button.configuration?.image != nil {
            let imageFrame = icon.convert(icon.bounds, to: visualHost ?? self)
            anchor = button.configuration?.imagePlacement == .top ? imageFrame : anchor.union(imageFrame)
        }
        if anchor.isNull || anchor.isEmpty {
            anchor = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        }
        let overlap = SPTabBadgeMetrics.contentOverlap
        let x = value.layoutDirection == .rightToLeft ? anchor.minX + overlap - size.width : anchor.maxX - overlap
        badge.frame = CGRect(
            x: max(0, min(x, bounds.width - size.width)),
            y: max(0, min(anchor.minY - size.height / 2, bounds.height - size.height)),
            width: size.width,
            height: size.height
        )
        badge.layer.cornerRadius = size.height / 2
    }
}
