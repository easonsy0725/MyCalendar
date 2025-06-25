import SwiftUI
import EventKit

struct DateCell: View {
    let date: Date
    let events: [EKEvent]
    
    var isEmptyCell: Bool { date == Date.distantPast }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isCurrentMonth: Bool { Calendar.current.isDate(date, equalTo: date, toGranularity: .month) }
    
    var body: some View {
        VStack(spacing: 4) {
            if !isEmptyCell {
                Text("\(Calendar.current.component(.day, from: date))")
                    .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                    .frame(width: 30, height: 30)
                    .background(isToday ? Circle().fill(Color.red) : nil)
                
                if !events.isEmpty {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 40)
        .opacity(isEmptyCell ? 0 : 1)
        .contentShape(Rectangle())
    }
}
