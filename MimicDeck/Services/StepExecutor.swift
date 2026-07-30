// Seam so MacroEngine can run against a fake instead of firing real
// events into the system. EventTapService is the real one.

import Foundation

@MainActor
protocol StepExecutor: AnyObject {
    func execute(_ step: MacroStep) async
}
