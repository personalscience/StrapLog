import StrapLogCore
import SwiftUI

extension AppPhase {
    /// nil for `.inactive`, the brief state between the two (app switcher, alerts).
    init?(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .foreground
        case .background: self = .background
        default: return nil
        }
    }
}
