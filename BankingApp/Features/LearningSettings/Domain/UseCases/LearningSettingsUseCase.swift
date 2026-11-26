import Foundation

protocol LearningSettingsUseCaseProtocol {
    func cached() -> LearningSettings?
    func fetch() async throws -> LearningSettings
    func save(_ settings: LearningSettings) async throws -> LearningSettings
    func hanziFontSize() -> Double?
    func setHanziFontSize(_ size: Double)
}

struct LearningSettingsUseCase: LearningSettingsUseCaseProtocol {
    let repository: LearningSettingsRepository

    func cached() -> LearningSettings? { repository.cachedSettings() }

    func fetch() async throws -> LearningSettings { try await repository.fetch() }

    func save(_ settings: LearningSettings) async throws -> LearningSettings {
        if let message = LearningSettingsValidator.error(for: settings) {
            throw LearningSettingsError.invalid(message: message)
        }
        return try await repository.save(settings)
    }

    func hanziFontSize() -> Double? { repository.hanziFontSize() }
    func setHanziFontSize(_ size: Double) { repository.setHanziFontSize(size) }
}
