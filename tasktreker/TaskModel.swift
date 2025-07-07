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

struct ShoppingItem: Codable, Identifiable, Hashable {
    var id: String { url }
    let full_name: String
    let image_url: String
    let price: String
    let price_with_card: String
    let short_name: String
    let url: String
}

struct Task: Codable, Identifiable, Equatable {
    var id: String
    let text: String
    let date: String
    let createdAt: String
    var priority: Int?
    var iot: Int?
    var shopping_list: [ShoppingItem]?
    
    enum CodingKeys: String, CodingKey {
        case text, date, priority, iot
        case createdAt = "created_at"
        case shopping_list = "shopping_list"
        case id
    }
}

struct Device: Identifiable, Equatable {
    let id: String
    let name: String
    let imageName: String
    let type: String
    var isOnline: Bool
    var mqttTopic: String?
    
    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}
