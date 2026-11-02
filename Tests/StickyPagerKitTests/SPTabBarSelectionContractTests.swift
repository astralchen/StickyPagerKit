import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarSelectionContractTests: XCTestCase {
    func testShouldSelectReplacementInvalidatesOriginalRequest() {
        let a = SPTabBarItem(title: "甲"), b = SPTabBarItem(title: "乙")
        let bar = SPTabBar(), delegate = ReentrantSelectionDelegate()
        bar.items = [a, b]
        bar.selectedItem = a
        bar.delegate = delegate
        delegate.shouldSelect = { bar, _ in
            bar.items = [b, a]
            bar.selectedItem = a
            return true
        }
        bar.requestSelection(of: b)
        XCTAssertTrue(bar.selectedItem === a)
        XCTAssertEqual(bar.selectedIndex, 1)
        XCTAssertTrue(delegate.selected.isEmpty)
    }

    func testNestedShouldSelectRequestSupersedesOuterRequest() {
        let a = SPTabBarItem(title: "甲"), b = SPTabBarItem(title: "乙")
        let bar = SPTabBar(), delegate = ReentrantSelectionDelegate()
        bar.items = [a, b]
        bar.delegate = delegate
        delegate.shouldSelect = { bar, item in
            if item === a {
                bar.requestSelection(of: b)
            }
            return true
        }
        bar.requestSelection(of: a)
        XCTAssertTrue(bar.selectedItem === b)
        XCTAssertEqual(delegate.selected.map(ObjectIdentifier.init), [ObjectIdentifier(b)])
    }

    func testDidSelectCanRequestNextItemWithoutDuplicateCommit() {
        let a = SPTabBarItem(title: "甲"), b = SPTabBarItem(title: "乙")
        let bar = SPTabBar(), delegate = ReentrantSelectionDelegate()
        bar.items = [a, b]
        bar.delegate = delegate
        bar.selectionRequest = { [weak bar] item in
            bar?.beginUserSelection(item)
            bar?.synchronizeSelection(item, animated: false)
            bar?.completeUserSelection()
        }
        delegate.didSelect = { bar, item in
            if item === a {
                bar.requestSelection(of: b)
            }
        }
        bar.requestSelection(of: a)
        bar.completeUserSelection()
        XCTAssertTrue(bar.selectedItem === b)
        XCTAssertEqual(delegate.selected.map(ObjectIdentifier.init), [a, b].map(ObjectIdentifier.init))
    }

    func testPropertiesAndContainerSynchronizationPreserveOpenDispatch() {
        let bar = SelectionOverrideBar(), item = SPTabBarItem(title: "标签")
        bar.items = [item]
        XCTAssertEqual(bar.calls, ["items"])
        bar.calls.removeAll()
        bar.selectedItem = item
        XCTAssertEqual(bar.calls, ["item", "index"])
        bar.calls.removeAll()
        bar.beginUserSelection(item)
        bar.synchronizeSelection(item, animated: false)
        bar.setTransitionProgress(from: 0, to: 0, progress: 0.5)
        XCTAssertEqual(bar.calls, ["item", "index", "progress"])
        XCTAssertTrue(bar.selectedItem === item)
    }
}

@MainActor
private final class ReentrantSelectionDelegate: SPTabBarDelegate {
    var shouldSelect: ((SPTabBar, SPTabBarItem) -> Bool)?
    var didSelect: ((SPTabBar, SPTabBarItem) -> Void)?
    var selected: [SPTabBarItem] = []
    func tabBar(_ tabBar: SPTabBar, shouldSelect item: SPTabBarItem) -> Bool {
        shouldSelect?(tabBar, item) ?? true
    }

    func tabBar(_ tabBar: SPTabBar, didSelect item: SPTabBarItem) {
        selected.append(item)
        didSelect?(tabBar, item)
    }
}

@MainActor
private final class SelectionOverrideBar: SPTabBar {
    var calls: [String] = []
    override func setItems(_ items: [SPTabBarItem]) {
        calls.append("items")
        super.setItems(items)
    }

    override func setSelectedItem(_ item: SPTabBarItem?, animated: Bool) {
        calls.append("item")
        super.setSelectedItem(item, animated: animated)
    }

    override func setSelectedIndex(_ index: Int?, animated: Bool) {
        calls.append("index")
        super.setSelectedIndex(index, animated: animated)
    }

    override func setTransitionProgress(from fromIndex: Int, to toIndex: Int, progress: CGFloat) {
        calls.append("progress")
        super.setTransitionProgress(from: fromIndex, to: toIndex, progress: progress)
    }
}
