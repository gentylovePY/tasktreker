import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var firebaseService: FirebaseService
    let userEmail: String
    
    @State private var taskText = ""
    @State private var selectedDate = Date()
    @State private var isDatePickerShown = false
    @State private var isImportant = false
    @State private var selectedDevice: Device? = nil 
    @State private var showDeviceSelection = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var buttonScale: CGFloat = 1.0
    
    private let primaryColor = Color(hex: "5E72EB")
    

    private let mockDevices: [Device] = [
       
        Device(
            id: "1",
            name: "Water Sensor",
            imageName: "water_sensor",
            type: "Датчик",
            isOnline: true
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(spacing: 20) {
                        TextField("О чем напомнить?", text: $taskText)
                            .focused($isTextFieldFocused)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isTextFieldFocused = true
                                }
                            }
                        
                        // Кнопка выбора устройства
                        Button(action: {
                            showDeviceSelection = true
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundColor(primaryColor)
                                
                                Text(selectedDevice?.name ?? "Выберите устройство")
                                    .foregroundColor(selectedDevice != nil ? .primary : .gray)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                        .sheet(isPresented: $showDeviceSelection) {
                            DeviceSelectionView(devices: mockDevices, selectedDevice: $selectedDevice)
                        }
                        
                        Toggle(isOn: $isImportant) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(isImportant ? .red : .gray)
                                Text("Важная задача")
                                    .font(.headline)
                                    .foregroundColor(isImportant ? .red : .primary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Дата выполнения")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            Button {
                                withAnimation(.spring()) {
                                    isDatePickerShown.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(primaryColor)
                                    
                                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .rotationEffect(.degrees(isDatePickerShown ? 90 : 0))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                            }
                            
                            if isDatePickerShown {
                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    Button(action: addTask) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить задачу")
                        }
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundColor(.white)
                        .background(isImportant ? Color.red : primaryColor)
                        .cornerRadius(12)
                        .scaleEffect(buttonScale)
                        .shadow(color: (isImportant ? Color.red : primaryColor).opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(taskText.isEmpty)
                    .padding()
                    .padding(.bottom, 8)
                    .onLongPressGesture(minimumDuration: .infinity, pressing: { isPressing in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            buttonScale = isPressing ? 0.95 : 1.0
                        }
                    }, perform: {})
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .accentColor(primaryColor)
    }
    
    private func addTask() {
        // Если выбрано устройство, просто закрываем экран
        if selectedDevice != nil {
            dismiss()
            return
        }
        
        // Стандартная логика добавления задачи
        let taskId = "\(Int(Date().timeIntervalSince1970 * 1000))"
        let createdAt = ISO8601DateFormatter().string(from: Date())
        let dateString = DateFormatter.taskDateFormatter.string(from: selectedDate)
        
        let task = Task(
            id: taskId,
            text: taskText,
            date: dateString,
            createdAt: createdAt,
            priority: nil,
            iot: isImportant ? 2 : 1
        )
        
        firebaseService.addTask(task, for: userEmail)
        dismiss()
    }
}

// Новая View для выбора устройства
struct DeviceSelectionView: View {
    let devices: [Device]
    @Binding var selectedDevice: Device?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(devices) { device in
                    Button(action: {
                        selectedDevice = device
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: device.imageName)
                                .foregroundColor(device.isOnline ? .blue : .gray)
                                .frame(width: 30, height: 30)
                            
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .foregroundColor(.primary)
                                Text(device.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedDevice?.id == device.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Выберите устройство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddTaskView(
            firebaseService: FirebaseService(),
            userEmail: "test@example.com"
        )
    }
}
