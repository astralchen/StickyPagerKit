import XCTest
import UIKit
@testable import StickyPagerKit

@MainActor
final class SPTabBarPresentationCoordinatorTests: XCTestCase {
    func testOldCompletionCannotStopAnimationStartedWhileApplyingFrame() {
        let coordinator = SPTabBarPresentationCoordinator()
        var targets: [Int?] = []
        coordinator.onFrame = { frame in
            targets.append(frame.to)
            if frame.to == 1, frame.progress == 1 {
                coordinator.startAnimation(self.animation(from: 1, to: 2))
            }
        }
        coordinator.startAnimation(animation(from: 0, to: 1))
        coordinator.advance(to: 1)
        XCTAssertEqual(coordinator.animation?.toIndex, 2)
        coordinator.advance(to: 0.5)
        XCTAssertEqual(targets, [1, 1, 2, 2])
        coordinator.onFrame = nil
        coordinator.stopAnimation()
    }

    func testPagingTakeoverRejectsLaterAnimationTicksAndResetDropsOrigin() {
        let coordinator = SPTabBarPresentationCoordinator()
        var count = 0
        coordinator.onFrame = { _ in count += 1 }
        coordinator.startAnimation(animation(from: 0, to: 3))
        coordinator.advance(to: 0.3)
        let origin = SPTabBarPresentationCoordinator.Origin(
            indicator: CGRect(x: 30, y: 0, width: 20, height: 3),
            offset: 40,
            fromGeometry: .zero,
            toGeometry: .zero
        )
        coordinator.setTransition(from: 3, to: 2, progress: 0.2, takeoverOrigin: origin)
        let before = count
        coordinator.advance(to: 1)
        XCTAssertEqual(count, before)
        XCTAssertNil(coordinator.animation)
        coordinator.setTransition(from: 3, to: 2, progress: 0.6, takeoverOrigin: nil)
        XCTAssertEqual(coordinator.origin?.offset, 40)
        coordinator.resetMotion()
        XCTAssertNil(coordinator.transition)
        XCTAssertNil(coordinator.origin)
    }

    private func animation(from: Int, to: Int) -> SPTabBarPresentationCoordinator.Animation {
        .init(
            fromIndex: from,
            toIndex: to,
            fromIndicator: CGRect(x: from * 50, y: 0, width: 20, height: 3),
            toIndicator: CGRect(x: to * 50, y: 0, width: 20, height: 3),
            fromGeometry: .zero,
            fromOffset: CGFloat(from * 20),
            toOffset: CGFloat(to * 20),
            startTime: CACurrentMediaTime()
        )
    }
}
