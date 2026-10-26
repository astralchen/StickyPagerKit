import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPPageViewportTests: XCTestCase {
    func testPagingSharesTabHeightMeasurementAcrossVisiblePages() {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
            let pager = SPPageViewController()
            let source = ViewportTableSource()
            let bar = ViewportMeasuringTabBar()
            for leading in [false, true] {
                let button = UIButton(type: .system)
                var configuration = UIButton.Configuration.filled()
                configuration.title = leading ? "筛选" : "菜单"
                button.configuration = configuration
                if leading {
                    bar.leadingAccessoryView = button
                } else {
                    bar.trailingAccessoryView = button
                }
            }
            pager.tabBar = bar
            window.rootViewController = pager
            window.showForTesting()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            pager.reloadData()
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            for sizing: SPTabBarSizing in [.content(minimum: 44), .fixed(60)] {
                pager.layout.tabBarSizing = sizing
                for top: CGFloat in [0, 12] {
                    bar.layoutConfiguration.contentInsets.top = top
                    pager.view.layoutIfNeeded()
                    // 两页同时可见，排除首次创建页面的测量，检查稳定分页阶段的成本。
                    pager.pagingView.contentOffset.x = pager.pagingView.bounds.width * 0.4
                    for _ in 0 ..< 3 {
                        bar.measurementCount = 0
                        pager.scrollViewDidScroll(pager.pagingView)
                        XCTAssertEqual(bar.measurementCount, sizing == .fixed(60) ? 0 : 1)
                    }
                    for page in source.pages {
                        XCTAssertEqual(page.additionalSafeAreaInsets.top, bar.bounds.height, accuracy: 0.01)
                    }
                }
            }
            window.closeForTesting()
        }
    }

    func testFirstTableSelectionPreservesPositionDuringAnimation() {
        for rtl in [false, true] {
            for count in [0, 2, 80] {
                for progress: CGFloat in [0, 0.5, 1] {
                    let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
                    let pager = SPPageViewController()
                    let source = ViewportTableSource(rowCount: count)
                    window.rootViewController = UINavigationController(rootViewController: pager)
                    window.showForTesting()
                    pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                    pager.dataSource = source
                    pager.headerView = UIView()
                    pager.layout = SPPageLayout(headerHeight: 220)
                    pager.reloadData()
                    window.layoutIfNeeded()
                    let collapse = max(0, 220 - pager.view.safeAreaInsets.top) * progress
                    let current = pager.currentScrollView!
                    current.contentOffset.y = collapse - current.adjustedContentInset.top
                    pager.setSelectedIndex(1, animated: true)
                    let binding = pager.records[1]!.binding!
                    let table = source.pages[1].tableView!
                    var gaps: [CGFloat] = []
                    var visibleSamples = 0
                    for _ in 0 ..< 35 {
                        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.016))
                        let viewport = table.convert(table.bounds, to: window)
                        if viewport.maxX > window.bounds.minX, viewport.minX < window.bounds.maxX {
                            visibleSamples += 1
                            XCTAssertEqual(binding.position, collapse, accuracy: 1)
                            XCTAssertEqual(
                                table.adjustedContentInset.top,
                                collapse + pager.tabBar.bounds.height,
                                accuracy: 1
                            )
                            if count > 0 {
                                let frame = table.convert(
                                    table.rectForRow(at: IndexPath(row: 0, section: 0)),
                                    to: window
                                )
                                let tabFrame = pager.tabBar.convert(pager.tabBar.bounds, to: window)
                                gaps.append(frame.minY - tabFrame.maxY)
                            }
                        }
                    }
                    XCTAssertEqual(pager.selectedIndex, 1)
                    XCTAssertGreaterThan(visibleSamples, 5)
                    XCTAssertTrue(
                        gaps.allSatisfy { abs($0) < 1 },
                        "首次切页的首行间距（RTL=\(rtl)，行数=\(count)，折叠=\(progress)）：\(gaps)"
                    )
                    window.closeForTesting()
                    window.rootViewController = nil
                }
            }
        }
    }

    func testSelfSizingRootTablePreservesPositionThroughSplitTraits() {
        verifySelfSizingRootTable(resizeWindow: false)
    }

    func testSelfSizingRootTablePreservesPositionThroughWindowResizing() {
        verifySelfSizingRootTable(resizeWindow: true)
    }

    func testSelfSizingRootTablePreservesPositionThroughSizeTransitionCompletion() {
        verifySelfSizingRootTable(resizeWindow: true, transition: true)
    }

    func testSelfSizingRootTablePreservesPositionInNavigationWindow() {
        verifySelfSizingRootTable(resizeWindow: true, transition: true, inNavigation: true)
    }

    func testSizeTransitionSettlesLayoutScheduledByRestoringOffset() {
        verifySelfSizingRootTable(resizeWindow: true, transition: true, inNavigation: true, deferredCorrection: true)
    }

    func testNestedViewportLayoutKeepsOuterHeaderProtection() {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 511, height: 900))
            let pager = SPPageViewController()
            let source = ViewportTableSource(rowCount: 80, rowHeight: 84)
            window.rootViewController = pager
            window.showForTesting()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            pager.reloadData()
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            pager.view.layoutIfNeeded()
            let binding = pager.records[0]!.binding!
            let table = source.pages[0].tableView!
            table.contentOffset.y = 45 - table.adjustedContentInset.top
            XCTAssertEqual(pager.collapseOffset, 45, accuracy: 0.5)
            let collapseRange = max(0, 220 - pager.view.safeAreaInsets.top)
            let cached = source.pages[1].tableView as! DeferredOffsetTableView
            var reentered = false
            cached.onNextLayout = {
                reentered = true
                // 缓存页布局重入父容器后，外层 Header 布局的保护仍应有效。
                pager.viewDidLayoutSubviews()
                let position = binding.position
                table.contentOffset.y = collapseRange - table.adjustedContentInset.top
                // 模拟外层几何事务将实际位置恢复；中间回写不能改变共享折叠量。
                binding.setPosition(position)
            }
            cached.setNeedsLayout()
            pager.view.setNeedsLayout()
            pager.view.layoutIfNeeded()
            XCTAssertTrue(reentered)
            XCTAssertEqual(binding.position, 45, accuracy: 0.5)
            XCTAssertEqual(pager.collapseOffset, 45, accuracy: 0.5)
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            XCTAssertEqual(binding.position, 45, accuracy: 0.5)
            XCTAssertEqual(pager.collapseOffset, 45, accuracy: 0.5)
            window.closeForTesting()
            window.rootViewController = nil
        }
    }

    func testBusinessPositionAfterViewportIsNotClassifiedByMatchingGeometry() {
        for rtl in [false, true] {
            for correction: CGFloat in [-10.5, 17] {
                let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 535, height: 796))
                let pager = SPPageViewController()
                let source = ViewportTableSource()
                window.rootViewController = pager
                window.showForTesting()
                pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                pager.dataSource = source
                pager.headerView = UIView()
                pager.layout = SPPageLayout(headerHeight: 220)
                pager.reloadData()
                pager.view.layoutIfNeeded()
                let binding = pager.records[0]!.binding!
                let table = source.pages[0].tableView!
                table.contentOffset.y = 546 + max(0, 220 - pager.view.safeAreaInsets.top) - table.adjustedContentInset
                    .top
                let coordinator = SizeTransitionCoordinator()
                pager.viewWillTransition(to: CGSize(width: 511, height: 900), with: coordinator)
                window.frame.size = CGSize(width: 511, height: 900)
                window.layoutIfNeeded()
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                coordinator.finish()
                XCTAssertEqual(binding.position - pager.collapseOffset, 546, accuracy: 0.5)
                // 业务同步移动内容与 offset，在公开几何上可以与估算补偿完全相同。
                // 转场已结束，框架不得猜测来源并撤销这次原生定位。
                for cell in table.visibleCells {
                    cell.frame.origin.y += correction
                }
                table.contentSize.height += correction
                table.contentOffset.y += correction
                XCTAssertEqual(binding.position - pager.collapseOffset, 546 + correction, accuracy: 0.5)
                pager.setSelectedIndex(1, animated: false)
                pager.setSelectedIndex(0, animated: false)
                XCTAssertEqual(binding.position - pager.collapseOffset, 546 + correction, accuracy: 0.5)
                window.closeForTesting()
                window.rootViewController = nil
            }
        }
    }

    func testEstimatedRowCompensationInsideViewportTransactionDoesNotBecomeSavedPosition() {
        for rtl in [false, true] {
            for correction: CGFloat in [-10.5, 17] {
                let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 535, height: 796))
                let pager = SPPageViewController()
                let source = ViewportTableSource()
                window.rootViewController = pager
                window.showForTesting()
                pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                pager.dataSource = source
                pager.headerView = UIView()
                pager.layout = SPPageLayout(headerHeight: 220)
                pager.reloadData()
                pager.view.layoutIfNeeded()
                let binding = pager.records[0]!.binding!
                let table = source.pages[0].tableView!
                table.contentOffset.y = 546 + max(0, 220 - pager.view.safeAreaInsets.top) - table.adjustedContentInset
                    .top
                table.layoutIfNeeded()
                let coordinator = SizeTransitionCoordinator()
                pager.viewWillTransition(to: CGSize(width: 511, height: 900), with: coordinator)
                window.frame.size = CGSize(width: 511, height: 900)
                window.layoutIfNeeded()
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                // 新契约只保护框架收尾事务内的回写；事务外相同几何由业务测试验证。
                let deferred = table as! DeferredOffsetTableView
                deferred.onNextLayout = {
                    let cells = table.visibleCells
                    XCTAssertFalse(cells.isEmpty)
                    for cell in cells {
                        cell.frame.origin.y += correction
                    }
                    table.contentSize.height += correction
                    table.contentOffset.y += correction
                }
                table.setNeedsLayout()
                coordinator.finish()
                XCTAssertEqual(binding.position - pager.collapseOffset, 546, accuracy: 0.5)
                pager.setSelectedIndex(1, animated: false)
                pager.setSelectedIndex(0, animated: false)
                XCTAssertEqual(binding.position - pager.collapseOffset, 546, accuracy: 0.5)
                // 几何未变化时的业务定位必须照常保存，包括与历史补偿相同的数值。
                for change: CGFloat in [-10.5, 10.5, 37] {
                    let expected = binding.position - pager.collapseOffset + change
                    table.contentOffset.y += change
                    XCTAssertEqual(binding.position - pager.collapseOffset, expected, accuracy: 0.5)
                    pager.setSelectedIndex(1, animated: false)
                    pager.setSelectedIndex(0, animated: false)
                    XCTAssertEqual(binding.position - pager.collapseOffset, expected, accuracy: 0.5)
                }
                // 业务数据更新不属于估算结算，即便行坐标与 offset 的变化恰好相同。
                source.pages[0].rowCount += 1
                let rowsUpdated = expectation(description: "业务插行完成")
                table.performBatchUpdates {
                    table.insertRows(at: [IndexPath(row: 80, section: 0)], with: .none)
                } completion: { _ in rowsUpdated.fulfill() }
                wait(for: [rowsUpdated], timeout: 1)
                table.layoutIfNeeded()
                // 插行自身会结算之前的估算；业务后续定位以数据更新后的实际位置为起点。
                let beforeUpdate = binding.position - pager.collapseOffset
                for cell in table.visibleCells {
                    cell.frame.origin.y += 17
                }
                table.contentSize.height += 17
                table.contentOffset.y += 17
                XCTAssertEqual(binding.position - pager.collapseOffset, beforeUpdate + 17, accuracy: 0.5)
                window.closeForTesting()
                window.rootViewController = nil
            }
        }
    }

    func testSameCountHeightUpdatesAndNativePositioningAfterViewport() {
        for rtl in [false, true] {
            for idle in [false, true] {
                let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 535, height: 796))
                let pager = SPPageViewController()
                let source = ViewportTableSource(rowCount: 80, rowHeight: 84)
                window.rootViewController = pager
                window.showForTesting()
                pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                pager.dataSource = source
                pager.headerView = UIView()
                pager.layout = SPPageLayout(headerHeight: 220)
                pager.reloadData()
                pager.view.layoutIfNeeded()
                let table = source.pages[0].tableView!
                let binding = pager.records[0]!.binding!
                table.scrollToRow(at: IndexPath(row: 12, section: 0), at: .top, animated: false)
                let coordinator = SizeTransitionCoordinator()
                pager.viewWillTransition(to: CGSize(width: 511, height: 900), with: coordinator)
                window.frame.size = CGSize(width: 511, height: 900)
                window.layoutIfNeeded()
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                coordinator.finish()
                if idle {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                let oldRowY = table.rectForRow(at: IndexPath(row: 14, section: 0)).minY
                let count = table.numberOfRows(inSection: 0)
                source.pages[0].rowHeights[12] = 101
                let updated = expectation(description: "等行数业务行高更新完成")
                UIView.performWithoutAnimation {
                    table.performBatchUpdates({}) { _ in updated.fulfill() }
                }
                wait(for: [updated], timeout: 1)
                table.layoutIfNeeded()
                XCTAssertEqual(table.numberOfRows(inSection: 0), count)
                XCTAssertEqual(table.rectForRow(at: IndexPath(row: 14, section: 0)).minY, oldRowY + 17, accuracy: 0.5)
                table.scrollToRow(at: IndexPath(row: 14, section: 0), at: .top, animated: false)
                XCTAssertEqual(binding.position, oldRowY + 17, accuracy: 0.5)
                for delta: CGFloat in [-10.5, 17, 37] {
                    let expected = binding.position + delta
                    table.setContentOffset(CGPoint(x: 0, y: expected - table.adjustedContentInset.top), animated: false)
                    XCTAssertEqual(binding.position, expected, accuracy: 0.5)
                    pager.setSelectedIndex(1, animated: false)
                    pager.setSelectedIndex(0, animated: false)
                    XCTAssertEqual(binding.position, expected, accuracy: 0.5)
                }
                window.closeForTesting()
                window.rootViewController = nil
            }
        }
    }

    func testNativeEstimatedRowsPreservePositionAfterIdleViewportSettlement() {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
            let pager = SPPageViewController()
            let source = ViewportTableSource()
            let navigation = UINavigationController(rootViewController: pager)
            window.rootViewController = navigation
            window.showForTesting()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            pager.reloadData()
            pager.view.layoutIfNeeded()
            let binding = pager.records[0]!.binding!
            let table = source.pages[0].tableView!
            for body: CGFloat in [503, 513.5, 524, 535.5] {
                table.scrollToRow(at: IndexPath(row: 20, section: 0), at: .top, animated: false)
                table.layoutIfNeeded()
                table.contentOffset.y = body + max(0, 220 - pager.view.safeAreaInsets.top) - table.adjustedContentInset
                    .top
                table.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
                XCTAssertEqual(binding.position - pager.collapseOffset, body, accuracy: 0.5)
                for size in [
                    CGSize(width: 535, height: 796),
                    CGSize(width: 511, height: 1376),
                    CGSize(width: 683, height: 1032),
                    CGSize(width: 1032, height: 1376)
                ] {
                    let coordinator = SizeTransitionCoordinator()
                    pager.viewWillTransition(to: size, with: coordinator)
                    window.frame.size = size
                    window.layoutIfNeeded()
                    pager.view.setNeedsLayout()
                    pager.view.layoutIfNeeded()
                    coordinator.finish()
                    // 等待真实 UITableView 的空闲期估算结算，不注入 offset 或行高回写。
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
                    XCTAssertEqual(
                        binding.position - pager.collapseOffset,
                        body,
                        accuracy: 0.5,
                        "rtl=\(rtl), size=\(size), contentHeight=\(table.contentSize.height)"
                    )
                    pager.setSelectedIndex(1, animated: false)
                    pager.setSelectedIndex(0, animated: false)
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                    XCTAssertEqual(binding.position - pager.collapseOffset, body, accuracy: 0.5)
                }
            }
            window.closeForTesting()
            window.rootViewController = nil
        }
    }

    func testSizeTransitionSavesBottomClampedByDeferredRowHeightSettlement() {
        verifyDeferredBottomSettlement(cached: false)
    }

    func testSizeTransitionSavesCachedPageBottomClampedByDeferredRowHeightSettlement() {
        verifyDeferredBottomSettlement(cached: true)
    }

    private func verifyDeferredBottomSettlement(cached: Bool) {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 535, height: 700))
            let pager = SPPageViewController()
            let source = ViewportTableSource(rowCount: 24, rowHeight: 84)
            window.rootViewController = pager
            window.showForTesting()
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            pager.reloadData()
            pager.view.layoutIfNeeded()
            let binding = pager.records[0]!.binding!
            let table = source.pages[0].tableView as! DeferredOffsetTableView
            table.layoutIfNeeded()
            table.contentOffset.y = binding.maximumPosition - 12 - table.adjustedContentInset.top
            let originalBody = binding.position - pager.collapseOffset
            XCTAssertGreaterThan(originalBody, 800)
            XCTAssertEqual(binding.maximumPosition - binding.position, 12, accuracy: 0.5)
            if cached {
                pager.setSelectedIndex(1, animated: false)
                let other = pager.records[1]!.binding!
                other.scrollView.contentOffset.y = pager.collapseOffset + 80 - other.scrollView.adjustedContentInset.top
            }

            func beginResize(_ size: CGSize) -> SizeTransitionCoordinator {
                let coordinator = SizeTransitionCoordinator()
                pager.viewWillTransition(to: size, with: coordinator)
                window.frame.size = size
                window.layoutIfNeeded()
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                return coordinator
            }
            func assertBody(_ expected: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
                XCTAssertEqual(binding.position - pager.collapseOffset, expected, accuracy: 0.5, file: file, line: line)
                XCTAssertEqual(
                    pager.collapseOffset,
                    220 - pager.view.safeAreaInsets.top,
                    accuracy: 0.5,
                    file: file,
                    line: line
                )
                XCTAssertEqual(
                    pager.tabBar.frame.minY,
                    pager.view.safeAreaInsets.top,
                    accuracy: 0.5,
                    file: file,
                    line: line
                )
                let physicalIndex = rtl ? 1 - pager.selectedIndex! : pager.selectedIndex!
                XCTAssertEqual(
                    pager.pagingView.contentOffset.x,
                    CGFloat(physicalIndex) * pager.pagingView.bounds.width,
                    accuracy: 0.5,
                    file: file,
                    line: line
                )
            }

            let coordinator = beginResize(CGSize(width: 800, height: 900))
            let estimatedMaximum = binding.maximumPosition
            var settlements = 0
            // 在最后恢复 offset 后才结算行高；真正重排 UITableView 的行与 contentSize。
            // 受控时序避免依赖系统偶发的自适应估算回写，不直接修改容器保存位置。
            binding.setPosition(binding.position - 10.5)
            table.layoutAfterNextRestore = {
                settlements += 1
                table.rowHeight = 73.5
                table.estimatedRowHeight = 73.5
                table.reloadData()
                table.layoutIfNeeded()
            }
            coordinator.finish()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertEqual(settlements, 1)
            XCTAssertEqual(table.contentSize.height, 24 * 73.5, accuracy: 0.5)
            XCTAssertLessThan(binding.maximumPosition, estimatedMaximum - 200)
            let settledBody = binding.maximumPosition - pager.collapseOffset
            XCTAssertLessThan(settledBody, originalBody - 200)
            assertBody(settledBody)
            if cached {
                XCTAssertEqual(pager.records[1]!.binding!.position - pager.collapseOffset, 80, accuracy: 0.5)
            }
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            assertBody(settledBody)

            // 重新缩小视口会放宽合法范围；此时必须保留结算后的正文，而不是复活旧底部。
            for size in [
                CGSize(width: 535, height: 600),
                CGSize(width: 800, height: 900),
                CGSize(width: 535, height: 700)
            ] {
                beginResize(size).finish()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                assertBody(settledBody)
                pager.setSelectedIndex(1, animated: false)
                pager.setSelectedIndex(0, animated: false)
                assertBody(settledBody)
            }
            table.contentOffset.y -= 37
            pager.setSelectedIndex(1, animated: false)
            pager.setSelectedIndex(0, animated: false)
            assertBody(settledBody - 37)
            window.closeForTesting()
            window.rootViewController = nil
        }
    }

    private func verifySelfSizingRootTable(
        resizeWindow: Bool,
        transition: Bool = false,
        inNavigation: Bool = false,
        deferredCorrection: Bool = false
    ) {
        for rtl in [false, true] {
            let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 1032, height: 1376))
            let pager = SPPageViewController()
            let root = inNavigation ? UINavigationController(rootViewController: pager) : UIViewController()
            let source = ViewportTableSource()
            window.rootViewController = root
            window.showForTesting()
            if !inNavigation {
                root.addChild(pager)
                root.view.addSubview(pager.view)
                pager.didMove(toParent: root)
            }
            pager.view.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            pager.dataSource = source
            pager.headerView = UIView()
            pager.layout = SPPageLayout(headerHeight: 220)
            pager.reloadData()
            func resize(_ size: CGSize, safeTop: CGFloat, sizeClass: UIUserInterfaceSizeClass) {
                let coordinator = SizeTransitionCoordinator()
                if transition {
                    pager.viewWillTransition(to: size, with: coordinator)
                }
                root.setOverrideTraitCollection(UITraitCollection(horizontalSizeClass: sizeClass), forChild: pager)
                if resizeWindow {
                    window.frame.size = size
                    root.view.frame.size = size
                }
                if !inNavigation {
                    pager.view.frame = CGRect(origin: .zero, size: size)
                }
                pager.additionalSafeAreaInsets.top = inNavigation ? 0 : safeTop
                root.view.layoutIfNeeded()
                pager.view.setNeedsLayout()
                pager.view.layoutIfNeeded()
                if deferredCorrection, let binding = pager.records[0]?.binding,
                   binding.position - pager.collapseOffset > 400 {
                    // 最后的定位可再次安排列表布局；模拟估算 84、实际 73.5 的单行差。
                    binding.setPosition(binding.position - 10.5)
                    (binding.scrollView as? DeferredOffsetTableView)?.correctionAfterNextRestore = -10.5
                }
                if transition {
                    coordinator.finish()
                }
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            resize(CGSize(width: 1032, height: 1376), safeTop: 86, sizeClass: .regular)
            let binding = pager.records[0]!.binding!
            for distance: CGFloat in deferredCorrection ? [546] : [546, 569, 450, 650, 582, 513.5] {
                let table = source.pages[0].tableView!
                table.contentOffset.y = distance + 220 - pager.view.safeAreaInsets.top - table.adjustedContentInset.top
                table.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                let saved = binding.position - pager.collapseOffset
                XCTAssertEqual(saved, distance, accuracy: 0.5)
                for (size, top, traits): (CGSize, CGFloat, UIUserInterfaceSizeClass) in [
                    (CGSize(width: 995, height: 1350.5), 86, .regular),
                    (CGSize(width: 536, height: 797), 86, .compact),
                    (CGSize(width: 535, height: 796), 64, .compact),
                    (CGSize(width: 511, height: 1376), 86, .compact),
                    (CGSize(width: 683, height: 1032), 64, .regular),
                    (CGSize(width: 1032, height: 1376), 86, .regular)
                ] {
                    resize(size, safeTop: top, sizeClass: traits)
                    XCTAssertEqual(binding.position - pager.collapseOffset, saved, accuracy: 0.5)
                    XCTAssertEqual(pager.collapseOffset, 220 - pager.view.safeAreaInsets.top, accuracy: 0.5)
                    pager.setSelectedIndex(1, animated: false)
                    pager.setSelectedIndex(0, animated: false)
                    XCTAssertEqual(binding.position - pager.collapseOffset, saved, accuracy: 0.5)
                }
                // 收尾保护必须解除，后续业务滚动仍应被记录并在切页后恢复。
                table.contentOffset.y += 37
                table.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                XCTAssertEqual(binding.position - pager.collapseOffset, saved + 37, accuracy: 0.5)
                pager.setSelectedIndex(1, animated: false)
                pager.setSelectedIndex(0, animated: false)
                XCTAssertEqual(binding.position - pager.collapseOffset, saved + 37, accuracy: 0.5)
            }
            window.closeForTesting()
            window.rootViewController = nil
        }
    }
}

