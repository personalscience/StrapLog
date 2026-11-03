/// A note being typed. Its marker is dated when the user began it, not when they finished typing.
public struct NoteDraft: Identifiable, Sendable, Hashable {
    public let startedAtMs: Int64
    public var id: Int64 { startedAtMs }

    public init(startedAtMs: Int64) {
        self.startedAtMs = startedAtMs
    }
}
