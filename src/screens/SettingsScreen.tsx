import { useCallback, useState } from 'react';
import { ActivityIndicator, Alert, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import {
  datDiaChiMacDinh,
  DiaChiKhachHang,
  getDiaChiList,
  getSessions,
  getVi,
  KhachHangVi,
  PhienDangNhapKhachHang,
  revokeSession,
  xoaDiaChi,
  xoaTaiKhoan,
} from '../api';
import { useAuth } from '../AuthContext';
import { COLORS } from '../theme';

// Backend trả DateTime dạng "yyyy-MM-ddTHH:mm:ss.fffffff" (Kind=Unspecified nhưng thực chất là UTC,
// khớp cách AppQuanLyIOS/DeviceSessionsView.formatUtc xử lý) — `new Date(iso)` không có hậu tố "Z"
// sẽ bị JS hiểu nhầm là GIỜ MÁY (lệch 7h so với giờ VN thật). Cắt về giây rồi ép hậu tố "Z" để parse
// đúng là UTC, sau đó lấy giờ/phút theo giờ máy hiện tại (VN = UTC+7) khi hiển thị.
function formatUtcShort(iso: string): string {
  const d = new Date(`${iso.slice(0, 19)}Z`);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getHours())}:${pad(d.getMinutes())} ${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
}

const HANG_COLOR: Record<string, string> = {
  'Kim Cương': '#00838F',
  'Vàng': '#B8860B',
  'Bạc': '#616161',
  'Thành Viên': COLORS.primary,
};

