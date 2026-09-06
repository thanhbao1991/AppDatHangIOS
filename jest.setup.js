// Các module native không chạy được trong Node — thay bằng bản giả đủ dùng cho test logic.
// Chỉ giả những thứ api.ts thực sự chạm tới; đừng giả cả react-native, jest-expo lo phần đó rồi.

jest.mock('@react-native-async-storage/async-storage', () => {
  const store = new Map();
  return {
    __esModule: true,
    default: {
      getItem: jest.fn(async key => (store.has(key) ? store.get(key) : null)),
      setItem: jest.fn(async (key, value) => {
        store.set(key, value);
      }),
      removeItem: jest.fn(async key => {
        store.delete(key);
      }),
      __store: store,
    },
  };
});

// SecureStore giả bằng Map trong bộ nhớ — test không cần Keychain thật, chỉ cần đúng ngữ nghĩa
// "ghi vào đây thì đọc lại được, xoá thì mất".
jest.mock('expo-secure-store', () => {
  const store = new Map();
  return {
    getItemAsync: jest.fn(async key => (store.has(key) ? store.get(key) : null)),
    setItemAsync: jest.fn(async (key, value) => {
      store.set(key, value);
    }),
    deleteItemAsync: jest.fn(async key => {
      store.delete(key);
    }),
    __store: store,
  };
});

jest.mock('expo-crypto', () => ({
  randomUUID: jest.fn(() => '00000000-0000-4000-8000-000000000000'),
}));

jest.mock('expo-constants', () => ({
  __esModule: true,
  default: { expoConfig: { extra: { apiBaseUrl: 'https://api.test.local/api' } } },
}));
