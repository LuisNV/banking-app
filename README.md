# TingTing — iOS SwiftUI base

Base project cho app học tiếng Trung **TingTing**: **SwiftUI + MVVM + Clean Architecture**, chia theo **feature**.
Màn hình đầu tiên là Đăng nhập (mật khẩu hoặc khuôn mặt/vân tay) kèm drawer "Học thử" trượt từ bên trái.

> Target trong Xcode vẫn tên `BankingApp` (tên hiển thị trên máy là TingTing). Có thể đổi tên target sau.

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

### Gọi API thật hay dữ liệu giả (mock)

| Scheme trong Xcode | Gọi tới |
|---|---|
| `BankingApp` | **API thật** tại `API_BASE_URL` (Debug: `project.yml` → `settings.configs.Debug`) |
| `BankingApp (Mock)` | Backend giả, không gọi mạng. Mọi tài khoản, mật khẩu `123456` |

- Sửa `API_BASE_URL` trong `project.yml` rồi **chạy lại `xcodegen generate`**. Sửa trực tiếp trong Xcode Build Settings sẽ bị ghi đè ở lần generate sau.
- Đổi nhanh không cần generate: Xcode ▸ *Edit Scheme* ▸ *Run* ▸ *Arguments* ▸ *Environment Variables*, thêm `API_BASE_URL` hoặc `USE_MOCK_API`. Biến môi trường được ưu tiên hơn `project.yml`.
- Khi app khởi động, console in dòng `⚙️ AppConfig — ...` cho biết đang dùng API nào. Bản Debug in đầy đủ request/response (mật khẩu được che).
- Bản Release luôn gọi API thật.
- Server `http://` trong mạng nội bộ (localhost, 192.168.x.x, `.local`) được phép khi phát triển. Chạy trên iPhone thật thì dùng IP máy tính trong LAN, không dùng `localhost`.

### Hợp đồng API

Mặc định Debug gọi `http://localhost:8081/api`. Đường dẫn ở `Features/Auth/Data/Network/AuthEndpoint.swift`, DTO ở `Features/Auth/Data/DTOs/AuthDTOs.swift`. Request gửi JSON `camelCase`.

```
POST {API_BASE_URL}/v1/auth/login     body: {"identifier" (email hoặc số điện thoại), "password", "deviceId", "deviceName", "platform"}
POST {API_BASE_URL}/v1/auth/refresh   body: {"refreshToken": "..."}
POST {API_BASE_URL}/v1/auth/logout    body: {"refreshToken": "..."}
GET  {API_BASE_URL}/v1/auth/me           Bearer token → thông tin tài khoản
PUT  {API_BASE_URL}/v1/users/me          Bearer token, body: {"fullName", "phone", "address", "gender", "dateOfBirth", "email"?, "currentPassword"?}
POST {API_BASE_URL}/v1/users/me/avatar  multipart/form-data, field "file" (JPEG) + Bearer token
```

