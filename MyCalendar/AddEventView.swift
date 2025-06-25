import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var calendarManager: CalendarManager
    let selectedDate: Date
    
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                }
                
                Section("Time") {
                    DatePicker("Starts", selection: $startDate)
                    DatePicker("Ends", selection: $endDate)
                }
            }
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addEvent() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear {
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: selectedDate)
                startDate = calendar.date(byAdding: .hour, value: 9, to: startOfDay)!
                endDate = calendar.date(byAdding: .hour, value: 10, to: startOfDay)!
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func addEvent() {
        guard endDate > startDate else {
            alertMessage = "End time must be after start time"
            showAlert = true
            return
        }
        
        calendarManager.addEvent(
            title: title,
            startDate: startDate,
            endDate: endDate
        )
        dismiss()
    }
}
