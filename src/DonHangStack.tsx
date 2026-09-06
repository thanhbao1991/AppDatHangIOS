import { createNativeStackNavigator } from '@react-navigation/native-stack';
import OrderStatusScreen from './screens/OrderStatusScreen';
import OrderDetailScreen from './screens/OrderDetailScreen';
import ThanhToanScreen from './screens/ThanhToanScreen';
import { COLORS } from './theme';

const Stack = createNativeStackNavigator();

export default function DonHangStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: COLORS.primary },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
      }}
    >
      <Stack.Screen name="DonHangList" component={OrderStatusScreen} options={{ title: 'Đơn của tôi' }} />
      <Stack.Screen name="DonHangChiTiet" component={OrderDetailScreen} options={{ title: 'Chi tiết đơn hàng' }} />
      <Stack.Screen name="ThanhToan" component={ThanhToanScreen} options={{ title: 'Thanh toán' }} />
    </Stack.Navigator>
  );
}
