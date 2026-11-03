import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarColorDiagnosticsTests: XCTestCase {
    private func record(_ name: String, _ statistics: SPTabColorStatistics) throws {
        let data = try JSONEncoder().encode(statistics)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRepeatedProgressSkipsButtonAssignmentsWhileChangedProgressKeepsCellCache() throws {
        let fixture = try SPTabColorFixture(colors: true)
        defer { fixture.close() }
        let diagnostics = SPTabColorDiagnostics()
        try fixture.attach(diagnostics)
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        diagnostics.statistics = .init()
        let refresh = fixture.bar.refreshStatistics
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.2)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 0)
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.3)
        XCTAssertEqual(diagnostics.statistics.baseConfigurationAssignments, 0)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 2)
        XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, 2)
        XCTAssertEqual(diagnostics.statistics.titleColorEvaluations, 2)
        XCTAssertEqual(diagnostics.statistics.iconColorEvaluations, 2)
        XCTAssertEqual(fixture.bar.refreshStatistics, refresh)
        try record("同进度跳过与双项变化", diagnostics.statistics)
    }

    func testCommitAndFrameWorkAreRecordedSeparatelyWithoutChangingRendering() throws {
        for enabled in [false, true] {
            let fixture = try SPTabColorFixture(colors: enabled)
            defer { fixture.close() }
            let diagnostics = SPTabColorDiagnostics()
            try fixture.attach(diagnostics)
            fixture.beginSelection()
            XCTAssertGreaterThan(diagnostics.statistics.baseConfigurationAssignments, 0)
            try record("选择提交-颜色\(enabled)", diagnostics.statistics)
            diagnostics.statistics = .init()
            let refresh = fixture.bar.refreshStatistics
            let image = try fixture.button(at: 1).configuration?.image
            fixture.frames(30)
            XCTAssertEqual(diagnostics.statistics.baseConfigurationAssignments, 0)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, enabled ? 60 : 0)
            XCTAssertEqual(fixture.bar.refreshStatistics, refresh)
            XCTAssertTrue(try fixture.button(at: 1).configuration?.image === image)
            XCTAssertEqual(fixture.bar.selectedIndex, 1)
            try record("三十个进度点-颜色\(enabled)", diagnostics.statistics)
            try fixture.attach(nil)
            let detached = diagnostics.statistics
            fixture.bar.setSelectedIndex(2, animated: false)
            XCTAssertEqual(diagnostics.statistics, detached)
        }
    }

    func testDiagnosticVariantsPreserveTitleAndImageSemantics() throws {
        for variant in ["titleOnly", "imageOnly", "originalImage", "equalEndpoints"] {
            let fixture = try SPTabColorFixture(colors: true)
            defer { fixture.close() }
            switch variant {
            case "titleOnly": fixture.bar.items.forEach { $0.image = nil }
            case "imageOnly": fixture.bar.items.forEach { $0.title = nil }
            case "originalImage":
                fixture.bar.items.forEach { $0.image = $0.image?.withRenderingMode(.alwaysOriginal) }
            default:
                fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .red
                fixture.bar.standardAppearance.itemAppearance.selected.iconColor = .red
            }
            fixture.bar.layoutIfNeeded()
            fixture.beginSelection()
            let diagnostics = SPTabColorDiagnostics()
            try fixture.attach(diagnostics)
            fixture.frames(30)
            let button = try fixture.button(at: 1)
            if variant == "titleOnly" {
                XCTAssertNil(button.configuration?.image)
            }
            if variant == "imageOnly" {
                XCTAssertNil(button.configuration?.title)
            }
            if variant == "originalImage" {
                XCTAssertEqual(button.configuration?.image?.renderingMode, .alwaysOriginal)
                XCTAssertEqual(diagnostics.statistics.iconColorEvaluations, 0)
            }
            if variant == "equalEndpoints" {
                let attributes = button.configuration?.titleTextAttributesTransformer?(AttributeContainer())
                XCTAssertEqual(attributes?.foregroundColor, UIColor.red)
            }
            // 记录无标题、等色端点等当前成本，不把冗余工作次数固化为行为契约。
            try record(variant, diagnostics.statistics)
        }
    }

    func testRetargetAndPagingTakeoverKeepDiagnosticsLocalToContent() throws {
        let fixture = try SPTabColorFixture(colors: true, combined: true)
        defer { fixture.close() }
        let diagnostics = SPTabColorDiagnostics()
        try fixture.attach(diagnostics)
        fixture.beginSelection()
        fixture.bar.advanceSelectionAnimation(to: 0.25)
        fixture.bar.setSelectedIndex(2, animated: true)
        fixture.bar.advanceSelectionAnimation(to: 0.25)
        fixture.bar.setTransitionProgress(from: 2, to: 0, progress: 0)
        diagnostics.statistics = .init()
        fixture.bar.setTransitionProgress(from: 2, to: 0, progress: 0.2)
        XCTAssertEqual(diagnostics.statistics.baseConfigurationAssignments, 0)
        XCTAssertGreaterThan(diagnostics.statistics.colorConfigurationAssignments, 2)
        try record("改选后分页接管的多项权重", diagnostics.statistics)
        fixture.bar.setSelectedIndex(2, animated: false)
        XCTAssertEqual(fixture.bar.selectedIndex, 2)
    }
}
