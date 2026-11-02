import UIKit

/// 管理布局事务、尺寸代次和安全区域协调，不保存页面选择或纵向历史。
@MainActor
internal final class SPPageLayoutCoordinator {
    private weak var host: SPPageViewController?
    init(host: SPPageViewController) {
        self.host = host
    }

    private var previousSize: CGSize = .zero
    private var previousTabBarHeight: CGFloat = 0
    private(set) var previousBoundsSize: CGSize = .zero
    private var sizeTransitionGeneration: UInt = 0
    private(set) var isTransitioningSize = false
    private(set) var previousCollapseRange: CGFloat?
    private(set) var isLayingOutPages = false
    var effectiveLayout: SPPageLayout {
        guard let host else {
            return SPPageLayout()
        }
        let configuration = host.layout.normalized
        // 只测量 content 策略，不缓存跨业务回调可能失效的高度或安全区域。
        let measuredHeight: CGFloat?
        if case .content = configuration.tabBarSizing {
            measuredHeight = host.storedTabBar.sizeThatFits(host.view.bounds.size).height
        } else {
            measuredHeight = nil
        }
        return SPPageGeometry.effectiveLayout(
            configuration,
            measuredTabHeight: measuredHeight,
            hasHeader: host.storedHeaderView != nil || host.storedHeaderController != nil,
            safeTop: host.isViewLoaded ? host.view.safeAreaInsets.top : 0
        )
    }

