import Foundation

/// Lưu dữ liệu không nhạy cảm (tuỳ chọn người dùng).
protocol KeyValueStore: AnyObject {
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {}
