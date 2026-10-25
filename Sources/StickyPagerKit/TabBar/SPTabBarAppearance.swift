import UIKit

/// 字体按 subheadline 的 Dynamic Type 比例缩放；nil 使用系统首选字体，选中态默认为 semibold。
@MainActor
public struct SPTabBarItemStateAppearance {
    public var font: UIFont?
    /// nil 按状态解析：选中跟随栏的 tintColor，普通与禁用使用系统标签色。
    public var titleColor: UIColor?
    public var iconColor: UIColor?
    public var badgeBackgroundColor: UIColor = .systemRed
    public var badgeTextColor: UIColor = .white
    public init(titleColor: UIColor? = .secondaryLabel, iconColor: UIColor? = .secondaryLabel) {
        self.titleColor = titleColor
        self.iconColor = iconColor
    }
}

@MainActor
public struct SPTabBarItemAppearance {
    public var normal = SPTabBarItemStateAppearance()
    public var selected = SPTabBarItemStateAppearance(titleColor: nil, iconColor: nil)
    public var disabled = SPTabBarItemStateAppearance(titleColor: .tertiaryLabel, iconColor: .tertiaryLabel)
    public init() {}
}

/// 栏背景复用 UIKit；赋值到标签栏或 Item 时复制，当前实例支持实时修改。
@MainActor
public final class SPTabBarAppearance: UIBarAppearance {
    public override class var supportsSecureCoding: Bool {
        true
    }

    /// nil 使用所选样式的默认颜色：胶囊使用 tertiarySystemFill，线条跟随栏 tintColor，自定义跟随选中文字颜色。
    public var indicatorColor: UIColor? {
        didSet {
            for bar in bars.allObjects {
                bar.indicatorAppearanceDidChange()
            }
            for item in items.allObjects {
                item.indicatorAppearanceDidChange()
            }
        }
    }

    /// nil 使用所选样式的默认布局；显式值完整覆盖预设，切换样式不会清除覆盖。
    /// 仅影响指示器，不参与内容测量；赋值、复制及归档保留值语义。
    public var indicatorLayout: SPTabBarIndicatorLayout? {
        didSet { indicatorChanged() }
    }

    public var itemAppearance = SPTabBarItemAppearance() {
        didSet { changed() }
    }

    private let bars = NSHashTable<SPTabBar>.weakObjects()
    private let items = NSHashTable<SPTabBarItem>.weakObjects()

    public override var backgroundEffect: UIBlurEffect? {
        didSet { changed() }
    }

    public override var backgroundColor: UIColor? {
        didSet { changed() }
    }

    public override var backgroundImage: UIImage? {
        didSet { changed() }
    }

    public override var backgroundImageContentMode: UIView.ContentMode {
        didSet { changed() }
    }

    public override var shadowColor: UIColor? {
        didSet { changed() }
    }

    public override var shadowImage: UIImage? {
        didSet { changed() }
    }

    public override init(idiom: UIUserInterfaceIdiom) {
        super.init(idiom: idiom)
        configureWithDefaultBackground()
    }

    public override init(barAppearance: UIBarAppearance) {
        super.init(barAppearance: barAppearance)
        if let source = barAppearance as? SPTabBarAppearance {
            indicatorColor = source.indicatorColor
            indicatorLayout = source.indicatorLayout
            itemAppearance = source.itemAppearance
        }
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
        if coder.containsValue(forKey: "SP.indicatorColor") {
            indicatorColor = coder.decodeObject(of: UIColor.self, forKey: "SP.indicatorColor")
        }
        if coder.containsValue(forKey: "SP.indicatorLayout"),
           let data = coder.decodeObject(of: NSData.self, forKey: "SP.indicatorLayout") as Data? {
            let decoder = JSONDecoder()
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "Infinity",
                negativeInfinity: "-Infinity",
                nan: "NaN"
            )
            indicatorLayout = try? decoder.decode(SPTabBarIndicatorLayout.self, from: data)
        }
        itemAppearance.normal = Self.decodeState(coder, key: "normal", fallback: itemAppearance.normal)
        itemAppearance.selected = Self.decodeState(coder, key: "selected", fallback: itemAppearance.selected)
        itemAppearance.disabled = Self.decodeState(coder, key: "disabled", fallback: itemAppearance.disabled)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(indicatorColor, forKey: "SP.indicatorColor")
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        if let indicatorLayout, let data = try? encoder.encode(indicatorLayout) {
            coder.encode(data as NSData, forKey: "SP.indicatorLayout")
        }
        Self.encodeState(itemAppearance.normal, coder: coder, key: "normal")
        Self.encodeState(itemAppearance.selected, coder: coder, key: "selected")
        Self.encodeState(itemAppearance.disabled, coder: coder, key: "disabled")
    }

    public override func copy(with zone: NSZone? = nil) -> Any {
        SPTabBarAppearance(barAppearance: self)
    }

    public override func configureWithDefaultBackground() {
        super.configureWithDefaultBackground()
        backgroundEffect = UIBlurEffect(style: .systemMaterial)
        backgroundColor = .clear
    }

    public override func configureWithOpaqueBackground() {
        super.configureWithOpaqueBackground()
        changed()
    }

    public override func configureWithTransparentBackground() {
        super.configureWithTransparentBackground()
        changed()
    }

    internal func attach(_ bar: SPTabBar) {
        bars.add(bar)
    }

    internal func detach(_ bar: SPTabBar) {
        bars.remove(bar)
    }

    internal func attach(_ item: SPTabBarItem) {
        items.add(item)
    }

    internal func detach(_ item: SPTabBarItem) {
        items.remove(item)
    }

    private func indicatorChanged() {
        for bar in bars.allObjects {
            bar.reloadIndicator()
        }
        for item in items.allObjects {
            item.indicatorDidChange()
        }
    }

    private func changed() {
        for bar in bars.allObjects {
            bar.itemDidChange()
        }
        for item in items.allObjects {
            item.appearanceDidChange()
        }
    }

    private static func encodeState(_ state: SPTabBarItemStateAppearance, coder: NSCoder, key: String) {
        coder.encode(state.font, forKey: key + ".font")
        coder.encode(state.titleColor, forKey: key + ".title")
        coder.encode(state.iconColor, forKey: key + ".icon")
        coder.encode(state.badgeBackgroundColor, forKey: key + ".badgeBackground")
        coder.encode(state.badgeTextColor, forKey: key + ".badgeText")
    }

    private static func decodeState(
        _ coder: NSCoder,
        key: String,
        fallback: SPTabBarItemStateAppearance
    ) -> SPTabBarItemStateAppearance {
        var state = fallback
        state.font = coder.decodeObject(of: UIFont.self, forKey: key + ".font")
        if coder.containsValue(forKey: key + ".title") {
            state.titleColor = coder.decodeObject(of: UIColor.self, forKey: key + ".title")
        }
        if coder.containsValue(forKey: key + ".icon") {
            state.iconColor = coder.decodeObject(of: UIColor.self, forKey: key + ".icon")
        }
        state.badgeBackgroundColor = coder.decodeObject(of: UIColor.self, forKey: key + ".badgeBackground") ?? state
            .badgeBackgroundColor
        state.badgeTextColor = coder.decodeObject(of: UIColor.self, forKey: key + ".badgeText") ?? state.badgeTextColor
        return state
    }
}
