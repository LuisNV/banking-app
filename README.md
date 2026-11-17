# BankingApp — iOS SwiftUI base

Base project cho app ngân hàng: **SwiftUI + MVVM + Clean Architecture**, chia theo **feature**.
Màn hình đầu tiên là Đăng nhập kèm drawer "Tiện ích" trượt từ bên trái.

## Yêu cầu

- Xcode 15.3+ (Swift 5.10), iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) để sinh `.xcodeproj`
- (tuỳ chọn) [SwiftLint](https://github.com/realm/SwiftLint)

## Chạy

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open BankingApp.xcodeproj
```

Cấu hình **Debug** dùng mock API (`USE_MOCK_API = YES`): mọi tên đăng nhập, mật khẩu `123456`.
Sau lần đăng nhập đầu, nút Face ID sẽ dùng được (refresh token lưu trong Keychain).
Đổi URL API trong `project.yml` → `settings.configs`.

## Thư viện (Swift Package Manager)

| Thư viện | Dùng cho |
|---|---|
| Alamofire | Networking, interceptor gắn token |
| Factory | Dependency Injection |
| KeychainAccess | Lưu token an toàn |
| Kingfisher | Tải/cache ảnh (đã khai báo sẵn để dùng ở các feature sau) |

Ngoài ra dùng sẵn của Apple: Observation (`@Observable`), async/await, LocalAuthentication.

## Kiến trúc

```
View ──▶ ViewModel ──▶ UseCase ──▶ Repository (protocol)
                                        ▲
                         RepositoryImpl ┘──▶ RemoteDataSource (API) / LocalDataSource (Keychain, UserDefaults)
```

- **Domain**: Entity, protocol Repository, UseCase. Không import SwiftUI/Alamofire.
- **Data**: DTO + mapping `toDomain()`, Endpoint, DataSource, RepositoryImpl. Map lỗi mạng → lỗi domain.
- **Presentation**: View + ViewModel (`@MainActor @Observable`). ViewModel nhận UseCase qua init (mặc định lấy từ Factory) nên test được bằng mock.
- **DI**: mỗi feature có `Container+<Feature>.swift`.
- Điều hướng giữa các luồng lớn qua `AppRouter`; ViewModel báo kết quả bằng closure (`onAuthenticated`).

## Cấu trúc thư mục

```
BankingApp/
├── App/                      # @main, RootView, AppRouter
├── Core/
│   ├── Config/               # AppConfig (đọc từ Info.plist)
│   ├── DI/                   # Container+Core
│   ├── Network/              # APIClient (Alamofire), Endpoint, AuthInterceptor, NetworkError
│   ├── Security/             # BiometricAuthService (Face ID / Touch ID)
│   ├── Storage/              # TokenStore (Keychain), KeyValueStore (UserDefaults)
│   └── Extensions/
├── DesignSystem/
│   ├── Theme/                # AppColor, AppMetrics
│   └── Components/           # Buttons, AppTextField, SideDrawer, BrandLogo
├── Features/
│   ├── Auth/
│   │   ├── Domain/           # User, AuthSession, AuthError, AuthRepository, UseCases
│   │   ├── Data/             # DTOs, AuthEndpoint, Remote/Local DataSource, AuthRepositoryImpl
│   │   ├── Presentation/Login/
│   │   └── DI/
│   ├── Utilities/            # Drawer tiện ích không cần đăng nhập (cùng cấu trúc)
│   └── Home/                 # Màn hình sau đăng nhập (placeholder)
└── Resources/                # Assets, Info.plist (XcodeGen sinh)
BankingAppTests/              # Test UseCase, Repository, ViewModel + Mocks
```

## Thêm feature mới

1. Tạo `Features/<Tên>/{Domain,Data,Presentation,DI}`.
2. Domain: entity + `protocol <Tên>Repository` + UseCase.
3. Data: DTO, Endpoint (enum conform `Endpoint`), RepositoryImpl.
4. DI: `extension Container { var ...: Factory<any ...> }`.
5. Presentation: ViewModel nhận UseCase qua init, View giữ ViewModel bằng `@State`.
6. Chạy lại `xcodegen generate`.

## Việc còn để giữ chỗ (TODO)

- Logo, App Icon, tên ngân hàng thật
- Số tổng đài (`AppConfig.supportHotline`)
- Luồng Quên mật khẩu, Mở tài khoản, chi tiết từng tiện ích
- Đa ngôn ngữ: chuỗi đang viết thẳng tiếng Việt, nên chuyển sang `Localizable.xcstrings`
- Refresh token tự động khi 401 (mở rộng `AuthInterceptor.retry`)
- SSL pinning (Alamofire `ServerTrustManager`) và phát hiện jailbreak trước khi lên production
