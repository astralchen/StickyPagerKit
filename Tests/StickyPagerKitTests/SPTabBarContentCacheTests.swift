import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarContentCacheTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 600, height: 844))
        window.rootViewController = UIViewController()
    }

    override func tearDown() async throws {
        window.closeForTesting()
        window = nil
    }

    private func mount(_ source: CacheContentSource) -> SPTabBar {
        window.showForTesting()
        let bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 320, height: 80))
        bar.items = (0 ..< 3).map { SPTabBarItem(title: "标签 \($0)") }
        bar.layoutConfiguration.contentInsets = .zero
        bar.layoutConfiguration.itemSpacing = 0
        bar.contentDelegate = source
        bar.contentStyle = .custom
        window.rootViewController!.view.addSubview(bar)
        bar.layoutIfNeeded()
        source.requests.removeAll()
        source.fittings.removeAll()
        return bar
    }

    func testItemChangesUseOneSnapshotAndExternalDataRequiresReload() {
        let source = CacheContentSource()
        let bar = mount(source)
        let first = bar.items[0]
        first.title = "新的标题"
        bar.layoutIfNeeded()
        XCTAssertEqual(source.requests.map(\.identifier), [ObjectIdentifier(first)])
        let snapshot = source.requests[0]
        first.tag = 123
        XCTAssertEqual(source.requests.last?.tag, 123)
        XCTAssertEqual(snapshot.tag, 0)
        XCTAssertEqual(snapshot.title, "新的标题")
        source.requests.removeAll()
        source.extraWidth = 30
        bar.setNeedsLayout()
        bar.layoutIfNeeded()
        XCTAssertTrue(source.requests.isEmpty)
        bar.reloadContent()
        bar.layoutIfNeeded()
        XCTAssertEqual(source.requests.count, 3)
    }

    func testSelectionReusesOtherItemsAndSelectedAppearanceInvalidatesAll() {
        let source = CacheContentSource()
        let bar = mount(source)
        bar.setSelectedIndex(0, animated: false)
        XCTAssertEqual(source.requests.map(\.identifier), [ObjectIdentifier(bar.items[0])])
        source.requests.removeAll()
        bar.setSelectedIndex(1, animated: false)
        // 第一项未选中配置已缓存，第三项从未改变；只需获取第二项选中配置。
        XCTAssertEqual(source.requests.map(\.identifier), [ObjectIdentifier(bar.items[1])])
        source.requests.removeAll()
        let appearance = SPTabBarAppearance()
        bar.items[1].standardAppearance = appearance
        XCTAssertEqual(source.requests.count, 3)
        source.requests.removeAll()
        bar.items[1].standardAppearance = nil
        XCTAssertEqual(source.requests.count, 3, "移除选中项外观也改变整栏环境")
    }

    func testSnapshotAppearanceAndAttributesCannotMutateItem() throws {
        let source = CacheContentSource()
        let bar = mount(source)
        let item = bar.items[0]
        item.standardAppearance = SPTabBarAppearance()
        item.standardAppearance!.backgroundColor = .red
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        item.setTitleTextAttributes([.shadow: shadow], for: .normal)
        let snapshot = try XCTUnwrap(source.requests.last)
        snapshot.standardAppearance?.backgroundColor = .blue
        XCTAssertEqual(snapshot.standardAppearance?.backgroundColor, .red)
        XCTAssertEqual(item.standardAppearance?.backgroundColor, .red)
        let copied = try XCTUnwrap(snapshot.titleTextAttributes(for: .normal)?[.shadow] as? NSShadow)
        copied.shadowBlurRadius = 20
        XCTAssertEqual((snapshot.titleTextAttributes(for: .normal)?[.shadow] as? NSShadow)?.shadowBlurRadius, 5)
        let context = try XCTUnwrap(source.lastContext)
        context.appearance.backgroundColor = .green
        XCTAssertNotEqual(context.appearance.backgroundColor, .green)
    }

    func testAutomaticHeightRefitsWhenNeighborChangesAllocatedWidth() {
        let source = CacheContentSource()
        source.automatic = true
        let bar = mount(source)
        bar.frame.size.width = 400
        bar.layoutConfiguration.itemSizing = .balanced
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.sizeThatFits(CGSize(width: 400, height: 0)).height, 40, accuracy: 0.01)
        source.requests.removeAll()
        source.fittings.removeAll()
        bar.items[0].tag = 220
        bar.layoutIfNeeded()
        XCTAssertEqual(source.requests.map(\.identifier), [ObjectIdentifier(bar.items[0])])
        XCTAssertTrue(source.fittings.contains { $0.0 == 1 && abs($0.1 - 90) < 0.01 }, "邻项配置复用后仍应按新宽度测高")
        let size = bar.sizeThatFits(CGSize(width: 400, height: 0))
        XCTAssertEqual(size.height, 60, accuracy: 0.01)
        source.fittings.removeAll()
        bar.items[0].accessibilityHint = "不影响宽度"
        bar.layoutIfNeeded()
        XCTAssertFalse(source.fittings.contains { $0.0 == 1 || $0.0 == 2 }, "最终分配宽度未变的邻项复用测量")
    }

    func testReorderUsesNewIndexAndRemovalDoesNotRetainItem() {
        let source = CacheContentSource()
        let bar = mount(source)
        let identities = bar.items.map(ObjectIdentifier.init)
        bar.items = [bar.items[1], bar.items[0], bar.items[2]]
        bar.layoutIfNeeded()
        XCTAssertEqual(source.requests.map(\.identifier), [identities[1], identities[0]])
        XCTAssertEqual(source.indices.suffix(2), [0, 1])
        weak var removed: SPTabBarItem?
        autoreleasepool {
            let item = bar.items[0]
            removed = item
            bar.items.removeFirst()
            bar.layoutIfNeeded()
        }
        XCTAssertNil(removed)
    }

    func testPerItemCacheIsBoundedAndCandidateDoesNotReplaceAppliedContents() {
        let resolver = SPTabBarContentResolver()
        let items = [SPTabBarItem(title: "A")]
        let environment = SPTabBarContentEnvironment(
            items: items,
            selectedIndex: nil,
            contentStyle: .custom,
            layoutConfiguration: SPTabBarLayoutConfiguration(),
            defaultContentLayout: SPTabBarDefaultContentLayout(),
            appearance: SPTabBarAppearance(),
            traitCollection: UITraitCollection(),
            tintColor: .blue,
            contentDirection: .leftToRight,
            delegateIdentity: nil
        )
        var requests = 0
        func measure(_ width: CGFloat) -> SPTabBarContentResolver.Measurement? {
            resolver.measure(width: width, environment: environment) { _, context in
                requests += 1
                return SPTabBarContent(
                    configuration: UIListContentConfiguration.cell(),
                    size: CGSize(width: context.availableWidth, height: 50)
                )
            }
        }
        let first = measure(200)!
        resolver.apply(first)
        _ = measure(300)
        _ = measure(400)
        _ = measure(500)
        XCTAssertEqual(resolver.applied?.width, first.width)
        XCTAssertEqual(resolver.content(at: 0)?.size?.width, first.width)
        let before = requests
        resolver.invalidate(preservingContentCache: true)
        _ = measure(300)
        XCTAssertEqual(requests, before + 1, "逐项仅保留最近两个输入，不无限累积候选宽度")
        resolver.invalidate()
        _ = measure(500)
        XCTAssertEqual(requests, before + 2)
    }
}

