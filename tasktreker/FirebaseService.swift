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
                    if let tasksDict = userDict["tasks"] as? [String: Any] {
                        var tasks: [Task] = []
                        
                        for (taskId, taskData) in tasksDict {
                            if let taskDict = taskData as? [String: Any] {
                                var taskJson = taskDict
                                taskJson["id"] = taskId
                                
                                let taskData = try JSONSerialization.data(withJSONObject: taskJson)
                                let task = try JSONDecoder().decode(Task.self, from: taskData)
                                tasks.append(task)
                            }
                        }
                        
                        self.currentUserTasks = tasks.sorted {
                            $0.date < $1.date // Сортируем по дате выполнения
                        }
                    }
                } catch {
                    self.error = "Ошибка обработки задач: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func addTask(_ task: Task, for email: String) {
        let taskData: [String: Any] = [
            "text": task.text,
            "date": task.date,
            "created_at": task.createdAt
        ]
        
        databaseRef.child("users/\(email)/tasks/\(task.id)").setValue(taskData) { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                }
            }
        }
    }
    
    func deleteTask(_ task: Task, for email: String) {
        databaseRef.child("users/\(email)/tasks/\(task.id)").removeValue { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
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
