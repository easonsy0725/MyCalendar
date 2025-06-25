import SwiftUI

struct SettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) var dismiss
    @State private var accessRequestState = AccessRequestState.notRequested
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Calendar Access")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                            Text(statusMessage)
                        }
                        .padding(.vertical, 5)
                        
                        Button(action: requestAccess) {
                            HStack {
                                if accessRequestState == .inProgress {
                                    ProgressView().tint(.white)
                                }
                                Text(buttonText).frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(buttonColor)
                        .disabled(accessRequestState == .inProgress)
                        
                        if case .failure(let error) = accessRequestState {
                            Text(error.localizedDescription)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 5)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2023.09").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func requestAccess() {
        accessRequestState = .notRequested
        
        if calendarManager.authorizationStatus == .denied {
            openAppSettings()
            return
        }
        
        accessRequestState = .inProgress
        
        calendarManager.requestAccess { success in
            DispatchQueue.main.async {
                if success {
                    self.accessRequestState = .success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.accessRequestState = .notRequested
                    }
                } else {
                    if self.calendarManager.authorizationStatus == .denied {
                        let error = self.calendarManager.lastAccessRequestError ?? NSError(
                            domain: "CalendarAccess",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error"]
                        )
                        self.accessRequestState = .failure(error: error)
                    } else {
                        self.accessRequestState = .notRequested
                    }
                }
            }
        }
    }
    
    private var statusMessage: String {
        switch calendarManager.authorizationStatus {
        case .authorized: return "Access granted"
        case .denied: return "Access denied"
        case .notDetermined: return "Access not requested"
        default: return "Unknown status"
        }
    }
    
    private var statusIcon: String {
        switch calendarManager.authorizationStatus {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch calendarManager.authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        default: return .gray
        }
    }
    
    private var buttonText: String {
        calendarManager.authorizationStatus == .denied ? "Open Settings" : "Request Access"
    }
    
    private var buttonColor: Color {
        switch accessRequestState {
        case .inProgress: return .blue.opacity(0.7)
        case .success: return .green
        case .failure: return .red
        default: return .blue
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}