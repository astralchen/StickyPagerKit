import UIKit

/// 单次内容解析的环境值；不持有标签栏，不保存已提交的选择状态。
@MainActor
internal struct SPTabBarContentEnvironment {
    let items: [SPTabBarItem]
    let selectedIndex: Int?
    let contentStyle: SPTabBar.ContentStyle
    let layoutConfiguration: SPTabBarLayoutConfiguration
    let defaultContentLayout: SPTabBarDefaultContentLayout
    let appearance: SPTabBarAppearance
    let traitCollection: UITraitCollection
    let tintColor: UIColor
    let contentDirection: UIUserInterfaceLayoutDirection
    let delegateIdentity: ObjectIdentifier?

    var titleFont: UIFont {
        .preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
    }

    private var stacked: Bool {
        switch defaultContentLayout.imagePlacement {
        case .automatic: return traitCollection.verticalSizeClass != .compact
        case .stacked: return true
        case .inline: return false
        }
    }

    private func itemFont(_ item: SPTabBarItem, style: SPTabBarItemStateAppearance, state: UIControl.State) -> UIFont {
        let attributes = item.titleTextAttributes(for: state) ?? item.titleTextAttributes(for: .normal)
        if let base = (attributes?[.font] as? UIFont) ?? style.font {
            return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: base, compatibleWith: traitCollection)
        }
        let font = titleFont
        guard state.contains(.selected) else {
            return font
        }
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }

    func measuredSize(_ item: SPTabBarItem) -> CGSize {
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
        let hasIcon = (item.image != nil || item.selectedImage != nil || item.landscapeImagePhone != nil)
            && defaultContentLayout.iconSize.width > 0 && defaultContentLayout.iconSize.height > 0
        let icon = hasIcon ? defaultContentLayout.iconSize : .zero
        let gap: CGFloat = hasIcon && !(item.title ?? "").isEmpty ? defaultContentLayout.imageTitleSpacing : 0
        let width = stacked ? max(title.width, icon.width) : title.width + icon.width + gap
        let height = stacked ? title.height + icon.height + gap : max(title.height, icon.height)
        let badgeSize = SPTabBadgeMetrics.size(
            for: item.badgeValue,
            font: .preferredFont(forTextStyle: .caption2, compatibleWith: traitCollection)
        )
        // 默认栏高已包含上下留白；大字号角标只补充超出留白的高度，避免顶部裁剪。
        let badgeOverflow = badgeSize
            .height - (defaultContentLayout.contentInsets.top + defaultContentLayout.contentInsets.bottom)
        return CGSize(
            width: width + SPTabBadgeMetrics.additionalWidth(
                for: badgeSize,
                trailingPadding: defaultContentLayout.contentInsets.trailing
            ),
            height: max(height + max(0, badgeOverflow), badgeOverflow)
        )
    }

    func configuration(
        for item: SPTabBarItem,
        at index: Int,
        selected: Bool,
        content: SPTabBarContent?,
        selectionProgress: CGFloat? = nil,
        onTap: @escaping @MainActor () -> Void
    ) -> SPTabContentConfiguration {
        let isSelected = selected
        if let content {
            var state = UICellConfigurationState(traitCollection: traitCollection)
            state.isSelected = isSelected
            state.isDisabled = !item.isEnabled
            if content.tracksSelectionProgress, let selectionProgress {
                state.setSPSelectionProgress(selectionProgress)
            }
            return SPTabContentConfiguration.custom(SPCustomTabContentConfiguration(
                content: content.configuration,
                measuredSize: content.size ?? CGSize(width: 44, height: 44),
                state: state,
                tracksSelectionProgress: content.tracksSelectionProgress,
                isAccessibilitySelected: index == selectedIndex,
                itemIdentifier: ObjectIdentifier(item),
                accessibilityIdentifier: "sp.tab.\(index)",
                accessibilityLabel: content.accessibilityLabel ?? item.accessibilityLabel ?? item.title,
                accessibilityHint: content.accessibilityHint ?? item.accessibilityHint,
                accessibilityValue: content.accessibilityValue ?? item.badgeValue.map { $0.isEmpty ? "有新内容" : $0 },
                onTap: onTap
            ))
        }
        let styles = appearance.itemAppearance
        let state = !item.isEnabled ? styles.disabled : (isSelected ? styles.selected : styles.normal)
        let defaultColor: UIColor = !item
            .isEnabled ? .tertiaryLabel : (isSelected ? tintColor : .secondaryLabel)
        let iconColor = state.iconColor ?? defaultColor
        let titleColor = state.titleColor ?? defaultColor
        var configuration = UIButton.Configuration.plain()
        if layoutConfiguration.constrainsContentWidth {
            configuration.titleLineBreakMode = .byTruncatingTail
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: defaultContentLayout.contentInsets.top,
            leading: defaultContentLayout.contentInsets.leading,
            bottom: defaultContentLayout.contentInsets.bottom,
            trailing: defaultContentLayout.contentInsets.trailing
        )
        configuration.title = item.title
        let baseImage = traitCollection.verticalSizeClass == .compact ? (item.landscapeImagePhone ?? item.image) : item
            .image
        configuration.image = isSelected ? (item.selectedImage ?? baseImage) : baseImage
        let imageInsets = traitCollection.verticalSizeClass == .compact && item
            .landscapeImagePhone != nil && (!isSelected || item.selectedImage == nil) ? item
            .landscapeImagePhoneInsets : item.imageInsets
        configuration.image = configuration.image.flatMap { image -> UIImage? in
            guard defaultContentLayout.iconSize.width > 0, defaultContentLayout.iconSize.height > 0 else {
                return nil
            }
            let ratio = min(
                defaultContentLayout.iconSize.width / max(1, image.size.width),
                defaultContentLayout.iconSize.height / max(1, image.size.height)
            )
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            // 符号光栅化后不再携带 isSymbolImage；显式保留其默认模板语义。
            let mode: UIImage.RenderingMode = image.isSymbolImage && image
                .renderingMode == .automatic ? .alwaysTemplate : image.renderingMode
            // 逻辑尺寸允许大值，但不能按其直接申请位图；普通图标仍使用屏幕分辨率。
            let format = UIGraphicsImageRendererFormat()
            format.scale = min(format.scale, 1024 / max(1, max(size.width, size.height)))
            return UIGraphicsImageRenderer(size: size, format: format)
                .image { _ in image.draw(in: CGRect(origin: .zero, size: size).inset(by: imageInsets)) }
                .withRenderingMode(mode)
        }
        configuration.imagePlacement = stacked ? .top : .leading
        configuration.imagePadding = defaultContentLayout.imageTitleSpacing
        configuration.baseForegroundColor = iconColor
        let controlState: UIControl.State = !item.isEnabled ? .disabled : (isSelected ? .selected : .normal)
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
        return SPTabContentConfiguration.standard(SPDefaultTabContentConfiguration(
            buttonConfiguration: configuration,
            layoutDirection: contentDirection,
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
            onTap: onTap
        ))
    }
}
