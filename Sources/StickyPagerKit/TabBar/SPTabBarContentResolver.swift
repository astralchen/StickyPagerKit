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
    private struct ContentKey: Equatable {
        let width: CGFloat
        let direction: UIUserInterfaceLayoutDirection
        let delegateIdentity: ObjectIdentifier?
        let index: Int
        let count: Int
        let selected: Bool
    }

    private struct ContentEntry {
        weak var item: SPTabBarItem?
        let key: ContentKey
        var content: SPTabBarContent?
        var automatic: Bool
        var allocatedWidth: CGFloat?
    }

    // 每项最多保存两个输入组合；不保留测量视图，删除项及代理变化立即淘汰。
    private var contentCache: [ObjectIdentifier: [ContentEntry]] = [:]
    private var cachedDelegateIdentity: ObjectIdentifier?
    func measure(
        width: CGFloat,
        environment: SPTabBarContentEnvironment,
        provider: (SPTabBarContentItem, SPTabBarContentContext) -> SPTabBarContent?
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
        if cachedDelegateIdentity != identity {
            contentCache.removeAll()
            cachedDelegateIdentity = identity
        }
        let identities = Set(items.map(ObjectIdentifier.init))
        contentCache = contentCache.filter { identities.contains($0.key) && $0.value.contains { $0.item != nil } }
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
        var entries: [Int: ContentEntry] = [:]
        func state(at index: Int) -> UICellConfigurationState {
            var value = UICellConfigurationState(traitCollection: traitCollection)
            value.isSelected = index == selectedIndex
            value.isDisabled = !items[index].isEnabled
            return value
        }
        func measuringView(for content: SPTabBarContent, at index: Int) -> UIView {
            let view = content.configuration.updated(for: state(at: index)).makeContentView()
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
            if #available(iOS 17, *) {
                view.updateTraitsIfNeeded()
            }
            measuringViews[index] = view
            return view
        }
        var result = items.enumerated().map { index, item -> SPTabBarContent? in
            guard environment.contentStyle == .custom else {
                return nil
            }
            let key = ContentKey(
                width: width,
                direction: direction,
                delegateIdentity: identity,
                index: index,
                count: items.count,
                selected: index == selectedIndex
            )
            if let cached = contentCache[ObjectIdentifier(item)]?.first(where: { $0.item === item && $0.key == key }) {
                entries[index] = cached
                return cached.content
            }
            let context = SPTabBarContentContext(
                index: index,
                itemCount: items.count,
                layoutConfiguration: layoutConfiguration,
                defaultContentLayout: defaultContentLayout,
                state: state(at: index),
                tintColor: tintColor,
                layoutDirection: direction,
                availableWidth: width,
                storedAppearance: SPTabBarAppearance(barAppearance: appearance)
            )
            contentRequests &+= 1
            entries[index] = ContentEntry(item: item, key: key, content: nil, automatic: false)
            guard var content = provider(SPTabBarContentItem(item), context) else {
                return nil
            }
            if let size = content.size {
                guard validContentSize(size) else {
                    return nil
                }
            } else {
                let view = measuringView(for: content, at: index)
                let container = view.superview!
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
                entries[index]?.automatic = true
                content.size = CGSize(width: ceil(constrained.width), height: 0)
            }
            return content
        }
        // 有效自定义项不测量内置回退内容；自动测量失败时按需补齐，并在本次布局内复用。
        var defaultSizes: [Int: CGSize] = [:]
        func defaultSize(at index: Int) -> CGSize {
            if let size = defaultSizes[index] {
                return size
            }
            let size = environment.measuredSize(items[index])
            defaultSizes[index] = size
            return size
        }
        var widths: [CGFloat] = []
        var allocated: [CGFloat] = []
        // 某项测量失败回退后，宽度分配可能改变，需要重新测量其余自动内容的高度。
        while true {
            widths = result.indices.map {
                max(
                    layoutConfiguration.minimumItemWidth,
                    result[$0]?.size?
                        .width ??
                        (defaultSize(at: $0)
                            .width +
                            (defaultContentLayout.contentInsets.leading + defaultContentLayout.contentInsets.trailing))
                )
            }
            allocated = SPTabBarLayout.resolvedWidths(
                widths,
                viewportWidth: width,
                itemSpacing: layoutConfiguration.itemSpacing,
                configuration: layoutConfiguration
            )
            var failed = false
            for index in result.indices where entries[index]?.automatic == true {
                guard let content = result[index] else {
                    continue
                }
                // 配置及最终分配宽度都未改变时，复用该项高度；邻项变宽仍须重新定宽测高。
                if entries[index]?.allocatedWidth == allocated[index] {
                    continue
                }
                let view = measuringViews[index] ?? measuringView(for: content, at: index)
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
                    entries[index]?.automatic = false
                    failed = true
                    continue
                }
                result[index]?.size?.height = ceil(fitted.height)
                entries[index]?.allocatedWidth = allocated[index]
            }
            if !failed {
                break
            }
        }
        guard revision == contentRevision else {
            return nil
        }
        // 只发布完整且仍属于当前版本的结果，回调重入失效时不污染逐项缓存。
        for (index, var entry) in entries {
            entry.content = result[index]
            let identity = ObjectIdentifier(items[index])
            var retained = contentCache[identity, default: []]
                .filter { $0.item === items[index] && $0.key != entry.key }
            retained.insert(entry, at: 0)
            contentCache[identity] = Array(retained.prefix(2))
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
                result[$0]?.size?.height ?? defaultContentLayout.height(for: defaultSize(at: $0).height)
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

    func invalidate(item: SPTabBarItem? = nil, preservingContentCache: Bool = false) {
        contentRevision &+= 1
        candidate = nil
        if let item {
            contentCache[ObjectIdentifier(item)] = nil
        } else if !preservingContentCache {
            contentCache.removeAll()
        }
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
