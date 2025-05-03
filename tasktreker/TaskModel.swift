import Foundation

struct User: Codable {
    let email: String
    let createdAt: String
    let lastActive: String
    let state: String
    let tasks: [String: Task]?
    
    enum CodingKeys: String, CodingKey {
        case email
        case createdAt = "created_at"
        case lastActive = "last_active"
        case state, tasks
    }
}

struct Task: Codable, Identifiable, Equatable {
    var id: String
    let text: String
    let date: String
    let createdAt: String
    var priority: Int?  // Опциональное поле приоритета
    var iot: Int?       // Добавленное поле iot
    
    enum CodingKeys: String, CodingKey {
        case text, date, priority, iot
        case createdAt = "created_at"
        case id
    }
}
