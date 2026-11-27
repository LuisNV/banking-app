import XCTest
@testable import BankingApp

private func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try XCTUnwrap(decoder.decode(APIResponse<T>.self, from: Data(json.utf8)).data)
}

private let origin = HSKVocabularyMapping.serverOrigin(of: URL(string: "http://localhost:8081/api")!)

final class TonesDataTests: XCTestCase {
    func test_decode_guide() throws {
        let guide = try decode("""
        {"code":0,"httpStatus":200,"message":"OK","traceId":"t","data":{"tones":[
          {"number":3,"pinyin":"mǎ","pitch":[2,1,4],"descriptionVi":"Xuống rồi lên.","audioUrl":"/audio/hsk/3.0-2025/3/764.m4a"},
          {"number":1,"pinyin":"mā","pitch":[5,5],"descriptionVi":"Cao và đều.","audioUrl":"/audio/pinyin/5988.wav"}],
          "sandhiTipVi":"Hai thanh 3 liền nhau: thanh đầu thành thanh 2."}}
        """, as: ToneGuideDTO.self).toDomain(audioBaseURL: origin)

        XCTAssertEqual(guide.tones.map(\.number), [1, 3], "Sắp theo số thanh")
        XCTAssertEqual(guide.tones[1].pitch, [2, 1, 4])
        XCTAssertEqual(guide.tones[0].audioURL?.absoluteString, "http://localhost:8081/audio/pinyin/5988.wav")
        XCTAssertNotNil(guide.sandhiTip)
        XCTAssertEqual(TonesEndpoint.guide.path, "v1/tones")
    }

    func test_decode_practice_syllablePosition() throws {
        let questions = try decode("""
        {"code":0,"httpStatus":200,"message":"OK","traceId":"t","data":{"questions":[
          {"hanzi":"你好","level":1,"entryNumber":147,"syllable":"hao","syllablePosition":2,"audioUrl":"/audio/hsk/3.0-2025/1/147.m4a","correctTone":3},
          {"hanzi":"的","level":1,"entryNumber":60,"syllable":"de","audioUrl":null,"correctTone":5}]}}
        """, as: TonePracticeDTO.self).toDomain(audioBaseURL: origin)

        XCTAssertEqual(questions.count, 1, "Bỏ câu thanh nhẹ (không có trong 4 lựa chọn)")
        XCTAssertEqual(questions[0].syllablePosition, 2)
        XCTAssertEqual(questions[0].targetCharacter, "好")
        XCTAssertEqual(questions[0].audioURL?.absoluteString, "http://localhost:8081/audio/hsk/3.0-2025/1/147.m4a")
        XCTAssertEqual(TonesEndpoint.practice.path, "v1/tones/practice")
    }

    func test_pitchContour_pointsMapToLevels() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let flat = PitchContour(pitch: [5, 5]).path(in: rect).boundingRect
        XCTAssertEqual(flat.minY, 0, accuracy: 0.01, "Mức 5 ở trên cùng")
        XCTAssertEqual(flat.height, 0, accuracy: 0.01)
        let falling = PitchContour(pitch: [5, 1]).path(in: rect).boundingRect
        XCTAssertEqual(falling.maxY, 40, accuracy: 0.01, "Mức 1 ở dưới cùng")
    }
}

@MainActor
final class TonesViewModelTests: XCTestCase {
    private final class Silent: PronunciationServiceProtocol {
        func speak(_ text: String, slow: Bool) {}
        func play(url: URL?, fallbackText text: String, slow: Bool) {}
    }

    func test_round_scoresAndFinishes() async {
        let sut = TonesViewModel(repository: MockTonesRepository(), pronunciation: Silent())
        await sut.load()
        XCTAssertEqual(sut.questions.count, 10)

        for index in 0..<10 {
            let question = sut.questions[index]
            sut.pick(index == 0 ? (question.correctTone % 4) + 1 : question.correctTone)
            sut.pick(question.correctTone) // chọn lại không đổi đáp án
            sut.next()
        }
        XCTAssertTrue(sut.isFinished)
        XCTAssertEqual(sut.score, 9)

        await sut.loadPractice()
        XCTAssertEqual(sut.index, 0)
        XCTAssertEqual(sut.score, 0)
    }
}

final class RadicalsDataTests: XCTestCase {
    func test_decode_item85() throws {
        let list = try decode("""
        {"code":0,"httpStatus":200,"message":"OK","traceId":"t","data":{"total":1,"items":[
          {"number":85,"symbol":"氵","canonical":"水","forms":["氵","水"],"hanViet":"thủy","aliasVi":null,"meaningVi":"nước",
           "strokes":3,"canonicalStrokes":4,"common":true,"descriptionVi":"Ba chấm thủy thường nằm bên trái chữ.",
           "examples":[{"hanzi":"河","hanViet":"hà","meaningVi":"sông"}]}]}}
        """, as: RadicalListDTO.self).toDomain()

        let radical = try XCTUnwrap(list.items.first)
        XCTAssertEqual(list.total, 1)
        XCTAssertTrue(radical.isVariant)
        XCTAssertEqual(radical.canonicalStrokes, 4)
        XCTAssertNil(radical.alias)
        XCTAssertEqual(radical.examples.first?.meaning, "sông")
    }

    func test_endpoint_query() {
        XCTAssertNil(RadicalsEndpoint.list(RadicalQuery(commonOnly: false)).queryItems, "Tất cả 214: không tham số")
        XCTAssertEqual(RadicalsEndpoint.list(RadicalQuery(commonOnly: true)).queryItems, ["commonOnly": "true"])
        let search = RadicalsEndpoint.list(RadicalQuery(commonOnly: false, search: " 85 ", strokes: .three))
        XCTAssertEqual(search.queryItems, ["q": "85", "strokes": "3"])
        XCTAssertEqual(RadicalsEndpoint.list(RadicalQuery(commonOnly: false, strokes: .fivePlus)).queryItems?["strokes"], "5+")
        XCTAssertEqual(search.path, "v1/radicals")
    }
}

@MainActor
final class RadicalsViewModelTests: XCTestCase {
    func test_modeSearchAndStrokes_filter_andKeepSelectionValid() async {
        let sut = RadicalsViewModel(repository: MockRadicalsRepository())
        await sut.reload()
        XCTAssertTrue(sut.items.allSatisfy(\.isCommon))
        XCTAssertFalse(sut.items.contains { $0.number == 1 })

        sut.mode = .all
        await sut.reload()
        XCTAssertTrue(sut.items.contains { $0.number == 1 })

        sut.search = "thuy"
        sut.strokes = .three
        await sut.reload()
        XCTAssertEqual(sut.items.map(\.number), [85])
        XCTAssertEqual(sut.selected?.number, 85)
    }
}
