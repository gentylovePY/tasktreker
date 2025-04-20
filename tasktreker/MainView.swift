import SwiftUI


struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Добро пожаловать!")
                    .font(.title)
                
                Spacer()
                
                Button("Выйти") {
                    authManager.logout()
                }
                .foregroundColor(.red)
            }
            .navigationTitle("Главная")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        authManager.logout()
                    }) {
                        Image(systemName: "person.crop.circle.fill.badge.xmark")
                    }
                }
            }
        }
    }
}
