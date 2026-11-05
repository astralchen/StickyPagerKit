import CryptoKit
import UIKit
import XCTest
@testable import StickyPagerKit

/// 对照配置／tint 提交顺序时，保留模型、状态和静态渲染证据；不作为性能计时。
@MainActor
final class SPTabBarTintOrderingTests: XCTestCase {
    func testStateAndRenderingSnapshots() throws {
        var records: [[String: Any]] = []
        for channel in ["title", "icon", "both"] {
            for state in ["normal", "highlighted", "disabled", "dimmed"] {
                let fixture = try SPTabColorFixture(colors: true)
                defer { fixture.close() }
                if channel == "title" {
                    fixture.bar.standardAppearance.itemAppearance.selected.iconColor = .red
                }
                if channel == "icon" {
                    fixture.bar.standardAppearance.itemAppearance.selected.titleColor = .red
                }
                fixture.beginSelection()
                let button = try fixture.button(at: 1)
                if state == "highlighted" {
                    button.isHighlighted = true
                }
                if state == "disabled" {
                    fixture.bar.items[1].isEnabled = false
                }
                if state == "dimmed" {
                    fixture.bar.tintAdjustmentMode = .dimmed
                }
                fixture.bar.layoutIfNeeded()
                button.layoutIfNeeded()
                for progress: CGFloat in [0.2, 0.5, 0.8] {
                    fixture.bar.setTransitionProgress(from: 0, to: 1, progress: progress)
                    let immediate = model(button)
                    fixture.bar.layoutIfNeeded()
                    button.layoutIfNeeded()
                    XCTAssertEqual(button.configuration?.title, "标签 1")
                    XCTAssertEqual(button.isHighlighted, state == "highlighted")
                    XCTAssertEqual(button.isEnabled, state != "disabled")
                    let rendered = UIGraphicsImageRenderer(bounds: button.bounds).image { context in
                        button.layer.render(in: context.cgContext)
                    }
                    let data = try XCTUnwrap(rendered.pngData())
                    let name = "\(channel)-\(state)-\(Int(progress * 100))"
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                    attachment.name = name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    records.append([
                        "name": name,
                        "immediate": immediate,
                        "afterLayout": model(button),
                        "renderedSHA256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    ])
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["schema": "sp-tint-ordering-v1", "records": records])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "tint-ordering"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func model(_ button: UIButton) -> [String: Any] {
        [
            "tint": rgba(button.tintColor),
            "title": rgba(button.titleLabel?.textColor),
            "imageTint": rgba(button.imageView?.tintColor),
            "foreground": rgba(button.configuration?.baseForegroundColor),
            "buttonFrame": components(button.frame),
            "titleFrame": components(button.titleLabel?.frame ?? .zero),
            "imageFrame": components(button.imageView?.frame ?? .zero),
            "enabled": button.isEnabled,
            "highlighted": button.isHighlighted,
            "adjustment": button.tintAdjustmentMode.rawValue
        ]
    }

    private func components(_ rect: CGRect) -> [Double] {
        [rect.origin.x, rect.origin.y, rect.width, rect.height].map(Double.init)
    }

    private func rgba(_ color: UIColor?) -> [Double] {
        guard let color else {
            return []
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return []
        }
        return [red, green, blue, alpha].map(Double.init)
    }
}
