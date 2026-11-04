/// Daily hydration goal derived from body weight.
public enum HydrationGoal {
    public static let mlPerKg = 33
    public static let minimumMl = 1500
    public static let maximumMl = 4000
    public static let roundingMl = 100

    /// Daily goal in mL: weight × 33 mL/kg, rounded to the nearest 100 mL and
    /// clamped to 1 500 – 4 000.
    public static func dailyMl(weightKg: Int) -> Int {
        // Clamped first: the result saturates long before 1 000 kg, and an
        // absurd input must never overflow into a crash.
        let raw = Double(min(max(weightKg, 0), 1000) * mlPerKg)
        let rounded = Int((raw / Double(roundingMl)).rounded()) * roundingMl
        return min(maximumMl, max(minimumMl, rounded))
    }

    /// Progress toward the goal as a fraction, clamped to 0…1.
    public static func progress(consumedMl: Int, goalMl: Int) -> Double {
        guard goalMl > 0 else { return 0 }
        return min(1, max(0, Double(consumedMl) / Double(goalMl)))
    }
}
