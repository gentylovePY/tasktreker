//
//  ProfileView.swift
//  tasktreker
//
//  Created by Роман Гиниятов on 25.04.2025.
//

import SwiftUI
import Firebase

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var firebaseService: FirebaseService
    
    @State private var showingLogoutAlert = false
    @State private var isImagePickerPresented = false
    @State private var avatarImage: UIImage?
    @State private var userName: String = "Роман Гиниятов"
    

    private var totalTasks: Int { firebaseService.currentUserTasks.count }
    private var completedTasks: Int {
        firebaseService.currentUserTasks.filter { task in
            guard let date = DateFormatter.taskDateFormatter.date(from: task.date) else { return false }
            return date < Date()
        }.count
    }
    private var overdueTasks: Int {
        firebaseService.currentUserTasks.filter { task in
            guard let date = DateFormatter.taskDateFormatter.date(from: task.date) else { return false }
            return date < Date() - 86400 // +1 день к сроку
        }.count
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
        
                profileHeader
                
                statsSection
                
                settingsSection
                
                devicesSection

                logoutButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Профиль")
        .alert("Выйти из аккаунта?", isPresented: $showingLogoutAlert) {
            //Button("Выйти", role: .destructive) { authManager.logout() }
            Button("Отмена", role: .cancel) {}
        }
    }
    
    // MARK: - Компоненты
    
    private var profileHeader: some View {
        HStack(spacing: 20) {

            Button(action: { isImagePickerPresented = true }) {
                ZStack {
                    if let avatarImage = avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .overlay(GradientStroke())
                .shadow(radius: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $avatarImage)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(userName)
                    .font(.title2.bold())
                
                Text("shshmsnem@yandex_dot_ru")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Участник с 20 апреля 2025")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Статистика")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 16) {
                StatCard(value: totalTasks, label: "Всего", color: .blue, icon: "checklist")
                StatCard(value: completedTasks, label: "Выполнено", color: .green, icon: "checkmark.circle.fill")
                StatCard(value: overdueTasks, label: "Просрочено", color: .red, icon: "exclamationmark.triangle.fill")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var settingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Настройки")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 8)
            
            SettingRow(icon: "moon.fill", title: "Тема", value: "Системная") {}
            SettingRow(icon: "bell.badge.fill", title: "Уведомления", value: "Вкл") {}
            SettingRow(icon: "face.smiling.fill", title: "Режим фокуса", value: "Неактивен") {}
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    

    private var devicesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Мои устройства")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                
                NavigationLink(destination: DevicesView(Devices: mockDevices)) {
                    Text("Все")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 8)
            
            // Показываем только первые 2 устройства в профиле
            ForEach(mockDevices.prefix(2)) { device in
                DeviceRow(device: device)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }


    private var mockDevices: [Device] {
        [
            Device(
                id: "1",
                name: "Алиса",
                imageName: "alice",
                type: "Умная колонка",
                isOnline: true
            ),
            Device(
                id: "2",
                name: "Датчик Температуры",
                imageName: "temp_sensor",
                type: "Датчик",
                isOnline: true
            )
        ]
    }

    struct DeviceRow: View {
        let device: Device
        var showChevron: Bool = true
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: device.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(device.isOnline ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(device.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var logoutButton: some View {
        Button(action: { showingLogoutAlert = true }) {
            HStack {
                Spacer()
                Text("Выйти из аккаунта")
                    .foregroundColor(.red)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Вспомогательные компоненты

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(15)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                Text(value)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

// MARK: - Обновляем MainView для добавления навигации


// Добавьте эти структуры в конец файла ProfileView.swift
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct GradientStroke: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
    }
}
