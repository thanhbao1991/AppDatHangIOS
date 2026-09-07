# AppDatHangIOS — Đenn Coffee

App đặt hàng khách, native SwiftUI (chuyển từ React Native/Expo ngày 2026-09-07 — bản RN cũ nằm ở
lịch sử git trước commit chuyển native). Đăng nhập SĐT + OTP, đặt món, theo dõi đơn, ví/điểm thưởng
(thẻ tem, vòng quay, Ly Bí Mật, giới thiệu bạn bè).

Backend (ASP.NET Core, không nằm trong repo này — private) tại `api.denncoffee.uk`.

## Build

```bash
brew install xcodegen   # macOS only
xcodegen generate
open AppDatHangIOS.xcodeproj
```

CI tự build `.ipa` chưa ký khi push lên `main` (`.github/workflows/build-ios.yml`) — tải artifact
từ tab Actions, ký/cài bằng Sideloadly.

## Tiến độ chuyển native

- [x] Giai đoạn 0 — khung dự án (XcodeGen, APIClient, Prefs/Keychain, CI)
- [ ] Giai đoạn 1 — đăng nhập
- [ ] Giai đoạn 2 — menu & giỏ hàng
- [ ] Giai đoạn 3 — checkout & địa chỉ (MapKit)
- [ ] Giai đoạn 4 — đơn hàng & thanh toán
- [ ] Giai đoạn 5 — gamification & cài đặt
- [ ] Giai đoạn 6 — push APNs thật (chờ Apple Developer Program)
