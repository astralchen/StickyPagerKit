import UIKit

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = ProcessInfo.processInfo.arguments.contains("--paging-trace")
            ? PagingTraceWindow(windowScene: windowScene) : UIWindow(windowScene: windowScene)
        if ProcessInfo.processInfo.arguments.contains("--rtl") {
            window.semanticContentAttribute = .forceRightToLeft
        }
        let navigation = UINavigationController(rootViewController: DemoLauncher())
        window.rootViewController = navigation
        self.window = window
        window.makeKeyAndVisible()
        if ProcessInfo.processInfo.arguments.contains("--open-demo") {
            navigation.pushViewController(DemoPager(), animated: false)
        }
    }
}
