import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingAddReminder = false
  
    var body: some View {
        NavigationView {
            ScrollView {  // Replaced List with ScrollView for custom cards
                if manager.reminders.isEmpty {
                    PlaceholderView(icon: "bell", title: "No Reminders Yet", subtitle: "Add a reminder to get started")
                        .padding(.top, 100)
                    HStack {
                        Spacer()
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach($manager.reminders) { $reminder in
                            HStack {
                                Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(reminder.isDone ? .goodGreen : .textGray)
                                    .onTapGesture {
                                        reminder.isDone.toggle()
                                        manager.saveReminders()
                                    }
                                VStack(alignment: .leading) {
                                    Text(reminder.title)
                                        .strikethrough(reminder.isDone)
                                    if !reminder.isDone {
                                        Text(reminder.dueDate, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.cardWhite)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Reminders")
            .background(Color.background.ignoresSafeArea())
            .toolbar {
                Button(action: { showingAddReminder = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
        }
    }
}

struct HarvestNoConnectionScreen: View {
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                Image(isLandscape ? "no_internet_check_bg_landscape" : "no_internet_check_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                if isLandscape {
                    Image("internet_ch_prompt")
                        .resizable()
                        .frame(width: 270, height: 210)
                        .padding(.trailing, 102)
                } else {
                    Image("internet_ch_prompt")
                        .resizable()
                        .frame(width: 270, height: 210)
                        .padding(.bottom, 102)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct AddReminderView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var repeatInterval: RepeatInterval = .none
  
    var body: some View {
        NavigationView {
            Form {
                TextField("Reminder title", text: $title)
                DatePicker("Due date", selection: $dueDate)
                Picker("Repeat", selection: $repeatInterval) {
                    ForEach(RepeatInterval.allCases, id: \.self) { Text($0.rawValue) }
                }
            }
            .navigationTitle("New Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let reminder = Reminder(title: title, dueDate: dueDate, repeatInterval: repeatInterval)
                        manager.reminders.append(reminder)
                        manager.saveReminders()
                        scheduleNotification(for: reminder)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
  
    func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "Farm inventory reminder"
        content.sound = .default
      
        var dateComponents: DateComponents?
        let calendar = Calendar.current
      
        switch reminder.repeatInterval {
        case .none:
            dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        case .daily:
            dateComponents = calendar.dateComponents([.hour, .minute], from: reminder.dueDate)
        case .weekly:
            dateComponents = calendar.dateComponents([.weekday, .hour, .minute], from: reminder.dueDate)
        case .monthly:
            dateComponents = calendar.dateComponents([.day, .hour, .minute], from: reminder.dueDate)
        }
      
        if let components = dateComponents {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeatInterval != .none)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension View {
    @ViewBuilder func conditionalScrollContentBackground(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(visibility)
        } else {
            self
        }
    }
}

#Preview {
    RemindersView()
}