- **Mở app**: còn refresh token trong Keychain thì vào thẳng Trang chủ (không gọi mạng), dùng thông tin user đã lưu lúc đăng nhập. Access token hết hạn thì request đầu tiên tự refresh; refresh bị từ chối thì về màn đăng nhập như mục *Hết phiên*.
- **Thiết bị** (gửi khi đăng nhập, `Core/Device/DeviceInfo.swift`): `deviceId` là UUID tạo lần đầu rồi lưu trong Keychain (giữ nguyên qua các lần mở app và đăng xuất), `deviceName` là tên máy (vd. "iPhone 15 Pro", máy chưa có trong bảng thì kèm mã máy), `platform` dạng "iOS 18.1".
- **Refresh**: khi một API cần đăng nhập trả 401, `AuthInterceptor` gọi `refresh` (qua `AuthTokenRefresher`), lưu token mới rồi gửi lại request đó một lần. Nhiều request cùng 401 chỉ gọi refresh một lần. Refresh cũng được dùng khi đăng nhập bằng sinh trắc học.
- **Hết phiên**: nếu refresh bị server từ chối (hoặc máy không còn refresh token), token bị xoá, app phát `Notification.Name.sessionExpired` và `AppRouter` đưa người dùng về màn đăng nhập kèm thông báo. Lỗi mạng tạm thời không làm người dùng bị đăng xuất.
- **Upload file**: khai báo `files` (và `formFields` nếu cần) trong endpoint, `APIClient` sẽ gửi `multipart/form-data`. Ví dụ `Features/Profile/Data/Network/ProfileEndpoint.swift`. Đổi ảnh đại diện: bấm vào ảnh ở tab Cá nhân hoặc màn Thông tin cá nhân → bottom sheet *Chụp ảnh* / *Chọn từ thư viện* → màn chỉnh ảnh (kéo, chụm để phóng to, chạm hai lần) cho vừa khung tròn → cắt thành ảnh vuông rồi upload (`Features/Profile/Presentation/Avatar`). Cần quyền camera (`NSCameraUsageDescription` trong `project.yml`); simulator không có camera nên nút Chụp ảnh bị tắt. Ảnh đại diện được thu nhỏ còn cạnh dài 1024 px và nén JPEG trước khi gửi (`AvatarImageProcessor`), giới hạn 5 MB (`UploadAvatarUseCase.maxMegabytes`). `data` trả về có thể là chuỗi URL, object có `avatarUrl`/`url`, hoặc `null`.
- **Thông tin cá nhân** (`v1/auth/me`): tải khi vào app, dùng cho lời chào ở Trang chủ, đầu tab Cá nhân và màn *Thông tin cá nhân* (kéo xuống để tải lại). `data` gồm `id` (số), `fullName`, `email`, `phone`, `address`, `gender` (`MALE`/`FEMALE`/`OTHER` → Nam/Nữ/Khác), `dateOfBirth` (`yyyy-MM-dd`), `avatarUrl`, `emailVerified`; chỉ `id` là bắt buộc, trường thiếu hiện "Chưa cập nhật". DTO ở `Features/Profile/Data/DTOs/ProfileDTOs.swift` (`UserProfileDTO`).
- **Sửa hồ sơ** (`PUT v1/users/me`, màn *Sửa thông tin*): app kiểm tra trước theo đúng quy tắc server (họ tên ≤ 150, số điện thoại ≤ 30, địa chỉ ≤ 500 ký tự, đều bắt buộc; ngày sinh không ở tương lai; email đúng định dạng, ≤ 254 ký tự) và bỏ khoảng trắng hai đầu, email chuyển chữ thường. Email không đổi thì không gửi `email`/`currentPassword`. Đổi email thì hiện bottom sheet hỏi mật khẩu hiện tại. Mã lỗi: `1001` thiếu mật khẩu (mở lại bottom sheet, không tính là một lần sai), `1002` sai mật khẩu (hiện đúng câu "Bạn còn N lần thử" của server trong bottom sheet), `1018` đang bị khoá (hiện "thử lại sau N phút" và khoá nút Xác nhận tới khi hết hạn, kể cả khi nhập đúng mật khẩu), `1003` email trùng (báo ở ô Email), `1004` số điện thoại trùng (báo ở ô Số điện thoại), `404` tài khoản không còn → đăng xuất. Bản Mock: mật khẩu `123456`, sai 5 lần thì khoá 15 phút, email `taken@example.com` và số `0000000000` báo trùng.
- **Đăng ký** (`v1/auth/registrations`, không cần token, `registrationId` là khoá phiên): bước 1 `POST /registrations` tạo phiên → bước 2 `POST /{id}/initiate` (mật khẩu + `biometricEnabled`, server gửi mã) → bước 3 `POST /{id}/verify` (gửi lại: `POST /{id}/otp/resend`, đổi email: `PUT /{id}/email` qua bottom sheet) → bước 4 `POST /{id}/complete` trả token nên vào thẳng app. `registrationId` + thông tin bước 1 được lưu trên máy; thoát app giữa chừng rồi mở lại màn đăng ký thì `GET /{id}` đưa về đúng bước (phiên sống 60 phút). Đếm ngược "Gửi lại sau" theo `resendAvailableAt` của server. Mã lỗi `1003`/`1004` đánh dấu ô Email/Số điện thoại, `1005`/`1006` quay về bước 1 (giữ thông tin đã nhập), `1007` hỏi lại server đang ở bước nào, `1010` hiện đúng câu "Bạn còn N lần thử". Bản Mock: mã `123456`, email `taken@example.com` và số `0000000000` báo trùng.
- **Đổi mật khẩu** (`v1/auth/password-changes`, cần access token, `Features/PasswordChange`): tab Cá nhân › *Đổi mật khẩu* mở toàn màn hình. Bước 1 `POST /password-changes` (mật khẩu hiện tại, mới, nhập lại, `logoutOtherDevices`) → server gửi mã tới email. Bước 2 `POST /{id}/verify` (gửi lại: `POST /{id}/otp/resend`, chờ 45 giây). App kiểm tra trước: mật khẩu mới ≥ 8 ký tự, có chữ hoa, thường, số, ≤ 72 byte UTF-8, khác mật khẩu hiện tại, nhập lại khớp. Mã lỗi theo `ErrorCode.java`: `1002` sai mật khẩu hiện tại (xoá ô, hiện câu của server), `1008`/`1009`/`1017` báo ở ô mật khẩu mới/nhập lại, `1018` khoá nút "Tiếp tục" tới khi hết hạn, `1016` báo cần đăng nhập lại, `1010`–`1013` báo dưới ô mã, `1014` ở bước 1 hiện câu của server còn lúc gửi lại mã dùng câu riêng của app (câu mặc định của server viết cho luồng đăng ký), `1019`/`1020` quay về bước 1. Token hết hạn giữa chừng thì `AuthInterceptor` tự refresh rồi gửi lại. Bản Mock: mật khẩu hiện tại `123456`, mã `123456`.
- **Quên mật khẩu** (`v1/auth/password-resets`, không cần token, `Features/PasswordReset`): link "Quên mật khẩu?" ở màn Đăng nhập và màn Đổi mật khẩu. Bước 1 `POST /password-resets` (`identifier`: email hoặc SĐT) → bước 2 `POST /{resetId}/verify` lấy `resetToken` (gửi lại: `POST /{resetId}/otp/resend`) → bước 3 `POST /{resetId}/complete`. Email/SĐT chưa đăng ký vẫn qua được bước 1 (server cố ý không tiết lộ), verify luôn sai. `1011`/`1012` làm nổi nút "Gửi lại mã"; `1021`/`1022`/`1014` lúc gửi lại → về bước 1; `1024` → tự xác minh lại bằng mã cũ (nếu còn hạn) rồi thử lại. Xong thì xoá phiên trên máy (server đã đăng xuất mọi thiết bị) và về màn đăng nhập với email/SĐT điền sẵn. Bản Mock: mã `123456`, identifier có chữ "unknown" coi như chưa đăng ký.
- **Cài đặt học** (`GET`/`PUT v1/users/me/learning-settings`, cần access token, `Features/LearningSettings`): mục tiêu mỗi ngày, nhắc học (giờ, ngày lặp, bỏ qua nếu đã học xong, múi giờ), kiểu chữ Hán, cách hiện pinyin. Lưu trên server, có bản sao trên máy để mở app là có ngay (kể cả offline); `LearningSettingsStore` dùng chung cho Trang chủ (vòng mục tiêu) và tab Cá nhân. PUT ghi đè toàn bộ, `timezone` luôn lấy múi giờ hiện tại của máy. Cỡ chữ Hán chỉ lưu trên máy. Nhắc học dùng thông báo cục bộ (`Core/Notifications/ReminderScheduler.swift`), hẹn lại mỗi lần tải/lưu cài đặt, huỷ khi đăng xuất; "Bỏ qua nếu đã học xong" chưa áp dụng cho thông báo cục bộ (cần push từ server). Lỗi 400 có câu tiếng Việt của server thì hiện nguyên văn, câu mặc định tiếng Anh của Spring thì thay bằng câu chung.
- **Logout**: gửi refresh token để server thu hồi, rồi xoá token trong Keychain (kể cả khi gọi API lỗi). Sau khi đăng xuất, phải đăng nhập bằng mật khẩu một lần trước khi dùng lại sinh trắc học.

