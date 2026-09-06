import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

// Production TraSuaApp Backend — VPS Contabo qua Cloudflare (xem CLAUDE.md gốc D:\Code).
// Trỏ sang backend khác bằng biến môi trường TRASUA_API_BASE_URL lúc build (xem app.config.ts);
// không đặt thì luôn là production, giữ nguyên hành vi cũ.
const API_BASE: string =
  (Constants.expoConfig?.extra as { apiBaseUrl?: string } | undefined)?.apiBaseUrl ??
  'https://api.denncoffee.uk/api';

// Trang QR chuyển khoản — [AllowAnonymous], tự vẽ QR VietQR + số tiền + STK, dùng lại NGUYÊN endpoint
// đã có sẵn cho SMS soạn sẵn (xem HoaDonController.GetBillQrByHoaDonId) thay vì tự dựng UI QR mới.
// maHoaDon dạng "HD xxxxxxxx" (8 hex đầu Guid) đã in sẵn/trả về từ dat-mon/ly-bi-mat.
export function getThanhToanQrUrl(maHoaDon: string): string {
  return `${API_BASE}/HoaDon/${maHoaDon}/qr`;
}

let cachedToken: string | null = null;
let cachedRefreshToken: string | null = null;
let cachedThietBiId: string | null = null;

// token/refreshToken nằm trong SecureStore (Keychain trên iOS, Keystore trên Android) chứ KHÔNG
// phải AsyncStorage — AsyncStorage lưu plaintext, đọc được nếu máy bị jailbreak/root hoặc qua backup
// thiết bị. Mọi dữ liệu KHÔNG nhạy cảm (tên khách, thietBiId, mốc đã đọc thông báo) vẫn để
// AsyncStorage vì SecureStore chậm hơn và giới hạn 2048 byte mỗi khoá.
//
// readSecure/writeSecure bọc try/catch vì SecureStore ném lỗi thật khi Keychain không dùng được
// (máy chưa mở khoá lần đầu, cấu hình thiết bị lạ). Mất token chỉ khiến khách phải đăng nhập lại —
// chấp nhận được; để lỗi thoát ra ngoài thì app trắng màn hình, tệ hơn nhiều.
async function readSecure(key: string): Promise<string | null> {
  try {
    return await SecureStore.getItemAsync(key);
  } catch {
    return null;
  }
}

async function writeSecure(key: string, value: string): Promise<void> {
  try {
    await SecureStore.setItemAsync(key, value);
  } catch {
    // bỏ qua — phiên vẫn sống trong biến cache tới khi đóng app
  }
}

async function deleteSecure(key: string): Promise<void> {
  try {
    await SecureStore.deleteItemAsync(key);
  } catch {
    // bỏ qua
  }
}

// Khách đã cài bản cũ đang giữ token trong AsyncStorage. Chuyển sang SecureStore trong lần đọc đầu
// tiên rồi xoá bản cũ, để họ không bị đá ra màn hình đăng nhập khi cập nhật app.
async function readTokenMigrating(key: string): Promise<string | null> {
  const secure = await readSecure(key);
  if (secure) return secure;

  const legacy = await AsyncStorage.getItem(key);
  if (!legacy) return null;

  await writeSecure(key, legacy);
  await AsyncStorage.removeItem(key);
  return legacy;
}

export async function getToken(): Promise<string | null> {
  if (cachedToken) return cachedToken;
  cachedToken = await readTokenMigrating('token');
  return cachedToken;
}

async function getRefreshToken(): Promise<string | null> {
  if (cachedRefreshToken) return cachedRefreshToken;
  cachedRefreshToken = await readTokenMigrating('refreshToken');
  return cachedRefreshToken;
}

// Lưu tên khách cục bộ để hiện lại ngay khi mở app (không phải gọi API "me" riêng).
export async function getSavedTenKhachHang(): Promise<string | null> {
  return AsyncStorage.getItem('tenKhachHang');
}

