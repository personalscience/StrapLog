/// A breathing rate as the training voice says it: `5.5` → `five and a half`, `7` → `seven`.
/// Whole and half rates are words (every rate `BreathingPacer` takes); anything else is digits.
public enum SpokenRate {
    private static let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
                                "ten", "eleven", "twelve"]

    public static func words(_ rate: Double) -> String {
        let whole = rate.rounded(.down)
        let half = rate - whole
        guard rate >= 0, Int(whole) < words.count, half == 0 || half == 0.5 else {
            return String(format: "%g", rate)
        }
        let name = words[Int(whole)]
        return half == 0 ? name : (whole == 0 ? "a half" : name + " and a half")
    }
}
