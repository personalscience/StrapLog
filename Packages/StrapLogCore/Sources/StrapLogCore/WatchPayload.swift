import Foundation

/// The WatchConnectivity wire format, both ways. Payloads are property-list dictionaries, so
/// each value travels as JSON `Data` under one key: the phone's application context carries
/// `LiveStatus` (absent while idle), a Watch message carries one `RemoteCommand`, and the
/// phone answers a start or stop with a `CommandReply`. A start or stop also goes as
/// complication user info, which wakes a Watch app whose complication is on the face.
public enum WatchPayload {
    static let statusKey = "status"
    static let commandKey = "command"
    static let replyKey = "reply"
    static let complicationKey = "complication"

    /// The application context for `status`; empty when no recording is open.
    public static func context(for status: LiveStatus?) -> [String: Any] {
        guard let data = status.flatMap({ try? JSONEncoder().encode($0) }) else { return [:] }
        return [statusKey: data]
    }

    /// The status in `context`, or nil when idle or unreadable (an older or newer phone app).
    public static func status(in context: [String: Any]) -> LiveStatus? {
        (context[statusKey] as? Data).flatMap { try? JSONDecoder().decode(LiveStatus.self, from: $0) }
    }

    /// Complication user info for `status`: the application context, marked so an idle one
    /// (no status) is not empty.
    public static func complicationInfo(for status: LiveStatus?) -> [String: Any] {
        context(for: status).merging([complicationKey: true]) { current, _ in current }
    }

    /// Whether `userInfo` is complication user info rather than a queued command.
    public static func isComplicationInfo(_ userInfo: [String: Any]) -> Bool {
        userInfo[complicationKey] as? Bool == true
    }

    public static func message(for command: RemoteCommand) -> [String: Any] {
        // A plain enum of strings always encodes.
        [commandKey: try! JSONEncoder().encode(command)]
    }

    /// The command in `message`, or nil when it carries none.
    public static func command(in message: [String: Any]) -> RemoteCommand? {
        (message[commandKey] as? Data).flatMap { try? JSONDecoder().decode(RemoteCommand.self, from: $0) }
    }

    public static func message(for reply: CommandReply) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(reply) else { return [:] }
        return [replyKey: data]
    }

    /// The reply in `message`, or nil when unreadable.
    public static func reply(in message: [String: Any]) -> CommandReply? {
        (message[replyKey] as? Data).flatMap { try? JSONDecoder().decode(CommandReply.self, from: $0) }
    }
}
