//
//  tasktrekerApp.swift
//  tasktreker
//
//  Created by Роман Гиниятов on 20.04.2025.
//

import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager()
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Градиентный фон с анимацией
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "3A7BD5"), Color(hex: "00D2FF")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(isAnimating ? 10 : 0))
            .animation(
                Animation.easeInOut(duration: 5).repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            if authManager.isAuthenticated {
                MainView()
                    .environmentObject(authManager)
                    .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 32) {
                    // Анимированное лого
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 4)
                            .frame(width: 160, height: 160)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    
                    // Заголовок с тенью
                    VStack(spacing: 8) {
                        Text("TASK TRACKER")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        
                        Text("Ваш идеальный помощник")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Кнопка авторизации
                    Button(action: {
                        withAnimation(.spring()) {
                            authManager.showWebView = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image("yandex-icon")
                                .resizable()
                                .frame(width: 24, height: 24)
                            
                            Text("Войти через Яндекс")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        )
                        .foregroundColor(.black)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                .padding(.top, 60)
                .sheet(isPresented: $authManager.showWebView) {
                    if let url = authManager.authURL {
                        YandexAuthWebView(url: url)
                            .environmentObject(authManager)
                    }
                }
            }
            
            // Индикатор загрузки
            if authManager.isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        
                        Text("Авторизация...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .transition(.opacity)
            }
        }
        .alert("Ошибка", isPresented: .constant(authManager.error != nil)) {
            Button("OK", role: .cancel) {
                authManager.error = nil
            }
        } message: {
            Text(authManager.error ?? "")
                .foregroundColor(.black)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Расширение для HEX цветов
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
