import XCTest
import UIKit
@testable import StickyPagerKit

/// 固定默认图文夹具；不同测量路径只改变明确指定的输入。
@MainActor
final class SPTabColorFixture {
    let window: SPTestWindow
    let bar: SPTabBar
    let collection: UICollectionView
    let buttons: [UIButton]

    init(colors: Bool, combined: Bool = false) throws {
        window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.showForTesting()
        bar = SPTabBar(frame: CGRect(x: 0, y: 100, width: 360, height: 64))
        bar.semanticContentAttribute = .forceLeftToRight
        bar.overrideUserInterfaceStyle = .light
        bar.layoutConfiguration.itemSizing = .equal
        bar.items = (0 ..< 6).map { SPTabBarItem(title: "标签 \($0)", image: UIImage(systemName: "star")) }
        bar.standardAppearance.itemAppearance.normal.titleColor = .red
        bar.standardAppearance.itemAppearance.normal.iconColor = .red
        bar.standardAppearance.itemAppearance.selected.titleColor = .blue
        bar.standardAppearance.itemAppearance.selected.iconColor = .blue
        if combined {
            bar.visualStyle = .fadeAndStretch
            bar.visualStyle.unselectedScale = 0.94
            bar.selectionAnimationStyle = .spring
        }
        bar.visualStyle.interpolatesDefaultColors = colors
        window.rootViewController!.view.addSubview(bar)
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        collection = try XCTUnwrap(bar.subviews.compactMap { $0 as? UICollectionView }.first)
        XCTAssertEqual(collection.visibleCells.count, 6)
        buttons = try collection.visibleCells.map { cell in
            let root = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" }
                ?? cell.contentView
            return try XCTUnwrap(root.subviews.compactMap { $0 as? UIButton }.first)
        }
    }

    func close() {
        bar.setSelectedIndex(0, animated: false)
        window.closeForTesting()
    }

    func attach(_ diagnostics: SPTabColorDiagnostics?) throws {
        for cell in collection.visibleCells {
            let view = try XCTUnwrap(cell.contentView as? SPTabColorDiagnosing)
            view.colorDiagnostics = diagnostics
        }
    }

    func beginSelection() {
        bar.setSelectedIndex(0, animated: false)
        bar.layoutIfNeeded()
        bar.setSelectedIndex(1, animated: true)
        bar.layoutIfNeeded()
    }

    func frames(_ count: Int, flushButtons: Bool = false) {
        for sample in 1 ... count {
            bar.advanceSelectionAnimation(to: CGFloat(sample) / CGFloat(count))
            bar.layoutIfNeeded()
            if flushButtons {
                buttons.forEach { $0.layoutIfNeeded() }
            }
        }
    }

    func button(at index: Int) throws -> UIButton {
        let cell = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: index, section: 0)))
        let root = cell.contentView.subviews.first { $0.accessibilityIdentifier == "sp.tab.visualHost" }
            ?? cell.contentView
        return try XCTUnwrap(root.subviews.compactMap { $0 as? UIButton }.first)
    }
}
