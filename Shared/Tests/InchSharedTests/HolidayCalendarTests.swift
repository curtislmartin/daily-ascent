import Testing
import Foundation
@testable import InchShared

struct HolidayCalendarTests {

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Fixed Holidays

    @Test func newYearDetected() {
        let date = makeDate(year: 2026, month: 1, day: 1)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_new_year"))
    }

    @Test func valentineDetected() {
        let date = makeDate(year: 2026, month: 2, day: 14)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_valentine"))
    }

    @Test func leapDayDetected() {
        let date = makeDate(year: 2028, month: 2, day: 29)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_leap_day"))
    }

    @Test func stPatrickDetected() {
        let date = makeDate(year: 2026, month: 3, day: 17)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_st_patrick"))
    }

    @Test func independenceDayDetected() {
        let date = makeDate(year: 2026, month: 7, day: 4)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_independence"))
    }

    @Test func halloweenDetected() {
        let date = makeDate(year: 2026, month: 10, day: 31)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_halloween"))
    }

    @Test func christmasDetected() {
        let date = makeDate(year: 2026, month: 12, day: 25)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_christmas"))
    }

    @Test func newYearsEveDetected() {
        let date = makeDate(year: 2026, month: 12, day: 31)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_nye"))
    }

    // MARK: - Regular Date Returns Empty

    @Test func regularDateReturnsEmpty() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        #expect(HolidayCalendar.holidays(for: date).isEmpty)
    }

    @Test func nonHolidayMarchDateReturnsEmpty() {
        let date = makeDate(year: 2026, month: 3, day: 10)
        #expect(HolidayCalendar.holidays(for: date).isEmpty)
    }

    // MARK: - Easter (Computus)

    @Test func easter2024() {
        // Known: 2024-03-31
        let easter = HolidayCalendar.easterSunday(year: 2024)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: easter) == 2024)
        #expect(cal.component(.month, from: easter) == 3)
        #expect(cal.component(.day, from: easter) == 31)
    }

    @Test func easter2026() {
        // Known: 2026-04-05
        let easter = HolidayCalendar.easterSunday(year: 2026)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: easter) == 2026)
        #expect(cal.component(.month, from: easter) == 4)
        #expect(cal.component(.day, from: easter) == 5)
    }

    @Test func easter2027() {
        // Known: 2027-03-28
        let easter = HolidayCalendar.easterSunday(year: 2027)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: easter) == 2027)
        #expect(cal.component(.month, from: easter) == 3)
        #expect(cal.component(.day, from: easter) == 28)
    }

    @Test func easterDetectedViaHolidays() {
        // 2024-03-31 is Easter Sunday
        let date = makeDate(year: 2024, month: 3, day: 31)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_easter"))
    }

    @Test func easterNotDetectedOnAdjacentDay() {
        // Day before Easter 2026 (April 4) should not trigger Easter
        let date = makeDate(year: 2026, month: 4, day: 4)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_easter") == false)
    }

    // MARK: - Thanksgiving

    @Test func thanksgiving2025() {
        // Known: 2025-11-27
        let thanksgiving = HolidayCalendar.thanksgiving(year: 2025)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: thanksgiving) == 2025)
        #expect(cal.component(.month, from: thanksgiving) == 11)
        #expect(cal.component(.day, from: thanksgiving) == 27)
    }

    @Test func thanksgiving2026() {
        // Known: 2026-11-26
        let thanksgiving = HolidayCalendar.thanksgiving(year: 2026)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.year, from: thanksgiving) == 2026)
        #expect(cal.component(.month, from: thanksgiving) == 11)
        #expect(cal.component(.day, from: thanksgiving) == 26)
    }

    @Test func thanksgivingDetectedViaHolidays() {
        // 2025-11-27 is Thanksgiving
        let date = makeDate(year: 2025, month: 11, day: 27)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_thanksgiving"))
    }

    @Test func thanksgivingNotDetectedOnAdjacent() {
        // Nov 28 2025 (Black Friday) should not trigger Thanksgiving
        let date = makeDate(year: 2025, month: 11, day: 28)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_thanksgiving") == false)
    }

    // MARK: - Friday the 13th

    @Test func fridayThe13thDetected() {
        // 2026-02-13 is a Friday
        let date = makeDate(year: 2026, month: 2, day: 13)
        let cal = Calendar(identifier: .gregorian)
        // Verify it's actually a Friday (weekday 6 in Gregorian, where 1=Sunday)
        #expect(cal.component(.weekday, from: date) == 6)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_friday_13"))
    }

    @Test func nonFridayThe13thNotDetected() {
        // 2026-03-13 is a Friday? Let's use a known non-Friday 13th
        // 2026-01-13 is a Tuesday
        let date = makeDate(year: 2026, month: 1, day: 13)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.weekday, from: date) != 6)
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_friday_13") == false)
    }

    @Test func friday12thNotDetected() {
        // Friday but not the 13th
        let date = makeDate(year: 2026, month: 2, day: 6)
        let cal = Calendar(identifier: .gregorian)
        #expect(cal.component(.weekday, from: date) == 6) // Friday
        #expect(HolidayCalendar.holidays(for: date).contains("holiday_friday_13") == false)
    }
}