// ThietBiId: sinh 1 lần, giữ ổn định suốt vòng đời cài đặt app — dùng để backend dedupe phiên theo
// thiết bị (đăng nhập lại cùng máy sẽ thu hồi phiên cũ, không tạo phiên mới chồng chất).
export async function getThietBiId(): Promise<string> {
  if (cachedThietBiId) return cachedThietBiId;
  let id = await AsyncStorage.getItem('thietBiId');
  if (!id) {
    // randomUUID() dùng nguồn ngẫu nhiên mật mã học, thay cho Date.now()+Math.random() trước đây
    // (đoán/trùng được về lý thuyết). Giữ tiền tố nền tảng để đọc log cho dễ.
    id = `${Platform.OS}-${Crypto.randomUUID()}`;
    await AsyncStorage.setItem('thietBiId', id);
  }
  cachedThietBiId = id;
  return id;
}

async function setSession(token: string, refreshToken: string, tenKhachHang: string) {
  cachedToken = token;
  cachedRefreshToken = refreshToken;
  await writeSecure('token', token);
  await writeSecure('refreshToken', refreshToken);
  await AsyncStorage.setItem('tenKhachHang', tenKhachHang);
}

export async function clearToken() {
  cachedToken = null;
  cachedRefreshToken = null;
  catalogCache.clear();
  await deleteSecure('token');
  await deleteSecure('refreshToken');
  // Xoá luôn bản AsyncStorage cũ phòng trường hợp đăng xuất trước khi kịp migrate.
  await AsyncStorage.removeItem('token');
  await AsyncStorage.removeItem('refreshToken');
  await AsyncStorage.removeItem('tenKhachHang');
}

// warnings: cảnh báo nghiệp vụ đi kèm response THÀNH CÔNG (vd "Đã trừ tồn kho âm: Trân châu đen") —
// backend đã trả sẵn (Result<T>.WithWarnings) từ lâu nhưng field này CHƯA từng được app đọc, luôn
// bị bỏ qua âm thầm. Optional vì phần lớn response không có.
type Envelope<T> = { isSuccess: boolean; message: string; data: T | null; warnings?: string[] | null };

// Gọi từ App.tsx để đưa app quay lại LoginScreen khi refresh token cũng hết hạn — request() không
// tự render UI được nên chỉ báo qua callback, App.tsx quyết định cách quay lại (reset tenKhachHang).
let sessionExpiredHandler: (() => void) | null = null;
export function setSessionExpiredHandler(fn: () => void) {
  sessionExpiredHandler = fn;
}

// fetch của React Native KHÔNG có timeout mặc định hợp lý — request treo tới khi OS bỏ cuộc (có thể
// hơn 1 phút trên mạng chập chờn), trong lúc đó màn hình chỉ quay vòng tròn không báo gì. 15s đủ
// rộng cho 3G yếu mà vẫn kịp báo lỗi trước khi khách bỏ cuộc.
const REQUEST_TIMEOUT_MS = 15000;

class TimeoutError extends Error {}

async function rawRequest<T>(path: string, options: RequestInit, token: string | null): Promise<{ status: number; envelope: Envelope<T> | null }> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(`${API_BASE}${path}`, {
      ...options,
      signal: controller.signal,
      headers: { ...headers, ...(options.headers as any) },
    });
  } catch (e: any) {
    // AbortError sinh ra từ controller.abort() ở trên — phân biệt với lỗi mạng thật để báo đúng.
    if (e?.name === 'AbortError') throw new TimeoutError();
    throw e;
  } finally {
    clearTimeout(timer);
  }
  // 401 từ [Authorize] trả body RỖNG (không phải JSON envelope) — res.json() sẽ throw nếu gọi
  // thẳng, từng khiến lỗi hết hạn phiên bị báo nhầm thành "Không kết nối được server.".
  let envelope: Envelope<T> | null = null;
  try {
    envelope = await res.json();
  } catch {
    envelope = null;
  }
  return { status: res.status, envelope };
}

