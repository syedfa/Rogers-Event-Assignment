import SwiftUI

/// Horizontal day picker along the top of Home, per the provided design: each day
/// is a rounded cell with weekday abbreviation over day number, the selected day
/// highlighted in the accent color.
struct DateStripView: View {
    let days: [Date]
    let selectedDate: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    DayCell(
                        day: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        isWeekend: calendar.isDateInWeekend(day)
                    )
                    .onTapGesture { onSelect(day) }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isWeekend: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(isWeekend ? .footnote.weight(.bold) : .caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : (isWeekend ? .red : .secondary))
            Text(day, format: .dateTime.day())
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 52, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
    }
}
