import Foundation

protocol HSKVocabularyRemoteDataSource: Sendable {
    func levels() async throws -> [HSKLevelDTO]
    func words(level: Int, status: String?, page: Int, size: Int) async throws -> HSKWordPageDTO
    func word(level: Int, entryNumber: Int) async throws -> HSKWordDetailDTO
    func reviews(_ body: HSKReviewRequestDTO) async throws -> HSKReviewResponseDTO
    func putProgress(level: Int, entryNumber: Int, body: HSKProgressPutDTO) async throws -> HSKProgressResponseDTO
}

final class HSKVocabularyRemoteDataSourceImpl: HSKVocabularyRemoteDataSource, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func levels() async throws -> [HSKLevelDTO] {
        try await client.request(HSKVocabularyEndpoint.levels, as: [HSKLevelDTO].self)
    }

    func words(level: Int, status: String?, page: Int, size: Int) async throws -> HSKWordPageDTO {
        try await client.request(
            HSKVocabularyEndpoint.words(level: level, status: status, page: page, size: size),
            as: HSKWordPageDTO.self
        )
    }

    func word(level: Int, entryNumber: Int) async throws -> HSKWordDetailDTO {
        try await client.request(HSKVocabularyEndpoint.word(level: level, entryNumber: entryNumber), as: HSKWordDetailDTO.self)
    }

    func reviews(_ body: HSKReviewRequestDTO) async throws -> HSKReviewResponseDTO {
        try await client.request(HSKVocabularyEndpoint.reviews(body), as: HSKReviewResponseDTO.self)
    }

    func putProgress(level: Int, entryNumber: Int, body: HSKProgressPutDTO) async throws -> HSKProgressResponseDTO {
        try await client.request(
            HSKVocabularyEndpoint.progress(level: level, entryNumber: entryNumber, body: body),
            as: HSKProgressResponseDTO.self
        )
    }
}
