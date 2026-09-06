import Constants from 'expo-constants';
import * as Device from 'expo-device';
import * as Notifications from 'expo-notifications';
import { Platform } from 'react-native';
import { registerPushToken } from './api';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

// Đăng ký nhận thông báo đẩy khi đơn đổi trạng thái (xem HoaDonTrangThaiService.PushChoKhachAsync ở
// backend). getExpoPushTokenAsync() BẮT BUỘC có projectId hợp lệ (Constants.expoConfig.extra.eas.
// projectId) — app này CHƯA link EAS project + build hiện tại ký qua Sideloadly (ad-hoc, Apple ID
// free) nên gần như chắc chắn KHÔNG có Apple Push credentials thật. Bỏ qua sớm + im lặng khi thiếu
// projectId, đừng gọi API để dính lỗi/crash — code này CHỜ SẴN tới khi có Apple Developer Program +
// gán lại credentials qua `eas credentials`, lúc đó chỉ cần điền projectId là chạy được ngay, không
// cần sửa gì thêm ở đây.
export async function registerForPushNotificationsAsync(): Promise<void> {
  try {
    if (!Device.isDevice) return; // simulator/emulator không nhận được push thật

    const projectId = Constants.expoConfig?.extra?.eas?.projectId;
    if (!projectId) return;

    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'Thông báo đơn hàng',
        importance: Notifications.AndroidImportance.MAX,
      });
    }

    const existing = await Notifications.getPermissionsAsync();
    let status = existing.status;
    if (status !== 'granted') {
      const requested = await Notifications.requestPermissionsAsync();
      status = requested.status;
    }
    if (status !== 'granted') return;

    const { data: expoPushToken } = await Notifications.getExpoPushTokenAsync({ projectId });
    await registerPushToken(expoPushToken);
  } catch {
    // Chưa có credentials/projectId hợp lệ là tình huống BÌNH THƯỜNG ở giai đoạn hiện tại — im lặng
    // bỏ qua, app vẫn dùng poll 10s trong OrderStatusScreen như phương án chính.
  }
}

// Gọi khi khách bấm đăng xuất/xoá tài khoản — gỡ token khỏi phiên hiện tại để không gửi nhầm thông
// báo cho thiết bị đã đăng xuất. Lỗi mạng ở đây không quan trọng (phiên sắp bị thu hồi ở server rồi).
export async function unregisterPushTokenAsync(): Promise<void> {
  try {
    await registerPushToken(null);
  } catch {
    // ignore
  }
}
