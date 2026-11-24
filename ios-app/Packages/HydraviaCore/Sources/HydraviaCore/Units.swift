import Foundation

/// What the user picked in Settings: follow the region, or force a system.
public enum UnitPreference: String, Codable, CaseIterable, Sendable {
    case automatic, metric, imperial

    /// The system the screens use. Automatic is imperial only for the US
    /// measurement system (the UK keeps millilitres for drinks).
    public func resolved(for measurementSystem: Locale.MeasurementSystem) -> UnitSystem {
        switch self {
        case .metric: .metric
        case .imperial: .imperial
        case .automatic: measurementSystem == .us ? .imperial : .metric
        }
    }
}

/// How quantities are shown and typed. Storage never changes: water is
/// always millilitres, weight kilograms, temperature degrees Celsius; only
/// what the user reads and enters converts.
///
/// Unit symbols are the same in every language ("ml", "oz", "kg", "lb"):
/// they were already untranslated in the catalogues, and the extensions
/// that format amounts don't share one catalogue.
public enum UnitSystem: String, Codable, Sendable {
    case metric, imperial

    /// One US fluid ounce.
    public static let mlPerFluidOunce = 29.5735
    public static let kgPerPound = 0.45359237

    // MARK: Volume

    public static func fluidOunces(fromMl ml: Double) -> Double { ml / mlPerFluidOunce }

    /// Millilitres for an amount in fluid ounces, rounded to the millilitre.
    public static func ml(fromFluidOunces oz: Double) -> Int { Int((oz * mlPerFluidOunce).rounded()) }

    /// The amount in this system's unit, rounded as the screens show it:
    /// whole millilitres; fluid ounces to the unit, or to a tenth under
    /// 10 oz (6.8 oz reads better than 7 for a 200 ml glass).
    public func displayVolume(ml: Int) -> Double {
        switch self {
        case .metric:
            return Double(ml)
        case .imperial:
            let oz = Self.fluidOunces(fromMl: Double(ml))
            return abs(oz) < 9.95 ? (oz * 10).rounded() / 10 : oz.rounded()
        }
    }

    public var volumeSymbol: String {
        switch self {
        case .metric: "ml"
        case .imperial: "oz"
        }
    }

    /// The number alone, for screens that set the unit apart ("8.5").
    public func volumeNumber(ml: Int, locale: Locale = .autoupdatingCurrent) -> String {
        displayVolume(ml: ml).formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    /// The amount with its unit ("250 ml", "8.5 oz").
    public func volume(ml: Int, locale: Locale = .autoupdatingCurrent) -> String {
        "\(volumeNumber(ml: ml, locale: locale)) \(volumeSymbol)"
    }

    /// A day's worth: litres with one decimal in metric ("1.8 L"), whole
    /// fluid ounces in imperial ("61 oz").
    public func dailyVolume(ml: Int, locale: Locale = .autoupdatingCurrent) -> String {
        switch self {
        case .metric:
            let litres = Double(ml) / 1000
            return "\(litres.formatted(.number.precision(.fractionLength(1)).locale(locale))) L"
        case .imperial:
            return volume(ml: ml, locale: locale)
        }
    }

    /// A whole number in this system's unit, for typed amounts and
    /// steppers: millilitres, or fluid ounces rounded to the unit.
    public func wholeInputValue(ml: Int) -> Int {
        switch self {
        case .metric: ml
        case .imperial: Int(Self.fluidOunces(fromMl: Double(ml)).rounded())
        }
    }

    /// Millilitres for a whole number typed in this system's unit.
    public func ml(fromInput value: Int) -> Int {
        switch self {
        case .metric: value
        case .imperial: Self.ml(fromFluidOunces: Double(value))
        }
    }

    /// `ml` moved by `steps` nudges: `metricStep` millilitres each, or one
    /// fluid ounce each in imperial, landing on a whole ounce (so 237 ml,
    /// 8 oz, goes to 266 ml, 9 oz, never to 8.3 oz).
    public func stepped(ml: Int, by steps: Int, metricStep: Int) -> Int {
        switch self {
        case .metric: ml + steps * metricStep
        case .imperial: Self.ml(fromFluidOunces: Double(wholeInputValue(ml: ml) + steps))
        }
    }

    /// `ml` snapped to the nearest `metricStep` millilitres, or the nearest
    /// whole fluid ounce in imperial (a dragged glass).
    public func snapped(ml: Double, metricStep: Int) -> Int {
        switch self {
        case .metric:
            return Int((ml / Double(metricStep)).rounded()) * metricStep
        case .imperial:
            return Self.ml(fromFluidOunces: Self.fluidOunces(fromMl: ml).rounded())
        }
    }

    /// The add-water presets of a new user: 200 / 330 / 500 ml, or 8 / 12 /
    /// 16 oz (a cup, a can, a pint) stored as millilitres.
    public var defaultFavoritesMl: [Int] {
        switch self {
        case .metric: [200, 330, 500]
        case .imperial: [8, 12, 16].map { Self.ml(fromFluidOunces: Double($0)) }
        }
    }

    // MARK: Weight

    public static func pounds(fromKg kg: Double) -> Double { kg / kgPerPound }

    /// The whole kilogram a pick in pounds is stored as.
    public static func kg(fromPounds pounds: Int) -> Int { Int((Double(pounds) * kgPerPound).rounded()) }

    /// The weight in this system's unit, to the unit.
    public func displayWeight(kg: Int) -> Int {
        switch self {
        case .metric: kg
        case .imperial: Int(Self.pounds(fromKg: Double(kg)).rounded())
        }
    }

    public var weightSymbol: String {
        switch self {
        case .metric: "kg"
        case .imperial: "lb"
        }
    }

    /// "70 kg", "154 lb".
    public func weight(kg: Int, locale: Locale = .autoupdatingCurrent) -> String {
        "\(displayWeight(kg: kg).formatted(.number.locale(locale))) \(weightSymbol)"
    }

    // MARK: Temperature

    public static func fahrenheit(fromCelsius celsius: Double) -> Double { celsius * 9 / 5 + 32 }

    /// Whole degrees in this system's scale.
    public func displayTemperature(celsius: Double) -> Int {
        switch self {
        case .metric: Int(celsius.rounded())
        case .imperial: Int(Self.fahrenheit(fromCelsius: celsius).rounded())
        }
    }

    /// "24°C", "75°F".
    public func temperature(celsius: Double, locale: Locale = .autoupdatingCurrent) -> String {
        let symbol = self == .metric ? "°C" : "°F"
        return "\(displayTemperature(celsius: celsius).formatted(.number.locale(locale)))\(symbol)"
    }
}

/// A body weight as the user picked it. The goal is computed from whole
/// kilograms; a pick made in pounds also keeps the exact pounds, so the
/// wheel can offer every pound (one pound is less than half a kilogram,
/// and many pounds share the same kilogram).
public struct BodyWeight: Equatable, Sendable {
    public var kg: Int
    /// The exact pick when it was made in pounds.
    public var pounds: Int?

    public init(kg: Int, pounds: Int? = nil) {
        self.kg = kg
        self.pounds = pounds
    }

    public static func pounds(_ pounds: Int) -> BodyWeight {
        BodyWeight(kg: UnitSystem.kg(fromPounds: pounds), pounds: pounds)
    }

    /// The pounds to show: the exact pick while it still matches the stored
    /// kilograms, otherwise the kilograms converted.
    public var displayPounds: Int {
        if let pounds, UnitSystem.kg(fromPounds: pounds) == kg { return pounds }
        return Int(UnitSystem.pounds(fromKg: Double(kg)).rounded())
    }
}
