/// Where the sensor is worn. Posture (`PostureTracker`) reads torso axes, so it is tracked only
/// for a chest sensor; an arm's gravity vector says nothing about lying down.
public enum SensorPlacement: Sendable, Equatable {
    case chest
    case arm
}