// allowRefresh=false dùng cho request nội bộ của refreshSession() — tránh gọi lại chính nó nếu
// refresh token cũng hết hạn (endpoint đó AllowAnonymous nên không bao giờ trả 401, nhưng vẫn
// chặn đệ quy cho chắc).
async function request<T>(path: string, options: RequestInit = {}, allowRefresh = true): Promise<Envelope<T>> {
  try {
    const token = await getToken();
    const first = await rawRequest<T>(path, options, token);

    // 401 khi chưa hề gửi token (đăng nhập sai mật khẩu, OTP sai...) là lỗi thật của endpoint đó,
    // không phải phiên hết hạn — trả thẳng message thật, đừng ghi đè bằng "Phiên đăng nhập hết hạn".
    if (first.status === 401 && allowRefresh && token) {
      const refreshed = await refreshSessionCoalesced(token);
      if (refreshed) {
        const retryToken = await getToken();
        const retry = await rawRequest<T>(path, options, retryToken);
        if (retry.envelope) return retry.envelope;
      }
      await clearToken();
      sessionExpiredHandler?.();
      return { isSuccess: false, message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.', data: null };
    }

    if (first.envelope) return first.envelope;

    // Có phản hồi HTTP nhưng không phải JSON envelope — 2 nguồn phổ biến nhất đều KHÔNG viết body:
    // rate limiter (429, xem Program.cs RejectionStatusCode, không có OnRejected) và authorization
    // middleware mặc định của ASP.NET Core (403, không có IAuthorizationMiddlewareResultHandler
    // riêng). Trước đây cả 2 lẫn mọi lỗi lạ khác đều ra chung "Không đọc được phản hồi từ server."
    // — khách tưởng máy/mạng mình hỏng trong khi thực ra bị chặn tốc độ hoặc thiếu quyền.
    if (first.status >= 500) {
      return { isSuccess: false, message: 'Server đang gặp sự cố, vui lòng thử lại sau ít phút.', data: null };
    }
    if (first.status === 429) {
      return { isSuccess: false, message: 'Bạn thao tác hơi nhanh, vui lòng chờ một chút rồi thử lại.', data: null };
    }
    if (first.status === 403) {
      return { isSuccess: false, message: 'Bạn không có quyền thực hiện thao tác này.', data: null };
    }
    return { isSuccess: false, message: 'Không đọc được phản hồi từ server.', data: null };
  } catch (e) {
    if (e instanceof TimeoutError) {
      return { isSuccess: false, message: 'Mạng chậm nên yêu cầu quá hạn, vui lòng thử lại.', data: null };
    }
    return { isSuccess: false, message: 'Không kết nối được server.', data: null };
  }
}

// ===== Đăng nhập khách (SĐT + OTP mô phỏng) =====

export type KhachHangLoginResponse = {
  thanhCong: boolean;
  message: string;
  token: string;
  refreshToken: string;
  khachHangId: string;
  tenKhachHang: string;
};

export function kiemTraSdt(soDienThoai: string) {
  return request<boolean>('/khachhang-auth/kiem-tra-sdt', {
    method: 'POST',
    body: JSON.stringify({ soDienThoai }),
  });
}

export async function dangNhapMatKhau(soDienThoai: string, matKhau: string) {
  const thietBiId = await getThietBiId();
  const result = await request<KhachHangLoginResponse>('/khachhang-auth/dang-nhap', {
    method: 'POST',
    body: JSON.stringify({
      soDienThoai,
      matKhau,
      thietBi: Platform.OS === 'ios' ? 'iPhone' : 'Android',
      nenTang: Platform.OS,
      thietBiId,
    }),
  });
  if (result.isSuccess && result.data) await setSession(result.data.token, result.data.refreshToken, result.data.tenKhachHang);
  return result;
}

export function guiOtp(soDienThoai: string) {
  return request<{ moPhong: boolean; otp: string }>('/khachhang-auth/gui-otp', {
    method: 'POST',
    body: JSON.stringify({ soDienThoai }),
  });
}

// Kiểm tra mã ngay khi khách nhập — không tiêu mã, chỉ chặn sớm mã sai trước khi qua màn đặt mật khẩu.
export function kiemTraOtp(soDienThoai: string, otp: string) {
  return request<boolean>('/khachhang-auth/kiem-tra-otp', {
    method: 'POST',
    body: JSON.stringify({ soDienThoai, otp }),
  });
}

// matKhau bắt buộc — SĐT chưa có tài khoản sẽ dùng để đặt mật khẩu (khớp flow ở LoginScreen).
export async function xacNhanOtp(soDienThoai: string, otp: string, matKhau: string) {
  const thietBiId = await getThietBiId();
  const result = await request<KhachHangLoginResponse>('/khachhang-auth/xac-nhan-otp', {
    method: 'POST',
    body: JSON.stringify({
      soDienThoai,
      otp,
      matKhau,
      thietBi: Platform.OS === 'ios' ? 'iPhone' : 'Android',
      nenTang: Platform.OS,
      thietBiId,
    }),
  });
  if (result.isSuccess && result.data) await setSession(result.data.token, result.data.refreshToken, result.data.tenKhachHang);
  return result;
}

// Refresh đang chạy dở (nếu có) — nhiều màn hình (Trang chủ: Ví, Thông báo, Đơn của tôi, Thẻ tem,
// Sinh nhật, Giới thiệu...) gọi request() song song lúc mount. Nếu token vừa hết hạn, TẤT CẢ cùng
// dính 401 và mỗi cái tự gọi /khachhang-auth/refresh riêng thì dính race: backend xoay vòng refresh
// token kiểu one-time-use (KhachHangAuthService.RefreshAsync ghi đè TokenHash ngay khi dùng) — request
// thắng race lưu token mới xong thì các request thua bị BE từ chối refresh token cũ (đã tiêu) → 401 →
// clearToken() xoá sạch luôn token mới vừa refresh thành công, bắt khách đăng xuất dù phiên còn sống
// (đã xác nhận qua log VPS: 3 request /api/khachhang-auth/refresh 401 cùng giây, xem incident
// incident_multiclient_refresh_token_race_2026_09 — cùng bug đã fix ở AppShipperAndroid/AppQuanLyIOS).
let refreshInFlight: Promise<boolean> | null = null;

// Double-check trước khi refresh: nếu token trong storage đã khác token vừa dùng lúc 401 nghĩa là 1
// request khác vừa refresh xong — dùng luôn, khỏi gọi /khachhang-auth/refresh thừa. Nếu chưa ai
// refresh, gộp lại 1 Promise dùng chung qua refreshSession() bên dưới.
async function refreshSessionCoalesced(previousToken: string): Promise<boolean> {
  const current = await getToken();
  if (current && current !== previousToken) return true;
  return refreshSession();
}

export async function refreshSession(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = doRefreshSession();
  try {
    return await refreshInFlight;
  } finally {
    refreshInFlight = null;
  }
}

async function doRefreshSession(): Promise<boolean> {
  const rt = await getRefreshToken();
  if (!rt) return false;
  const thietBiId = await getThietBiId();
  const result = await request<KhachHangLoginResponse>(
    '/khachhang-auth/refresh',
    {
      method: 'POST',
      body: JSON.stringify({
        refreshToken: rt,
        thietBi: Platform.OS === 'ios' ? 'iPhone' : 'Android',
        nenTang: Platform.OS,
        thietBiId,
      }),
    },
    false,
  );
  if (result.isSuccess && result.data) {
    await setSession(result.data.token, result.data.refreshToken, result.data.tenKhachHang);
    return true;
  }
  return false;
}

export async function logout() {
  await request<boolean>('/khachhang-auth/logout', { method: 'POST' });
  await clearToken();
}

export type PhienDangNhapKhachHang = {
  id: string;
  thietBi: string | null;
  nenTang: string | null;
  ngayTao: string;
  hetHan: string;
  laThietBiHienTai: boolean;
};

export function getSessions() {
  return request<PhienDangNhapKhachHang[]>('/khachhang-auth/sessions');
}

// Thu hồi 1 thiết bị KHÁC (không phải thiết bị đang gọi) — vd mất máy/cho mượn máy. Backend tự lọc
// theo khachHangId nên không cần kiểm tra id có thuộc mình trước khi gọi.
export function revokeSession(id: string) {
  return request<boolean>(`/khachhang-auth/sessions/${id}`, { method: 'DELETE' });
}

// Không throw/log lỗi ra ngoài — gọi từ push.ts mỗi lần app mở, lỗi mạng tạm thời không nên làm phiền
// khách. sid nằm trong JWT nên không cần tự truyền session id ở client.
export function registerPushToken(expoPushToken: string | null) {
  return request<boolean>('/khachhang-auth/push-token', {
    method: 'PUT',
    body: JSON.stringify({ expoPushToken }),
  });
}

// Xoá tài khoản app — KHÔNG xoá lịch sử mua hàng, chỉ vô hiệu hoá đăng nhập + xoá dữ liệu cá nhân
// riêng của app (địa chỉ, ngày sinh). Backend chặn nếu còn số dư ví/công nợ (xem
// KhachHangAuthService.XoaTaiKhoanAsync) — message lỗi đã đủ rõ để hiện thẳng cho khách.
export function xoaTaiKhoan() {
  return request<boolean>('/khachhang-auth/tai-khoan', { method: 'DELETE' });
}

// ===== Catalog (dùng chung API nhân viên — token khách có Role=KhachHang cũng qua được) =====

export type SanPhamBienThe = { id: string; tenBienThe: string; giaBan: number; macDinh: boolean };
export type SanPham = {
  id: string;
  ten: string;
  ngungBan: boolean;
  nhomSanPhamId: string | null;
  hinhAnh: string | null;
  bienThe: SanPhamBienThe[];
  // Chuỗi token đã chuẩn hoá sẵn từ server (SanPhamSearchHelper.BuildTimKiem) — tên không dấu,
  // tên liền không cách, viết tắt (VietTat/PhatAm), tên đầy đủ không viết tắt (TenKhongVietTat).
  // Dùng để search thay vì so trực tiếp `ten` — mới khớp được các kiểu gõ tắt/không dấu.
  timKiem: string;
  // Id món trên store shippershipping — null nghĩa là chưa đẩy lên store (món chỉ quản lý nội bộ
  // hoặc chưa đối soát), app khách chỉ nên hiện món đã có mặt trên store để tránh đặt món quán
  // chưa thật sự bán qua kênh này.
  storeFoodId: number | null;
};
export type NhomSanPham = { id: string; ten: string };
export type Topping = { id: string; ten: string; gia: number; ngungBan: boolean };

// Catalog được gọi lại MỖI LẦN mở tab Menu. Menu quán gần như không đổi trong một phiên dùng app,
// nên giữ lại kết quả 5 phút: mở/đóng tab vài lần chỉ còn 3 request thay vì 3 request mỗi lần.
//
// Cố tình CHỈ cache catalog. Ví, điểm, thẻ tem, đơn hàng đều là dữ liệu khách nhìn để biết tiền và
// điểm của mình — hiện số cũ ở đó là sai nghiêm trọng hơn nhiều so với việc tốn thêm một request.
const CATALOG_TTL_MS = 5 * 60 * 1000;

type CacheEntry = { luc: number; envelope: Envelope<any> };
const catalogCache = new Map<string, CacheEntry>();

async function cachedGet<T>(path: string): Promise<Envelope<T>> {
  const hit = catalogCache.get(path);
  if (hit && Date.now() - hit.luc < CATALOG_TTL_MS) {
    return hit.envelope as Envelope<T>;
  }

  const envelope = await request<T>(path);
  // Chỉ nhớ kết quả thành công — nhớ lỗi lại thì khách phải chờ hết TTL mới thử lại được.
  if (envelope.isSuccess) {
    catalogCache.set(path, { luc: Date.now(), envelope });
  }
  return envelope;
}

// Gọi khi cần chắc chắn lấy menu mới (kéo-để-làm-mới), và khi đăng xuất để khách sau không thấy
// dữ liệu của phiên trước.
export function xoaCacheCatalog() {
  catalogCache.clear();
}

// Endpoint menu RIÊNG cho khách (/dat-hang/menu/*), không phải /SanPham, /NhomSanPham, /Topping của
// nhân viên nữa. Backend trả đúng cùng DTO nên phần đọc dữ liệu không đổi.
//
// Lý do đổi: gọi endpoint nhân viên buộc backend phải cho vai trò KhachHang qua cửa authorization ở
// đó — một khe hở phải giữ mở. Khi bản app này phủ hết máy khách hàng thì backend đóng hẳn được.
export function getSanPhamList() {
  return cachedGet<SanPham[]>('/dat-hang/menu/san-pham');
}

export function getNhomSanPhamList() {
  return cachedGet<NhomSanPham[]>('/dat-hang/menu/nhom');
}

export function getToppingList() {
  return cachedGet<Topping[]>('/dat-hang/menu/topping');
}

// ===== Đặt món =====

export type DatMonItem = { sanPhamBienTheId: string; soLuong: number; ghiChu?: string; toppingIds: string[] };

// clientOrderId: mã chống tạo trùng. Người gọi sinh MỘT lần cho mỗi lần khách bấm "Đặt" và gửi lại Y
// HỆT ở mọi lần thử lại của đúng lần bấm đó (xem CheckoutScreen). Cần vì request này có timeout 15s:
// đơn có thể đã tạo xong trong DB nhưng response mất giữa đường trên 4G — khách bấm lại sẽ ra 2 đơn
// thật nếu không có mã này. Backend thấy mã đã tồn tại thì trả về chính đơn cũ với isSuccess=true.
export function datMon(
  items: DatMonItem[],
  diaChiText: string,
  ghiChu?: string,
  soDienThoaiText?: string,
  deliveryLat?: number,
  deliveryLong?: number,
  clientOrderId?: string,
) {
  return request<{ id: string; thanhTien: number }>('/dat-hang/dat-mon', {
    method: 'POST',
    body: JSON.stringify({
      items, ghiChu, diaChiText, soDienThoaiText, deliveryLat, deliveryLong, clientOrderId,
    }),
  });
}

export type UocTinhShip = {
  khoangCachKm: number;
  phiShip: number;
  shopLat: number;
  shopLong: number;
  tuyenDuong?: { lat: number; long: number }[] | null;
};

export function uocTinhShip(lat: number, long: number) {
  return request<UocTinhShip>('/dat-hang/uoc-tinh-ship', {
    method: 'POST',
    body: JSON.stringify({ lat, long }),
  });
}

export type DonHangKhachItemTopping = { toppingId: string; ten: string; gia: number };
export type DonHangKhachItem = {
  sanPhamBienTheId: string;
  tenSanPham: string;
  tenBienThe: string;
  soLuong: number;
  donGia: number;
  ghiChu?: string | null;
  toppings: DonHangKhachItemTopping[];
};

export type DonHangKhach = {
  id: string;
  maHoaDon: string;
  ngayGio: string;
  thanhTien: number;
  tenMonSummary: string;
  phanLoai?: string | null;
  tenBan?: string | null;
  diaChiText?: string | null;
  soDienThoaiText?: string | null;
  ghiChu?: string | null;
  items: DonHangKhachItem[];
  trangThai: 'ChoXacNhan' | 'DaXacNhan' | 'DangGiao' | 'HoanTat';
  daDanhGia: boolean;
  soSaoDaDanh?: number | null;
};

// Backend đã giới hạn 90 ngày; thêm trần số đơn để khách mua nhiều năm không phải tải danh sách
// khổng lồ mỗi 10 giây (màn hình đơn hàng poll liên tục khi đang mở).
//
// Cố tình KHÔNG làm infinite-scroll: màn hình này poll 10s/lần, phân trang cộng với polling rất dễ
// sinh lỗi kiểu "đang xem trang 3 thì bị kéo về trang 1". 50 đơn gần nhất phủ xa hơn nhu cầu thực
// tế của khách quán cà phê.
const SO_DON_TOI_DA = 50;

export function getDonCuaToi() {
  return request<DonHangKhach[]>(`/dat-hang/don-cua-toi?take=${SO_DON_TOI_DA}`);
}

// Chỉ được phép khi đơn còn "ChoXacNhan" (quán chưa bấm nhận) — backend tự chặn nếu trễ, xem
// DatHangService.HuyDonAsync.
export function huyDon(id: string) {
  return request<boolean>(`/dat-hang/don/${id}`, { method: 'DELETE' });
}

// ===== Địa chỉ giao hàng đã lưu =====

export type DiaChiKhachHang = { id: string; diaChi: string; isDefault: boolean; lat?: number | null; long?: number | null };

export function getDiaChiList() {
  return request<DiaChiKhachHang[]>('/dat-hang/dia-chi');
}

export function xoaDiaChi(id: string) {
  return request<boolean>(`/dat-hang/dia-chi/${id}`, { method: 'DELETE' });
}

export function datDiaChiMacDinh(id: string) {
  return request<boolean>(`/dat-hang/dia-chi/${id}/mac-dinh`, { method: 'PATCH' });
}

// ===== Thông báo =====

export type ThongBao = {
  id: string;
  loai: 'DonHang' | 'KhuyenMai';
  tieude: string;
  noiDung: string;
  ngayTao: string;
  hoaDonId?: string | null;
};

export function getThongBao() {
  return request<ThongBao[]>('/dat-hang/thong-bao');
}

// ===== Ví / điểm thưởng / hạng thành viên =====

export type FavoriteItem = { tenSanPham: string; tenBienThe: string };
export type KhachHangVi = {
  soDu: number;
  diemThangNay: number;
  diemThangTruoc: number;
  duocNhanVoucher: boolean;
  daNhanVoucher: boolean;
  tongNo: number;
  tongChiTieuLifetime: number;
  hang: string;
  monHayMua: FavoriteItem[];
};

export function getVi() {
  return request<KhachHangVi>('/dat-hang/vi');
}

// ===== Ly Bí Mật (blind box) =====

// Giá thật lấy từ GamificationConfig (staff chỉnh qua AppQuanLyIOS) — dùng để hiện đúng banner
// TRƯỚC khi khách bấm "Bóc". Trước đây banner hardcode 25.000đ ở client, staff đổi giá bên server
// là banner sai ngay lập tức mà không ai để ý cho tới khi khách phàn nàn.
export function getGiaLyBiMat() {
  return request<number>('/dat-hang/ly-bi-mat/gia');
}

export type LyBiMatResult = {
  hoaDonId: string;
  maHoaDon: string;
  tenSanPham: string;
  tenBienThe: string;
  giaThat: number;
  giaTraTien: number;
  tietKiem: number;
};

// clientOrderId: mã chống tạo trùng, cùng cơ chế với datMon() — người gọi sinh MỘT lần cho mỗi lần
// bấm và giữ nguyên qua mọi lần thử lại của đúng lần bấm đó.
export function datLyBiMat(diaChiText: string, ghiChu?: string, clientOrderId?: string) {
  return request<LyBiMatResult>('/dat-hang/ly-bi-mat', {
    method: 'POST',
    body: JSON.stringify({ diaChiText, ghiChu, clientOrderId }),
  });
}

// ===== Đánh giá đơn =====

export function danhGiaDon(hoaDonId: string, soSao: number, nhanXet?: string) {
  return request<boolean>('/dat-hang/danh-gia', {
    method: 'POST',
    body: JSON.stringify({ hoaDonId, soSao, nhanXet }),
  });
}

// ===== Thẻ sưu tập ly (stamp card) =====

export type TheTem = {
  tongDonLifetime: number;
  mocThuong: number;
  temHienTai: number;
  duDieuKienDoiThuong: boolean;
  soLanDaDoiThuong: number;
};

export function getTheTem() {
  return request<TheTem>('/dat-hang/the-tem');
}

export function doiTem() {
  return request<TheTem>('/dat-hang/the-tem/doi-thuong', { method: 'POST' });
}

// ===== Giới thiệu bạn bè =====

export type GioiThieuInfo = { maGioiThieu: string; soNguoiDaGioiThieu: number; daDuocGioiThieu: boolean };

export function getGioiThieu() {
  return request<GioiThieuInfo>('/dat-hang/gioi-thieu');
}

export function apDungMaGioiThieu(maGioiThieu: string) {
  return request<boolean>('/dat-hang/gioi-thieu/ap-dung', {
    method: 'POST',
    body: JSON.stringify({ maGioiThieu }),
  });
}

// ===== Sinh nhật =====

export type SinhNhatInfo = { ngaySinh: string | null; dangTrongThangSinhNhat: boolean; daNhanQuaNamNay: boolean };

export function getSinhNhat() {
  return request<SinhNhatInfo>('/dat-hang/sinh-nhat');
}

export function capNhatNgaySinh(ngaySinh: string) {
  return request<boolean>('/dat-hang/sinh-nhat', {
    method: 'PUT',
    body: JSON.stringify({ ngaySinh }),
  });
}

export function nhanQuaSinhNhat() {
  return request<number>('/dat-hang/sinh-nhat/nhan-qua', { method: 'POST' });
}

// ===== Vòng quay may mắn =====

export type VongQuayResult = { label: string; soTienThuong: number; trung: boolean };

export function quayVongQuay() {
  return request<VongQuayResult>('/dat-hang/vong-quay', { method: 'POST' });
}
