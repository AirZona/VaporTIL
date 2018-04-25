import Vapor
import Fluent

struct AcronymsController: RouteCollection {
    
    func boot(router: Router) throws {
        let acroynmsRoute = router.grouped("api", "acronyms")
        acroynmsRoute.get(use: getAllHandler)
        acroynmsRoute.post(use: createHandler)
        acroynmsRoute.get(Acronym.parameter, use: getHandler)
        acroynmsRoute.delete(Acronym.parameter, use: deleteHandler)
        acroynmsRoute.put(Acronym.parameter, use: updateHandler)
        acroynmsRoute.get(Acronym.parameter, "creator", use: getCreatorHandler)
        acroynmsRoute.get(Acronym.parameter, "categories", Category.parameter, use: getCategoriesHandler)
        acroynmsRoute.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        acroynmsRoute.get("search", use: searchHandler)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }
    
    func createHandler(_ req: Request) throws -> Future<Acronym> {
        let acronym = try req.content.decode(Acronym.self)
        return acronym.save(on: req)
    }
    
    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self).flatMap(to: HTTPStatus.self) { acronym in
            return acronym.delete(on: req).transform(to: .noContent)
        }
    }
    
    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self)) { acronym, updatedAcronym in
            acronym.short = updatedAcronym.short
            acronym.long = updatedAcronym.long
            return acronym.save(on: req)
        }
    }
    
    func getCreatorHandler(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(Acronym.self).flatMap(to: User.self) { acronym in
            return try acronym.creator.get(on: req)
        }
    }
    
    func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
        return try req.parameters.next(Acronym.self).flatMap(to: [Category].self) { acronym in
            return try acronym.categories.query(on: req).all()
        }
    }
    
    func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self)) { acronym, category in
            let pivot = try AcronymCategoryPivot(acronym.requireID(), category.requireID())
            return pivot.save(on: req).transform(to: .ok)
        }
    }
    
    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest, reason: "Missing search term in request")
        }
        
        return try Acronym.query(on: req).group(.or) { or in
            try or.filter(\.short, .custom(.sql("ILIKE")), .data(searchTerm))
            try or.filter(\.long, .custom(.sql("ILIKE")), .data(searchTerm))
            }.all()
    }
    
}

extension Acronym: Parameter {}
