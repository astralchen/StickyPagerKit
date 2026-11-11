import UIKit

/// 一次性验证的页面快照；标识、标签和索引映射始终一起替换。
@MainActor
internal struct SPPageSnapshot {
    let identifiers: [AnyHashable]
    let items: [SPTabBarItem]
    var topBounceBehaviors: [AnyHashable: SPTopBounceBehavior] = [:]
    private let indices: [AnyHashable: Int]

    static let empty = SPPageSnapshot(identifiers: [], items: [])!

    init?(identifiers: [AnyHashable], items: [SPTabBarItem]) {
        guard identifiers.count == items.count else {
            return nil
        }
        guard Set(items.map(ObjectIdentifier.init)).count == items.count else {
            NSLog("StickyPagerKit: reloadData 拒绝重复标签对象")
            return nil
        }
        guard Set(identifiers).count == identifiers.count else {
            NSLog("StickyPagerKit: reloadData 拒绝重复页面标识")
            return nil
        }
        self.identifiers = identifiers
        self.items = items
        indices = Dictionary(uniqueKeysWithValues: identifiers.enumerated().map { ($0.element, $0.offset) })
    }

    func index(of identifier: AnyHashable) -> Int? {
        indices[identifier]
    }
}

/// 只管理页面数据和保留策略；创建、挂载及解绑由容器在正确的 UIKit 时序执行。
@MainActor
internal final class SPPageStore {
    private(set) var snapshot = SPPageSnapshot.empty
    private(set) var records: [AnyHashable: SPPageRecord] = [:]
    private var positions: [AnyHashable: CGFloat] = [:]
    private var bindingSelections: [AnyHashable: SPScrollViewBindingSelection] = [:]
    private var topBounceOverrides: [AnyHashable: SPTopBounceBehavior] = [:]
    private var accessCounter: UInt = 0

    func apply(_ snapshot: SPPageSnapshot) {
        positions = positions.filter { snapshot.index(of: $0.key) != nil }
        bindingSelections = bindingSelections.filter { snapshot.index(of: $0.key) != nil }
        topBounceOverrides = topBounceOverrides.filter { snapshot.index(of: $0.key) != nil }
        self.snapshot = snapshot
    }

    func topBounceBehavior(for identifier: AnyHashable) -> SPTopBounceBehavior? {
        topBounceOverrides[identifier] ?? snapshot.topBounceBehaviors[identifier]
    }

    func setTopBounceBehavior(_ behavior: SPTopBounceBehavior?, for identifier: AnyHashable) {
        guard snapshot.index(of: identifier) != nil else {
            return
        }
        topBounceOverrides[identifier] = behavior
    }

    func advanceAccess() {
        accessCounter &+= 1
    }

    func accessRecord(_ identifier: AnyHashable) -> SPPageRecord? {
        let record = records[identifier]
        record?.access = accessCounter
        return record
    }

    func insert(_ record: SPPageRecord) {
        record.access = accessCounter
        records[record.identifier] = record
    }

    func remove(_ identifier: AnyHashable) -> SPPageRecord? {
        // 淘汰实例保留业务位置和运行时绑定选择；仅快照删除标识时清除历史。
        records.removeValue(forKey: identifier)
    }

    func position(for identifier: AnyHashable) -> CGFloat? {
        positions[identifier]
    }

    func setPosition(_ value: CGFloat, for identifier: AnyHashable) {
        positions[identifier] = value
    }

    func clampPosition(for identifier: AnyHashable, maximum: CGFloat) {
        positions[identifier] = min(positions[identifier] ?? 0, maximum)
    }

    func bindingSelection(for identifier: AnyHashable) -> SPScrollViewBindingSelection? {
        bindingSelections[identifier]
    }

    func setBindingSelection(_ value: SPScrollViewBindingSelection, for identifier: AnyHashable) {
        bindingSelections[identifier] = value
    }

    func evictionCandidates(protecting identifiers: Set<AnyHashable>) -> [SPPageRecord] {
        records.values.filter { !identifiers.contains($0.identifier) }.sorted { $0.access < $1.access }
    }
}
