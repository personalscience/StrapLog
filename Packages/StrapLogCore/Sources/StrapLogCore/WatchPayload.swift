import Foundation

/// The WatchConnectivity wire format, both ways. Payloads are property-list dictionaries, so
/// each value travels as JSON `Data` under one key: the phone's application context carries
/// `LiveStatus` (absent while idle), and a Watch message carries one `RemoteCommand`.
public enum WatchPayload {
    static let statusKey = "status"
    static let commandKey = "command"

    /// The application context for `status`; empty when no recording is open.
    public static func context(for status: LiveStatus?) -> [String: Any] {
        guard let data = status.flatMap({ try? JSONEncoder().encode($0) }) else { return [:] }
        return [statusKey: data]
    }

    /// The status in `context`, or nil when idle or unreadable (an older or newer phone app).
    public static func status(in context: [String: Any]) -> LiveStatus? {
        (context[statusKey] as? Data).flatMap { try? JSONDecoder().decode(LiveStatus.self, from: $0) }
    }

    public static func message(for command: RemoteCommand) -> [String: Any] {
        // A plain enum of strings always encodes.
        [commandKey: try! JSONEncoder().encode(command)]
    }

    /// The command in `message`, or nil when it carries none.
    public static func command(in message: [String: Any]) -> RemoteCommand? {
        (message[commandKey] as? Data).flatMap { try? JSONDecoder().decode(RemoteCommand.self, from: $0) }
    }
}
