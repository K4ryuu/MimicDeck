// Shared by AutoClickerConfig and MacroStep.click, so neither owns it.

import CoreGraphics
import Foundation

nonisolated enum MouseButton: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case left
    case right
    case middle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:   "Left click"
        case .right:  "Right click"
        case .middle: "Middle click"
        }
    }

    var cgButton: CGMouseButton {
        switch self {
        case .left:   .left
        case .right:  .right
        case .middle: .center
        }
    }

    var downType: CGEventType {
        switch self {
        case .left:   .leftMouseDown
        case .right:  .rightMouseDown
        case .middle: .otherMouseDown
        }
    }

    var upType: CGEventType {
        switch self {
        case .left:   .leftMouseUp
        case .right:  .rightMouseUp
        case .middle: .otherMouseUp
        }
    }
}
