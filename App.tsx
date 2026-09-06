import { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import LoginScreen from './src/screens/LoginScreen';
import MainTabs from './src/MainTabs';
import { clearToken, getSavedTenKhachHang, getToken, logout as apiLogout, setSessionExpiredHandler } from './src/api';
import { AuthContext } from './src/AuthContext';
import { CartProvider } from './src/CartContext';
import { registerForPushNotificationsAsync, unregisterPushTokenAsync } from './src/push';

export default function App() {
  const [tenKhachHang, setTenKhachHang] = useState<string | null>(null);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    (async () => {
      const token = await getToken();
      if (token) setTenKhachHang((await getSavedTenKhachHang()) ?? '');
      setChecking(false);
    })();
    // Refresh token cũng hết hạn (không chỉ access token) — request() gọi callback này thay vì
    // để mọi màn hình tự báo nhầm "Không kết nối được server.".
    setSessionExpiredHandler(() => setTenKhachHang(null));
  }, []);

  // Đăng ký push token mỗi khi có phiên đăng nhập (mở app lại/vừa đăng nhập xong) — token Expo có
  // thể đổi giữa các lần mở app nên đăng ký lại là bình thường, không cần so sánh với lần trước.
  useEffect(() => {
    if (tenKhachHang !== null) registerForPushNotificationsAsync();
  }, [tenKhachHang]);

  // Đăng xuất thủ công — KHÔNG tự đăng nhập lại sau đó (chỉ vào lại LoginScreen).
  const logout = async () => {
    await unregisterPushTokenAsync();
    try {
      await apiLogout();
    } catch {
      await clearToken();
    }
    setTenKhachHang(null);
  };

  if (checking) return null;

  return (
    <AuthContext.Provider value={{ tenKhachHang: tenKhachHang ?? '', logout }}>
      <CartProvider>
        <SafeAreaProvider>
          <NavigationContainer>
            {tenKhachHang !== null ? (
              <MainTabs />
            ) : (
              <LoginScreen onLoggedIn={(data) => setTenKhachHang(data.tenKhachHang)} />
            )}
          </NavigationContainer>
          <StatusBar style="auto" />
        </SafeAreaProvider>
      </CartProvider>
    </AuthContext.Provider>
  );
}
