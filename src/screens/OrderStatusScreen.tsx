import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, RefreshControl, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import { DonHangKhach, getDonCuaToi } from '../api';
import { COLORS } from '../theme';

const TRANG_THAI_LABEL: Record<DonHangKhach['trangThai'], string> = {
  ChoXacNhan: 'Chờ quán xác nhận',
  DaXacNhan: 'Quán đã nhận, đang chuẩn bị',
  DangGiao: 'Đang giao',
  HoanTat: 'Hoàn tất',
};

const TRANG_THAI_COLOR: Record<DonHangKhach['trangThai'], string> = {
  ChoXacNhan: COLORS.warning,
  DaXacNhan: COLORS.primary,
  DangGiao: '#1976D2',
  HoanTat: COLORS.success,
};

// Poll mỗi 10s khi màn hình đang mở — bản đầu chưa cần SignalR/push (xem plan).
const POLL_INTERVAL_MS = 10_000;

export default function OrderStatusScreen() {
  const navigation = useNavigation<any>();
  const [orders, setOrders] = useState<DonHangKhach[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const load = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const result = await getDonCuaToi();
      if (result.isSuccess && result.data) setOrders(result.data);
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
      intervalRef.current = setInterval(() => load(true), POLL_INTERVAL_MS);
      return () => {
        if (intervalRef.current) clearInterval(intervalRef.current);
      };
    }, [load]),
  );

  const onRefresh = async () => {
    setRefreshing(true);
    await load(true);
    setRefreshing(false);
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={COLORS.primary} size="large" />
      </View>
    );
  }

  return (
    <FlatList
      data={orders}
      keyExtractor={(o) => o.id}
      contentContainerStyle={{ padding: 16 }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      ListEmptyComponent={<Text style={styles.empty}>Chưa có đơn hàng nào.</Text>}
      renderItem={({ item }) => (
        <TouchableOpacity
          style={styles.card}
          activeOpacity={0.7}
          onPress={() => navigation.navigate('DonHangChiTiet', { order: item })}
        >
          <View style={styles.cardHeader}>
            <Text style={styles.maHoaDon}>{item.maHoaDon}</Text>
            <Text style={styles.ngay}>{new Date(item.ngayGio).toLocaleString('vi-VN')}</Text>
          </View>
          <Text style={styles.monSummary}>{item.tenMonSummary}</Text>
          <View style={styles.cardFooter}>
            <Text style={styles.thanhTien}>{item.thanhTien.toLocaleString('vi-VN')}đ</Text>
            <View style={[styles.statusChip, { backgroundColor: TRANG_THAI_COLOR[item.trangThai] }]}>
              <Text style={styles.statusText}>{TRANG_THAI_LABEL[item.trangThai]}</Text>
            </View>
          </View>
        </TouchableOpacity>
      )}
    />
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  empty: { textAlign: 'center', color: COLORS.textFaint, marginTop: 40 },
  card: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 14,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  maHoaDon: { fontWeight: '700', color: COLORS.text },
  ngay: { fontSize: 12, color: COLORS.textFaint },
  monSummary: { fontSize: 14, color: COLORS.textMuted, marginBottom: 10 },
  cardFooter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  thanhTien: { fontSize: 16, fontWeight: '700', color: COLORS.text },
  statusChip: { borderRadius: 12, paddingHorizontal: 10, paddingVertical: 4 },
  statusText: { color: '#fff', fontSize: 12, fontWeight: '600' },
});
