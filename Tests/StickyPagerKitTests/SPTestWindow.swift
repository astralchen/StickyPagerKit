import UIKit
import XCTest

@MainActor
extension UIWindow {
    /// 自然 trait 传播和属性更新依赖前台场景。宿主被其他 App 遮住时，报告实际运行条件。
    func requireForegroundForTesting(file: StaticString = #filePath, line: UInt = #line) throws {
        let scene = try XCTUnwrap(windowScene, "测试窗口应已连接 UIWindowScene", file: file, line: line)
        let isForeground = scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive
        _ = try XCTUnwrap(
            isForeground ? scene : nil,
            "UIKit 测试宿主需要保持前台，请在独立模拟器上运行。当前场景状态为 \(scene.activationState.rawValue)",
            file: file,
            line: line
        )
    }

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
