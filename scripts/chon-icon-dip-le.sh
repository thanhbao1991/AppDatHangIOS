#!/bin/bash
# Chọn ICON CHÍNH cho bản build theo dịp lễ (cách Shopee: đổi icon bằng bản cập nhật → khách KHÔNG thấy popup
# "You have changed the icon" của iOS). Chạy trên CI sau xcodegen, trước khi archive. (Chủ quán 2026-11-07: kết hợp
# icon theo bản cập nhật khi tiện + đổi theo server có popup khi bản cài chưa kịp.)
#
# - Dịp đang trong cửa sổ icon của server (7 ngày trước → 14 ngày sau lễ, GET /dat-hang/dip-le/hien-thi → maIcon),
#   hoặc dịp có icon sắp bắt đầu trong SO_NGAY_TRUOC ngày tới (GET /dip-le/sap-toi) → chép ảnh
#   Assets.xcassets/AppIcon-<MA>.appiconset đè lên AppIcon.appiconset (cùng tên file).
# - Ghi DennIconDip (<MA> hoặc rỗng) vào Info.plist — app đọc để biết icon chính đang đóng gói là dịp nào
#   (xem AppIconSwitcher.iconMucTieu): server muốn đúng icon đó thì khỏi đổi (không popup), lệch thì app tự đổi
#   bằng icon phụ (có popup, giãn ≥7 ngày). Vậy bản cập nhật nào ra cũng tiện tay mang icon dịp sắp tới.
# - Lỗi mạng/không có dịp → giữ icon quán, KHÔNG làm hỏng build.
set -uo pipefail

API="https://api.denncoffee.com/api/dat-hang"
SO_NGAY_TRUOC=30
ICONS="Assets.xcassets"
export TZ="Asia/Ho_Chi_Minh"
TODAY=$(date +%F)
MA=""

ma_hien=$(curl -fsS --max-time 15 "$API/dip-le/hien-thi" 2>/dev/null | grep -o '"maIcon":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$ma_hien" ] && [ -d "$ICONS/AppIcon-$ma_hien.appiconset" ]; then
  MA="$ma_hien"
fi

if [ -z "$MA" ]; then
  sap_toi=$(curl -fsS --max-time 15 "$API/dip-le/sap-toi" 2>/dev/null \
    | grep -o '"ma":"[^"]*","ngayBatDau":"[^"]*"' \
    | sed -E 's/"ma":"([^"]*)","ngayBatDau":"([^"]*)"/\1 \2/')
  while read -r ma ngay; do
    [ -n "$ma" ] || continue
    [ -d "$ICONS/AppIcon-$ma.appiconset" ] || continue
    # Chỉ xét dịp CÓ ICON gần nhất — xa hơn SO_NGAY_TRUOC thì để bản sau lo.
    con=$(( ( $(date -j -f %F "$ngay" +%s) - $(date -j -f %F "$TODAY" +%s) ) / 86400 ))
    if [ "$con" -le "$SO_NGAY_TRUOC" ]; then MA="$ma"; fi
    break
  done <<< "$sap_toi"
fi

if [ -n "$MA" ]; then
  cp "$ICONS/AppIcon-$MA.appiconset/"*.png "$ICONS/AppIcon.appiconset/"
  echo "Icon chinh ban nay: dip $MA"
else
  echo "Icon chinh ban nay: icon quan (khong co dip co icon trong $SO_NGAY_TRUOC ngay toi)"
fi

PLIST="Sources/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DennIconDip string $MA" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :DennIconDip $MA" "$PLIST"
exit 0
