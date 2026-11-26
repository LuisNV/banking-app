import XCTest
@testable import BankingApp

final class AppPopupTests: XCTestCase {
    func test_style_inferredFromMessage() {
        XCTAssertEqual(AppPopup.Style.inferred(from: "Không thể kết nối. Vui lòng kiểm tra mạng và thử lại."), .network)
        XCTAssertEqual(AppPopup.Style.inferred(from: "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."), .session)
        XCTAssertEqual(AppPopup.Style.inferred(from: "Email này đã được sử dụng."), .error)
    }

    func test_networkError_withRetry_hasRetryAndClose() {
        var retried = false
        let popup = AppPopup.error(title: "Không thể lưu", message: "Không thể kết nối tới máy chủ.") { retried = true }

        XCTAssertEqual(popup.style, .network)
        XCTAssertEqual(popup.title, "Mất kết nối")
        XCTAssertEqual(popup.primary.title, "Thử lại")
        XCTAssertEqual(popup.secondary?.title, "Đóng")
        popup.primary.handler()
        XCTAssertTrue(retried)
    }

    func test_businessError_hasSingleButton() {
        let popup = AppPopup.error(title: "Không thể lưu", message: "Email này đã được sử dụng.", retry: {})
        XCTAssertEqual(popup.style, .error)
        XCTAssertEqual(popup.title, "Không thể lưu")
        XCTAssertEqual(popup.primary.title, "Đã hiểu")
        XCTAssertNil(popup.secondary)
    }

    @MainActor
    func test_center_queuesPopups() async throws {
        let center = AppPopupCenter()
        let first = AppPopup.error(title: "A", message: "a")
        let second = AppPopup.error(title: "B", message: "b")

        center.present(first)
        center.present(second)
        XCTAssertEqual(center.popup?.id, first.id)

        center.dismiss(id: first.id)
        XCTAssertNil(center.popup)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(center.popup?.id, second.id)

        center.dismiss(id: second.id)
        XCTAssertNil(center.popup)
    }

    @MainActor
    func test_toast_showsAndHides() {
        let center = AppPopupCenter()
        let toast = AppToast(title: "Không tải được")
        center.showToast(toast)
        XCTAssertEqual(center.toast?.id, toast.id)
        center.hideToast(id: toast.id)
        XCTAssertNil(center.toast)
    }
}
