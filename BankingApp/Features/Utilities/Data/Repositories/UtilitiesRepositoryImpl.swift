import Foundation

/// Danh sách tiện ích tĩnh. Khi có API cấu hình menu từ server,
/// thêm RemoteDataSource vào đây mà không cần sửa Domain/Presentation.
final class UtilitiesRepositoryImpl: UtilitiesRepository {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func publicUtilities() async throws -> [UtilityItem] {
        [
            UtilityItem(id: "qr", kind: .qrPayment, title: "Quét QR thanh toán"),
            UtilityItem(id: "fx", kind: .exchangeRate, title: "Tỷ giá ngoại tệ"),
            UtilityItem(id: "rate", kind: .savingsRate, title: "Lãi suất tiết kiệm"),
            UtilityItem(id: "atm", kind: .atmLocator, title: "ATM & chi nhánh"),
            UtilityItem(id: "promo", kind: .promotions, title: "Ưu đãi"),
            UtilityItem(id: "loan", kind: .loanCalculator, title: "Tính khoản vay"),
        ]
    }

    func supportContact() -> SupportContact {
        SupportContact(title: "Tổng đài 24/7", hotline: config.supportHotline)
    }
}
