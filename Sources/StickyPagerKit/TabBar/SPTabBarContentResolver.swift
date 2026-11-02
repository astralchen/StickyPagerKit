import UIKit

/// 管理候选宽度测量与已应用内容快照；测量本身不修改 Collection View 的布局。
@MainActor
internal final class SPTabBarContentResolver {
    let measurementHost = UIView()
    struct Measurement {
        let revision: UInt
        let width: CGFloat
        let direction: UIUserInterfaceLayoutDirection
        let delegateIdentity: ObjectIdentifier?
        let contents: [SPTabBarContent?]
        let itemWidths: [CGFloat]
        let layoutConfiguration: SPTabBarLayoutConfiguration
        let height: CGFloat
    }

    private(set) var applied: Measurement?
    private(set) var measurementPasses: UInt = 0
    private(set) var contentRequests: UInt = 0
    private var candidate: Measurement?
    private var contentRevision: UInt = 0
    private var resolvingCustomContents = false
    func measure(
        width: CGFloat,
        environment: SPTabBarContentEnvironment,
        provider: (SPTabBarItem, Int, SPTabBarContentContext) -> SPTabBarContent?
    ) -> Measurement? {
        let items = environment.items
        let selectedIndex = environment.selectedIndex
        let layoutConfiguration = environment.layoutConfiguration
        let defaultContentLayout = environment.defaultContentLayout
        let contentInsets = layoutConfiguration.contentInsets
        let traitCollection = environment.traitCollection
        let tintColor = environment.tintColor
        let appearance = environment.appearance
        let titleFont = environment.titleFont
        guard !resolvingCustomContents else {
            return nil
        }
        let width = width.isFinite ? max(0, width - contentInsets.leading - contentInsets.trailing) : 0
        let identity = environment.delegateIdentity
        let direction = environment.contentDirection
        for snapshot in [applied, candidate] {
            if let snapshot, snapshot.revision == contentRevision, snapshot.width == width,
               snapshot.direction == direction, snapshot.delegateIdentity == identity {
                return snapshot
            }
        }
        resolvingCustomContents = true
        measurementPasses &+= 1
        defer { resolvingCustomContents = false }
        let revision = contentRevision
        measurementHost
            .semanticContentAttribute = direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        if #available(iOS 17, *) {
            measurementHost.updateTraitsIfNeeded()
        }
        var measuringViews: [Int: UIView] = [:]
        var measuringContainers: [UIView] = []
        defer { measuringContainers.forEach { $0.removeFromSuperview() } }
        var result = items.enumerated().map { index, item -> SPTabBarContent? in
            guard environment.contentStyle == .custom else {
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
            contentRequests &+= 1
            guard var content = provider(item, index, context) else {
                return nil
            }
            if let size = content.size {
                guard validContentSize(size) else {
                    return nil
                }
            } else {
                let view = content.configuration.updated(for: state).makeContentView()
                view.translatesAutoresizingMaskIntoConstraints = false
                view.semanticContentAttribute = measurementHost.semanticContentAttribute
                let container = UIView()
                container.translatesAutoresizingMaskIntoConstraints = false
                measurementHost.addSubview(container)
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
                guard natural.width.isFinite, natural.width > 0,
                      natural.width <= SPTabBarGeometryLimits.maximumMagnitude else {
                    view.removeFromSuperview()
                    return nil
                }
                // 部分系统内容视图重写 fitting，不采用外加的软宽度约束。
                // 通过普通 Auto Layout 宿主求可行首选宽度，优先级略低于 required，让业务最小宽度优先。
                let preferredWidth = (layoutConfiguration.itemSizing == .balanced || layoutConfiguration
                    .itemSizing == .equal) && width > 0
                    ? min(natural.width, width) : natural.width
                let constrained = container.systemLayoutSizeFitting(
                    CGSize(width: preferredWidth, height: 0),
                    withHorizontalFittingPriority: UILayoutPriority(UILayoutPriority.required.rawValue - 1),
                    verticalFittingPriority: .fittingSizeLevel
                )
                guard constrained.width.isFinite, constrained.width > 0,
                      constrained.width <= SPTabBarGeometryLimits.maximumMagnitude else {
                    view.removeFromSuperview()
                    return nil
                }
                measuringViews[index] = view
                content.size = CGSize(width: ceil(constrained.width), height: 0)
            }
            return content
        }
        let defaultSizes = items.map { environment.measuredSize($0) }
        var widths: [CGFloat] = []
        // 某项测量失败回退后，宽度分配可能改变，需要重新测量其余自动内容的高度。
        while true {
            widths = result.indices.map {
                max(
                    layoutConfiguration.minimumItemWidth,
                    result[$0]?.size?
                        .width ??
                        (defaultSizes[$0]
                            .width +
                            (defaultContentLayout.contentInsets.leading + defaultContentLayout.contentInsets.trailing))
                )
            }
            let allocated = SPTabBarLayout.resolvedWidths(
                widths,
                viewportWidth: width,
                itemSpacing: layoutConfiguration.itemSpacing,
                configuration: layoutConfiguration
            )
            var failed = false
            for index in measuringViews.keys.sorted() {
                guard let view = measuringViews[index] else {
                    continue
                }
                // 系统内容视图可能忽略软宽度；有限宽度策略通过普通宿主求解高度。
                let fittingView = layoutConfiguration.constrainsContentWidth ? (view.superview ?? view) : view
                let fitted = fittingView.systemLayoutSizeFitting(
                    CGSize(width: allocated[index], height: 0),
                    // 有限宽度策略不能被业务 required 最小宽度撑开；软测量避免产生约束冲突。
                    withHorizontalFittingPriority: layoutConfiguration.constrainsContentWidth
                        ? UILayoutPriority(UILayoutPriority.required.rawValue - 1) : .required,
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
        let measurement = Measurement(
            revision: revision,
            width: width,
            direction: direction,
            delegateIdentity: identity,
            contents: result,
            itemWidths: widths,
            layoutConfiguration: layoutConfiguration,
            // 只对默认图文保留原有高度规则；自定义内容不承担容器的最小栏高策略。
            height: result.indices.map {
                result[$0]?.size?.height ?? defaultContentLayout.height(for: defaultSizes[$0].height)
            }.max() ?? defaultContentLayout.height(for: ceil(titleFont.lineHeight))
        )
        candidate = measurement
        return measurement
    }

    private func validContentSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
            && size.width <= SPTabBarGeometryLimits.maximumMagnitude && size.height <= SPTabBarGeometryLimits
            .maximumMagnitude
    }

    @discardableResult
    func apply(_ measurement: Measurement) -> Bool {
        if let previous = applied, previous.revision == measurement.revision,
           previous.width == measurement.width, previous.direction == measurement.direction,
           previous.delegateIdentity == measurement.delegateIdentity {
            return false
        }
        applied = measurement
        return true
    }

    func invalidate() {
        contentRevision &+= 1
        candidate = nil
    }

    func content(at index: Int) -> SPTabBarContent? {
        guard let applied, applied.contents.indices.contains(index) else {
            return nil
        }
        return applied.contents[index]
    }

    func metricsDiffer(from previous: Measurement?) -> Bool {
        guard let previous, let current = applied else {
            return false
        }
        func widths(_ value: Measurement) -> [CGFloat] {
            SPTabBarLayout.resolvedWidths(
                value.itemWidths,
                viewportWidth: value.width,
                itemSpacing: value.layoutConfiguration.itemSpacing,
                configuration: value.layoutConfiguration
            )
        }
        func alignmentOffset(_ value: Measurement, widths: [CGFloat]) -> CGFloat {
            SPTabBarLayout.alignmentOffset(
                widths,
                viewportWidth: value.width,
                itemSpacing: value.layoutConfiguration.itemSpacing,
                alignment: value.layoutConfiguration.alignment,
                isRightToLeft: value.direction == .rightToLeft
            )
        }
        let previousWidths = widths(previous)
        let currentWidths = widths(current)
        return previous.layoutConfiguration.contentInsets != current.layoutConfiguration.contentInsets ||
            (current.itemWidths.count > 1 && previous.layoutConfiguration.itemSpacing != current.layoutConfiguration
                .itemSpacing) ||
            previousWidths != currentWidths ||
            alignmentOffset(previous, widths: previousWidths) != alignmentOffset(current, widths: currentWidths) ||
            previous.height != current.height
    }
}
