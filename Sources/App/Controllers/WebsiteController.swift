import Vapor
import Leaf
import Authentication
import Crypto

struct WebsiteController: RouteCollection {
    
    func boot(router: Router) throws {
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post("login", use: loginPostHandler)
        authSessionRoutes.get("register", use: registerHandler)
        authSessionRoutes.post("register", use: registerPostHandler)
        
        let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
        protectedRoutes.get("create-acronym", use: createAcronymHandler)
        protectedRoutes.post("create-acronym", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
        
    }
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
            let context = IndexContext(title: "Homepage", acronyms: acronyms.isEmpty ? nil : acronyms)
            return try req.leaf().render("index", context)
        }
    }
    
    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
            return try flatMap(to: View.self, acronym.creator.get(on: req), acronym.categories.query(on: req).all()) { creator, categories in
                let context = AcronymContext(title: acronym.long, acronym: acronym, creator: creator, categories: categories)
                return try req.leaf().render("acronym", context)
            }
        }
    }
    
    func userHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(User.self).flatMap(to: View.self) { user in
            return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
                let context = UserContext(title: user.name, user: user, acronyms: acronyms.isEmpty ? nil : acronyms)
                return try req.leaf().render("user", context)
            }
        }
    }
    
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        return User.query(on: req).all().flatMap(to: View.self) { users in
            let context = AllUsersContext(title: "All Users", users: users.isEmpty ? nil : users)
            return try req.leaf().render("allUsers", context)
        }
    }
    
    func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Category.self).flatMap(to: View.self) { category in
            return try category.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
                let context = CategoryContext(title: category.name, category: category, acronyms: acronyms.isEmpty ? nil : acronyms)
                return try req.leaf().render("category", context)
            }
        }
    }
    
    func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        return Category.query(on: req).all().flatMap(to: View.self) { categories in
            let context = AllCategoriesContext(title: "All Categories", categories: categories.isEmpty ? nil : categories)
            return try req.leaf().render("allCategories", context)
        }
    }
    
    func createAcronymHandler(req: Request) throws -> Future<View> {
        let context = CreateAcronymContext(title: "Create An Acronym")
        return try req.leaf().render("createAcronym", context)
    }
    
    func createAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(AcronymPostData.self).flatMap(to: Response.self) { data in
            let user = try req.requireAuthenticated(User.self)
            let acronym = try Acronym(short: data.acronymShort, long: data.acronymLong, creatorID: user.requireID())
            return acronym.save(on: req).map(to: Response.self) { acronym in
                guard let id = acronym.id else {
                    return req.redirect(to: "/")
                }
                return req.redirect(to: "/acronyms/\(id)")
            }
        }
    }
    
    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameters.next(Acronym.self).flatMap(to: View.self) { acronym in
            let context = EditAcronymContext(title: "Edit Acronym", acronym: acronym)
            return try req.leaf().render("createAcronym", context)
        }
    }
    
    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try flatMap(to: Response.self, req.parameters.next(Acronym.self), req.content.decode(AcronymPostData.self)) { acronym, data in
            acronym.short = data.acronymShort
            acronym.long = data.acronymLong
            acronym.creatorID = try req.requireAuthenticated(User.self).requireID()
            
            return acronym.save(on: req).map(to: Response.self) { acronym in
                guard let id = acronym.id else {
                    return req.redirect(to: "/")
                }
                return req.redirect(to: "/acronyms/\(id)")
            }
        }
    }
    
    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self).flatMap(to: Response.self) { acronym in
            return acronym.delete(on: req).transform(to: req.redirect(to: "/"))
        }
    }
    
    func loginHandler(_ req: Request) throws -> Future<View> {
        let context = LoginContext(title: "Log In")
        return try req.leaf().render("login", context)
    }
    
    func loginPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(LoginPostData.self).flatMap(to: Response.self) { data in
            let verifier = try req.make(BCryptDigest.self)
            return User.authenticate(username: data.username, password: data.password, using: verifier, on: req).map(to: Response.self) { user in
                guard let user = user else {
                    return req.redirect(to: "/login")
                }
                try req.authenticate(user)
                return req.redirect(to: "/")
            }
        }
    }
    
    func registerHandler(_ req: Request) throws -> Future<View> {
        let context = RegisterContext(title: "Sign Up")
        return try req.leaf().render("register", context)
    }
    
    func registerPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(RegisterPostData.self).flatMap(to: Response.self) { data in
            return try User.query(on: req).filter(\.username, .custom(.sql("ILIKE")), .data(data.username)).all().map(to: Response.self) { users in
                if users.isEmpty {
                    let hasher = try req.make(BCryptDigest.self)
                    let password = try hasher.hash(data.password)
                    let user = User(name: data.name, username: data.username, password: password)
                    
                    let _ = user.save(on: req)
                    
                    try req.authenticate(user)
                    return req.redirect(to: "/")
                } else {
                    throw Abort(.badRequest, reason: "User name already exists")
                }
            }
        }
    }
}

extension Request {
    func leaf() throws -> LeafRenderer {
        return try self.make(LeafRenderer.self)
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let creator: User
    let categories: [Category]?
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]?
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]?
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: [Acronym]?
}

struct AllCategoriesContext: Encodable {
    let title: String
    let categories: [Category]?
}

struct CreateAcronymContext: Encodable {
    let title: String
}

struct AcronymPostData: Content {
    static var defaultMediaType = MediaType.urlEncodedForm
    let acronymLong: String
    let acronymShort: String
}

struct EditAcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let editing = true
}

struct LoginContext: Encodable {
    let title: String
}

struct LoginPostData: Content {
    let username: String
    let password: String
}

struct RegisterContext: Encodable {
    let title: String
}

struct RegisterPostData: Content {
    let name: String
    let username: String
    let password: String
}
