import SwiftUI
import WidgetKit

struct MonthBackground: View {
    var look: WidgetLook
    var body: some View {
        Palette(look).background
    }
}

struct MonthContent: View {
    var today: Date
    var settings: MonthSettings
    var eventDays: Set<Date>
    var family: WidgetFamily
    var look: WidgetLook
    /// In the app the arrows call this; in the widget they run ShiftMonthIntent.
    var onShift: ((Int) -> Void)?

    private var palette: Palette { Palette(look, accent: settings.accent) }
    private var calendar: Calendar { Calendar.current }

    private var firstMonth: Date {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        return calendar.date(byAdding: .month, value: settings.monthOffset, to: start) ?? start
    }

    var body: some View {
        if family == .systemSmall {
            VStack(spacing: 6) {
                header(title: monthTitle(firstMonth), showLeft: true, showRight: true)
                MonthGrid(month: firstMonth, today: today, eventDays: settings.showEventDots ? eventDays : [], palette: palette)
            }
            .padding(12)
        } else {
            let second = calendar.date(byAdding: .month, value: 1, to: firstMonth) ?? firstMonth
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 6) {
                    header(title: monthTitle(firstMonth), showLeft: true, showRight: false)
                    MonthGrid(month: firstMonth, today: today, eventDays: settings.showEventDots ? eventDays : [], palette: palette)
                }
                VStack(spacing: 6) {
                    header(title: monthTitle(second), showLeft: false, showRight: true)
                    MonthGrid(month: second, today: today, eventDays: settings.showEventDots ? eventDays : [], palette: palette)
                }
            }
            .padding(12)
        }
    }

    private func monthTitle(_ month: Date) -> String {
        let sameYear = calendar.component(.year, from: month) == calendar.component(.year, from: today)
        return Fmt.string(month, sameYear ? "MMMM" : "MMM yyyy").uppercased()
    }

    private func header(title: String, showLeft: Bool, showRight: Bool) -> some View {
        HStack(spacing: 0) {
            if showLeft { arrow("chevron.left", delta: -1) } else { Color.clear.frame(width: 22, height: 22) }
            Spacer(minLength: 2)
            shiftButton(delta: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
            }
            Spacer(minLength: 2)
            if showRight { arrow("chevron.right", delta: 1) } else { Color.clear.frame(width: 22, height: 22) }
        }
    }

    private func arrow(_ symbol: String, delta: Int) -> some View {
        shiftButton(delta: delta) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(palette.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(palette.fill))
        }
    }

    @ViewBuilder
    private func shiftButton<Label: View>(delta: Int, @ViewBuilder label: () -> Label) -> some View {
        if let onShift {
            Button { onShift(delta) } label: { label() }
                .buttonStyle(.plain)
        } else {
            Button(intent: ShiftMonthIntent(delta: delta)) { label() }
                .buttonStyle(.plain)
        }
    }
}

struct MonthGrid: View {
    var month: Date
    var today: Date
    var eventDays: Set<Date>
    var palette: Palette

    private var calendar: Calendar { Calendar.current }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Day numbers laid out in weeks; nil = empty cell.
    private var weeks: [[Int?]] {
        let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<31
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading) + range.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func isWeekend(column: Int) -> Bool {
        let weekday = (calendar.firstWeekday - 1 + column) % 7 + 1
        return weekday == 1 || weekday == 7  // Sunday, Saturday
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(isWeekend(column: index) ? palette.tertiary : palette.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        cell(week[column], column: column)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func cell(_ day: Int?, column: Int) -> some View {
        if let day, let date = calendar.date(byAdding: .day, value: day - 1, to: month) {
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let hasEvent = eventDays.contains(calendar.startOfDay(for: date))
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .heavy : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isToday ? palette.onAccent : (isWeekend(column: column) ? palette.secondary : palette.primary))
                .frame(width: 19, height: 17)
                .background {
                    if isToday {
                        Circle().fill(palette.accent).frame(width: 19, height: 19).widgetAccentable()
                    }
                }
                .overlay(alignment: .bottom) {
                    if hasEvent && !isToday {
                        Circle().fill(palette.accent).frame(width: 3, height: 3).offset(y: 3).widgetAccentable()
                    }
                }
        } else {
            Color.clear.frame(height: 17)
        }
    }
}
