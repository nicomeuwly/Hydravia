import Foundation
import Testing
@testable import HydraviaCore

@Suite("Units")
struct UnitsTests {
    private let en = Locale(identifier: "en_US")

    @Test func automaticFollowsTheRegion() {
        #expect(UnitPreference.automatic.resolved(for: .us) == .imperial)
        #expect(UnitPreference.automatic.resolved(for: .metric) == .metric)
        #expect(UnitPreference.automatic.resolved(for: .uk) == .metric)
        #expect(UnitPreference.metric.resolved(for: .us) == .metric)
        #expect(UnitPreference.imperial.resolved(for: .metric) == .imperial)
    }

    @Test func millilitresAndOuncesConvert() {
        #expect(UnitSystem.ml(fromFluidOunces: 8) == 237)
        #expect(UnitSystem.ml(fromFluidOunces: 16) == 473)
        #expect(abs(UnitSystem.fluidOunces(fromMl: 29.5735) - 1) < 1e-9)
    }

    @Test(arguments: [
        (200, 6.8), (237, 8.0), (250, 8.5), (330, 11.0), (500, 17.0), (2300, 78.0), (293, 9.9), (295, 10.0),
    ])
    func ouncesRoundToATenthUnderTen(ml: Int, expected: Double) {
        #expect(UnitSystem.imperial.displayVolume(ml: ml) == expected)
    }

    @Test func formatsAmountsWithTheirUnit() {
        #expect(UnitSystem.metric.volume(ml: 1250, locale: en) == "1,250 ml")
        #expect(UnitSystem.imperial.volume(ml: 250, locale: en) == "8.5 oz")
        #expect(UnitSystem.imperial.volume(ml: 237, locale: en) == "8 oz")
        #expect(UnitSystem.imperial.volumeNumber(ml: 2300, locale: en) == "78")
        #expect(UnitSystem.metric.dailyVolume(ml: 1840, locale: en) == "1.8 L")
        #expect(UnitSystem.imperial.dailyVolume(ml: 1840, locale: en) == "62 oz")
        #expect(UnitSystem.metric.volume(ml: 250, locale: Locale(identifier: "fr_FR")) == "250 ml")
        #expect(UnitSystem.imperial.volume(ml: 250, locale: Locale(identifier: "fr_FR")) == "8,5 oz")
    }

    @Test func typedAmountsConvert() {
        #expect(UnitSystem.metric.ml(fromInput: 330) == 330)
        #expect(UnitSystem.imperial.ml(fromInput: 12) == 355)
        #expect(UnitSystem.imperial.wholeInputValue(ml: 330) == 11)
        #expect(UnitSystem.metric.wholeInputValue(ml: 330) == 330)
    }

    @Test func stepsLandOnWholeOunces() {
        #expect(UnitSystem.metric.stepped(ml: 250, by: 1, metricStep: 10) == 260)
        #expect(UnitSystem.imperial.stepped(ml: 237, by: 1, metricStep: 10) == 266)
        #expect(UnitSystem.imperial.stepped(ml: 250, by: -1, metricStep: 10) == 207)
        #expect(UnitSystem.imperial.displayVolume(ml: UnitSystem.imperial.stepped(ml: 200, by: 1, metricStep: 10)) == 8)
    }

    @Test func dragSnapsToTheGrid() {
        #expect(UnitSystem.metric.snapped(ml: 274, metricStep: 50) == 250)
        #expect(UnitSystem.imperial.snapped(ml: 250, metricStep: 50) == 237)
    }

    @Test func imperialPresetsAreWholeOunces() {
        #expect(UnitSystem.metric.defaultFavoritesMl == [200, 330, 500])
        #expect(UnitSystem.imperial.defaultFavoritesMl == [237, 355, 473])
        #expect(UnitSystem.imperial.defaultFavoritesMl.map { UnitSystem.imperial.displayVolume(ml: $0) } == [8, 12, 16])
    }

    @Test func weightsConvert() {
        #expect(UnitSystem.metric.weight(kg: 70, locale: en) == "70 kg")
        #expect(UnitSystem.imperial.weight(kg: 70, locale: en) == "154 lb")
        #expect(UnitSystem.imperial.displayWeight(kg: 30) == 66)
        #expect(UnitSystem.imperial.displayWeight(kg: 250) == 551)
    }

    @Test func temperaturesConvert() {
        #expect(UnitSystem.metric.temperature(celsius: 23.6, locale: en) == "24°C")
        #expect(UnitSystem.imperial.temperature(celsius: 24, locale: en) == "75°F")
        #expect(UnitSystem.imperial.displayTemperature(celsius: -40) == -40)
        #expect(UnitSystem.imperial.displayTemperature(celsius: 0) == 32)
    }

    @Test func everyPoundIsKeptAsPicked() {
        // 154 and 155 lb share 70 kg: both stay distinct on screen.
        #expect(BodyWeight.pounds(154).kg == 70)
        #expect(BodyWeight.pounds(155).kg == 70)
        #expect(BodyWeight.pounds(155).displayPounds == 155)
        #expect(BodyWeight(kg: 70).displayPounds == 154)
        // Pounds that no longer match the kilograms are ignored.
        #expect(BodyWeight(kg: 80, pounds: 155).displayPounds == 176)
    }
}
