import Foundation

/// 主线程释放时立即恢复 UIKit 状态。其他线程只移交清理所需的资源，不延长析构对象的生命周期。
internal func spPerformMainActorCleanup(_ cleanup: @escaping @MainActor @Sendable () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated { cleanup() }
    } else {
        DispatchQueue.main.async(execute: cleanup)
    }
}
