import SwiftUI

struct DevicesView: View {
    @Environment(\.dismiss) var dismiss
    let Devices: [Device]
    
 
    private var allDevices: [Device] {
        Devices + []
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
              
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Мой дом")
                            .font(.largeTitle.bold())
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
         
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Избранные устройства")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Text("Ред.")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Сетка устройств (2 колонки)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], spacing: 16) {
                            ForEach(allDevices) { device in
                                DeviceGridCard(device: device)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Секция "Про"
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Про")
                            .font(.headline.bold())
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach([
                                ("О Про", "info.circle.fill"),
                                ("Расширьте возможности Алисы", "wand.and.stars"),
                                ("Дайджест апреля", "calendar"),
                                ("Что можно делать в чате?", "message.fill"),
                                ("Дайджест марта", "calendar")
                            ], id: \.0) { item in
                                HStack {
                                    Image(systemName: item.1)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    Text(item.0)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                
                                if item.0 != "Дайджест марта" {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct DeviceGridCard: View {
    let device: Device
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.isOnline ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: device.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(device.isOnline ? .blue : .gray)
            }
            
            VStack(spacing: 4) {
                Text(device.name)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text(device.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(device.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}
