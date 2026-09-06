import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import * as Crypto from 'expo-crypto';
import { datLyBiMat, DiaChiKhachHang, getDiaChiList, getGiaLyBiMat, LyBiMatResult } from '../api';
import { COLORS } from '../theme';
import KeyboardAvoider from '../components/KeyboardAvoider';

// Fallback CHỈ dùng khi request lấy giá thật lỗi (mất mạng lúc mở màn hình) — 25.000đ là giá mặc
// định lúc viết tính năng này, có thể lệch nếu staff đã đổi. Ưu tiên tuyệt đối là giaLyBiMat lấy từ
// server; hằng số này không dùng để tính tiền, DatLyBiMatAsync luôn tự lấy giá server-side khi đặt.
const GIA_LY_BI_MAT_FALLBACK = 25_000;

export default function LyBiMatScreen() {
  const navigation = useNavigation<any>();
  const [diaChi, setDiaChi] = useState('');
  const [savedDiaChi, setSavedDiaChi] = useState<DiaChiKhachHang[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<LyBiMatResult | null>(null);
  const [giaLyBiMat, setGiaLyBiMat] = useState(GIA_LY_BI_MAT_FALLBACK);
  // Mã chống tạo trùng cho đúng lần bấm "Bóc" này — cùng lý do và cùng vòng đời với
  // CheckoutScreen.clientOrderIdRef (xem đó để hiểu đầy đủ).
  const clientOrderIdRef = useRef<string | null>(null);

  useEffect(() => {
    (async () => {
      const res = await getDiaChiList();
      if (res.isSuccess && res.data) {
        setSavedDiaChi(res.data);
        const macDinh = res.data.find((d) => d.isDefault);
        if (macDinh) setDiaChi(macDinh.diaChi);
      }
    })();
    (async () => {
      const res = await getGiaLyBiMat();
      if (res.isSuccess && typeof res.data === 'number') setGiaLyBiMat(res.data);
    })();
  }, []);

  const handleBoc = async () => {
    if (!diaChi.trim()) {
      setError('Vui lòng nhập địa chỉ giao hàng.');
      return;
    }
    setLoading(true);
    setError('');
    if (!clientOrderIdRef.current) clientOrderIdRef.current = Crypto.randomUUID();
    try {
      const res = await datLyBiMat(diaChi.trim(), undefined, clientOrderIdRef.current);
      if (res.isSuccess && res.data) {
        clientOrderIdRef.current = null;
        setResult(res.data);
      } else {
        setError(res.message || 'Có lỗi xảy ra, thử lại nhé.');
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  if (result) {
    return (
      <View style={styles.revealWrap}>
        <Text style={styles.revealEmoji}>🎉</Text>
        <Text style={styles.revealTitle}>Bạn nhận được</Text>
        <Text style={styles.revealItem}>
          {result.tenSanPham} ({result.tenBienThe})
        </Text>
        <Text style={styles.revealPrice}>
          Trả {result.giaTraTien.toLocaleString('vi-VN')}đ — giá thật {result.giaThat.toLocaleString('vi-VN')}đ
        </Text>
        {result.tietKiem > 0 && (
          <Text style={styles.revealSaved}>Bạn đã tiết kiệm {result.tietKiem.toLocaleString('vi-VN')}đ! 🎊</Text>
        )}
        <Text style={styles.revealMa}>Mã đơn: {result.maHoaDon}</Text>

        <TouchableOpacity
          style={styles.primaryBtn}
          onPress={() => navigation.navigate('ThanhToan', { hoaDonId: result.hoaDonId })}
        >
          <Text style={styles.primaryBtnText}>Thanh toán</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.secondaryBtn} onPress={() => setResult(null)}>
          <Text style={styles.secondaryBtnText}>Bốc thêm 1 ly khác</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <KeyboardAvoider>
      <View style={{ padding: 20 }}>
        <Text style={styles.emoji}>🎁</Text>
        <Text style={styles.title}>Ly Bí Mật</Text>
        <Text style={styles.desc}>
          Chỉ {giaLyBiMat.toLocaleString('vi-VN')}đ, quán sẽ chọn NGẪU NHIÊN 1 món cho bạn — có thể là món giá
          cao hơn nhiều! Thử vận may của bạn 🍀
        </Text>

        <Text style={styles.label}>Giao đến</Text>
        <TextInput
          style={styles.input}
          placeholder="Nhập địa chỉ giao hàng..."
          placeholderTextColor={COLORS.textFaint}
          value={diaChi}
          onChangeText={setDiaChi}
          multiline
          textContentType="fullStreetAddress"
          autoComplete="street-address"
        />
        {savedDiaChi.length > 0 && (
          <View style={styles.chipRow}>
            {savedDiaChi.map((d) => (
              <TouchableOpacity key={d.id} style={styles.chip} onPress={() => setDiaChi(d.diaChi)}>
                <Text style={styles.chipText} numberOfLines={1}>
                  {d.isDefault ? '★ ' : ''}
                  {d.diaChi}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <TouchableOpacity style={styles.primaryBtn} onPress={handleBoc} disabled={loading}>
          {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.primaryBtnText}>Bốc Ly Bí Mật 🎲</Text>}
        </TouchableOpacity>
      </View>
    </KeyboardAvoider>
  );
}

const styles = StyleSheet.create({
  emoji: { fontSize: 48, textAlign: 'center', marginBottom: 8 },
  title: { fontSize: 20, fontWeight: '700', color: COLORS.text, textAlign: 'center', marginBottom: 8 },
  desc: { fontSize: 14, color: COLORS.textMuted, textAlign: 'center', lineHeight: 20, marginBottom: 20 },
  label: { fontSize: 13, fontWeight: '700', color: COLORS.primary, marginBottom: 6 },
  input: {
    fontSize: 14,
    color: COLORS.text,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    padding: 12,
    minHeight: 44,
    backgroundColor: '#fff',
  },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 8 },
  chip: { borderWidth: 1, borderColor: COLORS.border, borderRadius: 14, paddingHorizontal: 10, paddingVertical: 5, maxWidth: 220 },
  chipText: { fontSize: 12, color: COLORS.textMuted },
  error: { color: COLORS.danger, marginTop: 12, textAlign: 'center' },
  primaryBtn: { backgroundColor: COLORS.primary, borderRadius: 10, paddingVertical: 14, alignItems: 'center', marginTop: 20 },
  primaryBtnText: { color: '#fff', fontWeight: '700', fontSize: 16 },
  secondaryBtn: { paddingVertical: 12, alignItems: 'center', marginTop: 8 },
  secondaryBtnText: { color: COLORS.primary, fontWeight: '600' },
  revealWrap: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, backgroundColor: COLORS.bg },
  revealEmoji: { fontSize: 60, marginBottom: 12 },
  revealTitle: { fontSize: 15, color: COLORS.textMuted, marginBottom: 6 },
  revealItem: { fontSize: 22, fontWeight: '700', color: COLORS.text, textAlign: 'center', marginBottom: 8 },
  revealPrice: { fontSize: 14, color: COLORS.textMuted, marginBottom: 8 },
  revealSaved: { fontSize: 15, fontWeight: '700', color: COLORS.success, marginBottom: 8 },
  revealMa: { fontSize: 12, color: COLORS.textFaint, marginBottom: 20 },
});
