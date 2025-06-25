import SwiftUI
import EventKit

struct CalendarView: View {
    @StateObject private var calendarManager = CalendarManager()
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var showingPermissionAlert = false
    @State private var showingSettingsSheet = false
    @State private var accessRequestState = AccessRequestState.notRequested
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(calendarManager.authorizationStatus != .authorized)
                    
                    Spacer()
                    
                    Text(currentMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.title.bold())
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(calendarManager.authorizationStatus != .authorized)
                    
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(.leading, 10)
                    }
                }
                .padding(.horizontal)
                
                VStack {
                    Text("Status: \(calendarManager.authorizationStatusString())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let error = calendarManager.lastAccessRequestError {
                        Text("Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if calendarManager.authorizationStatus == .authorized {
                    calendarContentView
                } else {
                    accessRequiredView
                }
            }
            .padding()
            .navigationTitle("My Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEvent = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(calendarManager.authorizationStatus != .authorized)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(calendarManager: calendarManager, selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView(calendarManager: calendarManager)
            }
            .onAppear(perform: handleCalendarAccess)
            .onChange(of: currentMonth) { newMonth in
                if calendarManager.authorizationStatus == .authorized {
                    calendarManager.loadEvents(for: newMonth)
                }
            }
            .alert("Calendar Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") { openAppSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable calendar access in Settings to use all features")
            }
        }
    }
    
    private var calendarContentView: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(), count: 7)) {
                ForEach(daysInMonth(), id: \.self) { date in
                    DateCell(
                        date: date,
                        events: calendarManager.events.filter {
                            Calendar.current.isDate($0.startDate, inSameDayAs: date)
                        }
                    )
                    .onTapGesture { selectedDate = date }
                }
            }
            
            List {
                Section("Events on \(selectedDate.formatted(.dateTime.month().day()))") {
                    if eventsForSelectedDate().isEmpty {
                        Text("No events scheduled")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(eventsForSelectedDate(), id: \.eventIdentifier) { event in
                            VStack(alignment: .leading) {
                                Text(event.title).font(.headline)
                                Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    private var accessRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            Text("Calendar Access Needed").font(.title2.bold())
            
            Text("To display and manage your events, please grant access to your Apple Calendar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            
            Button(action: requestAccess) {
                HStack {
                    if case .inProgress = accessRequestState {
                        ProgressView().tint(.white)
                    }
                    Text(buttonText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(buttonBackground)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            if case .failure(let error) = accessRequestState {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var buttonText: String {
        switch accessRequestState {
        case .inProgress: return "Requesting Access..."
        case .success: return "Access Granted"
        case .failure: return "Try Again"
        default:
            return calendarManager.authorizationStatus == .denied ? "Open Settings" : "Grant Access"
        }
    }
    
    private var buttonBackground: some View {
        Group {
            switch accessRequestState {
            case .inProgress: Color.blue.opacity(0.7)
            case .success: Color.green
            case .failure: Color.red
            default: Color.blue
            }
        }
    }
    
    private func requestAccess() {
        accessRequestState = .inProgress
        
        if calendarManager.authorizationStatus == .denied {
            openAppSettings()
            accessRequestState = .notRequested
            return
        }
        
        calendarManager.requestAccess { success in
            DispatchQueue.main.async {
                if success {
                    self.accessRequestState = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.accessRequestState = .notRequested
                    }
                } else {
                    let error = self.calendarManager.lastAccessRequestError ?? NSError(
                        domain: "CalendarAccess",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Access request failed"]
                    )
                    self.accessRequestState = .failure(error: error)
                }
            }
        }
    }
    
    private func eventsForSelectedDate() -> [EKEvent] {
        calendarManager.events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }
    }
    
    private func handleCalendarAccess() {
        calendarManager.checkStatus()
        if calendarManager.authorizationStatus == .authorized {
            calendarManager.loadEvents(for: currentMonth)
        } else if calendarManager.authorizationStatus == .denied {
            showingPermissionAlert = true
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func daysInMonth() -> [Date] {
        let calendar = Calendar.current
        guard let monthRange = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        var days: [Date] = []
        
        for _ in 1..<firstWeekday { days.append(Date.distantPast) }
        for day in 0..<monthRange.count {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
}
        }
        
        return days
    }
}
