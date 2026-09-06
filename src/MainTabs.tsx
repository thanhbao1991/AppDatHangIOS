import { useEffect, useState } from 'react';
import { Ionicons } from '@expo/vector-icons';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import AsyncStorage from '@react-native-async-storage/async-storage';
import HomeStack from './HomeStack';
import DonHangStack from './DonHangStack';
import SettingsStack from './SettingsStack';
import ThongBaoScreen, { THONG_BAO_LAST_SEEN_KEY } from './screens/ThongBaoScreen';
import { getThongBao } from './api';
import { COLORS } from './theme';

const Tab = createBottomTabNavigator();

// Poll nhẹ mỗi 60s để cập nhật badge số tin chưa đọc — đơn giản hơn SignalR cho MVP, đủ dùng vì
// tin thông báo (xác nhận/giao/hoàn tất đơn, khuyến mãi) không cần realtime tức khắc.
const POLL_INTERVAL_MS = 60_000;

export default function MainTabs() {
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    let cancelled = false;

    const check = async () => {
      const result = await getThongBao();
      if (cancelled || !result.isSuccess || !result.data) return;
      const lastSeen = await AsyncStorage.getItem(THONG_BAO_LAST_SEEN_KEY);
      const count = lastSeen ? result.data.filter((t) => t.ngayTao > lastSeen).length : result.data.length;
      setUnreadCount(count);
    };

    check();
    const interval = setInterval(check, POLL_INTERVAL_MS);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: COLORS.primary,
        tabBarInactiveTintColor: COLORS.textFaint,
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeStack}
        options={{
          title: 'Thực đơn',
          tabBarIcon: ({ color, size, focused }) => (
            <Ionicons name={focused ? 'restaurant' : 'restaurant-outline'} size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="DonHang"
        component={DonHangStack}
        options={{
          title: 'Đơn của tôi',
          tabBarIcon: ({ color, size, focused }) => (
            <Ionicons name={focused ? 'receipt' : 'receipt-outline'} size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="ThongBao"
        component={ThongBaoScreen}
        listeners={{ focus: () => setUnreadCount(0) }}
        options={{
          title: 'Thông báo',
          headerShown: true,
          headerStyle: { backgroundColor: COLORS.primary },
          headerTintColor: '#fff',
          tabBarBadge: unreadCount > 0 ? unreadCount : undefined,
          tabBarIcon: ({ color, size, focused }) => (
            <Ionicons name={focused ? 'notifications' : 'notifications-outline'} size={size} color={color} />
          ),
        }}
      />
      <Tab.Screen
        name="Settings"
        component={SettingsStack}
        options={{
          title: 'Cài đặt',
          tabBarIcon: ({ color, size, focused }) => (
            <Ionicons name={focused ? 'settings' : 'settings-outline'} size={size} color={color} />
          ),
        }}
      />
    </Tab.Navigator>
  );
}
