import XCTest

@MainActor
final class RefreshGestureTests: XCTestCase {
    func testRefreshRetractionPreservesHeaderThroughoutUpwardDrag() throws {
        try verifyRefresh(index: 1, rtl: false)
    }

    func testRefreshRetractionPreservesHeaderThroughoutUpwardDragRTL() throws {
        try verifyRefresh(index: 1, rtl: true)
    }

    func testShortRefreshRetractionPreservesHeaderThroughoutUpwardDrag() throws {
        try verifyRefresh(index: 2, rtl: false)
    }

    func testShortRefreshRetractionPreservesHeaderThroughoutUpwardDragRTL() throws {
        try verifyRefresh(index: 2, rtl: true)
    }

    private func verifyRefresh(index: Int, rtl: Bool) throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        let app = XCUIApplication()
        app.launchArguments = ["--open-demo", "--window-regression", "--refresh-regression"]
        if rtl {
            app.launchArguments.append("--rtl")
        }
        app.launch()
        defer { app.terminate() }
        let tab = app.buttons["sp.tab.\(index)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let table = app.tables["demo.list"]
        func geometry() throws -> [String: Double] {
            let raw = try XCTUnwrap(table.value as? String)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Double])
        }
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(
            forDuration: 0.1,
            thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        )
        let ended = NSPredicate { _, _ in
            // 受控切页期间列表会短暂离开无障碍树，等待阶段不应把缺失快照记为测试失败。
            guard table.exists, let raw = table.value as? String,
                  let values = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Double] else {
                return false
            }
            return values["refreshEnded"] == 1
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ended, object: nil)], timeout: 15),
            .completed
        )
        // 短列表的空白区域不一定命中列表内容，从可见 cell 开始发送恢复滚动。
        let beforeDrag = try geometry()
        // 同时检查下一次触摸前的位置，防止主队列补偿已完成后又被列表布局覆盖。
        XCTAssertEqual(
            try XCTUnwrap(beforeDrag["position"]),
            try XCTUnwrap(beforeDrag["beforeEndPosition"]),
            accuracy: 1
        )
        let start = table.cells.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -table.frame.height * 0.04)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )
        let values = try geometry()
        print("REFRESH PROCESS METRICS \(values)")
        let attachment = XCTAttachment(string: String(describing: values))
        attachment.name = "刷新与真实拖动过程指标"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(values["refreshStarted"], 1)
        XCTAssertEqual(values["returnedRefreshing"], 1, "切页与返回必须发生在真实刷新期间")
        XCTAssertGreaterThan(try XCTUnwrap(values["dragFrames"]), 0, "必须采集真实拖动中的显示帧")
        XCTAssertLessThanOrEqual(try XCTUnwrap(values["maxReverseHeaderMovement"]), 1)
        // pan 的 began 回调可能晚于首次 offset 更新；用触摸前的坐标同时覆盖最早的反向帧。
        XCTAssertLessThanOrEqual(
            try XCTUnwrap(values["maxDragTabY"]),
            try XCTUnwrap(beforeDrag["currentHeaderY"]) + 1
        )
        XCTAssertEqual(
            try XCTUnwrap(values["afterEndPosition"]),
            try XCTUnwrap(values["beforeEndPosition"]),
            accuracy: 1
        )
        XCTAssertEqual(try XCTUnwrap(values["afterEndHeaderDelta"]), 0, accuracy: 1)
        XCTAssertEqual(try XCTUnwrap(values["afterEndGap"]), 0, accuracy: 1)
    }
}
