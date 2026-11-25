import Foundation
import KeychainAccess
import UIKit

/// Thông tin thiết bị gửi kèm khi đăng nhập, để server quản lý phiên theo từng máy.
struct DeviceInfo: Equatable {
    /// UUID cố định của máy cho app này (giữ nguyên qua các lần mở app, kể cả khi đăng xuất).
    let id: String
    /// Vd. "iPhone 15 Pro".
    let name: String
    /// Vd. "iOS 18.1".
    let platform: String
}

protocol DeviceInfoProviding {
    var current: DeviceInfo { get }
}

final class SystemDeviceInfoProvider: DeviceInfoProviding {
    private enum Key {
        static let deviceId = "device.id"
    }

    private let keychain: Keychain
    private lazy var cached: DeviceInfo = DeviceInfo(
        id: Self.loadOrCreateId(in: keychain),
        name: Self.marketingName(for: Self.modelIdentifier()),
        platform: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    )

    init(service: String = Bundle.main.bundleIdentifier ?? "com.example.tingting") {
        // Lưu trong Keychain (không phải UserDefaults) để id ổn định hơn và không bị sao lưu sang máy khác.
        keychain = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    var current: DeviceInfo { cached }

    private static func loadOrCreateId(in keychain: Keychain) -> String {
        if let existing = try? keychain.get(Key.deviceId), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString.lowercased()
        try? keychain.set(id, key: Key.deviceId)
        return id
    }

    /// Mã máy, vd. "iPhone16,1". Trên simulator lấy mã của máy đang giả lập.
    static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    /// "iPhone16,1" → "iPhone 15 Pro". Máy chưa có trong bảng: "iPhone (iPhone19,1)".
    static func marketingName(for identifier: String) -> String {
        if let name = marketingNames[identifier] { return name }
        let family = identifier.prefix(while: { $0.isLetter })
        return family.isEmpty ? identifier : "\(family) (\(identifier))"
    }

    private static let marketingNames: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,5": "iPhone 16e",
        "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
    ]
}