@MainActor
private final class CacheContentSource: SPTabBarContentDelegate {
    var requests: [SPTabBarContentItem] = []
    var indices: [Int] = []
    var fittings: [(Int, CGFloat)] = []
    var lastContext: SPTabBarContentContext?
    var extraWidth: CGFloat = 0
    var automatic = false
    func content(for item: SPTabBarContentItem, context: SPTabBarContentContext) -> SPTabBarContent? {
        requests.append(item)
        indices.append(context.index)
        lastContext = context
        let width = CGFloat(item.tag == 0 ? 80 : item.tag) + extraWidth
        if automatic {
            return SPTabBarContent(configuration: CacheAutomaticConfiguration(
                width: width,
                index: context.index,
                source: self
            ))
        }
        var configuration = UIListContentConfiguration.cell()
        configuration.text = item.title
        return SPTabBarContent(configuration: configuration, size: CGSize(width: width, height: 60))
    }
}

private struct CacheAutomaticConfiguration: UIContentConfiguration {
    let width: CGFloat
    let index: Int
    weak var source: CacheContentSource?
    func makeContentView() -> UIView & UIContentView {
        CacheAutomaticView(self)
    }

    func updated(for state: UIConfigurationState) -> Self {
        self
    }
}

@MainActor
private final class CacheAutomaticView: UIView, UIContentView {
    var configuration: any UIContentConfiguration
    init(_ value: CacheAutomaticConfiguration) {
        configuration = value
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: (configuration as! CacheAutomaticConfiguration).width, height: 20)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let value = configuration as! CacheAutomaticConfiguration
        let width = horizontalFittingPriority == .required ? targetSize.width : value.width
        value.source?.fittings.append((value.index, width))
        return CGSize(width: width, height: ceil(200 / max(1, width)) * 20)
    }
}
