import Factory
import Foundation

extension Container {
    var hskVocabularyRemoteDataSource: Factory<any HSKVocabularyRemoteDataSource> {
        self { HSKVocabularyRemoteDataSourceImpl(client: self.apiClient()) }
    }

    var vocabularyRepository: Factory<any VocabularyRepository> {
        self { () -> any VocabularyRepository in
            if self.appConfig().useMockAPI {
                return MockVocabularyRepository()
            }
            return VocabularyRepositoryImpl(
                remote: self.hskVocabularyRemoteDataSource(),
                apiBaseURL: self.appConfig().baseURL
            )
        }.singleton
    }
}
