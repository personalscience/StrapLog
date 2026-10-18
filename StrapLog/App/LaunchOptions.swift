import Foundation

/// Launch arguments that switch the app off the real strap, for the simulator and UI tests.
/// Debug builds only: a Release build ignores them and always records from the strap.
///
///     -replay <fixture>   play Tests/fixtures/<fixture>.json instead of connecting to the H10
///     -speed <x>          replay speed multiplier (default 1)
///     -freshDatabase      use an empty database in the temp directory and unedited marker bars (UI tests)
struct LaunchOptions: Equatable {
    var replayFixture: String?
    var replaySpeed: Double = 1
    var freshDatabase = false

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        #if DEBUG
        var it = arguments.makeIterator()
        while let arg = it.next() {
            switch arg {
            case "-replay": replayFixture = it.next()
            case "-speed": replaySpeed = it.next().flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil } ?? 1
            case "-freshDatabase": freshDatabase = true
            default: continue
            }
        }
        #endif
    }
}
