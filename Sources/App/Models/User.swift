import FluentPostgreSQL
import Vapor

final class User: Codable {
    
    var id: UUID?
    var name: String
    var username: String
    
    init(name: String, username: String) {
        self.name = name
        self.username = username
    }
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {}

extension User {
    
    var acronyms: Children<User, Acronym> {
        return children(\.creatorID)
    }
    
}
