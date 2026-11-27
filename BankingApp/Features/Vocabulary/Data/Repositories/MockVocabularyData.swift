import Foundation

/// Dữ liệu mẫu HSK 1 (một phần) để dựng giao diện khi chưa có API.
enum MockVocabularyData {
    static let hsk1: [VocabWord] = [
        VocabWord(
            id: "hsk1-nihao", level: 1, entryNumber: 1, topic: "Chào hỏi",
            hanzi: "你好", pinyin: "nǐ hǎo", meaning: "xin chào", partOfSpeech: "Cụm từ · dùng khi gặp mặt",
            hanViet: "Nhĩ hảo", hanVietNote: "“ngươi tốt” → lời chào",
            characters: [.init(hanzi: "你", reading: "Nhĩ", meaning: "bạn, ngươi"), .init(hanzi: "好", reading: "Hảo", meaning: "tốt")],
            examples: [.init(hanzi: "你好，我叫明安。", pinyin: "Nǐ hǎo, wǒ jiào Míng Ān.", meaning: "Xin chào, tôi tên là Minh An.", note: nil), .init(hanzi: "老师，您好！", pinyin: "Lǎoshī, nín hǎo!", meaning: "Em chào thầy/cô ạ!", note: "您 (nín) là cách nói lịch sự của 你")],
            decomposition: [.init(character: "你", hanViet: "nhĩ", layout: "Trái/phải", components: [.init(character: "亻", hanViet: "nhân", meaning: "người"), .init(character: "尔", hanViet: "nhĩ", meaning: "ngươi")], mnemonic: "Người mà mình gọi là ngươi → bạn."), .init(character: "好", hanViet: "hảo", layout: "Trái/phải", components: [.init(character: "女", hanViet: "nữ", meaning: "phụ nữ"), .init(character: "子", hanViet: "tử", meaning: "con")], mnemonic: "Mẹ bế con → điều tốt, hay.")],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-xiexie", level: 1, entryNumber: 2, topic: "Chào hỏi",
            hanzi: "谢谢", pinyin: "xièxie", meaning: "cảm ơn", partOfSpeech: "Động từ",
            hanViet: "Tạ tạ", hanVietNote: nil,
            characters: [.init(hanzi: "谢", reading: "Tạ", meaning: "cảm tạ, cảm ơn")],
            examples: [.init(hanzi: "谢谢你！", pinyin: "Xièxie nǐ!", meaning: "Cảm ơn bạn!", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-zaijian", level: 1, entryNumber: 3, topic: "Chào hỏi",
            hanzi: "再见", pinyin: "zàijiàn", meaning: "tạm biệt", partOfSpeech: "Động từ",
            hanViet: "Tái kiến", hanVietNote: "“gặp lại” → tạm biệt",
            characters: [.init(hanzi: "再", reading: "Tái", meaning: "lại, lần nữa"), .init(hanzi: "见", reading: "Kiến", meaning: "gặp, thấy")],
            examples: [.init(hanzi: "老师，再见！", pinyin: "Lǎoshī, zàijiàn!", meaning: "Em chào thầy/cô, em về ạ!", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-duibuqi", level: 1, entryNumber: 4, topic: "Chào hỏi",
            hanzi: "对不起", pinyin: "duìbuqǐ", meaning: "xin lỗi", partOfSpeech: "Động từ",
            hanViet: "Đối bất khởi", hanVietNote: nil,
            characters: [.init(hanzi: "对", reading: "Đối", meaning: "đối diện"), .init(hanzi: "不", reading: "Bất", meaning: "không"), .init(hanzi: "起", reading: "Khởi", meaning: "dậy, nổi")],
            examples: [.init(hanzi: "对不起，我来晚了。", pinyin: "Duìbuqǐ, wǒ lái wǎn le.", meaning: "Xin lỗi, tôi đến muộn.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-bukeqi", level: 1, entryNumber: 5, topic: "Chào hỏi",
            hanzi: "不客气", pinyin: "bú kèqi", meaning: "không có gì", partOfSpeech: "Cụm từ · đáp lại lời cảm ơn",
            hanViet: "Bất khách khí", hanVietNote: "“đừng khách sáo”",
            characters: [.init(hanzi: "不", reading: "Bất", meaning: "không"), .init(hanzi: "客", reading: "Khách", meaning: "khách"), .init(hanzi: "气", reading: "Khí", meaning: "khí")],
            examples: [.init(hanzi: "谢谢！不客气。", pinyin: "Xièxie! Bú kèqi.", meaning: "Cảm ơn! Không có gì.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-qing", level: 1, entryNumber: 6, topic: "Chào hỏi",
            hanzi: "请", pinyin: "qǐng", meaning: "mời, xin (lịch sự)", partOfSpeech: "Động từ",
            hanViet: "Thỉnh", hanVietNote: nil,
            characters: [.init(hanzi: "请", reading: "Thỉnh", meaning: "mời, xin")],
            examples: [.init(hanzi: "请坐。", pinyin: "Qǐng zuò.", meaning: "Mời ngồi.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-baba", level: 1, entryNumber: 7, topic: "Gia đình",
            hanzi: "爸爸", pinyin: "bàba", meaning: "bố, ba", partOfSpeech: "Danh từ",
            hanViet: "Ba ba", hanVietNote: nil,
            characters: [.init(hanzi: "爸", reading: "Ba", meaning: "cha, bố")],
            examples: [.init(hanzi: "我爸爸是医生。", pinyin: "Wǒ bàba shì yīshēng.", meaning: "Bố tôi là bác sĩ.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-mama", level: 1, entryNumber: 8, topic: "Gia đình",
            hanzi: "妈妈", pinyin: "māma", meaning: "mẹ, má", partOfSpeech: "Danh từ",
            hanViet: "Ma ma", hanVietNote: nil,
            characters: [.init(hanzi: "妈", reading: "Ma", meaning: "mẹ")],
            examples: [.init(hanzi: "我妈妈是老师。", pinyin: "Wǒ māma shì lǎoshī.", meaning: "Mẹ tôi là giáo viên.", note: nil)],
            decomposition: [.init(character: "妈", hanViet: "ma", layout: "Trái/phải", components: [.init(character: "女", hanViet: "nữ", meaning: "phụ nữ"), .init(character: "马", hanViet: "mã", meaning: "ngựa")], mnemonic: "Người phụ nữ, đọc gần như 马 → mẹ.")],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-erzi", level: 1, entryNumber: 9, topic: "Gia đình",
            hanzi: "儿子", pinyin: "érzi", meaning: "con trai", partOfSpeech: "Danh từ",
            hanViet: "Nhi tử", hanVietNote: nil,
            characters: [.init(hanzi: "儿", reading: "Nhi", meaning: "con, trẻ"), .init(hanzi: "子", reading: "Tử", meaning: "con")],
            examples: [.init(hanzi: "他有一个儿子。", pinyin: "Tā yǒu yí ge érzi.", meaning: "Anh ấy có một con trai.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-nver", level: 1, entryNumber: 10, topic: "Gia đình",
            hanzi: "女儿", pinyin: "nǚ'ér", meaning: "con gái", partOfSpeech: "Danh từ",
            hanViet: "Nữ nhi", hanVietNote: nil,
            characters: [.init(hanzi: "女", reading: "Nữ", meaning: "con gái, nữ"), .init(hanzi: "儿", reading: "Nhi", meaning: "con, trẻ")],
            examples: [.init(hanzi: "她女儿很漂亮。", pinyin: "Tā nǚ'ér hěn piàoliang.", meaning: "Con gái cô ấy rất xinh.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-jia", level: 1, entryNumber: 11, topic: "Gia đình",
            hanzi: "家", pinyin: "jiā", meaning: "nhà, gia đình", partOfSpeech: "Danh từ",
            hanViet: "Gia", hanVietNote: nil,
            characters: [.init(hanzi: "家", reading: "Gia", meaning: "nhà")],
            examples: [.init(hanzi: "我家有四口人。", pinyin: "Wǒ jiā yǒu sì kǒu rén.", meaning: "Nhà tôi có bốn người.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-pengyou", level: 1, entryNumber: 12, topic: "Gia đình",
            hanzi: "朋友", pinyin: "péngyou", meaning: "bạn bè", partOfSpeech: "Danh từ",
            hanViet: "Bằng hữu", hanVietNote: nil,
            characters: [.init(hanzi: "朋", reading: "Bằng", meaning: "bạn"), .init(hanzi: "友", reading: "Hữu", meaning: "bạn")],
            examples: [.init(hanzi: "他是我的朋友。", pinyin: "Tā shì wǒ de péngyou.", meaning: "Anh ấy là bạn tôi.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-yi", level: 1, entryNumber: 13, topic: "Số đếm",
            hanzi: "一", pinyin: "yī", meaning: "một", partOfSpeech: "Số từ",
            hanViet: "Nhất", hanVietNote: nil,
            characters: [.init(hanzi: "一", reading: "Nhất", meaning: "một")],
            examples: [.init(hanzi: "我有一个哥哥。", pinyin: "Wǒ yǒu yí ge gēge.", meaning: "Tôi có một anh trai.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-er", level: 1, entryNumber: 14, topic: "Số đếm",
            hanzi: "二", pinyin: "èr", meaning: "hai", partOfSpeech: "Số từ",
            hanViet: "Nhị", hanVietNote: nil,
            characters: [.init(hanzi: "二", reading: "Nhị", meaning: "hai")],
            examples: [.init(hanzi: "今天是二月三号。", pinyin: "Jīntiān shì èr yuè sān hào.", meaning: "Hôm nay là ngày 3 tháng 2.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-san", level: 1, entryNumber: 15, topic: "Số đếm",
            hanzi: "三", pinyin: "sān", meaning: "ba", partOfSpeech: "Số từ",
            hanViet: "Tam", hanVietNote: nil,
            characters: [.init(hanzi: "三", reading: "Tam", meaning: "ba")],
            examples: [.init(hanzi: "我有三本书。", pinyin: "Wǒ yǒu sān běn shū.", meaning: "Tôi có ba quyển sách.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-si", level: 1, entryNumber: 16, topic: "Số đếm",
            hanzi: "四", pinyin: "sì", meaning: "bốn", partOfSpeech: "Số từ",
            hanViet: "Tứ", hanVietNote: nil,
            characters: [.init(hanzi: "四", reading: "Tứ", meaning: "bốn")],
            examples: [.init(hanzi: "我家有四口人。", pinyin: "Wǒ jiā yǒu sì kǒu rén.", meaning: "Nhà tôi có bốn người.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-wu", level: 1, entryNumber: 17, topic: "Số đếm",
            hanzi: "五", pinyin: "wǔ", meaning: "năm (số 5)", partOfSpeech: "Số từ",
            hanViet: "Ngũ", hanVietNote: nil,
            characters: [.init(hanzi: "五", reading: "Ngũ", meaning: "năm")],
            examples: [.init(hanzi: "现在五点。", pinyin: "Xiànzài wǔ diǎn.", meaning: "Bây giờ là năm giờ.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-shi", level: 1, entryNumber: 18, topic: "Số đếm",
            hanzi: "十", pinyin: "shí", meaning: "mười", partOfSpeech: "Số từ",
            hanViet: "Thập", hanVietNote: nil,
            characters: [.init(hanzi: "十", reading: "Thập", meaning: "mười")],
            examples: [.init(hanzi: "这个十块钱。", pinyin: "Zhège shí kuài qián.", meaning: "Cái này mười tệ.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-jintian", level: 1, entryNumber: 19, topic: "Thời gian",
            hanzi: "今天", pinyin: "jīntiān", meaning: "hôm nay", partOfSpeech: "Danh từ",
            hanViet: "Kim thiên", hanVietNote: "“ngày nay”",
            characters: [.init(hanzi: "今", reading: "Kim", meaning: "nay"), .init(hanzi: "天", reading: "Thiên", meaning: "ngày, trời")],
            examples: [.init(hanzi: "今天很热。", pinyin: "Jīntiān hěn rè.", meaning: "Hôm nay rất nóng.", note: nil)],
            decomposition: [.init(character: "今", hanViet: "kim", layout: "Trên/dưới", components: [.init(character: "人", hanViet: "nhân", meaning: "người"), .init(character: "一", hanViet: "nhất", meaning: "một")], mnemonic: nil), .init(character: "天", hanViet: "thiên", layout: "Trên/dưới", components: [.init(character: "一", hanViet: "nhất", meaning: "một"), .init(character: "大", hanViet: "đại", meaning: "to lớn")], mnemonic: "Thứ ở trên cả cái lớn → trời, ngày.")],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-mingtian", level: 1, entryNumber: 20, topic: "Thời gian",
            hanzi: "明天", pinyin: "míngtiān", meaning: "ngày mai", partOfSpeech: "Danh từ",
            hanViet: "Minh thiên", hanVietNote: nil,
            characters: [.init(hanzi: "明", reading: "Minh", meaning: "sáng, kế tiếp"), .init(hanzi: "天", reading: "Thiên", meaning: "ngày, trời")],
            examples: [.init(hanzi: "明天见！", pinyin: "Míngtiān jiàn!", meaning: "Mai gặp nhé!", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-zuotian", level: 1, entryNumber: 21, topic: "Thời gian",
            hanzi: "昨天", pinyin: "zuótiān", meaning: "hôm qua", partOfSpeech: "Danh từ",
            hanViet: "Tạc thiên", hanVietNote: nil,
            characters: [.init(hanzi: "昨", reading: "Tạc", meaning: "hôm qua"), .init(hanzi: "天", reading: "Thiên", meaning: "ngày, trời")],
            examples: [.init(hanzi: "昨天我去商店了。", pinyin: "Zuótiān wǒ qù shāngdiàn le.", meaning: "Hôm qua tôi đã đi cửa hàng.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-nian", level: 1, entryNumber: 22, topic: "Thời gian",
            hanzi: "年", pinyin: "nián", meaning: "năm", partOfSpeech: "Danh từ",
            hanViet: "Niên", hanVietNote: nil,
            characters: [.init(hanzi: "年", reading: "Niên", meaning: "năm")],
            examples: [.init(hanzi: "我今年二十岁。", pinyin: "Wǒ jīnnián èrshí suì.", meaning: "Năm nay tôi 20 tuổi.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-yue", level: 1, entryNumber: 23, topic: "Thời gian",
            hanzi: "月", pinyin: "yuè", meaning: "tháng", partOfSpeech: "Danh từ",
            hanViet: "Nguyệt", hanVietNote: nil,
            characters: [.init(hanzi: "月", reading: "Nguyệt", meaning: "trăng, tháng")],
            examples: [.init(hanzi: "我一月去北京。", pinyin: "Wǒ yī yuè qù Běijīng.", meaning: "Tháng một tôi đi Bắc Kinh.", note: nil)],
            audioURL: nil
        ),
        VocabWord(
            id: "hsk1-xianzai", level: 1, entryNumber: 24, topic: "Thời gian",
            hanzi: "现在", pinyin: "xiànzài", meaning: "bây giờ", partOfSpeech: "Danh từ",
            hanViet: "Hiện tại", hanVietNote: nil,
            characters: [.init(hanzi: "现", reading: "Hiện", meaning: "hiện ra"), .init(hanzi: "在", reading: "Tại", meaning: "ở")],
            examples: [.init(hanzi: "现在几点？", pinyin: "Xiànzài jǐ diǎn?", meaning: "Bây giờ là mấy giờ?", note: nil)],
            audioURL: nil
        ),
    ]
}
