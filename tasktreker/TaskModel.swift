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
    
    enum CodingKeys: String, CodingKey {
        case text, date
        case createdAt = "created_at"
        case id
    }
}
