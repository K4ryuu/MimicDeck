// SwiftUI leaves the arrow cursor over a Link, which makes clickable text feel
// dead. This puts the pointing hand back.

import AppKit
import SwiftUI

extension View {
    func pointingHandCursor() -> some View {
        onHover { isInside in
            if isInside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