    func willTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        guard let host else {
            return
        }
        sizeTransitionGeneration &+= 1
        let generation = sizeTransitionGeneration
        isTransitioningSize = true
        host.forwardSizeTransition(to: size, with: coordinator)
        let queued = coordinator.animate(alongsideTransition: nil) { [weak self, weak host] _ in
            guard let self, let host, self.sizeTransitionGeneration == generation else {
                return
            }
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            for record in host.records.values {
                host.vertical.align(record)
                // 恢复 offset 可能触发自适应列表再次布局；在转场保护结束前消化回写。
                record.controller.view.setNeedsLayout()
                record.controller.view.layoutIfNeeded()
                if let binding = record.binding {
                    // 延迟行高结算也可能缩短范围；保存新底部，避免下次缩放恢复过期位置。
                    host.store.clampPosition(
                        for: record.identifier,
                        maximum: max(0, binding.maximumPosition - self.effectiveLayout.collapseRange)
                    )
                }
                host.vertical.align(record)
            }
            // 事务结束后立即交还原生定位；不依据空闲期行高／offset 的相关性回滚业务写入。
            self.isTransitioningSize = false
        }
        if !queued {
            isTransitioningSize = false
        }
    }

    func layoutSubviews() {
        guard let host else {
            return
        }
        let l = effectiveLayout
        let wasLayingOut = isLayingOutPages
        isLayingOutPages = true
        previousBoundsSize = host.view.bounds.size
        // 子页布局可能重入容器；内层返回时不能撤销外层仍在使用的保护。
        defer { isLayingOutPages = wasLayingOut }
        let rangeChanged = previousCollapseRange != l.collapseRange
        if rangeChanged {
            // 旋转、导航栏显隐或安全区域变化时，已吸顶的页面继续吸顶。
            let wasCollapsed = previousCollapseRange.map { $0 > 0 && host.vertical.collapseOffset >= $0 } ?? false
            host.vertical.updateCollapseRange(l.collapseRange, preservingCollapsed: wasCollapsed)
            previousCollapseRange = l.collapseRange
            host.vertical.stopAnimation()
        }
        // 页面铺满容器宽度并延伸至底边；安全区域由子页面的布局或自动滚动 inset 处理。
        let pageFrame = SPPageGeometry.viewport(size: host.view.bounds.size, layout: l)
        let sizeChanged = pageFrame.size != previousSize || l.tabBarHeight != previousTabBarHeight
        if sizeChanged {
            host.selection.cancelPaging()
            host.vertical.stopAnimation()
            previousSize = pageFrame.size
            previousTabBarHeight = l.tabBarHeight
        }
        let wasSuppressing = host.selection.suppressPaging
        host.selection.suppressPaging = true
        host.pagingView.frame = pageFrame
        host.pagingView.contentSize = CGSize(
            width: pageFrame.width * CGFloat(host.identifiers.count),
            height: pageFrame.height
        )
        // 先对齐分页视口，再布局子页，避免 RTL 尺寸变化时按旧偏移计算子页安全区域。
        if !host.pagingView.isDragging && !host.pagingView.isDecelerating && host.selection.transitionTarget == nil {
            host.selection.alignPaging()
        }
        for (id, record) in host.records {
            guard let index = host.store.snapshot.index(of: id) else {
                continue
            }
            layoutPage(record, at: index, layout: l)
            if rangeChanged || sizeChanged {
                host.vertical.align(record)
                // inset 与定位会触发 UITableView 的行高结算；完成布局后再恢复契约中的内容位移。
                record.binding?.scrollView.setNeedsLayout()
                record.binding?.scrollView.layoutIfNeeded()
                if sizeChanged, let binding = record.binding {
                    // 放大视口可能缩短可滚动范围；同步保存位置，避免切页后恢复到旧底部以外。
                    host.store.clampPosition(for: id, maximum: max(0, binding.maximumPosition - l.collapseRange))
                }
                host.vertical.align(record)
            }
        }
        host.selection.suppressPaging = wasSuppressing
        if rangeChanged {
            host.vertical.publishHeader()
        } else {
            layoutHeader()
        }
    }

    func updateLayoutConfiguration() {
        guard let host else {
            return
        }
        guard host.isViewLoaded else {
            return
        }
        host.selection.cancelPaging()
        host.vertical.stopAnimation()
        let range = effectiveLayout.collapseRange
        let wasCollapsed = previousCollapseRange.map { $0 > 0 && host.vertical.collapseOffset >= $0 } ?? false
        // 内容自适应导致 Header 增高时，沿用安全区域变化的吸顶契约，保留正文位置。
        host.vertical.updateCollapseRange(range, preservingCollapsed: wasCollapsed)
        previousCollapseRange = range
        for record in host.records.values {
            record.binding?.setRange(range)
            host.vertical.align(record)
        }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        host.vertical.publishHeader()
    }

    func layoutHeader() {
        guard let host else {
            return
        }
        let l = effectiveLayout
        host.headerHost.frame = CGRect(
            x: 0,
            y: 0,
            width: host.view.bounds.width,
            height: max(0, l.headerHeight - host.vertical.collapseOffset)
        )
        host.headerHost.contentSize = CGSize(width: host.view.bounds.width, height: l.headerHeight)
        host.headerHost.contentOffset = CGPoint(x: 0, y: host.vertical.collapseOffset)
        let contentFrame = CGRect(x: 0, y: 0, width: host.view.bounds.width, height: l.headerHeight)
        host.storedHeaderView?.frame = contentFrame
        host.storedHeaderController?.view.frame = contentFrame
        // 背景铺满容器，标签栏内部负责交互内容的左右安全区域避让。
        host.storedTabBar.frame = CGRect(
            x: 0,
            y: host.headerHost.frame.maxY,
            width: host.view.bounds.width,
            height: l.tabBarHeight
        )
        let wasLayingOut = isLayingOutPages
        isLayingOutPages = true
        for (id, record) in host.records {
            guard let index = host.store.snapshot.index(of: id) else {
                continue
            }
            layoutPage(record, at: index, layout: l)
        }
        isLayingOutPages = wasLayingOut
        host.view.bringSubviewToFront(host.headerHost)
        host.view.bringSubviewToFront(host.storedTabBar)
    }

    func layoutPage(_ record: SPPageRecord, at index: Int, layout: SPPageLayout) {
        guard let host else {
            return
        }
        let inset = max(0, layout.collapseRange - host.vertical.collapseOffset)
        let updates = {
            record.controller.view.frame = SPPageGeometry.pageFrame(
                physicalIndex: self.physicalIndex(index),
                viewport: host.pagingView.bounds.size,
                top: inset
            )
            record.safeArea.setTopContribution(layout.tabBarHeight)
            record.controller.view.layoutIfNeeded()
        }
        if let binding = record.binding {
            binding.layoutPage(
                range: layout.collapseRange,
                collapse: host.vertical.collapseOffset,
                root: record.controller.view,
                topOcclusion: layout.tabBarHeight,
                updates: updates
            )
        } else {
            updates()
        }
    }

    func physicalIndex(_ logical: Int) -> CGFloat {
        guard let host else {
            return 0
        }
        return SPPageGeometry.physicalIndex(logical, count: host.identifiers.count, isRTL: host.isRTL)
    }
}
