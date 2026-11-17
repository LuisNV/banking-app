import Foundation

protocol UtilitiesRepository {
    func publicUtilities() async throws -> [UtilityItem]
    func supportContact() -> SupportContact
}
