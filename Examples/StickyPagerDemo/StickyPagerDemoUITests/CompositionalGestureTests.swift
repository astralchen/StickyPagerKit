import XCTest

@MainActor
final class CompositionalGestureTests: XCTestCase {
    private var app: XCUIApplication!
    private var collection: XCUIElement {
        app.collectionViews["demo.compositional"]
    }

    private var status: XCUIElement {
        app.staticTexts["demo.status"]
    }

    override func setUp() async throws {
        continueAfterFailure = false
        UITestOrientation.set(.portrait)
        app = XCUIApplication()
        app.launchArguments = ["--open-demo", "--compositional", "--window-regression", "--paging-trace"]
        if name.contains("RTL") {
            app.launchArguments.append("--rtl")
        }
        app.launch()
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        expectPage("compositional")
    }

    override func tearDown() async throws {
        print("FINAL COMPOSITIONAL \(collection.exists ? collection.value ?? "" : "offscreen")")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    private func expectPage(_ page: String) {
        let predicate = NSPredicate { [self] _, _ in (status.value as? String)?.contains("page=\(page);") == true }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5),
            .completed
        )
    }

    private func geometry() throws -> [String: Double] {
        let data = try XCTUnwrap((collection.value as? String)?.data(using: .utf8))
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Double])
        print("COMPOSITIONAL GEOMETRY \(result)")
        return result
    }

    private func trace() throws -> [String: Any] {
        let encoded = (status.value as? String ?? "").components(separatedBy: ";")[0].replacingOccurrences(
            of: "gesture=",
            with: ""
        )
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        print("COMPOSITIONAL TRACE \(String(data: data, encoding: .utf8) ?? "")")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @discardableResult
    private func drag(
        y: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        dy: CGFloat = 0,
        velocity: XCUIGestureVelocity = .slow,
        hold: TimeInterval = 0.2
    ) -> CGFloat {
        let window = app.windows.firstMatch
        let frame = window.frame
        let fields = (status.value as? String ?? "").split(separator: ";")
        func inset(_ name: String) -> CGFloat {
            let value = fields.first { $0.hasPrefix("\(name)=") }?.split(separator: "=").last.flatMap { Double($0) }
            XCTAssertNotNil(value, "缺少窗口安全区域：\(name)")
            return CGFloat(value ?? 0)
        }
        let left = inset("safeLeft") + 4, right = frame.width - inset("safeRight") - 4
        let startX = min(right, max(left, frame.width * start))
        let endX = min(right, max(left, frame.width * end))
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: startX, dy: y - frame.minY)).press(
            forDuration: 0.05,
            thenDragTo: origin
                .withOffset(CGVector(
                    dx: endX,
                    dy: y - frame.minY + dy
                )),
            withVelocity: velocity,
            thenHoldForDuration: hold
        )
        return abs(endX - startX)
    }

    private func sectionY(_ section: Int) throws -> CGFloat {
        let viewport = collection.frame.intersection(app.windows.firstMatch.frame)
        let top = max(viewport.minY, app.collectionViews["sp.tabBar.collection"].frame.maxY)
        print(
            "SECTION VIEWPORT collection=\(collection.frame), window=\(app.windows.firstMatch.frame), toolbar=\(app.toolbars.firstMatch.frame)"
        )
        // 浮动工具栏的 AX 容器可能覆盖整个窗口；状态标签才是实际可见的工具栏内容。
        let bottom = min(viewport.maxY, status.frame.minY - 12)
        let cell = collection.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@",
            "demo.compositional.\(section)."
        )).allElementsBoundByIndex
            .first {
                let frame = $0.frame
                print("SECTION CELL \($0.identifier) frame=\(frame)")
                // 部分露出的首项中心可能已经位于标签栏后方；输入点必须真正落在可见内容内。
                return frame.midY > top && frame.midY < bottom
                    && frame.midX > viewport.minX && frame.midX < viewport.maxX
            }
        let frame = try XCTUnwrap(cell).frame
        XCTAssertGreaterThan(frame.midY, top)
        XCTAssertLessThan(frame.midY, bottom)
        return frame.midY
    }

    private func assertInnerGesture(
        _ section: Int,
        from: CGFloat,
        to: CGFloat,
        dy: CGFloat = 0,
        velocity: XCUIGestureVelocity = .slow,
        hold: TimeInterval = 0.2
    ) throws {
        let before = try trace()
        drag(y: try sectionY(section), from: from, to: to, dy: dy, velocity: velocity, hold: hold)
        expectPage("compositional")
        let after = try trace()
        XCTAssertGreaterThan(try XCTUnwrap(after["sequence"] as? Int), try XCTUnwrap(before["sequence"] as? Int))
        let samples = try XCTUnwrap(after["samples"] as? [[String: Double]])
        XCTAssertEqual(samples.last?["phase"], 3)
        XCTAssertGreaterThan(
            abs(try XCTUnwrap(samples.last?["x"]) - XCTUnwrap(samples.first?["x"])),
            app.windows.firstMatch.frame.width * 0.4
        )
        XCTAssertLessThanOrEqual(
            try XCTUnwrap(after["maxOffset"] as? Double) - XCTUnwrap(after["minOffset"] as? Double),
            1,
            "Section 拖动过程中容器不能同时横移"
        )
        XCTAssertEqual(
            try XCTUnwrap(after["offset"] as? Double),
            try XCTUnwrap(before["offset"] as? Double),
            accuracy: 1
        )
    }

    private func assertPageDrag(y: CGFloat, movesLeft: Bool, expectedPage: String) throws {
        let before = try trace()
        let width = app.windows.firstMatch.frame.width
        let distance = drag(y: y, from: movesLeft ? 0.85 : 0.15, to: movesLeft ? 0.15 : 0.85)
        XCTAssertGreaterThan(distance, width * 0.5, "安全区域内仍须真实拖过半页")
        expectPage(expectedPage)
        let after = try trace()
        let samples = try XCTUnwrap(after["samples"] as? [[String: Double]])
        XCTAssertEqual(samples.first?["phase"], 0)
        XCTAssertEqual(samples.last?["phase"], 3)
        XCTAssertEqual(
            abs(try XCTUnwrap(samples.last?["x"]) - XCTUnwrap(samples.first?["x"])),
            Double(distance),
            accuracy: 1
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(after["maxOffset"] as? Double) - XCTUnwrap(after["minOffset"] as? Double),
            width * 0.5
        )
        XCTAssertEqual(
            try XCTUnwrap(after["offset"] as? Double),
            try XCTUnwrap(before["offset"] as? Double) + (movesLeft ? width : -width),
            accuracy: 1
        )
        XCTAssertEqual(after["dragging"] as? Bool, false)
        XCTAssertEqual(after["decelerating"] as? Bool, false)
    }

    func testSectionStartEdgeHandoff() throws {
        for section in [0, 1] {
            let y = try sectionY(section)
            try assertPageDrag(y: y, movesLeft: false, expectedPage: "saved")
            try assertPageDrag(y: y, movesLeft: true, expectedPage: "compositional")
        }
    }

    func testSectionEdgesRTL() throws {
        // 此 Demo 只强制容器 RTL；原生 Section 仍从左侧开始，按实际物理边界交接。
        for (section, key) in [(0, "continuous"), (1, "groupPaging")] {
            let y = try sectionY(section)
            try assertPageDrag(y: y, movesLeft: false, expectedPage: "topics")
            try assertPageDrag(y: y, movesLeft: true, expectedPage: "compositional")
            for _ in 0 ..< 15 {
                if try XCTUnwrap(geometry()[key + "RemainingRight"]) <= 0.5 {
                    break
                }
                try assertInnerGesture(section, from: 0.8, to: 0.2)
            }
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry()[key + "RemainingRight"]), 0.5)
            let end = try XCTUnwrap(geometry()[key])
            try assertPageDrag(y: y, movesLeft: true, expectedPage: "saved")
            try assertPageDrag(y: y, movesLeft: false, expectedPage: "compositional")
            XCTAssertEqual(try XCTUnwrap(geometry()[key]), end, accuracy: 2)
            try assertInnerGesture(section, from: 0.2, to: 0.8)
            XCTAssertLessThan(try XCTUnwrap(geometry()[key]), end - 40)
        }
    }

    func testHorizontalSectionsAndBothBoundaries() throws {
        for (section, key) in [(0, "continuous"), (1, "groupPaging")] {
            let initial = try XCTUnwrap(geometry()[key])
            try assertInnerGesture(section, from: 0.8, to: 0.2)
            XCTAssertGreaterThan(try XCTUnwrap(geometry()[key]), initial + 40)
            try assertInnerGesture(section, from: 0.8, to: 0.2, dy: 20)
            // 快速连续输入后检查新触摸能否继续改变内部偏移。
            try assertInnerGesture(section, from: 0.8, to: 0.2, velocity: .fast, hold: 0)
            try assertInnerGesture(section, from: 0.2, to: 0.8, velocity: .fast, hold: 0)
            for _ in 0 ..< 15 {
                if try XCTUnwrap(geometry()[key + "RemainingRight"]) <= 0.5 {
                    break
                }
                try assertInnerGesture(section, from: 0.8, to: 0.2)
            }
            XCTAssertLessThanOrEqual(try XCTUnwrap(geometry()[key + "RemainingRight"]), 0.5)
            let end = try XCTUnwrap(geometry()[key])
            XCTAssertGreaterThan(end, initial + 500)
            let y = try sectionY(section)
            try assertPageDrag(y: y, movesLeft: true, expectedPage: "topics")
            try assertPageDrag(y: y, movesLeft: false, expectedPage: "compositional")
            XCTAssertEqual(try XCTUnwrap(geometry()[key]), end, accuracy: 2)
            try assertInnerGesture(section, from: 0.2, to: 0.8)
            XCTAssertLessThan(try XCTUnwrap(geometry()[key]), end - 40, "到达末端后新触摸应仍能返回")
        }
    }

    func testVerticalHeaderPagingAndPositionRestoration() throws {
        // 先在横向卡片上纵向拖动，验证正交滚动不会吞掉外层纵向手势。
        let initialY = collection.frame.minY
        drag(y: try sectionY(0), from: 0.5, to: 0.51, dy: -180)
        expectPage("compositional")
        _ = try trace()
        XCTAssertLessThan(collection.frame.minY, initialY - 30)
        collection.swipeUp()
        XCTAssertTrue((status.value as? String)?.contains("progress=1.00") == true)
        XCTAssertEqual(collection.frame.minY, app.collectionViews["sp.tabBar.collection"].frame.minY, accuracy: 1)
        let before = try XCTUnwrap(geometry()["position"])
        XCTAssertGreaterThan(before, 150)
        // 组合布局位于两个列表页之间，两侧均须用真实拖动越过半页并完整返回。
        for (movesLeft, neighbor) in [(false, "saved"), (true, "topics")] {
            let y = try sectionY(2)
            try assertPageDrag(y: y, movesLeft: movesLeft, expectedPage: neighbor)
            try assertPageDrag(y: y, movesLeft: !movesLeft, expectedPage: "compositional")
            XCTAssertEqual(try XCTUnwrap(geometry()["position"]), before, accuracy: 2)
            XCTAssertTrue((status.value as? String)?.contains("progress=1.00") == true)
        }
        collection.swipeDown()
        XCTAssertLessThan(try XCTUnwrap(geometry()["position"]), before - 40)
        for _ in 0 ..< 3 {
            collection.swipeDown()
        }
        XCTAssertTrue((status.value as? String)?.contains("progress=0.00") == true)
        XCTAssertEqual(collection.frame.minY, initialY, accuracy: 1)
    }

    func testHorizontalPositionsSurviveTabRoundTrip() throws {
        try assertInnerGesture(0, from: 0.8, to: 0.2)
        try assertInnerGesture(1, from: 0.8, to: 0.2)
        let before = try geometry()
        for (index, neighbor) in [(10, "saved"), (12, "topics")] {
            app.buttons["sp.tab.\(index)"].tap()
            expectPage(neighbor)
            app.buttons["sp.tab.11"].tap()
            expectPage("compositional")
            let after = try geometry()
            for key in ["continuous", "groupPaging", "position"] {
                XCTAssertEqual(try XCTUnwrap(after[key]), try XCTUnwrap(before[key]), accuracy: 2)
            }
        }
        try assertInnerGesture(0, from: 0.2, to: 0.8)
        XCTAssertLessThan(try XCTUnwrap(geometry()["continuous"]), try XCTUnwrap(before["continuous"]) - 40)
    }
}
