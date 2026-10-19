import UIKit

/// 字体按 subheadline 的 Dynamic Type 比例缩放；nil 使用系统首选字体。
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
    public enum Layout: Int, Sendable { case automatic, stacked, inline }
    public var layout: Layout = .automatic
    public var normal = SPTabBarItemStateAppearance()
    public var selected = SPTabBarItemStateAppearance(titleColor: nil, iconColor: nil)
    public var disabled = SPTabBarItemStateAppearance(titleColor: .tertiaryLabel, iconColor: .tertiaryLabel)
    public init() {}
}

/// 栏背景复用 UIKit；赋值到标签栏或 Item 时复制，当前实例支持实时修改。
@MainActor
public final class SPTabBarAppearance: UIBarAppearance {
    public override class var supportsSecureCoding: Bool { true }
    public enum SelectionStyle: Int, Sendable { case capsule, underline, none }
    public var selectionStyle: SelectionStyle = .capsule { didSet { changed() } }
    public var selectionColor: UIColor = .tertiarySystemFill { didSet { changed() } }
    public var itemAppearance = SPTabBarItemAppearance() { didSet { changed() } }
    private let bars = NSHashTable<SPTabBar>.weakObjects()
    private let items = NSHashTable<SPTabBarItem>.weakObjects()

    public override var backgroundEffect: UIBlurEffect? { didSet { changed() } }
    public override var backgroundColor: UIColor? { didSet { changed() } }
    public override var backgroundImage: UIImage? { didSet { changed() } }
    public override var backgroundImageContentMode: UIView.ContentMode { didSet { changed() } }
    public override var shadowColor: UIColor? { didSet { changed() } }
    public override var shadowImage: UIImage? { didSet { changed() } }

    public override init(idiom: UIUserInterfaceIdiom) {
        super.init(idiom: idiom)
        configureWithDefaultBackground()
    }

    public override init(barAppearance: UIBarAppearance) {
        super.init(barAppearance: barAppearance)
        if let source = barAppearance as? SPTabBarAppearance {
            selectionStyle = source.selectionStyle
            selectionColor = source.selectionColor
            itemAppearance = source.itemAppearance
        }
    }

    public required init(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = SelectionStyle(rawValue: coder.decodeInteger(forKey: "SP.selectionStyle")) ?? .capsule
        selectionColor = coder.decodeObject(of: UIColor.self, forKey: "SP.selectionColor") ?? .tertiarySystemFill
        itemAppearance.layout = SPTabBarItemAppearance.Layout(rawValue: coder.decodeInteger(forKey: "SP.layout")) ?? .automatic
        itemAppearance.normal = Self.decodeState(coder, key: "normal", fallback: itemAppearance.normal)
        itemAppearance.selected = Self.decodeState(coder, key: "selected", fallback: itemAppearance.selected)
        itemAppearance.disabled = Self.decodeState(coder, key: "disabled", fallback: itemAppearance.disabled)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(selectionStyle.rawValue, forKey: "SP.selectionStyle")
        coder.encode(selectionColor, forKey: "SP.selectionColor")
        coder.encode(itemAppearance.layout.rawValue, forKey: "SP.layout")
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

    internal func attach(_ bar: SPTabBar) { bars.add(bar) }
    internal func detach(_ bar: SPTabBar) { bars.remove(bar) }
    internal func attach(_ item: SPTabBarItem) { items.add(item) }
    internal func detach(_ item: SPTabBarItem) { items.remove(item) }
    private func changed() {
        for bar in bars.allObjects { bar.itemDidChange() }
        for item in items.allObjects { item.appearanceDidChange() }
    }

    private static func encodeState(_ state: SPTabBarItemStateAppearance, coder: NSCoder, key: String) {
        coder.encode(state.font, forKey: key + ".font")
        coder.encode(state.titleColor, forKey: key + ".title")
        coder.encode(state.iconColor, forKey: key + ".icon")
        coder.encode(state.badgeBackgroundColor, forKey: key + ".badgeBackground")
        coder.encode(state.badgeTextColor, forKey: key + ".badgeText")
    }

    private static func decodeState(_ coder: NSCoder, key: String, fallback: SPTabBarItemStateAppearance) -> SPTabBarItemStateAppearance {
        var state = fallback
        state.font = coder.decodeObject(of: UIFont.self, forKey: key + ".font")
        if coder.containsValue(forKey: key + ".title") {
            state.titleColor = coder.decodeObject(of: UIColor.self, forKey: key + ".title")
        }
        if coder.containsValue(forKey: key + ".icon") {
            state.iconColor = coder.decodeObject(of: UIColor.self, forKey: key + ".icon")
        }
        state.badgeBackgroundColor = coder.decodeObject(of: UIColor.self, forKey: key + ".badgeBackground") ?? state.badgeBackgroundColor
        state.badgeTextColor = coder.decodeObject(of: UIColor.self, forKey: key + ".badgeText") ?? state.badgeTextColor
        return state
    }
}
