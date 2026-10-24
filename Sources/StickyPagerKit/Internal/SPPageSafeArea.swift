import UIKit

/// 将标签栏遮挡加入子页面安全区域，仅恢复本组件贡献的部分。
@MainActor
internal final class SPPageSafeArea {
    private weak var controller: UIViewController?
    private var observation: NSKeyValueObservation?
    private var baseInsets: UIEdgeInsets
    private var topContribution: CGFloat = 0
    private var updating = false
    private var notificationDepth = 0
    private var internalWriteDepth: Int?
    private var externalDepth = 0
    private var externalStart: UIEdgeInsets?
    private var pendingApply = false

    init(controller: UIViewController) {
        self.controller = controller
        baseInsets = controller.additionalSafeAreaInsets
        observation = controller.observe(\.additionalSafeAreaInsets, options: [
            .prior,
            .old,
            .new
        ]) { [weak self] _, change in
            MainActor.assumeIsolated { self?.insetsChanged(change) }
        }
    }

    isolated deinit { detach() }

    func setTopContribution(_ height: CGFloat) {
        topContribution = max(0, height)
        apply()
    }

    func detach() {
        guard let controller else {
            return
        }
        // 外部 setter 尚在同步回调中时，也保留已写入的最新业务基准。
        if externalDepth > 0 {
            captureBase(from: externalStart, current: controller.additionalSafeAreaInsets)
        }
        observation?.invalidate()
        observation = nil
        self.controller = nil
        pendingApply = false
        if controller.additionalSafeAreaInsets != baseInsets {
            controller.additionalSafeAreaInsets = baseInsets
        }
    }

    private func insetsChanged(_ change: NSKeyValueObservedChange<UIEdgeInsets>) {
        guard let controller else {
            return
        }
        if change.isPrior {
            notificationDepth += 1
            guard notificationDepth != internalWriteDepth else {
                return
            }
            if externalDepth == 0 {
                externalStart = change.oldValue
            }
            externalDepth += 1
            return
        }
        defer { notificationDepth -= 1 }
        guard notificationDepth != internalWriteDepth else {
            // 本次通知结束即释放层级，保留后续 KVO 观察者发起的业务写入。
            internalWriteDepth = nil
            return
        }
        externalDepth -= 1
        guard externalDepth == 0 else {
            return
        }
        captureBase(from: externalStart, current: controller.additionalSafeAreaInsets)
        externalStart = nil
        apply()
    }

    private func captureBase(from old: UIEdgeInsets?, current: UIEdgeInsets) {
        // 未修改 top 时，getter 中的标签栏贡献不能重复计入业务基准。
        let top = old?.top == current.top ? baseInsets.top : current.top
        baseInsets = current
        baseInsets.top = top
    }

    private func apply() {
        pendingApply = true
        guard !updating, externalDepth == 0 else {
            return
        }
        updating = true
        defer { updating = false }
        // 框架 setter 的业务回调可修改基准、贡献或解绑；串行处理最新状态。
        while pendingApply, let controller {
            pendingApply = false
            var insets = baseInsets
            insets.top += topContribution
            guard controller.additionalSafeAreaInsets != insets else {
                continue
            }
            let previous = internalWriteDepth
            internalWriteDepth = notificationDepth + 1
            controller.additionalSafeAreaInsets = insets
            internalWriteDepth = previous
        }
    }
}
