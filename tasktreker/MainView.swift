// MainView.swift
import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var firebaseService = FirebaseService()
    let userEmail = "shshmsnem@yandex_dot_ru" // Замените на реальный email после авторизации
    
    var body: some View {
        NavigationView {
            VStack {
                if firebaseService.isLoading {
                    ProgressView()
                        .scaleEffect(2)
                } else if let error = firebaseService.error {
                    Text("Ошибка: \(error)")
                        .foregroundColor(.red)
                } else {
                    List(firebaseService.currentUserTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.text)
                                .font(.headline)
                            
                            HStack {
                                Text("Дата выполнения: \(task.date)")
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("Создано: \(formattedDate(task.createdAt))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
                
                Button("Выйти") {
                    authManager.logout()
                }
                .foregroundColor(.red)
                .padding()
            }
            .navigationTitle("Мои задачи")
            .onAppear {
                firebaseService.fetchUserTasks(email: userEmail)
            }
        }
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}
