import Foundation

/// The app's version as an Info.plist stamped by tools/stamp_build.sh shows it, so a recording
/// (phone) or a screen (Watch) can be tied to the build that made it.
public enum BuildStamp {
    /// `1.1 (67)`: version and build number (the git commit count).
    public static func short(_ info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let number = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(number))"
    }

    /// `1.1 (67) · dd795a4-dirty`: `short` plus the commit.
    public static func full(_ info: [String: Any]) -> String {
        "\(short(info)) · \(info["StrapLogCommit"] as? String ?? "unstamped")"
    }
}
