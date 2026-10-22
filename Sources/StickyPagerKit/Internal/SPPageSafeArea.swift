import UIKit

/// 将标签栏遮挡加入子页面安全区域，仅恢复本组件贡献的部分。
@MainActor
internal final class SPPageSafeArea {
    private weak var controller: UIViewController?
    private var observation: NSKeyValueObservation?
    private var baseInsets: UIEdgeInsets
    private var topContribution: CGFloat = 0
    private var updating = false

    init(controller: UIViewController) {
        self.controller = controller
        baseInsets = controller.additionalSafeAreaInsets
        observation = controller.observe(\.additionalSafeAreaInsets, options: [.old, .new]) { [weak self] _, change in
            MainActor.assumeIsolated {
                guard let self, !self.updating, let controller = self.controller else {
                    return
                }
                let insets = controller.additionalSafeAreaInsets
                // 修改其他方向时 getter 仍包含栏高，不能把未变化的 top 再算入业务基准。
                let baseTop = change.oldValue?.top == insets.top ? self.baseInsets.top : insets.top
                self.baseInsets = insets
                self.baseInsets.top = baseTop
                self.apply()
            }
        }
    }

    isolated deinit { detach() }

    func setTopContribution(_ height: CGFloat) {
        topContribution = max(0, height)
        apply()
    }

    func detach() {
        observation?.invalidate()
        observation = nil
        guard let controller else {
            return
        }
        controller.additionalSafeAreaInsets = baseInsets
        self.controller = nil
    }

    private func apply() {
        guard let controller else {
            return
        }
        var insets = baseInsets
        insets.top += topContribution
        guard controller.additionalSafeAreaInsets != insets else {
            return
        }
        updating = true
        controller.additionalSafeAreaInsets = insets
        updating = false
    }
}
