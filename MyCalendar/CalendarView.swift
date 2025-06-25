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
                    .disabled(!calendarManager.isFullAccessAuthorized)
                    
                    Spacer()
                    
                    Text(currentMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.title.bold())
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(!calendarManager.isFullAccessAuthorized)
                    
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
                
                if calendarManager.isFullAccessAuthorized {
                    calendarContentView
                } else if calendarManager.isWriteAccessAuthorized {
                    writeOnlyView
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
                    .disabled(!calendarManager.isWriteAccessAuthorized)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(calendarManager: calendarManager, selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView(calendarManager: calendarManager)
            }
            .onAppear(perform: handleCalendarAccess)
            .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                calendarManager.checkStatus()
                if calendarManager.isFullAccessAuthorized {
                    calendarManager.loadEvents(for: currentMonth)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                calendarManager.checkStatus()
            }
            .onChange(of: currentMonth) { newMonth in
                if calendarManager.isFullAccessAuthorized {
                    calendarManager.loadEvents(for: newMonth)
                } else if calendarManager.authorizationStatus == EKAuthorizationStatus.denied {
                    showingPermissionAlert = true
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
    
    private var writeOnlyView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .padding(.bottom, 20)
            
            Text("Write-Only Access").font(.title2.bold())
            
            Text("You can add new events, but to see them in the app, please grant Full Access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            
            Button(action: openAppSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
    
    private var accessRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            Text("Calendar Access Needed").font(.title2.bold())
            
            if calendarManager.authorizationStatus == .restricted {
                Text("Your device is restricted from changing calendar permissions. This may be due to Screen Time or a management profile. Check Settings > General > VPN & Device Management. If this app is listed there, it is being managed and you may need to contact your IT administrator.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)
            } else {
                Text("To display and manage your events, please grant access to your Apple Calendar.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)
            }
            
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
            .disabled(calendarManager.authorizationStatus == .restricted)
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
            switch calendarManager.authorizationStatus {
            case .denied: return "Open Settings"
            case .restricted: return "Access Restricted"
            default: return "Grant Access"
            }
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
        if calendarManager.authorizationStatus == .restricted {
            return
        }
        
        accessRequestState = .inProgress
        
        if calendarManager.authorizationStatus == EKAuthorizationStatus.denied {
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
        print("[CalendarView] View appeared, handling calendar access.")
        calendarManager.checkStatus()
        if calendarManager.authorizationStatus == .notDetermined {
            print("[CalendarView] Status is 'not determined', proceeding to request access.")
            requestAccess()
        } else if calendarManager.isFullAccessAuthorized {
            print("[CalendarView] Status is 'full access', loading events.")
            calendarManager.loadEvents(for: currentMonth)
        } else if calendarManager.authorizationStatus == .denied {
            print("[CalendarView] Status is 'denied', showing alert.")
            showingPermissionAlert = true
        } else {
            print("[CalendarView] Status is '\(calendarManager.authorizationStatusString())', showing appropriate view.")
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
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

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