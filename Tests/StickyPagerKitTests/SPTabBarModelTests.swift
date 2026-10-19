import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarModelTests: XCTestCase {
    private var window: UIWindow!
    override func setUp() async throws {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }
    override func tearDown() async throws {
        window.isHidden = true
        window.rootViewController = nil
        window = nil
    }
    private func mount(_ items: [SPTabBarItem]) -> SPTabBar {
        let bar = SPTabBar()
        bar.items = items
        bar.frame = CGRect(x: 0, y: 100, width: 320, height: bar.sizeThatFits(.zero).height)
        window.rootViewController!.view.addSubview(bar)
        bar.layoutIfNeeded()
        return bar
    }
    private func collection(_ bar: SPTabBar) -> UICollectionView {
        bar.subviews.compactMap { $0 as? UICollectionView }.first!
    }
    private func button(_ bar: SPTabBar, _ index: Int = 0) -> UIButton {
        bar.layoutIfNeeded()
        let collection = collection(bar)
        collection.layoutIfNeeded()
        return collection.cellForItem(at: IndexPath(item: index, section: 0))!.contentView.subviews.compactMap { $0 as? UIButton }.first!
    }

    func testDefaultColorsFollowTintAndRespectExplicitOverrides() {
        let selected = SPTabBarItem(title: "选中", image: UIImage(systemName: "star"))
        let normal = SPTabBarItem(title: "普通", image: UIImage(systemName: "star"))
        let disabled = SPTabBarItem(title: "禁用")
        disabled.isEnabled = false
        let host = window.rootViewController!.view!
        host.tintColor = .systemGreen
        let bar = mount([selected, normal, disabled])
        bar.selectedItem = selected

        func assertColor(_ index: Int, _ expected: UIColor, file: StaticString = #filePath, line: UInt = #line) {
            let tab = button(bar, index)
            tab.layoutIfNeeded()
            XCTAssertEqual(tab.titleLabel?.textColor.resolvedColor(with: bar.traitCollection), expected.resolvedColor(with: bar.traitCollection), file: file, line: line)
            XCTAssertEqual(tab.configuration?.baseForegroundColor, expected, file: file, line: line)
        }
        for style: UIUserInterfaceStyle in [.light, .dark] {
            window.overrideUserInterfaceStyle = style
            host.layoutIfNeeded()
            assertColor(0, .systemGreen)
            assertColor(1, .secondaryLabel)
            // UIButton 对禁用图标还会应用系统的 disabled 配色变换。
            XCTAssertEqual(button(bar, 2).configuration?.baseForegroundColor, .tertiaryLabel)
        }
        host.tintColor = .systemOrange
        assertColor(0, .systemOrange)
        bar.tintColor = .systemPurple
        assertColor(0, .systemPurple)
        bar.standardAppearance.itemAppearance.selected.titleColor = .systemRed
        bar.standardAppearance.itemAppearance.selected.iconColor = .systemRed
        bar.tintColor = .systemBlue
        assertColor(0, .systemRed)
        selected.setTitleTextAttributes([.foregroundColor: UIColor.systemBrown], for: .selected)
        button(bar).layoutIfNeeded()
        XCTAssertEqual(button(bar).titleLabel?.textColor, .systemBrown)
        selected.setTitleTextAttributes(nil, for: .selected)
        bar.standardAppearance.itemAppearance.selected.titleColor = nil
        bar.standardAppearance.itemAppearance.selected.iconColor = nil
        assertColor(0, .systemBlue)
        bar.selectedItem = normal
        assertColor(0, .secondaryLabel)
        assertColor(1, .systemBlue)
    }

    func testAutomaticColorsSurviveAppearanceCopyAndSecureArchive() throws {
        let appearance = SPTabBarAppearance()
        appearance.itemAppearance.normal.titleColor = nil
        appearance.itemAppearance.normal.iconColor = nil
        let copy = try XCTUnwrap(appearance.copy() as? SPTabBarAppearance)
        let data = try NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        XCTAssertNil(decoded.itemAppearance.normal.titleColor)
        XCTAssertNil(decoded.itemAppearance.normal.iconColor)
        XCTAssertNil(decoded.itemAppearance.selected.titleColor)
        XCTAssertNil(decoded.itemAppearance.selected.iconColor)
        let bar = mount([SPTabBarItem(title: "自动颜色")])
        bar.standardAppearance = decoded
        bar.selectedItem = bar.items[0]
        bar.tintColor = .systemTeal
        button(bar).layoutIfNeeded()
        XCTAssertEqual(button(bar).titleLabel?.textColor, .systemTeal)
    }

    func testUIBarItemPropertiesUpdateRenderingThroughBaseReference() {
        let item = SPTabBarItem(title: nil)
        let base: UIBarItem = item
        let bar = mount([item])
        base.title = "基类标题"
        base.tag = 42
        base.image = UIImage(systemName: "star")
        base.setTitleTextAttributes([.foregroundColor: UIColor.systemPurple, .font: UIFont.systemFont(ofSize: 23)], for: .normal)
        bar.layoutIfNeeded()
        XCTAssertEqual(button(bar).configuration?.title, "基类标题")
        XCTAssertEqual(item.tag, 42)
        XCTAssertNotNil(button(bar).configuration?.image)
        XCTAssertGreaterThanOrEqual(button(bar).titleLabel!.font.pointSize, 23)
        base.isEnabled = false
        XCTAssertFalse(button(bar).isEnabled)
        base.title = nil
        XCTAssertNil(button(bar).configuration?.title)
    }

    func testBarAppearanceCopiesAndSecureArchivePreserveCustomFields() throws {
        let appearance = SPTabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemPink
        appearance.selectionStyle = .underline
        appearance.itemAppearance.layout = .inline
        appearance.itemAppearance.selected.font = .systemFont(ofSize: 25)
        appearance.itemAppearance.disabled.badgeTextColor = .systemGreen
        let bar = mount([SPTabBarItem(title: "A")])
        bar.standardAppearance = appearance
        appearance.selectionStyle = .none
        XCTAssertEqual(bar.standardAppearance.selectionStyle, .underline)
        let copy = try XCTUnwrap(bar.standardAppearance.copy() as? SPTabBarAppearance)
        copy.itemAppearance.selected.font = .systemFont(ofSize: 40)
        XCTAssertEqual(bar.standardAppearance.itemAppearance.selected.font?.pointSize, 25)
        let data = try NSKeyedArchiver.archivedData(withRootObject: bar.standardAppearance, requiringSecureCoding: true)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: SPTabBarAppearance.self, from: data))
        XCTAssertEqual(decoded.selectionStyle, .underline)
        XCTAssertEqual(decoded.itemAppearance.layout, .inline)
        XCTAssertEqual(decoded.itemAppearance.selected.font?.pointSize, 25)
        XCTAssertEqual(decoded.backgroundColor, .systemPink)
        XCTAssertEqual(decoded.itemAppearance.disabled.badgeTextColor, .systemGreen)
        let native = UINavigationBarAppearance()
        native.configureWithTransparentBackground()
        native.backgroundColor = .systemOrange
        let imported = SPTabBarAppearance(barAppearance: native)
        XCTAssertEqual(imported.backgroundColor, .systemOrange)
        XCTAssertNil(imported.backgroundEffect)
    }

    func testAppearanceGetterUpdatesLiveAndItemAssignmentCopies() {
        let item = SPTabBarItem(title: "A")
        let bar = mount([item])
        bar.selectedItem = item
        let source = SPTabBarAppearance()
        item.standardAppearance = source
        source.selectionStyle = .none
        XCTAssertEqual(item.standardAppearance?.selectionStyle, .capsule)
        item.standardAppearance?.selectionStyle = .none
        let indicator = collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
        XCTAssertTrue(indicator.isHidden)
        item.standardAppearance = nil
        bar.standardAppearance.selectionStyle = .underline
        bar.layoutIfNeeded()
        XCTAssertFalse(indicator.isHidden)
        XCTAssertEqual(indicator.bounds.height, 3)
        bar.standardAppearance.configureWithTransparentBackground()
        let material = bar.subviews.compactMap { $0 as? UIVisualEffectView }.first!
        XCTAssertNil(material.effect)
    }

    func testItemArchivePreservesInheritedAndCustomProperties() throws {
        let item = SPTabBarItem(title: "归档", image: UIImage(systemName: "star"), selectedImage: UIImage(systemName: "star.fill"))
        item.tag = 73
        item.isEnabled = false
        item.badgeValue = "8"
        item.imageInsets = UIEdgeInsets(top: 1, left: 2, bottom: 3, right: 4)
        item.setTitleTextAttributes([.foregroundColor: UIColor.systemBlue], for: .selected)
        item.standardAppearance = SPTabBarAppearance()
        item.standardAppearance?.selectionStyle = .underline
        let data = try NSKeyedArchiver.archivedData(withRootObject: item, requiringSecureCoding: false)
        let decoded = try XCTUnwrap(NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SPTabBarItem)
        XCTAssertEqual(decoded.title, "归档")
        XCTAssertEqual(decoded.tag, 73)
        XCTAssertFalse(decoded.isEnabled)
        XCTAssertEqual(decoded.badgeValue, "8")
        XCTAssertEqual(decoded.imageInsets, item.imageInsets)
        XCTAssertNotNil(decoded.image)
        XCTAssertNotNil(decoded.selectedImage)
        XCTAssertEqual(decoded.standardAppearance?.selectionStyle, .underline)
        XCTAssertEqual(decoded.titleTextAttributes(for: .selected)?[.foregroundColor] as? UIColor, .systemBlue)
    }

    func testAutomaticLayoutTraitsAndLargeBadgeStayInsideCell() {
        let item = SPTabBarItem(title: "图文", image: UIImage(systemName: "star"))
        item.badgeValue = "99+"
        let host = window.rootViewController!
        let child = UIViewController()
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        let bar = mount([item])
        child.view.addSubview(bar)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            child.overrideUserInterfaceStyle = style
            for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
                host.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
                    UITraitCollection(verticalSizeClass: .regular), UITraitCollection(preferredContentSizeCategory: category)
                ]), forChild: child)
                host.view.layoutIfNeeded()
                child.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
                let stackedHeight = bar.sizeThatFits(.zero).height
                bar.frame.size.height = stackedHeight
                bar.layoutIfNeeded()
                let tab = button(bar)
                tab.layoutIfNeeded()
                XCTAssertEqual(tab.configuration?.imagePlacement, .top)
                XCTAssertGreaterThanOrEqual(tab.frame.height, tab.titleLabel!.font.lineHeight + 24 + 4)
                host.setOverrideTraitCollection(UITraitCollection(traitsFrom: [
                    UITraitCollection(verticalSizeClass: .compact), UITraitCollection(preferredContentSizeCategory: category)
                ]), forChild: child)
                host.view.layoutIfNeeded()
                child.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
                XCTAssertLessThan(bar.sizeThatFits(.zero).height, stackedHeight)
                XCTAssertEqual(button(bar).configuration?.imagePlacement, .leading)
            }
        }
    }

    func testIdentityReorderRemovalAndInvalidInput() {
        let a = SPTabBarItem(title: "相同"), b = SPTabBarItem(title: "相同")
        let bar = mount([a, b])
        bar.selectedItem = a
        bar.items = [b, a]
        XCTAssertEqual(bar.selectedIndex, 1)
        bar.items = [a, a]
        XCTAssertTrue(bar.items[0] === b)
        bar.selectedItem = SPTabBarItem(title: "外部")
        XCTAssertTrue(bar.selectedItem === a)
        bar.items = [b]
        XCTAssertNil(bar.selectedItem)
    }

    func testLiveUpdatesMultipleHostsAndReleasedHost() {
        let item = SPTabBarItem(title: "旧标题")
        let first = mount([item]), second = mount([item])
        item.title = "新的长标题"
        item.badgeValue = "99"
        XCTAssertEqual(button(first).configuration?.title, item.title)
        XCTAssertEqual(button(second).accessibilityValue, "99")
        first.items = []
        item.title = "继续更新"
        XCTAssertTrue(first.items.isEmpty)
        XCTAssertEqual(button(second).configuration?.title, "继续更新")
        weak var released: SPTabBar?
        autoreleasepool {
            let temporary = mount([item])
            released = temporary
            temporary.removeFromSuperview()
        }
        XCTAssertNil(released)
        item.badgeValue = nil
        XCTAssertNil(button(second).accessibilityValue)
    }

    func testSelectionDelegateDisabledAndProgrammaticSemantics() {
        let a = SPTabBarItem(title: "A"), b = SPTabBarItem(title: "B")
        let bar = mount([a, b]), spy = SelectionSpy()
        bar.delegate = spy
        bar.requestSelection(of: a)
        bar.requestSelection(of: a)
        XCTAssertEqual(spy.selected.count, 2)
        b.isEnabled = false
        bar.requestSelection(of: b)
        XCTAssertTrue(bar.selectedItem === a)
        XCTAssertTrue(button(bar, 1).accessibilityTraits.contains(.notEnabled))
        bar.selectedItem = b
        XCTAssertTrue(bar.selectedItem === b)
        XCTAssertEqual(spy.selected.count, 2)
        spy.allowed = false
        bar.requestSelection(of: a)
        XCTAssertTrue(bar.selectedItem === b)
    }

    func testCoordinatorCommitCancellationAndProgrammaticSupersession() {
        let a = SPTabBarItem(title: "A"), b = SPTabBarItem(title: "B")
        let bar = mount([a, b]), spy = SelectionSpy()
        bar.delegate = spy
        bar.selectedItem = a
        bar.selectionRequest = { [weak bar] in bar?.beginUserSelection($0) }
        bar.requestSelection(of: b)
        XCTAssertTrue(bar.selectedItem === a)
        XCTAssertTrue(spy.selected.isEmpty)
        bar.synchronizeSelection(b, animated: false)
        bar.completeUserSelection()
        bar.completeUserSelection()
        XCTAssertEqual(spy.selected.count, 1)
        bar.requestSelection(of: a)
        bar.cancelUserSelection()
        bar.synchronizeSelection(a, animated: false)
        bar.completeUserSelection()
        XCTAssertEqual(spy.selected.count, 1)
        bar.requestSelection(of: b)
        bar.selectedItem = b
        bar.completeUserSelection()
        XCTAssertEqual(spy.selected.count, 1)
    }

    func testAppearanceOverrideAndStableSelectedMetrics() {
        let item = SPTabBarItem(title: "标题", image: UIImage(systemName: "star"), selectedImage: UIImage(systemName: "star.fill"))
        let bar = mount([item, SPTabBarItem(title: "第二项")])
        bar.standardAppearance.itemAppearance.selected.font = .systemFont(ofSize: 28)
        bar.layoutIfNeeded()
        let before = collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame
        bar.selectedItem = item
        bar.layoutIfNeeded()
        XCTAssertEqual(before, collection(bar).collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.frame)
        let appearance = SPTabBarAppearance()
        appearance.selectionStyle = .none
        item.standardAppearance = appearance
        bar.layoutIfNeeded()
        let indicator = collection(bar).subviews.first { $0.accessibilityIdentifier == "sp.tabBar.selection" }!
        XCTAssertTrue(indicator.isHidden)
        item.standardAppearance = nil
        XCTAssertFalse(indicator.isHidden)
    }

    func testLayoutVariantsAndBadgeGeometry() {
        for rtl in [false, true] {
            let item = SPTabBarItem(title: "图文", image: UIImage(systemName: "star"))
            let bar = mount([item])
            bar.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            bar.standardAppearance.itemAppearance.layout = .stacked
            let stackedHeight = bar.sizeThatFits(.zero).height
            bar.standardAppearance.itemAppearance.layout = .inline
            XCTAssertGreaterThan(stackedHeight, bar.sizeThatFits(.zero).height)
            for badge: String? in [nil, "", "99+"] {
                item.badgeValue = badge
                bar.layoutIfNeeded()
                let collection = collection(bar)
                let cell = collection.cellForItem(at: IndexPath(item: 0, section: 0))!
                cell.layoutIfNeeded()
                let label = cell.contentView.subviews.compactMap { $0 as? UILabel }.first!
                XCTAssertEqual(label.isHidden, badge == nil)
                XCTAssertTrue(cell.bounds.contains(label.frame))
                XCTAssertGreaterThanOrEqual(button(bar).bounds.width, 44)
                XCTAssertGreaterThanOrEqual(button(bar).bounds.height, 44)
            }
            bar.removeFromSuperview()
        }
    }
}

@MainActor
final class SelectionSpy: SPTabBarDelegate {
    var allowed = true
    var selected: [SPTabBarItem] = []
    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool { allowed }
    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) { selected.append(item) }
}
