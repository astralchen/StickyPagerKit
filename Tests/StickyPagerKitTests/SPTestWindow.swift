import UIKit
import XCTest

@MainActor
extension UIWindow {
    /// 在测试方法实际挂载时调用，不跨越 XCTest 的异步 setUp 显示边界。
    /// 真实 application host 会提交控制器的 appearance 更新；让显示转场先完成再操作夹具。
    func showForTesting() {
        if isHidden {
            makeKeyAndVisible()
        }
        finishUpdatesForTesting()
    }

    /// 窗口仍可见时移除根控制器，让 UIKit 完成消失转场，再隐藏窗口。
    func closeForTesting() {
        finishUpdatesForTesting()
        rootViewController = nil
        finishUpdatesForTesting()
        isHidden = true
        finishUpdatesForTesting()
    }

    private func finishUpdatesForTesting() {
        layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
}

/// 固定几何夹具仍使用真实 scene／window 生命周期；屏幕安全区域由导航集成夹具验证。
/// 固定尺寸用例仅通过控制器 additionalSafeAreaInsets 注入所需安全区域。
@MainActor
final class SPTestWindow: UIWindow {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let application: UIApplication? = UIApplication.shared
        let scene = application?.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        XCTAssertNotNil(scene, "请通过 Scripts/validate.sh 的 UIKit application host 运行库测试")
        windowScene = scene
        self.frame = frame
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(frame:)")
    }

    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }
}
