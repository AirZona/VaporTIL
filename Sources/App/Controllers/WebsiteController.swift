import Vapor
import Leaf

struct WebsiteController: RouteCollection {
    
    func boot(router: Router) throws {
        router.get(use: indexHandler)
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", use: allUsersHandler)
        router.get("categories", Category.parameter, use: categoryHandler)
        router.get("categories", use: allCategoriesHandler)
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
        return User.query(on: req).all().flatMap(to: View.self) { users in
            let context = CreateAcronymContext(title: "Create An Acronym", users: users)
            return try req.leaf().render("createAcronym", context)
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
    let users: [User]
}
