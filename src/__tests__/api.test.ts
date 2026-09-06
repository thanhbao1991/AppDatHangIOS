/**
 * Test tầng gọi API — phần logic dễ hỏng nhất mà lại không nhìn thấy được trên màn hình:
 * lưu/đọc token, timeout, gộp refresh khi nhiều request cùng nhận 401, cache catalog.
 *
 * api.ts giữ state ở cấp module (cachedToken, cache catalog...) nên MỖI test phải nạp lại module
 * bằng jest.isolateModulesAsync, nếu không state của test trước rò sang test sau.
 */

const API = 'https://api.test.local/api';

type FetchMock = jest.Mock<Promise<any>, any[]>;

function envelope(data: any, isSuccess = true, message = '') {
  return {
    ok: true,
    status: 200,
    json: async () => ({ isSuccess, message, data }),
  };
}

// require() trong isolateModules chứ không phải import() động: import() cần Node chạy với
// --experimental-vm-modules, còn jest ở đây đang chạy CommonJS.
function loadApi(): any {
  let mod: any;
  jest.isolateModules(() => {
    mod = require('../api');
  });
  return mod;
}

describe('api', () => {
  let fetchMock: FetchMock;

  beforeEach(() => {
    jest.clearAllMocks();
    // clearAllMocks chỉ xoá lịch sử gọi, KHÔNG xoá Map dữ liệu bên trong hai module giả — không dọn
    // thì token của test trước còn nguyên và test sau tưởng nhầm là đã đọc được từ nơi mình mong đợi.
    require('expo-secure-store').__store.clear();
    require('@react-native-async-storage/async-storage').default.__store.clear();
    fetchMock = jest.fn();
    (global as any).fetch = fetchMock;
  });

  describe('lưu phiên', () => {
    it('đọc token từ SecureStore', async () => {
      const SecureStore = require('expo-secure-store');
      await SecureStore.setItemAsync('token', 'token-bi-mat');

      const api = loadApi();

      expect(await api.getToken()).toBe('token-bi-mat');
    });

    // Khách đang dùng bản cũ có token nằm trong AsyncStorage. Cập nhật app không được đá họ ra
    // màn hình đăng nhập.
    it('chuyển token cũ từ AsyncStorage sang SecureStore rồi xoá bản cũ', async () => {
      const AsyncStorage = require('@react-native-async-storage/async-storage').default;
      const SecureStore = require('expo-secure-store');
      await AsyncStorage.setItem('token', 'token-cu');

      const api = loadApi();
      const token = await api.getToken();

      expect(token).toBe('token-cu');
      expect(await SecureStore.getItemAsync('token')).toBe('token-cu');
      expect(await AsyncStorage.getItem('token')).toBeNull();
    });

    it('đăng xuất xoá token ở cả SecureStore lẫn AsyncStorage', async () => {
      const AsyncStorage = require('@react-native-async-storage/async-storage').default;
      const SecureStore = require('expo-secure-store');
      await SecureStore.setItemAsync('token', 'a');
      await SecureStore.setItemAsync('refreshToken', 'b');
      await AsyncStorage.setItem('token', 'a-cu');

      const api = loadApi();
      await api.clearToken();

      expect(await SecureStore.getItemAsync('token')).toBeNull();
      expect(await SecureStore.getItemAsync('refreshToken')).toBeNull();
      expect(await AsyncStorage.getItem('token')).toBeNull();
    });

    it('thietBiId sinh bằng UUID ngẫu nhiên mật mã học và giữ nguyên các lần sau', async () => {
      const api = loadApi();

      const lan1 = await api.getThietBiId();
      const lan2 = await api.getThietBiId();

      expect(lan1).toBe(lan2);
      expect(lan1).toContain('00000000-0000-4000-8000-000000000000');
    });
  });

  describe('xử lý lỗi', () => {
    it('báo lỗi quá hạn khi request bị timeout', async () => {
      jest.useFakeTimers();
      // fetch không bao giờ resolve — chỉ phản ứng khi AbortController bắn abort.
      fetchMock.mockImplementation(
        (_url: string, options: any) =>
          new Promise((_resolve, reject) => {
            options.signal.addEventListener('abort', () => {
              const err: any = new Error('Aborted');
              err.name = 'AbortError';
              reject(err);
            });
          })
      );

      const api = loadApi();
      const promise = api.getSanPhamList();
      await jest.advanceTimersByTimeAsync(15000);
      const res = await promise;

      expect(res.isSuccess).toBe(false);
      expect(res.message).toContain('quá hạn');
      jest.useRealTimers();
    });

    it('phân biệt lỗi server 5xx với lỗi mất mạng', async () => {
      fetchMock.mockResolvedValue({
        ok: false,
        status: 503,
        json: async () => {
          throw new Error('không phải JSON');
        },
      });

      const api = loadApi();
      const res = await api.getSanPhamList();

      expect(res.isSuccess).toBe(false);
      expect(res.message).toContain('Server đang gặp sự cố');
    });

    it('báo mất kết nối khi fetch ném lỗi mạng', async () => {
      fetchMock.mockRejectedValue(new Error('Network request failed'));

      const api = loadApi();
      const res = await api.getSanPhamList();

      expect(res.isSuccess).toBe(false);
      expect(res.message).toContain('Không kết nối được server');
    });
  });

  describe('cache catalog', () => {
    it('không gọi lại mạng ở lần lấy menu thứ hai', async () => {
      fetchMock.mockResolvedValue(envelope([{ id: '1' }]));

      const api = loadApi();
      await api.getSanPhamList();
      await api.getSanPhamList();

      expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    it('không nhớ kết quả lỗi — lần sau vẫn thử lại', async () => {
      fetchMock.mockRejectedValueOnce(new Error('Network request failed'));
      fetchMock.mockResolvedValueOnce(envelope([{ id: '1' }]));

      const api = loadApi();
      const loi = await api.getSanPhamList();
      const lai = await api.getSanPhamList();

      expect(loi.isSuccess).toBe(false);
      expect(lai.isSuccess).toBe(true);
      expect(fetchMock).toHaveBeenCalledTimes(2);
    });

    it('đăng xuất thì quên menu đã nhớ', async () => {
      fetchMock.mockResolvedValue(envelope([{ id: '1' }]));

      const api = loadApi();
      await api.getSanPhamList();
      await api.clearToken();
      await api.getSanPhamList();

      expect(fetchMock).toHaveBeenCalledTimes(2);
    });
  });

  // Đây là chỗ từng gây sự cố thật (nhiều client cùng refresh làm văng phiên), nên khoá lại bằng test.
  describe('gộp refresh token', () => {
    it('nhiều request cùng nhận 401 chỉ gọi refresh MỘT lần', async () => {
      const SecureStore = require('expo-secure-store');
      await SecureStore.setItemAsync('token', 'token-het-han');
      await SecureStore.setItemAsync('refreshToken', 'refresh-con-han');

      const unauthorized = {
        ok: false,
        status: 401,
        json: async () => {
          throw new Error('body rỗng');
        },
      };

      fetchMock.mockImplementation(async (url: string) => {
        if (url.includes('/khachhang-auth/refresh')) {
          return envelope({ token: 'token-moi', refreshToken: 'refresh-moi', tenKhachHang: 'A' });
        }
        // Request nghiệp vụ: lần đầu 401, sau khi có token mới thì OK.
        return unauthorized;
      });

      const api = loadApi();
      await Promise.all([api.getVi(), api.getTheTem(), api.getDonCuaToi()]);

      const soLanRefresh = fetchMock.mock.calls.filter((c: any[]) =>
        String(c[0]).includes('/khachhang-auth/refresh')
      ).length;
      expect(soLanRefresh).toBe(1);
    });
  });

  describe('giới hạn số đơn', () => {
    it('luôn kèm take khi lấy danh sách đơn', async () => {
      fetchMock.mockResolvedValue(envelope([]));

      const api = loadApi();
      await api.getDonCuaToi();

      expect(String(fetchMock.mock.calls[0][0])).toBe(`${API}/dat-hang/don-cua-toi?take=50`);
    });
  });
});
