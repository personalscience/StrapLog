import Foundation

/// What the chart is looking at: a span, and where it ends. `anchorEndMs` nil follows the end
/// (now, on the live screen); panning back pins it, panning to the end lets go again.
/// `highlightMs` is the marker last jumped to, drawn stronger than the rest.
public struct ChartViewport: Sendable, Equatable {
    public var span: ChartSpan
    public var anchorEndMs: Int64?
    public var highlightMs: Int64?

    /// Span a jump uses when the chart shows the whole recording.
    public static let jumpSpan = ChartSpan.fiveMinutes

    public init(span: ChartSpan = .default, anchorEndMs: Int64? = nil, highlightMs: Int64? = nil) {
        self.span = span
        self.anchorEndMs = anchorEndMs
        self.highlightMs = highlightMs
    }

    /// Whether the view is pinned behind the end rather than following it.
    public var isPinned: Bool { anchorEndMs != nil }

    /// The range to draw, with the anchor clamped into the recording.
    public func window(nowMs: Int64, startedAtMs: Int64) -> ChartWindow {
        ChartWindow(span: span, endMs: endMs(nowMs: nowMs, startedAtMs: startedAtMs), startedAtMs: startedAtMs)
    }

    /// Steps the span by a pinch; the end stays where it is.
    public func zoomed(by magnification: Double, nowMs: Int64, startedAtMs: Int64) -> ChartViewport {
        var out = self
        out.span = span.zoomed(by: magnification, elapsedMs: nowMs - startedAtMs)
        return out.clamped(nowMs: nowMs, startedAtMs: startedAtMs)
    }

    /// Moves the end by `ms` (negative is back in time). Reaching the end follows it again.
    public func panned(byMs ms: Int64, nowMs: Int64, startedAtMs: Int64) -> ChartViewport {
        guard span != .all else { return self }
        var out = self
        out.anchorEndMs = endMs(nowMs: nowMs, startedAtMs: startedAtMs) + ms
        return out.clamped(nowMs: nowMs, startedAtMs: startedAtMs)
    }

    /// Centres `atMs` in the current span (`jumpSpan` if showing everything) and highlights it.
    public func jump(toMs atMs: Int64, nowMs: Int64, startedAtMs: Int64) -> ChartViewport {
        let span = span == .all ? Self.jumpSpan : span
        let half = span.lengthMs(elapsedMs: nowMs - startedAtMs) / 2
        return ChartViewport(span: span, anchorEndMs: atMs + half, highlightMs: atMs)
            .clamped(nowMs: nowMs, startedAtMs: startedAtMs)
    }

    /// The end the window uses: the anchor kept within `[start + length, now]`, or now.
    private func endMs(nowMs: Int64, startedAtMs: Int64) -> Int64 {
        guard let anchorEndMs, span != .all else { return nowMs }
        let earliest = min(startedAtMs + span.lengthMs(elapsedMs: nowMs - startedAtMs), nowMs)
        return min(max(anchorEndMs, earliest), nowMs)
    }

    /// Drops an anchor that sits at (or past) the end, so the view follows again.
    private func clamped(nowMs: Int64, startedAtMs: Int64) -> ChartViewport {
        var out = self
        let end = endMs(nowMs: nowMs, startedAtMs: startedAtMs)
        out.anchorEndMs = end >= nowMs ? nil : end
        return out
    }
}

/// A JSON string, so `@SceneStorage` can keep the live chart's viewport.
extension ChartViewport: RawRepresentable {
    private struct Stored: Codable {
        var span: Int
        var anchorEndMs: Int64?
        var highlightMs: Int64?
    }

    public init?(rawValue: String) {
        guard let stored = try? JSONDecoder().decode(Stored.self, from: Data(rawValue.utf8)),
              let span = ChartSpan(rawValue: stored.span) else { return nil }
        self.init(span: span, anchorEndMs: stored.anchorEndMs, highlightMs: stored.highlightMs)
    }

    /// Sorted keys keep the string stable: with `RawRepresentable`, `==` can resolve to the
    /// stdlib overload that compares raw values, and unsorted JSON key order varies per run.
    public var rawValue: String {
        let stored = Stored(span: span.rawValue, anchorEndMs: anchorEndMs, highlightMs: highlightMs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: (try? encoder.encode(stored)) ?? Data(), as: UTF8.self)
    }
}
