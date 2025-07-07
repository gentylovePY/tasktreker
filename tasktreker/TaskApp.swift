//
//  TaskApp.swift
//  tasktreker
//
//  Created by Роман Гиниятов on 20.04.2025.
//

// TaskApp.swift
import SwiftUI
import Firebase

@main
struct TaskApp: App {
    init() {
        FirebaseApp.configure()
       
    }
    
    var body: some Scene {
        WindowGroup {
            AuthView()
        }
    }
 
}
