import { createNativeStackNavigator } from '@react-navigation/native-stack';
import SettingsScreen from './screens/SettingsScreen';
import UuDaiScreen from './screens/UuDaiScreen';
import { COLORS } from './theme';

const Stack = createNativeStackNavigator();

export default function SettingsStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: COLORS.primary },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
      }}
    >
      <Stack.Screen name="SettingsHome" component={SettingsScreen} options={{ title: 'Cài đặt' }} />
      <Stack.Screen name="UuDai" component={UuDaiScreen} options={{ title: 'Ưu đãi của tôi' }} />
    </Stack.Navigator>
  );
}
