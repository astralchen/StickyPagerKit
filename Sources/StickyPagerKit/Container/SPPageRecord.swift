import UIKit

@MainActor
internal final class SPPageRecord {
    let identifier: AnyHashable
    let controller: UIViewController
    let safeArea: SPPageSafeArea
    var binding: SPScrollBinding?
    var isPreparingBinding = true
    var isBinding = false
    var needsBinding = false
    var scrollViewSelection = SPScrollViewBindingSelection(.automatic)
    var access: UInt = 0
    init(identifier: AnyHashable, controller: UIViewController) {
        self.identifier = identifier
        self.controller = controller
        safeArea = SPPageSafeArea(controller: controller)
    }
}
