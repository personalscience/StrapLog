@preconcurrency import PolarBleSdk

/// Proves the Polar SDK resolves and links in the app target.
/// Phase 3 replaces this with `PolarHeartSource`, the only file allowed to import PolarBleSdk.
enum PolarSDKLink {
    static let featureCount = PolarBleSdkFeature.allCases.count
}
