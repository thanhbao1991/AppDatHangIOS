# AppDatHangIOS — Đenn Coffee

App đặt hàng khách (React Native / Expo) cho Đenn Coffee. Đăng nhập SĐT + OTP, đặt món, theo dõi
đơn, ví/điểm thưởng (thẻ tem, vòng quay, Ly Bí Mật, giới thiệu bạn bè).

Backend (ASP.NET Core, không nằm trong repo này — private) tại `api.denncoffee.uk`.

Tách ra thành repo riêng ngày 2026-09-06 từ monorepo TraSuaApp/DaenApp để build `.ipa` chạy miễn
phí trên macOS runner của GitHub Actions (chỉ free cho repo Public). Lịch sử commit trước ngày này
nằm ở monorepo gốc (private), không mang theo sang đây.

## Build

```bash
npm install
npx expo start
```

CI tự build `.ipa` chưa ký khi push lên `main` (`.github/workflows/build-ios.yml`) — tải artifact
từ tab Actions, ký/cài bằng Sideloadly.
