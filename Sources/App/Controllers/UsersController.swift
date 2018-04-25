import Vapor

struct UsersController: RouteCollection {
    
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        usersRoute.get(use: getAllHandler)
        usersRoute.post(use: createHandler)
        usersRoute.get(User.parameter, use: getHandler)
        usersRoute.get(User.parameter, "acronyms", use: getAcronymsHandler)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[User]> {
        return User.query(on: req).all()
    }
    
    func createHandler(_ req: Request) throws -> Future<User> {
        return try req.content.decode(User.self).flatMap(to: User.self) { user in
            return user.save(on: req)
        }
    }
    
    func getHandler(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(User.self)
    }
    
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(User.self).flatMap(to: [Acronym].self) { user in
            return try user.acronyms.query(on: req).all()
        }
    }
    
}

extension User: Parameter {}
