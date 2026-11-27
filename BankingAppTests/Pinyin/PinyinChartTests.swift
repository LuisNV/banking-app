import XCTest
@testable import BankingApp

final class PinyinChartDataTests: XCTestCase {
    func test_decode_chart_resolvesAudio_andMapsCombinations() throws {
        let json = """
        {"code":0,"httpStatus":200,"message":"Thành công","traceId":"t","data":{
          "initials":[{"titleVi":"Mặt lưỡi · Đầu lưỡi sau · Đầu lưỡi trước","items":[
            {"symbol":"zh","pinyin":"zhōng","hanzi":"中","meaningVi":"giữa",
             "tipVi":"Hơi cong đầu lưỡi về phía sau lợi trên rồi nhả nhẹ.","audioUrl":"/audio/hsk/3.0-2025/3/981.m4a"}]}],
          "finals":[{"titleVi":"Vận mẫu mũi sau","items":[
            {"symbol":"ong","pinyin":"zhōng","hanzi":"中","meaningVi":"giữa","tipVi":"Tròn môi và kết thúc bằng ng.","audioUrl":null}]},
            {"titleVi":"Rỗng","items":[]}],
          "combinations":[{"initial":"zh","finalSymbol":"ong","syllable":"zhong"},{"initial":null,"finalSymbol":"er","syllable":"er"}]}}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chart = try XCTUnwrap(decoder.decode(APIResponse<PinyinChartDTO>.self, from: Data(json.utf8)).data)
            .toDomain(audioBaseURL: HSKVocabularyMapping.serverOrigin(of: URL(string: "http://localhost:8081/api")!))

        let zh = try XCTUnwrap(chart.initials.first?.sounds.first)
        XCTAssertEqual(zh.symbol, "zh")
        XCTAssertEqual(zh.examplePinyin, "zhōng")
        XCTAssertEqual(zh.audioURL?.absoluteString, "http://localhost:8081/audio/hsk/3.0-2025/3/981.m4a")
        XCTAssertEqual(chart.finals.count, 1, "Bỏ nhóm không có âm nào")
        XCTAssertNil(chart.finals[0].sounds[0].audioURL)
        XCTAssertEqual(chart.combinations[0], PinyinCombination(initial: "zh", final: "ong", syllable: "zhong"))
        XCTAssertEqual(chart.combinations[1].initial, "", "initial null → không có thanh mẫu")
        XCTAssertEqual(PinyinEndpoint.chart.path, "v1/pinyin/chart")
    }
}

@MainActor
final class PinyinChartViewModelTests: XCTestCase {
    private final class SpyPronunciation: PronunciationServiceProtocol {
        var played: [(URL?, String)] = []
        func speak(_ text: String, slow: Bool) {}
        func play(url: URL?, fallbackText text: String, slow: Bool) { played.append((url, text)) }
    }

    private struct StubRepository: PinyinRepository {
        let value: PinyinChart
        func chart() async throws -> PinyinChart { value }
    }

    private func makeChart() -> PinyinChart {
        PinyinChart(
            initials: [PinyinGroup(id: "g", title: "Âm môi", sounds: [
                PinyinSound(symbol: "b", examplePinyin: "bā", exampleHanzi: "八"),
                PinyinSound(symbol: "m", examplePinyin: "mā", exampleHanzi: "妈", audioURL: URL(string: "http://x/m.m4a")),
            ])],
            finals: [PinyinGroup(id: "f", title: "Đơn", sounds: [PinyinSound(symbol: "a")])],
            combinations: [
                .init(initial: "", final: "er", syllable: "er"),
                .init(initial: "b", final: "a", syllable: "ba"),
                .init(initial: "j", final: "ü", syllable: "ju"),
                .init(initial: "b", final: "ai", syllable: "bai"),
            ]
        )
    }

    func test_selectSound_playsAudio_andKeepsSelectionPerTab() async {
        let spy = SpyPronunciation()
        let sut = PinyinChartViewModel(repository: StubRepository(value: makeChart()), pronunciation: spy)
        await sut.load()

        XCTAssertEqual(sut.selectedSound?.symbol, "b", "Mặc định chọn âm đầu tiên")
        sut.select(sut.groups[0].sounds[1])
        XCTAssertEqual(sut.selectedSound?.symbol, "m")
        XCTAssertEqual(spy.played.last?.0?.absoluteString, "http://x/m.m4a")

        sut.tab = .finals
        XCTAssertEqual(sut.selectedSound?.symbol, "a")
        sut.tab = .initials
        XCTAssertEqual(sut.selectedSound?.symbol, "m")
    }

    func test_combinations_groupedByInitial_noInitialLast() async {
        let sut = PinyinChartViewModel(repository: StubRepository(value: makeChart()), pronunciation: SpyPronunciation())
        await sut.load()

        XCTAssertEqual(sut.combinationInitials, ["b", "j", ""])
        XCTAssertEqual(sut.combinationsForInitial.map(\.syllable), ["ba", "bai"])
        sut.selectCombinationInitial("j")
        XCTAssertEqual(sut.currentCombination?.syllable, "ju")
        XCTAssertEqual(sut.totalCombinations, 4)
    }
}