@MainActor
private final class ViewportMeasuringTabBar: SPTabBar {
    var measurementCount = 0

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        measurementCount += 1
        return super.sizeThatFits(size)
    }
}

@MainActor
private final class ViewportTableSource: SPPageViewControllerDataSource {
    let pages: [ViewportTablePage]

    init(rowCount: Int = 80, rowHeight: CGFloat? = nil) {
        pages = [ViewportTablePage(), ViewportTablePage()]
        for page in pages {
            page.rowCount = rowCount
            page.initialRowHeight = rowHeight
        }
    }

    func numberOfPages(in pageViewController: SPPageViewController) -> Int {
        pages.count
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        identifierForPageAt index: Int
    ) -> AnyHashable {
        index
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        viewControllerAt index: Int
    ) -> UIViewController {
        pages[index]
    }

    func pageViewController(
        _ pageViewController: SPPageViewController,
        tabBarItemAt index: Int
    ) -> SPTabBarItem {
        SPTabBarItem(title: "列表 \(index)")
    }
}

@MainActor
private final class ViewportTablePage: UITableViewController {
    var rowCount = 80
    var initialRowHeight: CGFloat?
    var rowHeights: [Int: CGFloat] = [:]

    override func loadView() {
        tableView = DeferredOffsetTableView(frame: .zero, style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = initialRowHeight ?? UITableView.automaticDimension
        tableView.estimatedRowHeight = initialRowHeight ?? 84
        tableView.sectionHeaderTopPadding = 0
        tableView.alwaysBounceVertical = true
        refreshControl = UIRefreshControl()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rowHeights[indexPath.row] ?? tableView.rowHeight
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = "内容 \(indexPath.row + 1)"
        content.secondaryText = "原生 UITableView · 已刷新 0 次"
        cell.contentConfiguration = content
        return cell
    }
}

/// 在恢复定位之后的下一次布局中模拟 UITableView 估算行高的 offset 回写。
@MainActor
private final class DeferredOffsetTableView: UITableView {
    var onNextLayout: (() -> Void)?
    var correctionAfterNextRestore: CGFloat?
    private var pendingCorrection: CGFloat?
    var layoutAfterNextRestore: (() -> Void)?
    private var pendingLayout: (() -> Void)?

    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        super.setContentOffset(contentOffset, animated: animated)
        if let layout = layoutAfterNextRestore {
            layoutAfterNextRestore = nil
            pendingLayout = layout
            setNeedsLayout()
        }
        if let correction = correctionAfterNextRestore {
            correctionAfterNextRestore = nil
            pendingCorrection = correction
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let action = onNextLayout {
            onNextLayout = nil
            action()
        }
        if let layout = pendingLayout {
            pendingLayout = nil
            layout()
        }
        if let correction = pendingCorrection {
            pendingCorrection = nil
            contentOffset.y += correction
        }
    }
}
