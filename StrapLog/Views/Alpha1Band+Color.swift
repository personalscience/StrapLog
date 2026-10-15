import StrapLogCore
import SwiftUI

extension Alpha1Band {
    var color: Color {
        switch self {
        case .rest: .blue
        case .easy: .green
        case .moderate: .orange
        case .veryHard: .red
        }
    }
}