export default function SettingsScreen() {
  const navigation = useNavigation<any>();
  const { tenKhachHang, logout } = useAuth();
  const [sessions, setSessions] = useState<PhienDangNhapKhachHang[]>([]);
  const [diaChiList, setDiaChiList] = useState<DiaChiKhachHang[]>([]);
  const [vi, setVi] = useState<KhachHangVi | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    const [sessionsRes, diaChiRes, viRes] = await Promise.all([getSessions(), getDiaChiList(), getVi()]);
    if (sessionsRes.isSuccess && sessionsRes.data) setSessions(sessionsRes.data);
    if (diaChiRes.isSuccess && diaChiRes.data) setDiaChiList(diaChiRes.data);
    if (viRes.isSuccess && viRes.data) setVi(viRes.data);
    setLoading(false);
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const handleXoaDiaChi = async (id: string) => {
    const result = await xoaDiaChi(id);
    if (result.isSuccess) setDiaChiList((prev) => prev.filter((d) => d.id !== id));
  };

  const handleDatMacDinh = async (id: string) => {
    const result = await datDiaChiMacDinh(id);
    if (result.isSuccess) {
      setDiaChiList((prev) => prev.map((d) => ({ ...d, isDefault: d.id === id })));
    }
  };

  const handleThuHoiSession = (item: PhienDangNhapKhachHang) => {
    Alert.alert('Đăng xuất thiết bị này?', item.thietBi ?? 'Thiết bị không rõ', [
      { text: 'Huỷ', style: 'cancel' },
      {
        text: 'Đăng xuất',
        style: 'destructive',
        onPress: async () => {
          const result = await revokeSession(item.id);
          if (result.isSuccess) setSessions((prev) => prev.filter((s) => s.id !== item.id));
        },
      },
    ]);
  };

  const handleXoaTaiKhoan = () => {
    Alert.alert(
      'Xoá tài khoản?',
      'Bạn sẽ không thể đăng nhập lại và mất toàn bộ địa chỉ đã lưu. Lịch sử mua hàng vẫn được quán lưu lại. Không thể hoàn tác.',
      [
        { text: 'Huỷ', style: 'cancel' },
        {
          text: 'Xoá tài khoản',
          style: 'destructive',
          onPress: async () => {
            const result = await xoaTaiKhoan();
            if (result.isSuccess) {
              logout();
            } else {
              Alert.alert('Không xoá được', result.message);
            }
          },
        },
      ],
    );
  };

  return (
    <ScrollView style={{ flex: 1 }}>
      <View style={styles.header}>
        <Text style={styles.name}>{tenKhachHang}</Text>
      </View>

      {loading ? (
        <ActivityIndicator color={COLORS.primary} style={{ marginTop: 24 }} />
      ) : (
        <>
          {vi && (
            <View style={styles.viCard}>
              <View style={styles.viTopRow}>
                <View style={[styles.hangBadge, { backgroundColor: HANG_COLOR[vi.hang] ?? COLORS.primary }]}>
                  <Text style={styles.hangBadgeText}>👑 Hạng {vi.hang}</Text>
                </View>
                <Text style={styles.viSoDu}>{vi.soDu.toLocaleString('vi-VN')}đ</Text>
              </View>
              <Text style={styles.viLabel}>Số dư ví</Text>
              <View style={styles.viStatsRow}>
                <View style={styles.viStat}>
                  <Text style={styles.viStatValue}>{vi.diemThangNay}</Text>
                  <Text style={styles.viStatLabel}>Điểm tháng này</Text>
                </View>
                <View style={styles.viStat}>
                  <Text style={styles.viStatValue}>{vi.tongChiTieuLifetime.toLocaleString('vi-VN')}đ</Text>
                  <Text style={styles.viStatLabel}>Tổng chi tiêu</Text>
                </View>
              </View>
              {vi.tongNo > 0 && (
                <Text style={styles.viNo}>Công nợ hiện tại: {vi.tongNo.toLocaleString('vi-VN')}đ</Text>
              )}
              {vi.monHayMua.length > 0 && (
                <Text style={styles.viMonHayMua}>
                  Hay gọi: {vi.monHayMua.map((m) => `${m.tenSanPham}${m.tenBienThe ? ` (${m.tenBienThe})` : ''}`).join(', ')}
                </Text>
              )}
            </View>
          )}

          <TouchableOpacity style={styles.uuDaiRow} onPress={() => navigation.navigate('UuDai')}>
            <Text style={styles.uuDaiEmoji}>🎁</Text>
            <Text style={styles.uuDaiText}>Ưu đãi của tôi</Text>
            <Text style={styles.uuDaiArrow}>›</Text>
          </TouchableOpacity>

          <Text style={styles.sectionTitle}>Địa chỉ đã lưu</Text>
          {diaChiList.length === 0 ? (
            <Text style={styles.emptyText}>Chưa có địa chỉ nào — nhập ở bước đặt hàng sẽ tự lưu lại.</Text>
          ) : (
            <View style={{ paddingHorizontal: 16 }}>
              {diaChiList.map((item) => (
                <View key={item.id} style={styles.diaChiRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.diaChiText}>
                      {item.isDefault ? '★ ' : ''}
                      {item.diaChi}
                    </Text>
                    {!item.isDefault && (
                      <TouchableOpacity onPress={() => handleDatMacDinh(item.id)}>
                        <Text style={styles.diaChiAction}>Đặt làm mặc định</Text>
                      </TouchableOpacity>
                    )}
                  </View>
                  <TouchableOpacity onPress={() => handleXoaDiaChi(item.id)} style={styles.diaChiRemove}>
                    <Text style={styles.diaChiRemoveText}>✕</Text>
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}

          <Text style={styles.sectionTitle}>Thiết bị đã đăng nhập</Text>
          <View style={{ paddingHorizontal: 16 }}>
            {sessions.map((item) => {
              const accent = item.laThietBiHienTai ? COLORS.success : COLORS.primary;
              return (
                <View key={item.id} style={styles.sessionCard}>
                  <View style={[styles.sessionIconWrap, { backgroundColor: `${accent}22` }]}>
                    <Text style={styles.sessionIconEmoji}>{item.nenTang === 'Desktop' ? '💻' : '📱'}</Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <View style={styles.sessionTitleRow}>
                      <Text style={styles.sessionDevice}>{item.thietBi ?? 'Thiết bị không rõ'}</Text>
                      {item.laThietBiHienTai && (
                        <View style={styles.sessionBadge}>
                          <Text style={styles.sessionBadgeText}>Thiết bị này</Text>
                        </View>
                      )}
                    </View>
                    <Text style={[styles.sessionPlatform, { color: accent }]}>{item.nenTang ?? '?'}</Text>
                    <Text style={styles.sessionMeta}>
                      Đăng nhập {formatUtcShort(item.ngayTao)} · Hết hạn {formatUtcShort(item.hetHan)}
                    </Text>
                  </View>
                  {!item.laThietBiHienTai && (
                    <TouchableOpacity onPress={() => handleThuHoiSession(item)} style={styles.sessionRevokeBtn}>
                      <Text style={styles.sessionRevokeText}>✕</Text>
                    </TouchableOpacity>
                  )}
                </View>
              );
            })}
          </View>
        </>
      )}

      <TouchableOpacity style={styles.logoutBtn} onPress={logout}>
        <Text style={styles.logoutText}>Đăng xuất</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.deleteAccountBtn} onPress={handleXoaTaiKhoan}>
        <Text style={styles.deleteAccountText}>Xoá tài khoản</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  header: { padding: 20, alignItems: 'center', backgroundColor: COLORS.primaryTint },
  name: { fontSize: 20, fontWeight: '700', color: COLORS.primaryDark },
  viCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    margin: 16,
    marginBottom: 4,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  viTopRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  hangBadge: { borderRadius: 14, paddingHorizontal: 12, paddingVertical: 5 },
  hangBadgeText: { color: '#fff', fontSize: 12, fontWeight: '700' },
  viSoDu: { fontSize: 20, fontWeight: '700', color: COLORS.text },
  viLabel: { fontSize: 12, color: COLORS.textFaint, textAlign: 'right', marginTop: 2 },
  viStatsRow: { flexDirection: 'row', marginTop: 14, gap: 12 },
  viStat: { flex: 1, backgroundColor: COLORS.bg, borderRadius: 10, padding: 10, alignItems: 'center' },
  viStatValue: { fontSize: 15, fontWeight: '700', color: COLORS.primary },
  viStatLabel: { fontSize: 11, color: COLORS.textMuted, marginTop: 2 },
  viNo: { fontSize: 12, color: COLORS.danger, marginTop: 10, fontWeight: '600' },
  viMonHayMua: { fontSize: 12, color: COLORS.textMuted, marginTop: 8, lineHeight: 17 },
  uuDaiRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    marginHorizontal: 16,
    marginTop: 12,
    padding: 14,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  uuDaiEmoji: { fontSize: 20, marginRight: 10 },
  uuDaiText: { flex: 1, fontSize: 15, fontWeight: '600', color: COLORS.text },
  uuDaiArrow: { fontSize: 20, color: COLORS.textFaint },
  sectionTitle: { fontSize: 13, color: COLORS.textMuted, paddingHorizontal: 16, paddingTop: 16, paddingBottom: 4 },
  emptyText: { fontSize: 13, color: COLORS.textFaint, paddingHorizontal: 16 },
  diaChiRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.divider,
  },
  diaChiText: { fontSize: 14, color: COLORS.text, lineHeight: 19 },
  diaChiAction: { fontSize: 12, color: COLORS.primary, fontWeight: '600', marginTop: 4 },
  diaChiRemove: { padding: 6 },
  diaChiRemoveText: { color: COLORS.danger, fontSize: 16 },
  sessionCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 14,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  sessionIconWrap: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  sessionIconEmoji: { fontSize: 18 },
  sessionTitleRow: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap' },
  sessionDevice: { fontSize: 15, fontWeight: '700', color: COLORS.text },
  sessionBadge: {
    backgroundColor: COLORS.success,
    borderRadius: 10,
    paddingHorizontal: 7,
    paddingVertical: 2,
    marginLeft: 6,
  },
  sessionBadgeText: { color: '#fff', fontSize: 10, fontWeight: '700' },
  sessionPlatform: { fontSize: 12, fontWeight: '700', marginTop: 2 },
  sessionMeta: { fontSize: 11, color: COLORS.textFaint, marginTop: 2 },
  sessionRevokeBtn: { padding: 6, marginLeft: 4 },
  sessionRevokeText: { color: COLORS.danger, fontSize: 16, fontWeight: '700' },
  logoutBtn: {
    marginHorizontal: 16,
    marginTop: 16,
    backgroundColor: COLORS.danger,
    borderRadius: 8,
    paddingVertical: 14,
    alignItems: 'center',
  },
  logoutText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  deleteAccountBtn: {
    margin: 16,
    marginTop: 12,
    paddingVertical: 10,
    alignItems: 'center',
  },
  deleteAccountText: { color: COLORS.textFaint, fontWeight: '600', fontSize: 13, textDecorationLine: 'underline' },
});
