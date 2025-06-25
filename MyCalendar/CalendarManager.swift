import EventKit
import SwiftUI

enum AccessRequestState: Equatable {
    case notRequested
    case inProgress
    case success
    case failure(error: Error)
    
    static func == (lhs: AccessRequestState, rhs: AccessRequestState) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested): return true
        case (.inProgress, .inProgress): return true
        case (.success, .success): return true
        case (.failure, .failure): return true
        default: return false
        }
    }
}

class CalendarManager: NSObject, ObservableObject {
    let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isRequestingAccess = false
    @Published var lastAccessRequestError: Error? = nil
    
    override init() {
        super.init()
        checkStatus()
    }
    
    func requestAccess(completion: ((Bool) -> Void)? = nil) {
        isRequestingAccess = true
        lastAccessRequestError = nil
        
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResponse(granted: granted, error: error, completion: completion)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResponse(granted: granted, error: error, completion: completion)
                }
            }
        }
    }
    
    private func handleAccessResponse(granted: Bool, error: Error?, completion: ((Bool) -> Void)?) {
        isRequestingAccess = false
        checkStatus()
        
        if let error = error {
            lastAccessRequestError = error
            completion?(false)
            return
        }
        
        if granted {
            loadEvents(for: Date())
            completion?(true)
        } else {
            lastAccessRequestError = NSError(
                domain: "CalendarAccess",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access was denied"]
            )
            completion?(false)
        }
    }
    
    func loadEvents(for date: Date) {
        guard authorizationStatus == .authorized else { return }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        guard let monthStart = calendar.date(from: components) else { return }
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { return }
        
        let predicate = eventStore.predicateForEvents(
            withStart: monthStart,
            end: monthEnd,
            calendars: nil
        )
        
        events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
    
    func addEvent(title: String, startDate: Date, endDate: Date) {
        guard authorizationStatus == .authorized else { return }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            loadEvents(for: startDate)
        } catch {
            print("Error saving event: \(error.localizedDescription)")
        }
    }
    
    func checkStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func authorizationStatusString() -> String {
        switch authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        @unknown default: return "Unknown"
        }
    }
}
        @unknown default: return "Unknown"
        }
    }
}
