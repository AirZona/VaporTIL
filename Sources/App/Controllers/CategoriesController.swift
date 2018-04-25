import Vapor

struct CategoriesController: RouteCollection {
    
    func boot(router: Router) throws {
        let categoriesRoute = router.grouped("api", "categories")
        categoriesRoute.get(use: getAllHandler)
        categoriesRoute.post(use: createHandler)
        categoriesRoute.get(Category.parameter, use: getHandler)
        categoriesRoute.get(Category.parameter, "acronyms", use: getAcronymsHandler)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Category]> {
        return Category.query(on: req).all()
    }
    
    func createHandler(_ req: Request) throws -> Future<Category> {
        return try req.content.decode(Category.self).flatMap(to: Category.self) { category in
            return category.save(on: req)
        }
    }
    
    func getHandler(_ req: Request) throws -> Future<Category> {
        return try req.parameters.next(Category.self)
    }
    
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(Category.self).flatMap(to: [Acronym].self) { category in
            return try category.acronyms.query(on: req).all()
        }
    }
    
}

extension Category: Parameter {}
