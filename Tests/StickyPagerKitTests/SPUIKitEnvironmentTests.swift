import Observation
import UIKit
import XCTest

/// UIKit 的自动 observation 与系统安全区域必须在 application host 中验证。
@MainActor
final class SPUIKitEnvironmentTests: XCTestCase {
    private func makeWindow(root: UIViewController = UIViewController()) throws -> UIWindow {
        let application: UIApplication? = UIApplication.shared
        let host = try XCTUnwrap(application, "请使用 SP_SCOPE=library Scripts/validate.sh test 提供 UIKit 宿主")
        let scene = try XCTUnwrap(host.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.showForTesting()
        return window
    }

    func testApplicationHostProvidesConnectedWindowScene() throws {
        let window = try makeWindow()
        defer { window.closeForTesting(); window.rootViewController = nil }
        window.layoutIfNeeded()
        XCTAssertNotNil(window.windowScene)
        XCTAssertTrue(window.rootViewController?.view.window === window)
        XCTAssertGreaterThan(window.bounds.width, 0)
        XCTAssertGreaterThan(window.bounds.height, 0)
    }

    func testGeometryWindowKeepsRequestedBoundsInRealScene() {
        let window = SPTestWindow(frame: CGRect(x: 0, y: 0, width: 2048, height: 844))
        window.rootViewController = UIViewController()
        window.showForTesting()
        defer { window.closeForTesting() }
        XCTAssertNotNil(window.windowScene)
        XCTAssertEqual(window.bounds.size, CGSize(width: 2048, height: 844))
        XCTAssertEqual(window.safeAreaInsets, .zero)
        window.rootViewController?.additionalSafeAreaInsets.left = 30
        window.layoutIfNeeded()
        XCTAssertEqual(window.rootViewController?.view.safeAreaInsets.left, 30)
    }

    func testWindowFixtureFinishesAppearanceBeforeRootRemoval() throws {
        let controller = AppearanceProbeController()
        let window = try makeWindow(root: controller)
        XCTAssertEqual(controller.events, ["willAppear", "didAppear"])
        window.closeForTesting()
        window.rootViewController = nil
        XCTAssertEqual(controller.events, ["willAppear", "didAppear", "willDisappear", "didDisappear"])
    }

    func testAutomaticObservationSettlesAcrossSuccessiveTransactions() async throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("自动 updateProperties observation 需要 iOS 26+")
        }
        let window = try makeWindow()
        defer { window.closeForTesting(); window.rootViewController = nil }
        let model = ObservationModel()
        let probe = ObservationProbe(model: model)
        window.rootViewController!.view.addSubview(probe)
        probe.frame = CGRect(x: 0, y: 100, width: 100, height: 44)
        probe.setNeedsUpdateProperties()
        window.layoutIfNeeded()
        // 每次变化都跨越真实运行循环／CA 提交；不手工重置 UIKit 计数或关闭 observation。
        for value in 1 ... 64 {
            let before = probe.updateCount
            model.value = value
            for _ in 0 ..< 100 {
                try await Task.sleep(nanoseconds: 10_000_000)
                if probe.renderedValue == value {
                    break
                }
            }
            XCTAssertEqual(probe.renderedValue, value, "模型变化应自动更新 UI")
            XCTAssertLessThanOrEqual(probe.updateCount - before, 3, "单次变化不应反复安排属性更新")
        }
        let settled = probe.updateCount
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(probe.updateCount, settled, "输入停止后属性更新应收敛")
    }
}

@available(iOS 26.0, *)
@MainActor
@Observable
private final class ObservationModel {
    var value = 0
}

@available(iOS 26.0, *)
@MainActor
private final class ObservationProbe: UIView {
    let model: ObservationModel
    private(set) var renderedValue = -1
    private(set) var updateCount = 0

    init(model: ObservationModel) {
        self.model = model
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("请使用 init(model:)")
    }

    override func updateProperties() {
        super.updateProperties()
        updateCount += 1
        renderedValue = model.value
    }
}

@MainActor
private final class AppearanceProbeController: UIViewController {
    var events: [String] = []
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        events.append("willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        events.append("didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        events.append("willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        events.append("didDisappear")
    }
}
