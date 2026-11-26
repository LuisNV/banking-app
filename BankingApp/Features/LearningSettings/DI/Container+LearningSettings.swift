import Factory
import Foundation

extension Container {
    // MARK: Data
    var learningSettingsRemoteDataSource: Factory<any LearningSettingsRemoteDataSource> {
        self { () -> any LearningSettingsRemoteDataSource in
            if self.appConfig().useMockAPI {
                return MockLearningSettingsRemoteDataSource()
            }
            return LearningSettingsRemoteDataSourceImpl(client: self.apiClient())
        }.singleton
    }

    var learningSettingsRepository: Factory<any LearningSettingsRepository> {
        self {
            LearningSettingsRepositoryImpl(
                remote: self.learningSettingsRemoteDataSource(),
                keyValueStore: self.keyValueStore()
            )
        }.singleton
    }

    // MARK: Domain
    var learningSettingsUseCase: Factory<any LearningSettingsUseCaseProtocol> {
        self { LearningSettingsUseCase(repository: self.learningSettingsRepository()) }
    }

    // MARK: Services
    var reminderScheduler: Factory<any ReminderScheduling> {
        self { LocalReminderScheduler() }.singleton
    }
}