Mọi phản hồi bọc trong envelope (`Core/Network/APIResponse.swift`):

```json
{
  "code": 0,
  "httpStatus": 200,
  "message": "OK",
  "traceId": "abc123",
  "data": {
    "access_token": "...", "refresh_token": "...", "expires_in": 900, "token_type": "Bearer",
    "user": {"id": "u_001", "full_name": "...", "username": "..."}
  }
}
```

- `code != 0` hoặc `httpStatus` ngoài 2xx → `NetworkError.api`, app hiện đúng `message` của server.
- `user` có thể vắng mặt.
- Decode thất bại → console Debug in rõ kiểu và lỗi (thiếu field nào, sai kiểu gì).

## Thư viện (Swift Package Manager)

| Thư viện | Dùng cho |
|---|---|
| Alamofire | Networking, interceptor gắn token |
| Factory | Dependency Injection |
| KeychainAccess | Lưu token an toàn |
| Kingfisher | Tải/cache ảnh (đã khai báo sẵn để dùng ở các feature sau) |

Ngoài ra dùng sẵn của Apple: Observation (`@Observable`), async/await, LocalAuthentication.

## Icon & màn khởi động

- **Icon app** (`Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, 1024×1024): chữ 听 trắng (Noto Serif SC Bold) trên nền xanh `#0A5BD3`, không bo góc (iOS tự bo).
- **Launch Screen** của iOS (`UILaunchScreen` trong `project.yml`): nền `LaunchBackground` + ảnh `LaunchLogo` (ô trắng mờ chứa 听, 112 pt).
- **Màn "Mở app"** (`App/SplashView.swift`): nối tiếp Launch Screen với cùng ảnh, cùng vị trí, hiện khoảng 0,9 giây kèm tên app, vòng xoay và phiên bản rồi mờ dần.
- **Lớp phủ đang xử lý** (`DesignSystem/Components/LoadingOverlay.swift`): nền tối mờ, icon app với vòng xoay bao quanh, không có chữ (`message` chỉ cho VoiceOver).

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
│   ├── Utilities/            # Drawer "Học thử": từ điển, pinyin, thanh điệu, viết chữ, bộ thủ, HSK
│   └── Home/                 # Trang chủ (chuỗi học, mục tiêu, bài đang học, từ của ngày, công cụ) + thanh tab nổi
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

- Email hỗ trợ (`AppConfig.supportEmail`), link Điều khoản / Quyền riêng tư
- Luồng Quên mật khẩu, màn hình từng công cụ học thử
- Đa ngôn ngữ: chuỗi đang viết thẳng tiếng Việt, nên chuyển sang `Localizable.xcstrings`
- Đăng nhập Apple / Google (chưa làm)
- API Trang chủ: số liệu (chuỗi học, mục tiêu, bài đang học, từ của ngày) đang lấy từ `MockHomeRepository`. Khi có API, thêm RemoteDataSource + `HomeRepositoryImpl` trong `Features/Home/Data` và đổi factory ở `Container+Home.swift`
- Tab Bài học, Ôn tập đang là màn tạm
- Tab Cá nhân: đổi ảnh, bật/tắt đăng nhập sinh trắc học (lưu trên máy, bật lại phải xác thực), góp ý qua email, đăng xuất đã chạy thật. Sửa thông tin, Đổi mật khẩu, Mục tiêu mỗi ngày, Nhắc học, Chữ Hán đang là màn tạm; số liệu (từ đã học, bài hoàn thành, cấp độ) lấy từ `MockHomeRepository`
