import Foundation

/// serve-sim 0.1.48 的公开 gesture 通道；输入进入模拟器 HID，再由 UIKit 识别。
/// XCTest 的单段 drag 无法表达同次触摸折返，此适配仅属于 UI 测试。
@MainActor
enum NativeTouchPath {
    static func drag(url: URL, points: [CGPoint]) async throws {
        let session = URLSession(configuration: .ephemeral)
        let socket = session.webSocketTask(with: url)
        socket.resume()
        defer {
            socket.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }
        func send(_ type: String, _ point: CGPoint) async throws {
            let json = try JSONSerialization.data(withJSONObject: ["type": type, "x": point.x, "y": point.y])
            try await socket.send(.data(Data([3]) + json))
        }
        guard let first = points.first, let last = points.last else {
            return
        }
        try await send("begin", first)
        do {
            try await Task.sleep(nanoseconds: 100000000)
            for (start, end) in zip(points, points.dropFirst()) {
                for step in 1 ... 60 {
                    let fraction = CGFloat(step) / 60
                    try await send("move", CGPoint(
                        x: start.x + (end.x - start.x) * fraction,
                        y: start.y + (end.y - start.y) * fraction
                    ))
                    try await Task.sleep(nanoseconds: 25000000)
                }
            }
            try await Task.sleep(nanoseconds: 300000000)
            try await send("end", last)
            try await Task.sleep(nanoseconds: 800000000)
        } catch {
            // 失败时也释放手指，避免影响后续用例。
            try? await send("end", last)
            throw error
        }
    }
}
