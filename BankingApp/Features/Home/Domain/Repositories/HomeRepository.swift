import Foundation

protocol HomeRepository {
    func dashboard() async throws -> HomeDashboard
}
