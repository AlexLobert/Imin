import Foundation

enum AutoResetSetting: String, CaseIterable, Identifiable {
    case minutes30
    case hour1
    case hours2
    case hours4
    case tonight
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minutes30:
            return "30 minutes"
        case .hour1:
            return "1 hour"
        case .hours2:
            return "2 hours"
        case .hours4:
            return "4 hours"
        case .tonight:
            return "Tonight"
        case .never:
            return "Never"
        }
    }

    func resetDate(from start: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .minutes30:
            return calendar.date(byAdding: .minute, value: 30, to: start)
        case .hour1:
            return calendar.date(byAdding: .hour, value: 1, to: start)
        case .hours2:
            return calendar.date(byAdding: .hour, value: 2, to: start)
        case .hours4:
            return calendar.date(byAdding: .hour, value: 4, to: start)
        case .tonight:
            var comps = calendar.dateComponents([.year, .month, .day], from: start)
            comps.hour = 21
            comps.minute = 0
            comps.second = 0
            let todayNine = calendar.date(from: comps) ?? start
            if start <= todayNine {
                return todayNine
            }
            return calendar.date(byAdding: .day, value: 1, to: todayNine)
        case .never:
            return nil
        }
    }
}
