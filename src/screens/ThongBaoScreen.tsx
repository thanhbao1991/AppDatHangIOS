import { useCallback, useState } from 'react';
import { ActivityIndicator, FlatList, RefreshControl, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useFocusEffect, useNavigation } from '@react-navigation/native';
import { getThongBao, ThongBao } from '../api';
import { COLORS } from '../theme';

export const THONG_BAO_LAST_SEEN_KEY = 'thongBaoLastSeen';

export default function ThongBaoScreen() {
  const navigation = useNavigation<any>();
  const [items, setItems] = useState<ThongBao[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const result = await getThongBao();
      if (result.isSuccess && result.data) {
        setItems(result.data);
        if (result.data.length > 0) {
          // Đánh dấu đã xem = mốc thời gian tin mới nhất — MainTabs dùng mốc này để tính badge số
          // tin chưa đọc, so vào lần vào lại tab tiếp theo.
          await AsyncStorage.setItem(THONG_BAO_LAST_SEEN_KEY, result.data[0].ngayTao);
        }
      }
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
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
      data={items}
      keyExtractor={(i) => i.id}
      contentContainerStyle={{ padding: 16 }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      ListEmptyComponent={<Text style={styles.empty}>Chưa có thông báo nào.</Text>}
      renderItem={({ item }) => (
        <TouchableOpacity
          style={styles.card}
          activeOpacity={item.hoaDonId ? 0.7 : 1}
          onPress={() => {
            if (item.hoaDonId) navigation.navigate('DonHang');
          }}
        >
          <View style={[styles.iconWrap, item.loai === 'KhuyenMai' && styles.iconWrapPromo]}>
            <Text style={styles.iconText}>{item.loai === 'KhuyenMai' ? '🎁' : '📦'}</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.tieude}>{item.tieude}</Text>
            <Text style={styles.noiDung}>{item.noiDung}</Text>
            <Text style={styles.ngay}>{new Date(item.ngayTao).toLocaleString('vi-VN')}</Text>
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
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 12,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  iconWrap: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  iconWrapPromo: { backgroundColor: '#FFF3E0' },
  iconText: { fontSize: 18 },
  tieude: { fontSize: 14, fontWeight: '700', color: COLORS.text },
  noiDung: { fontSize: 13, color: COLORS.textMuted, marginTop: 2, lineHeight: 18 },
  ngay: { fontSize: 11, color: COLORS.textFaint, marginTop: 6 },
});
