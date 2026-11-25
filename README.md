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
POST {API_BASE_URL}/v1/auth/login     body: {"email": "...", "password": "..."}
POST {API_BASE_URL}/v1/auth/refresh   body: {"refreshToken": "..."}
POST {API_BASE_URL}/v1/auth/logout    body: {"refreshToken": "..."}
POST {API_BASE_URL}/v1/users/me/avatar  multipart/form-data, field "file" (JPEG) + Bearer token
```

- **Refresh**: khi một API cần đăng nhập trả 401, `AuthInterceptor` gọi `refresh` (qua `AuthTokenRefresher`), lưu token mới rồi gửi lại request đó một lần. Nhiều request cùng 401 chỉ gọi refresh một lần. Refresh cũng được dùng khi đăng nhập bằng sinh trắc học.
- **Hết phiên**: nếu refresh bị server từ chối (hoặc máy không còn refresh token), token bị xoá, app phát `Notification.Name.sessionExpired` và `AppRouter` đưa người dùng về màn đăng nhập kèm thông báo. Lỗi mạng tạm thời không làm người dùng bị đăng xuất.
- **Upload file**: khai báo `files` (và `formFields` nếu cần) trong endpoint, `APIClient` sẽ gửi `multipart/form-data`. Ví dụ `Features/Profile/Data/Network/ProfileEndpoint.swift`. Ảnh đại diện được thu nhỏ còn cạnh dài 1024 px và nén JPEG trước khi gửi (`AvatarImageProcessor`), giới hạn 5 MB (`UploadAvatarUseCase.maxMegabytes`). `data` trả về có thể là chuỗi URL, object có `avatarUrl`/`url`, hoặc `null`.
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

- Logo, App Icon thật
- Email hỗ trợ (`AppConfig.supportEmail`), link Điều khoản / Quyền riêng tư
- Luồng Quên mật khẩu, màn hình từng công cụ học thử
- API đăng ký: luồng Đăng ký đang dùng `MockRegistrationRepository` (mã xác minh `123456`, email `taken@example.com` báo đã tồn tại). Khi có API, thêm RemoteDataSource + RepositoryImpl trong `Features/Register/Data` và đổi factory ở `Container+Register.swift`
- Đa ngôn ngữ: chuỗi đang viết thẳng tiếng Việt, nên chuyển sang `Localizable.xcstrings`
- Đăng nhập Apple / Google (chưa làm)
- API Trang chủ: số liệu (chuỗi học, mục tiêu, bài đang học, từ của ngày) đang lấy từ `MockHomeRepository`. Khi có API, thêm RemoteDataSource + `HomeRepositoryImpl` trong `Features/Home/Data` và đổi factory ở `Container+Home.swift`
- Tab Bài học, Ôn tập đang là màn tạm
- Tab Cá nhân: đổi ảnh, bật/tắt đăng nhập sinh trắc học (lưu trên máy, bật lại phải xác thực), góp ý qua email, đăng xuất đã chạy thật. Sửa thông tin, Đổi mật khẩu, Mục tiêu mỗi ngày, Nhắc học, Chữ Hán đang là màn tạm; số liệu (từ đã học, bài hoàn thành, cấp độ) lấy từ `MockHomeRepository`
