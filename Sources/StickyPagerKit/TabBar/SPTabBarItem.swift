import UIKit

/// 标签内容。对象身份标识标签；所有属性均在主线程修改并自动刷新宿主。
@MainActor
public final class SPTabBarItem: UIBarItem {
    private var storedTitle: String? = nil
    public override var title: String? {
        get { storedTitle }
        set { storedTitle = newValue; changed() }
    }

    private var storedImage: UIImage? = nil
    public override var image: UIImage? {
        get { storedImage }
        set { storedImage = newValue; changed() }
    }

    public var selectedImage: UIImage? {
        didSet { changed() }
    }

    private var storedIsEnabled: Bool = true
    public override var isEnabled: Bool {
        get { storedIsEnabled }
        set { storedIsEnabled = newValue; changed() }
    }

    /// nil 隐藏、空字符串显示圆点，其余值显示文本。
    public var badgeValue: String? {
        didSet { changed() }
    }

    public var badgeColor: UIColor? {
        didSet { changed() }
    }

    private var storedAccessibilityLabel: String? = nil
    public override var accessibilityLabel: String? {
        get { storedAccessibilityLabel }
        set { storedAccessibilityLabel = newValue; changed() }
    }

    private var storedAccessibilityHint: String? = nil
    public override var accessibilityHint: String? {
        get { storedAccessibilityHint }
        set { storedAccessibilityHint = newValue; changed() }
    }

    private var storedAppearance: SPTabBarAppearance?
    /// 赋值时复制；nil 表示采用宿主标签栏的外观。
    public var standardAppearance: SPTabBarAppearance? {
        get { storedAppearance }
        set {
            storedAppearance?.detach(self)
            storedAppearance = newValue.map { SPTabBarAppearance(barAppearance: $0) }
            storedAppearance?.attach(self)
            changed()
        }
    }

    private let hosts = NSHashTable<SPTabBar>.weakObjects()

    public init(title: String?, image: UIImage? = nil, selectedImage: UIImage? = nil) {
        self.selectedImage = selectedImage
        super.init()
        self.title = title
        self.image = image
    }

    private var storedTag = 0
    public override var tag: Int {
        get { storedTag }
        set { storedTag = newValue }
    }

