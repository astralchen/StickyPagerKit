import UIKit

/// 仅用于呈现的进度快照，不具有提交选中页的权力。
@MainActor
internal struct SPPagingProgress {
    let fromID: AnyHashable
    let toID: AnyHashable
    let fromIndex: Int
    let toIndex: Int
    let fraction: CGFloat
    let snapshotGeneration: UInt
    let selectionGeneration: UInt

    func isCurrent(snapshot: SPPageSnapshot, snapshotGeneration: UInt, selectionGeneration: UInt) -> Bool {
        self.snapshotGeneration == snapshotGeneration && self.selectionGeneration == selectionGeneration
            && snapshot.index(of: fromID) == fromIndex && snapshot.index(of: toID) == toIndex
    }
}
