import Foundation

/// Detects fixed and variable-date holidays, returning achievement IDs.
public enum HolidayCalendar {

    // MARK: - Public API

    /// Returns matching holiday achievement IDs for the given date.
    public static func holidays(for date: Date) -> [String] {
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let year = cal.component(.year, from: date)
        let weekday = cal.component(.weekday, from: date) // 1=Sunday … 7=Saturday

        var results: [String] = []

        // Fixed-date holidays
        switch (month, day) {
        case (1, 1):   results.append("holiday_new_year")
        case (2, 14):  results.append("holiday_valentine")
        case (2, 29):  results.append("holiday_leap_day")
        case (3, 17):  results.append("holiday_st_patrick")
        case (7, 4):   results.append("holiday_independence")
        case (10, 31): results.append("holiday_halloween")
        case (12, 25): results.append("holiday_christmas")
        case (12, 31): results.append("holiday_nye")
        default: break
        }

        // Friday the 13th (weekday 6 == Friday in Gregorian calendar)
        if weekday == 6 && day == 13 {
            results.append("holiday_friday_13")
        }

        // Easter Sunday
        let easter = easterSunday(year: year)
        if cal.isDate(date, inSameDayAs: easter) {
            results.append("holiday_easter")
        }

        // US Thanksgiving (4th Thursday of November)
        let turkey = thanksgiving(year: year)
        if cal.isDate(date, inSameDayAs: turkey) {
            results.append("holiday_thanksgiving")
        }

        return results
    }

    /// Returns Easter Sunday for the given year using the Anonymous Gregorian Computus.
    public static func easterSunday(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date.now
    }

    /// Returns US Thanksgiving (4th Thursday of November) for the given year.
    public static func thanksgiving(year: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // Start at November 1
        var components = DateComponents()
        components.year = year
        components.month = 11
        components.day = 1
        guard let novFirst = cal.date(from: components) else { return Date.now }

        // Find the first Thursday (weekday 5 in Gregorian: 1=Sunday)
        let weekdayOfNovFirst = cal.component(.weekday, from: novFirst)
        // Days until Thursday: Thursday is weekday 5
        let daysUntilThursday = (5 - weekdayOfNovFirst + 7) % 7
        let firstThursdayDay = 1 + daysUntilThursday
        // 4th Thursday = first Thursday + 21 days
        let fourthThursdayDay = firstThursdayDay + 21

        var resultComponents = DateComponents()
        resultComponents.year = year
        resultComponents.month = 11
        resultComponents.day = fourthThursdayDay
        return cal.date(from: resultComponents) ?? Date.now
    }
}
