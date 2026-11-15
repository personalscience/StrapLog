/// One temperature report from a wearable (the BaroShift armband's vendor frame `0x38`, which
/// changes about once a minute), in tenths of a degree Celsius. Which sensor each value comes from
/// is inferred from captures, not documented: `ambient` warms slowly after the band goes on
/// (23 → 26 °C over 3 min, 2026-11-03), `skin` runs a few degrees above it, and `body` sits near
/// 35–36.5 °C as if estimated from the other two.
public struct TemperatureReading: Sendable, Equatable {
    public var ambientDeci: Int
    public var skinDeci: Int
    public var bodyDeci: Int

    public init(ambientDeci: Int, skinDeci: Int, bodyDeci: Int) {
        self.ambientDeci = ambientDeci
        self.skinDeci = skinDeci
        self.bodyDeci = bodyDeci
    }
}
