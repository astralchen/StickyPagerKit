import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarColorOptimizationTests: XCTestCase {
    func testAbsentOrEmptyTitleDoesNotCreateColorTransformer() throws {
        for title: String? in [nil, ""] {
            let fixture = try SPTabColorFixture(colors: true)
            defer { fixture.close() }
            fixture.bar.items.forEach { $0.title = title }
            fixture.bar.layoutIfNeeded()
            fixture.beginSelection()
            let diagnostics = SPTabColorDiagnostics()
            try fixture.attach(diagnostics)
            fixture.frames(30, flushButtons: true)
            XCTAssertEqual(diagnostics.statistics.titleColorEvaluations, 0)
            XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, 0)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 60)
            XCTAssertEqual(try fixture.button(at: 1).configuration?.baseForegroundColor, UIColor.blue)
            // 原色图片也不参与着色；两种通道均无可见内容时不再写入配置。
            fixture.bar.items.forEach { $0.image = $0.image?.withRenderingMode(.alwaysOriginal) }
            fixture.bar.layoutIfNeeded()
            fixture.beginSelection()
            diagnostics.statistics = .init()
            fixture.frames(30)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 0)
            XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, 0)
        }
    }

    func testEqualEndpointsSkipAssignmentsAndSingleChannelKeepsOtherAttributes() throws {
        for changingIcon in [false, true] {
            let fixture = try SPTabColorFixture(colors: true)
            defer { fixture.close() }
            fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .red
            fixture.bar.standardAppearance.itemAppearance.selected.iconColor = .red
            fixture.beginSelection()
            let diagnostics = SPTabColorDiagnostics()
            try fixture.attach(diagnostics)
            fixture.frames(30, flushButtons: true)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 0)
            XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, 0)
            if changingIcon {
                fixture.bar.standardAppearance.itemAppearance.selected.iconColor = .blue
            } else {
                fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .blue
            }
            fixture.beginSelection()
            let button = try fixture.button(at: 1)
            let image = button.configuration?.image
            let font = button.configuration?.titleTextAttributesTransformer?(AttributeContainer()).uiKit.font
            diagnostics.statistics = .init()
            fixture.frames(30, flushButtons: true)
            XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 60)
            XCTAssertEqual(diagnostics.statistics.titleTransformerCreations, changingIcon ? 0 : 60)
            XCTAssertEqual(button.titleLabel?.textColor, changingIcon ? UIColor.red : UIColor.blue)
            XCTAssertEqual(button.configuration?.baseForegroundColor, changingIcon ? UIColor.blue : UIColor.red)
            XCTAssertEqual(button.configuration?.titleTextAttributesTransformer?(AttributeContainer()).uiKit.font, font)
            XCTAssertTrue(button.configuration?.image === image)
        }
    }

    func testDifferentProgressWithSameResolvedColorSkipsWriteButCanResume() throws {
        let fixture = try SPTabColorFixture(colors: true)
        defer { fixture.close() }
        let cell = try XCTUnwrap(fixture.collection.cellForItem(at: IndexPath(item: 1, section: 0)))
        let content = try XCTUnwrap(cell.contentView as? SPTabContentProgressDisplaying)
        let diagnostics = SPTabColorDiagnostics()
        try fixture.attach(diagnostics)
        content.updateSelectionProgress(-1)
        content.updateSelectionProgress(-2)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 0)
        content.updateSelectionProgress(0.5)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 1)
        content.updateSelectionProgress(1)
        diagnostics.statistics = .init()
        content.updateSelectionProgress(2)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 0)
        content.updateSelectionProgress(0)
        XCTAssertEqual(diagnostics.statistics.colorConfigurationAssignments, 1)
        XCTAssertEqual(try fixture.button(at: 1).configuration?.baseForegroundColor, UIColor.red)
    }

    func testNewSnapshotRestoresColorsAfterTitleRemovalAndAttributeChanges() throws {
        let fixture = try SPTabColorFixture(colors: true)
        defer { fixture.close() }
        let item = fixture.bar.items[1]
        item.title = nil
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.5)
        let font = UIFont.systemFont(ofSize: 23, weight: .bold)
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: 1, height: 2)
        item.setTitleTextAttributes([.font: font, .shadow: shadow], for: .normal)
        item.title = "恢复标题"
        fixture.bar.layoutIfNeeded()
        fixture.bar.setTransitionProgress(from: 0, to: 1, progress: 0.5)
        let button = try fixture.button(at: 1)
        let attributes = try XCTUnwrap(button.configuration?.titleTextAttributesTransformer?(AttributeContainer()))
        let expectedFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: font,
            compatibleWith: fixture.bar.traitCollection
        )
        XCTAssertEqual(attributes.uiKit.font, expectedFont)
        XCTAssertEqual(attributes.shadow?.shadowOffset, shadow.shadowOffset)
        button.layoutIfNeeded()
        XCTAssertEqual(button.titleLabel?.textColor, UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1))
        fixture.bar.visualStyle.interpolatesDefaultColors = false
        fixture.bar.layoutIfNeeded()
        button.layoutIfNeeded()
        // 关闭连续效果后，0.5 的分页进度按既有离散规则呈现目标项。
        XCTAssertEqual(button.titleLabel?.textColor, UIColor.blue)
    }
}
