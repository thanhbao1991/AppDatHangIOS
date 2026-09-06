import type { ConfigContext, ExpoConfig } from 'expo/config';

// Cấu hình động chồng lên app.json. Mục đích: KHÔNG để giá trị bí mật hay giá trị phụ thuộc môi
// trường nằm cứng trong file commit vào git.
//
// - GOOGLE_MAPS_IOS_API_KEY: app hiện dùng PROVIDER_DEFAULT (Apple Maps trên iOS) nên chưa cần key
//   thật, app.json vẫn để chuỗi placeholder. Khi nào bật Google Maps thì đặt biến môi trường lúc
//   build, đừng sửa placeholder trong app.json rồi commit nhầm key thật.
// - TRASUA_API_BASE_URL: trỏ app sang backend khác (máy dev, staging) mà không phải sửa code.
//   Không đặt thì mặc định production.
const DEFAULT_API_BASE_URL = 'https://api.denncoffee.uk/api';

export default ({ config }: ConfigContext): ExpoConfig => {
  const googleMapsKey = process.env.GOOGLE_MAPS_IOS_API_KEY;

  const plugins: ExpoConfig['plugins'] = (config.plugins ?? []).map(plugin => {
    if (Array.isArray(plugin) && plugin[0] === 'react-native-maps' && googleMapsKey) {
      return ['react-native-maps', { ...plugin[1], iosGoogleMapsApiKey: googleMapsKey }] as [string, any];
    }
    return plugin;
  });

  return {
    ...config,
    name: config.name ?? 'Đenn Coffee',
    slug: config.slug ?? 'AppDatHangIOS',
    plugins,
    extra: {
      ...config.extra,
      apiBaseUrl: process.env.TRASUA_API_BASE_URL ?? DEFAULT_API_BASE_URL,
    },
  };
};
