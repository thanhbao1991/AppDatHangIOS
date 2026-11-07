#!/bin/bash
# Chọn ICON CHÍNH cho bản build theo dịp lễ (cách Shopee: đổi icon bằng bản cập nhật → khách KHÔNG thấy popup
# "You have changed the icon" của iOS). Chạy trên CI sau xcodegen, trước khi archive. (Chủ quán 2026-11-07: kết hợp
# icon theo bản cập nhật khi tiện + đổi theo server có popup khi bản cài chưa kịp.)
#
# - Lấy ĐÚNG icon server đang hiển thị lúc build (GET /dip-le/hien-thi → maIconHienTai: dịp trong cửa sổ 30 ngày trước →
#   3 ngày sau lễ, hoặc dịp vừa qua đang được giữ tới khi dịp kế vào cửa sổ) → chép ảnh
#   Assets.xcassets/AppIcon-<MA>.appiconset đè lên AppIcon.appiconset (cùng tên file). Khớp server nên khách cài mới /
#   cập nhật KHÔNG bị popup đổi icon ngay lần mở đầu. Nộp cuối tháng 11 → Noel (server đổi sang Noel từ 24/11).
#   Không có dịp / lỗi mạng → icon quán, KHÔNG làm hỏng build.
# - Ghi DennIconDip (<MA> hoặc rỗng) vào Info.plist — app đọc để biết icon chính đang đóng gói là dịp nào
#   (xem AppIconSwitcher.iconMucTieu): server muốn đúng icon đó thì khỏi đổi (không popup), lệch thì app tự đổi
#   bằng icon phụ (có popup, giãn ≥7 ngày). Vậy bản cập nhật nào ra cũng tiện tay mang icon dịp sắp tới.
# - Lỗi mạng/không có dịp → giữ icon quán, KHÔNG làm hỏng build.
set -uo pipefail

API="https://api.denncoffee.com/api/dat-hang"
ICONS="Assets.xcassets"
MA=""

ma_hien=$(curl -fsS --max-time 15 "$API/dip-le/hien-thi" 2>/dev/null | grep -o '"maIconHienTai":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$ma_hien" ] && [ -d "$ICONS/AppIcon-$ma_hien.appiconset" ]; then MA="$ma_hien"; fi

if [ -n "$MA" ]; then
  cp "$ICONS/AppIcon-$MA.appiconset/"*.png "$ICONS/AppIcon.appiconset/"
  echo "Icon chinh ban nay: dip $MA"
else
  echo "Icon chinh ban nay: icon quan (server khong co dip nao dang hien)"
fi

PLIST="Sources/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DennIconDip string $MA" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :DennIconDip $MA" "$PLIST"
exit 0
