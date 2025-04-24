// FirebaseService.swift
import Foundation
import FirebaseDatabase

class FirebaseService: ObservableObject {
    @Published var currentUserTasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var databaseRef: DatabaseReference!
    private var userHandle: DatabaseHandle?
    
    init() {
        databaseRef = Database.database().reference()
    }
    
    func fetchUserTasks(email: String) {
        isLoading = true
        currentUserTasks = []
        
        userHandle = databaseRef.child("users/\(email)").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                guard let userDict = snapshot.value as? [String: Any] else {
                    self.error = "Пользователь не найден"
                    return
                }
                
                do {
                    // Получаем задачи пользователя
                    if let tasksDict = userDict["tasks"] as? [String: Any] {
                        var tasks: [Task] = []
                        
                        for (taskId, taskData) in tasksDict {
                            if let taskDict = taskData as? [String: Any] {
                                var taskJson = taskDict
                                taskJson["id"] = taskId // Добавляем ID задачи
                                
                                let taskData = try JSONSerialization.data(withJSONObject: taskJson)
                                let task = try JSONDecoder().decode(Task.self, from: taskData)
                                tasks.append(task)
                            }
                        }
                        
                        self.currentUserTasks = tasks.sorted {
                            $0.createdAt > $1.createdAt // Сортируем по дате создания (новые сначала)
                        }
                    }
                } catch {
                    self.error = "Ошибка обработки задач: \(error.localizedDescription)"
                }
            }
        }
    }
    
    deinit {
        if let handle = userHandle {
            databaseRef.removeObserver(withHandle: handle)
        }
    }
}
