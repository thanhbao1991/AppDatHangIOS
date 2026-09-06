import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import * as Crypto from 'expo-crypto';
import * as Location from 'expo-location';
import MapView, { Marker, Polyline, PROVIDER_DEFAULT } from 'react-native-maps';
import { datMon, DiaChiKhachHang, getDiaChiList, uocTinhShip, UocTinhShip } from '../api';
import { useCart } from '../CartContext';
import { COLORS } from '../theme';
import KeyboardAvoider from '../components/KeyboardAvoider';

type Coord = { lat: number; long: number };

export default function CheckoutScreen() {
  const navigation = useNavigation<any>();
  const { items, removeItem, setQuantity, clear, totalPrice } = useCart();
  const [ghiChu, setGhiChu] = useState('');
  const [diaChi, setDiaChi] = useState('');
  const [savedDiaChi, setSavedDiaChi] = useState<DiaChiKhachHang[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  // Mã chống tạo trùng cho ĐÚNG lần bấm "Đặt" này. Sinh ở lần bấm đầu và giữ nguyên qua mọi lần thử
  // lại (mất mạng, timeout 15s) để backend nhận ra là cùng một đơn. Chỉ xoá khi đặt thành công —
  // giỏ hàng lúc đó cũng đã clear, lần đặt sau là đơn mới thật nên phải sinh mã mới.
  const clientOrderIdRef = useRef<string | null>(null);

  // Vị trí giao hàng thật (GPS hoặc pin kéo trên map) — null nghĩa là chưa xác định được, đơn vẫn đặt
  // được nhưng không có phí ship tính theo khoảng cách (server bỏ qua, xem DatHangService).
  const [coord, setCoord] = useState<Coord | null>(null);
  const [locLoading, setLocLoading] = useState(false);
  const [locError, setLocError] = useState('');
  const [ship, setShip] = useState<UocTinhShip | null>(null);
  const mapRef = useRef<MapView>(null);

  useEffect(() => {
    (async () => {
      const result = await getDiaChiList();
      if (result.isSuccess && result.data) {
        setSavedDiaChi(result.data);
        const macDinh = result.data.find((d) => d.isDefault);
        if (macDinh) {
          setDiaChi(macDinh.diaChi);
          if (macDinh.lat != null && macDinh.long != null) {
            applyCoord({ lat: macDinh.lat, long: macDinh.long });
          }
        }
      }
    })();
  }, []);

  const applyCoord = async (c: Coord) => {
    setCoord(c);
    setShip(null);
    const result = await uocTinhShip(c.lat, c.long);
    if (result.isSuccess && result.data) setShip(result.data);
    const routePoints = result.data?.tuyenDuong?.map((p) => ({ latitude: p.lat, longitude: p.long })) ?? [];
    mapRef.current?.fitToCoordinates(
      routePoints.length > 0
        ? routePoints
        : [
            { latitude: c.lat, longitude: c.long },
            { latitude: result.data?.shopLat ?? c.lat, longitude: result.data?.shopLong ?? c.long },
          ],
      { edgePadding: { top: 40, right: 40, bottom: 40, left: 40 }, animated: true },
    );
  };

  const dungViTriHienTai = async () => {
    setLocError('');
    setLocLoading(true);
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== Location.PermissionStatus.GRANTED) {
        setLocError('Bạn cần cho phép truy cập vị trí để tính phí ship.');
        return;
      }
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
      const c = { lat: pos.coords.latitude, long: pos.coords.longitude };
      await applyCoord(c);

      const places = await Location.reverseGeocodeAsync({ latitude: c.lat, longitude: c.long });
      if (places.length > 0) {
        const p = places[0];
        const raw = [p.streetNumber, p.street, p.subregion ?? p.district, p.city ?? p.region].filter(Boolean) as string[];
        // Vùng nông thôn đôi khi subregion/city trùng nhau (vd "X. Krông Pắc" x2) do geocoder không có
        // dữ liệu đường/số nhà chi tiết — loại trùng liên tiếp thay vì hiện lặp lại gây khó hiểu.
        const parts = raw.filter((v, i) => v !== raw[i - 1]);
        if (parts.length > 0) setDiaChi(parts.join(', '));
      }
    } catch {
      setLocError('Không lấy được vị trí. Bạn có thể kéo ghim trên bản đồ hoặc nhập địa chỉ tay.');
    } finally {
      setLocLoading(false);
    }
  };

  const handleDatHang = async () => {
    if (items.length === 0) return;
    if (!diaChi.trim()) {
      setError('Vui lòng nhập địa chỉ giao hàng.');
      return;
    }
    setLoading(true);
    setError('');
    if (!clientOrderIdRef.current) clientOrderIdRef.current = Crypto.randomUUID();
    try {
      const result = await datMon(
        items.map((i) => ({
          sanPhamBienTheId: i.sanPhamBienTheId,
          soLuong: i.soLuong,
          ghiChu: i.ghiChu,
          toppingIds: i.toppings.map((t) => t.id),
        })),
        diaChi.trim(),
        ghiChu || undefined,
        undefined,
        coord?.lat,
        coord?.long,
        clientOrderIdRef.current,
      );
      if (result.isSuccess && result.data) {
        clientOrderIdRef.current = null;
        clear();
        navigation.navigate('ThanhToan', { hoaDonId: result.data.id });
      } else {
        setError(result.message || 'Đặt hàng thất bại.');
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <KeyboardAvoider>
      <FlatList
        data={items}
        keyExtractor={(i) => i.key}
        contentContainerStyle={{ padding: 16 }}
        ListEmptyComponent={<Text style={styles.empty}>Giỏ hàng trống.</Text>}
        ListHeaderComponent={
          items.length > 0 ? (
            <View style={styles.addressBox}>
              <Text style={styles.addressLabel}>Giao đến</Text>
              <TextInput
                style={styles.addressInput}
                placeholder="Nhập địa chỉ giao hàng..."
                placeholderTextColor={COLORS.textFaint}
                value={diaChi}
                onChangeText={setDiaChi}
                multiline
              />
              {savedDiaChi.length > 0 && (
                <View style={styles.addressChipRow}>
                  {savedDiaChi.map((d) => (
                    <TouchableOpacity
                      key={d.id}
                      style={[styles.addressChip, diaChi === d.diaChi && styles.addressChipActive]}
                      onPress={() => {
                        setDiaChi(d.diaChi);
                        if (d.lat != null && d.long != null) applyCoord({ lat: d.lat, long: d.long });
                      }}
                    >
                      <Text
                        style={[styles.addressChipText, diaChi === d.diaChi && styles.addressChipTextActive]}
                        numberOfLines={1}
                      >
                        {d.isDefault ? '★ ' : ''}
                        {d.diaChi}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              )}

              <TouchableOpacity style={styles.gpsBtn} onPress={dungViTriHienTai} disabled={locLoading}>
                {locLoading ? (
                  <ActivityIndicator size="small" color={COLORS.primary} />
                ) : (
                  <Text style={styles.gpsBtnText}>📍 Dùng vị trí hiện tại (tính phí ship chính xác)</Text>
                )}
              </TouchableOpacity>
              {locError ? <Text style={styles.locError}>{locError}</Text> : null}

              {coord && ship && (
                <>
                  <MapView
                    ref={mapRef}
                    provider={PROVIDER_DEFAULT}
                    style={styles.map}
                    initialRegion={{
                      latitude: coord.lat,
                      longitude: coord.long,
                      latitudeDelta: 0.05,
                      longitudeDelta: 0.05,
                    }}
                  >
                    <Marker coordinate={{ latitude: ship.shopLat, longitude: ship.shopLong }} title="Đenn Coffee" pinColor={COLORS.primary} />
                    <Marker
                      coordinate={{ latitude: coord.lat, longitude: coord.long }}
                      title="Giao đến đây"
                      draggable
                      onDragEnd={(e) => applyCoord({ lat: e.nativeEvent.coordinate.latitude, long: e.nativeEvent.coordinate.longitude })}
                    />
                    <Polyline
                      coordinates={
                        ship.tuyenDuong && ship.tuyenDuong.length > 0
                          ? ship.tuyenDuong.map((p) => ({ latitude: p.lat, longitude: p.long }))
                          : [
                              { latitude: ship.shopLat, longitude: ship.shopLong },
                              { latitude: coord.lat, longitude: coord.long },
                            ]
                      }
                      strokeColor={COLORS.primary}
                      strokeWidth={3}
                      lineDashPattern={ship.tuyenDuong && ship.tuyenDuong.length > 0 ? undefined : [6, 4]}
                    />
                  </MapView>
                  <Text style={styles.mapHint}>
                    {ship.tuyenDuong && ship.tuyenDuong.length > 0
                      ? 'Tuyến đường thực tế — kéo ghim để chỉnh đúng vị trí giao hàng'
                      : 'Đường ước tính (đường chim bay) — kéo ghim để chỉnh đúng vị trí giao hàng'}
                  </Text>
                  <View style={styles.shipRow}>
                    <Text style={styles.shipText}>Khoảng cách ~{ship.khoangCachKm.toFixed(1)}km</Text>
                    <Text style={styles.shipFee}>Phí ship: {ship.phiShip.toLocaleString('vi-VN')}đ</Text>
                  </View>
                </>
              )}
            </View>
          ) : null
        }
        renderItem={({ item }) => (
          <View style={styles.itemRow}>
            <View style={{ flex: 1 }}>
              <Text style={styles.itemName}>
                {item.tenSanPham} ({item.tenBienThe})
              </Text>
              {item.toppings.length > 0 && (
                <Text style={styles.itemTopping}>+ {item.toppings.map((t) => t.ten).join(', ')}</Text>
              )}
              <View style={styles.qtyRow}>
                <TouchableOpacity
                  style={styles.qtyBtn}
                  onPress={() => setQuantity(item.key, item.soLuong - 1)}
                >
                  <Text style={styles.qtyBtnText}>-</Text>
                </TouchableOpacity>
                <Text style={styles.qtyValue}>{item.soLuong}</Text>
                <TouchableOpacity
                  style={styles.qtyBtn}
                  onPress={() => setQuantity(item.key, item.soLuong + 1)}
                >
                  <Text style={styles.qtyBtnText}>+</Text>
                </TouchableOpacity>
              </View>
            </View>
            <Text style={styles.itemPrice}>
              {(item.soLuong * (item.giaBan + item.toppings.reduce((s, t) => s + t.gia, 0))).toLocaleString('vi-VN')}đ
            </Text>
            <TouchableOpacity onPress={() => removeItem(item.key)} style={styles.removeBtn}>
              <Text style={styles.removeText}>✕</Text>
            </TouchableOpacity>
          </View>
        )}
      />

      {items.length > 0 && (
        <View style={styles.footer}>
          <TextInput
            style={styles.noteInput}
            placeholder="Ghi chú cho đơn hàng (không bắt buộc)"
            value={ghiChu}
            onChangeText={setGhiChu}
          />
          <Text style={styles.total}>
            Tạm tính: {(totalPrice + (ship?.phiShip ?? 0)).toLocaleString('vi-VN')}đ
            {ship ? ` (gồm ${ship.phiShip.toLocaleString('vi-VN')}đ phí ship)` : ''}
          </Text>
          {error ? <Text style={styles.error}>{error}</Text> : null}
          <TouchableOpacity style={styles.orderBtn} onPress={handleDatHang} disabled={loading}>
            {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.orderBtnText}>Đặt hàng</Text>}
          </TouchableOpacity>
        </View>
      )}
    </KeyboardAvoider>
  );
}

const styles = StyleSheet.create({
  empty: { textAlign: 'center', color: COLORS.textFaint, marginTop: 40 },
  addressBox: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 12,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  addressLabel: { fontSize: 13, fontWeight: '700', color: COLORS.primary, marginBottom: 6 },
  addressInput: {
    fontSize: 14,
    color: COLORS.text,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    padding: 10,
    minHeight: 40,
  },
  addressChipRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginTop: 8 },
  addressChip: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 14,
    paddingHorizontal: 10,
    paddingVertical: 5,
    maxWidth: 220,
  },
  addressChipActive: { backgroundColor: COLORS.primaryTint, borderColor: COLORS.primary },
  addressChipText: { fontSize: 12, color: COLORS.textMuted },
  addressChipTextActive: { color: COLORS.primary, fontWeight: '600' },
  gpsBtn: {
    marginTop: 10,
    borderWidth: 1,
    borderColor: COLORS.primary,
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: 'center',
  },
  gpsBtnText: { color: COLORS.primary, fontWeight: '600', fontSize: 13 },
  locError: { color: COLORS.danger, fontSize: 12, marginTop: 6 },
  map: { height: 180, borderRadius: 8, marginTop: 10 },
  mapHint: { fontSize: 11, color: COLORS.textFaint, marginTop: 4, textAlign: 'center' },
  shipRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 },
  shipText: { fontSize: 13, color: COLORS.textMuted },
  shipFee: { fontSize: 13, fontWeight: '700', color: COLORS.primary },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.divider,
  },
  itemName: { fontSize: 15, fontWeight: '600', color: COLORS.text },
  itemTopping: { fontSize: 13, color: COLORS.textMuted, marginTop: 2 },
  qtyRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 6 },
  qtyBtn: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
  },
  qtyBtnText: { fontSize: 16, fontWeight: '700', color: COLORS.primary },
  qtyValue: { fontSize: 14, fontWeight: '700', minWidth: 20, textAlign: 'center' },
  itemPrice: { fontSize: 14, color: COLORS.text, marginRight: 8 },
  removeBtn: { padding: 6 },
  removeText: { color: COLORS.danger, fontSize: 16 },
  footer: {
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: COLORS.divider,
    backgroundColor: '#fff',
  },
  noteInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 12,
  },
  total: { fontSize: 16, fontWeight: '700', color: COLORS.text, marginBottom: 12 },
  error: { color: COLORS.danger, marginBottom: 8 },
  orderBtn: { backgroundColor: COLORS.primary, borderRadius: 8, paddingVertical: 14, alignItems: 'center' },
  orderBtnText: { color: '#fff', fontWeight: '700', fontSize: 16 },
});
