import UIKit

internal enum SPScrollGeometry {
    static func collapse(_ position: CGFloat, range: CGFloat) -> CGFloat {
        min(max(position, 0), max(range, 0))
    }

    static func content(_ position: CGFloat, range: CGFloat) -> CGFloat {
        max(0, position - max(0, range))
    }

    static func position(collapse: CGFloat, content: CGFloat, range: CGFloat) -> CGFloat {
        collapse < range ? max(0, collapse) : range + max(0, content)
    }

    static func shortContentInset(
        height: CGFloat,
        contentHeight: CGFloat,
        baseTop: CGFloat,
        baseBottom: CGFloat
    ) -> CGFloat {
        max(0, height - contentHeight - baseTop - baseBottom)
    }

    static func selectedIndex(oldID: AnyHashable?, oldIndex: Int?, identifiers: [AnyHashable]) -> Int? {
        guard !identifiers.isEmpty else {
            return nil
        }
        if let oldID, let index = identifiers.firstIndex(of: oldID) {
            return index
        }
        return min(oldIndex ?? 0, identifiers.count - 1)
    }
}
