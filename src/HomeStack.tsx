import { createNativeStackNavigator } from '@react-navigation/native-stack';
import MenuScreen from './screens/MenuScreen';
import CheckoutScreen from './screens/CheckoutScreen';
import LyBiMatScreen from './screens/LyBiMatScreen';
import ThanhToanScreen from './screens/ThanhToanScreen';
import { COLORS } from './theme';

const Stack = createNativeStackNavigator();

export default function HomeStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: COLORS.primary },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
      }}
    >
      <Stack.Screen name="Menu" component={MenuScreen} options={{ title: 'Thực đơn' }} />
      <Stack.Screen name="Checkout" component={CheckoutScreen} options={{ title: 'Giỏ hàng' }} />
      <Stack.Screen name="LyBiMat" component={LyBiMatScreen} options={{ title: 'Ly Bí Mật 🎁' }} />
      <Stack.Screen name="ThanhToan" component={ThanhToanScreen} options={{ title: 'Thanh toán' }} />
    </Stack.Navigator>
  );
}
