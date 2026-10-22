import XCTest

/// 外部驱动只负责操作设备；各用例仍须断言实际场景方向及旋转后的布局。
@MainActor
enum UITestOrientation {
    static func set(_ orientation: UIDeviceOrientation, file: StaticString = #filePath, line: UInt = #line) {
        guard ProcessInfo.processInfo.environment["SP_UI_EXTERNAL_ROTATION"] == "1" else {
            XCUIDevice.shared.orientation = orientation
            return
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let identifier = UUID().uuidString
        let request: [String: Any] = ["id": identifier, "orientation": orientation.rawValue]
        do {
            let data = try JSONSerialization.data(withJSONObject: request, options: .sortedKeys)
            try data.write(to: directory.appendingPathComponent("rotation-request.json"), options: .atomic)
        } catch {
            XCTFail("无法写入外部旋转请求：\(error)", file: file, line: line)
            return
        }
        print("EXTERNAL ROTATION REQUEST \(identifier) orientation=\(orientation.rawValue)")
        let acknowledged = NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent("rotation-response.json")),
                  let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            return response["id"] as? String == identifier
                && response["orientation"] as? Int == orientation.rawValue
        }
        // 等待电脑操作完成；该确认不代表界面已旋转，后续场景方向断言仍保持原要求。
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: acknowledged, object: nil)],
            timeout: 120
        )
        XCTAssertEqual(result, .completed, "外部旋转驱动未确认请求 \(identifier)", file: file, line: line)
    }
}
