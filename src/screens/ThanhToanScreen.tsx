import { useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { WebView } from 'react-native-webview';
import { useNavigation, useRoute } from '@react-navigation/native';
import { getThanhToanQrUrl } from '../api';
import { COLORS } from '../theme';

// Nhúng thẳng trang HTML tự vẽ QR đã có sẵn ở backend (HoaDonController.GetBillQrByHoaDonId,
// [AllowAnonymous]) — dùng lại NGUYÊN, không tự dựng UI QR/tính tiền riêng ở app, tránh lệch logic
// với Desktop/SMS đã dùng chung 1 nguồn (BankQrConfig). Trang tự hiện đúng số tiền CÒN LẠI của đơn.
export default function ThanhToanScreen() {
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  const hoaDonId: string = route.params.hoaDonId;
  const [loading, setLoading] = useState(true);

  return (
    <View style={{ flex: 1, backgroundColor: COLORS.bg }}>
      {loading && (
        <View style={styles.loadingOverlay}>
          <ActivityIndicator color={COLORS.primary} size="large" />
        </View>
      )}
      <WebView
        source={{ uri: getThanhToanQrUrl(hoaDonId) }}
        onLoadEnd={() => setLoading(false)}
        style={{ flex: 1 }}
      />
      <View style={styles.footer}>
        <Text style={styles.hint}>Quét mã hoặc bấm vào QR để mở app ngân hàng — chuyển khoản xong quán sẽ tự ghi nhận.</Text>
        <TouchableOpacity style={styles.doneBtn} onPress={() => navigation.navigate('DonHang')}>
          <Text style={styles.doneBtnText}>Xong, xem đơn của tôi</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1,
    backgroundColor: COLORS.bg,
  },
  footer: {
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: COLORS.divider,
    backgroundColor: '#fff',
  },
  hint: { fontSize: 12, color: COLORS.textMuted, textAlign: 'center', marginBottom: 12, lineHeight: 17 },
  doneBtn: { backgroundColor: COLORS.primary, borderRadius: 10, paddingVertical: 14, alignItems: 'center' },
  doneBtnText: { color: '#fff', fontWeight: '700', fontSize: 15 },
});