    private var titleAttributes: [UInt: [NSAttributedString.Key: Any]] = [:]
    public override init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        // UIBarItem 是抽象基类；具体属性及归档由本类实现。
        super.init()
        title = coder.decodeObject(forKey: "SP.title") as? String
        image = coder.decodeObject(forKey: "SP.image") as? UIImage
        isEnabled = coder.containsValue(forKey: "SP.enabled") ? coder.decodeBool(forKey: "SP.enabled") : true
        tag = coder.decodeInteger(forKey: "SP.tag")
        accessibilityLabel = coder.decodeObject(forKey: "SP.accessibilityLabel") as? String
        accessibilityHint = coder.decodeObject(forKey: "SP.accessibilityHint") as? String
        landscapeImagePhone = coder.decodeObject(forKey: "SP.landscape") as? UIImage
        largeContentSizeImage = coder.decodeObject(forKey: "SP.largeImage") as? UIImage
        imageInsets = coder.decodeUIEdgeInsets(forKey: "SP.imageInsets")
        landscapeImagePhoneInsets = coder.decodeUIEdgeInsets(forKey: "SP.landscapeInsets")
        largeContentSizeImageInsets = coder.decodeUIEdgeInsets(forKey: "SP.largeInsets")
        if let attributes = coder.decodeObject(forKey: "SP.titleAttributes") as? [String: [String: Any]] {
            for (key, value) in attributes {
                if let raw = UInt(key) {
                    titleAttributes[raw] = Dictionary(uniqueKeysWithValues: value.map { (
                        NSAttributedString.Key($0.key),
                        $0.value
                    ) })
                }
            }
        }
        selectedImage = coder.decodeObject(forKey: "SP.selectedImage") as? UIImage
        badgeValue = coder.decodeObject(forKey: "SP.badgeValue") as? String
        badgeColor = coder.decodeObject(forKey: "SP.badgeColor") as? UIColor
        standardAppearance = coder.decodeObject(of: SPTabBarAppearance.self, forKey: "SP.appearance")
    }

    public override func encode(with coder: NSCoder) {
        coder.encode(title, forKey: "SP.title")
        coder.encode(image, forKey: "SP.image")
        coder.encode(isEnabled, forKey: "SP.enabled")
        coder.encode(tag, forKey: "SP.tag")
        coder.encode(accessibilityLabel, forKey: "SP.accessibilityLabel")
        coder.encode(accessibilityHint, forKey: "SP.accessibilityHint")
        coder.encode(landscapeImagePhone, forKey: "SP.landscape")
        coder.encode(largeContentSizeImage, forKey: "SP.largeImage")
        coder.encode(imageInsets, forKey: "SP.imageInsets")
        coder.encode(landscapeImagePhoneInsets, forKey: "SP.landscapeInsets")
        coder.encode(largeContentSizeImageInsets, forKey: "SP.largeInsets")
        let attributes = Dictionary(uniqueKeysWithValues: titleAttributes.map { key, value in
            (String(key), Dictionary(uniqueKeysWithValues: value.map { ($0.key.rawValue, $0.value) }))
        })
        coder.encode(attributes, forKey: "SP.titleAttributes")
        coder.encode(selectedImage, forKey: "SP.selectedImage")
        coder.encode(badgeValue, forKey: "SP.badgeValue")
        coder.encode(badgeColor, forKey: "SP.badgeColor")
        coder.encode(standardAppearance, forKey: "SP.appearance")
    }

    private var storedLandscapeImagePhone: UIImage? = nil
    public override var landscapeImagePhone: UIImage? {
        get { storedLandscapeImagePhone }
        set { storedLandscapeImagePhone = newValue; changed() }
    }

    private var storedImageInsets: UIEdgeInsets = .zero
    public override var imageInsets: UIEdgeInsets {
        get { storedImageInsets }
        set { storedImageInsets = newValue; changed() }
    }

    private var storedLandscapeImagePhoneInsets: UIEdgeInsets = .zero
    public override var landscapeImagePhoneInsets: UIEdgeInsets {
        get { storedLandscapeImagePhoneInsets }
        set { storedLandscapeImagePhoneInsets = newValue; changed() }
    }

    private var storedLargeContentSizeImage: UIImage? = nil
    public override var largeContentSizeImage: UIImage? {
        get { storedLargeContentSizeImage }
        set { storedLargeContentSizeImage = newValue; changed() }
    }

    private var storedLargeContentSizeImageInsets: UIEdgeInsets = .zero
    public override var largeContentSizeImageInsets: UIEdgeInsets {
        get { storedLargeContentSizeImageInsets }
        set { storedLargeContentSizeImageInsets = newValue; changed() }
    }

    /// 单项文字属性优先于栏级状态外观；支持字体、前景色和阴影。
    public override func setTitleTextAttributes(
        _ attributes: [NSAttributedString.Key: Any]?,
        for state: UIControl.State
    ) {
        titleAttributes[state.rawValue] = attributes
        changed()
    }

    public override func titleTextAttributes(for state: UIControl.State) -> [NSAttributedString.Key: Any]? {
        titleAttributes[state.rawValue]
    }

    internal func attach(_ bar: SPTabBar) {
        hosts.add(bar)
    }

    internal func detach(_ bar: SPTabBar) {
        hosts.remove(bar)
    }

    internal func appearanceDidChange() {
        changed()
    }

    private func changed() {
        for bar in hosts.allObjects {
            bar.itemDidChange()
        }
    }
}

@MainActor
public protocol SPTabBarDelegate: AnyObject {
    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem)
}

public extension SPTabBarDelegate {
    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool {
        true
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {}
}
