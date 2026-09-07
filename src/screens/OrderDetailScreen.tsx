import { useCallback, useState } from 'react';
import { ActivityIndicator, Alert, Image, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { useFocusEffect, useNavigation, useRoute } from '@react-navigation/native';
import { danhGiaDon, DonHangKhach, getDonCuaToi, huyDon } from '../api';
import { useCart } from '../CartContext';
import { COLORS } from '../theme';

const TRANG_THAI_LABEL: Record<DonHangKhach['trangThai'], string> = {
  ChoXacNhan: 'Chờ quán xác nhận',
  DaXacNhan: 'Quán đã nhận, đang chuẩn bị',
  DangGiao: 'Đang giao',
  HoanTat: 'Hoàn tất',
};

// Thứ tự cố định để vẽ timeline — trạng thái thực tế có thể "nhảy cóc" (vd thanh toán ngay khi giao)
// nên so sánh theo index thay vì đúng khớp từng bước.
const STEPS: DonHangKhach['trangThai'][] = ['ChoXacNhan', 'DaXacNhan', 'DangGiao', 'HoanTat'];

export default function OrderDetailScreen() {
  const navigation = useNavigation<any>();
  const route = useRoute<any>();
  // Đơn được truyền sang từ danh sách để vẽ được ngay (không chớp màn hình trắng), NHƯNG nó là ảnh
  // chụp lúc rời danh sách — quán có thể đã xác nhận/giao xong trong lúc đó. Nên vẫn tải lại khi màn
  // hình được focus và thay bằng bản mới, thay vì tin mãi vào params.
  const [order, setOrder] = useState<DonHangKhach>(route.params.order);
  const currentStep = STEPS.indexOf(order.trangThai);
  const { addItem, clear } = useCart();

  const [daDanhGia, setDaDanhGia] = useState(order.daDanhGia);
  const [soSaoDaDanh, setSoSaoDaDanh] = useState(order.soSaoDaDanh ?? 0);
  const [pickSao, setPickSao] = useState(0);
  const [nhanXet, setNhanXet] = useState('');
  const [dangGui, setDangGui] = useState(false);
  const [dangHuy, setDangHuy] = useState(false);

  useFocusEffect(
    useCallback(() => {
      let huy = false;
      (async () => {
        const res = await getDonCuaToi();
        if (huy || !res.isSuccess || !res.data) return;

        const moi = res.data.find(d => d.id === order.id);
        if (!moi) return;

        setOrder(moi);
        // Đánh giá chỉ đi một chiều (đã đánh giá thì không gỡ được), nên chỉ đồng bộ theo hướng
        // "server nói đã đánh giá" — tránh ghi đè mất đánh giá khách vừa gửi ở phiên này.
        if (moi.daDanhGia) {
          setDaDanhGia(true);
          setSoSaoDaDanh(moi.soSaoDaDanh ?? 0);
        }
      })();
      return () => {
        huy = true;
      };
    }, [order.id])
  );

  const handleHuyDon = () => {
    Alert.alert('Huỷ đơn này?', `Đơn ${order.maHoaDon} sẽ bị huỷ, không thể hoàn tác.`, [
      { text: 'Không', style: 'cancel' },
      {
        text: 'Huỷ đơn',
        style: 'destructive',
        onPress: async () => {
          setDangHuy(true);
          try {
            const res = await huyDon(order.id);
            if (res.isSuccess) {
              navigation.goBack();
            } else {
              Alert.alert('Không huỷ được', res.message);
            }
          } finally {
            setDangHuy(false);
          }
        },
      },
    ]);
  };

  const handleDatLai = () => {
    // Sơ khai: dùng giá LÚC ĐẶT LẦN TRƯỚC để ước tính giỏ hàng — server vẫn luôn ép giá theo
    // catalog HIỆN TẠI khi thực sự đặt (xem DatHangService.DatMonAsync), nên số tiền cuối cùng có
    // thể khác nếu quán đã đổi giá — chấp nhận được cho tính năng "Đặt lại" nhanh.
    clear();
    for (const it of order.items) {
      addItem({
        sanPhamBienTheId: it.sanPhamBienTheId,
        tenSanPham: it.tenSanPham,
        tenBienThe: it.tenBienThe,
        giaBan: it.donGia,
        soLuong: it.soLuong,
        ghiChu: it.ghiChu ?? undefined,
        toppings: it.toppings.map((t) => ({ id: t.toppingId, ten: t.ten, gia: t.gia })),
      });
    }
    navigation.navigate('Home', { screen: 'Checkout' });
  };

  const handleGuiDanhGia = async () => {
    if (pickSao === 0) return;
    setDangGui(true);
    try {
      const res = await danhGiaDon(order.id, pickSao, nhanXet || undefined);
      if (res.isSuccess) {
        setDaDanhGia(true);
        setSoSaoDaDanh(pickSao);
      }
    } finally {
      setDangGui(false);
    }
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: COLORS.bg }} contentContainerStyle={{ padding: 16 }}>
      <View style={styles.card}>
        <View style={styles.headerRow}>
          <Text style={styles.maHoaDon}>{order.maHoaDon}</Text>
          <Text style={styles.ngay}>{new Date(order.ngayGio).toLocaleString('vi-VN')}</Text>
        </View>

        <View style={styles.timeline}>
          {STEPS.map((step, i) => (
            <View key={step} style={styles.timelineStep}>
              <View style={styles.timelineRow}>
                <View style={[styles.dot, i <= currentStep && styles.dotActive]} />
                {i < STEPS.length - 1 && <View style={[styles.line, i < currentStep && styles.lineActive]} />}
              </View>
              <Text style={[styles.stepLabel, i <= currentStep && styles.stepLabelActive]}>
                {TRANG_THAI_LABEL[step]}
              </Text>
            </View>
          ))}
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionTitle}>{order.phanLoai === 'Ship' ? 'Giao đến' : 'Hình thức'}</Text>
        {order.phanLoai === 'Ship' ? (
          <>
            <Text style={styles.infoText}>{order.diaChiText || '—'}</Text>
            {order.soDienThoaiText ? <Text style={styles.infoSub}>SĐT: {order.soDienThoaiText}</Text> : null}
          </>
        ) : (
          <Text style={styles.infoText}>
            {order.phanLoai === 'Mv' ? 'Mang về' : `Tại quán${order.tenBan ? ` — Bàn ${order.tenBan}` : ''}`}
          </Text>
        )}
        {order.ghiChu ? <Text style={styles.infoSub}>Ghi chú: {order.ghiChu}</Text> : null}
      </View>

      <View style={styles.card}>
        <Text style={styles.sectionTitle}>Món đã đặt</Text>
        {order.items.map((it, idx) => (
          <View key={idx} style={styles.itemRow}>
            {it.hinhAnh ? (
              <Image source={{ uri: it.hinhAnh }} style={styles.itemThumb} resizeMode="cover" />
            ) : (
              <View style={styles.itemThumbPlaceholder}>
                <Text style={styles.itemThumbPlaceholderText}>{it.tenSanPham.trim().charAt(0).toUpperCase()}</Text>
              </View>
            )}
            <View style={{ flex: 1 }}>
              <Text style={styles.itemName}>
                {it.soLuong} x {it.tenSanPham} ({it.tenBienThe})
              </Text>
              {it.toppings.length > 0 && (
                <Text style={styles.itemSub}>+ {it.toppings.map((t) => t.ten).join(', ')}</Text>
              )}
              {it.ghiChu ? <Text style={styles.itemSub}>Ghi chú: {it.ghiChu}</Text> : null}
            </View>
            <Text style={styles.itemPrice}>
              {(it.soLuong * (it.donGia + it.toppings.reduce((s, t) => s + t.gia, 0))).toLocaleString('vi-VN')}đ
            </Text>
          </View>
        ))}
        <View style={styles.totalRow}>
          <Text style={styles.totalLabel}>Tổng cộng</Text>
          <Text style={styles.totalValue}>{order.thanhTien.toLocaleString('vi-VN')}đ</Text>
        </View>
      </View>

      {order.trangThai !== 'HoanTat' && (
        <TouchableOpacity
          style={styles.thanhToanBtn}
          onPress={() => navigation.navigate('ThanhToan', { hoaDonId: order.id })}
        >
          <Text style={styles.thanhToanBtnText}>💳 Thanh toán</Text>
        </TouchableOpacity>
      )}

      {order.trangThai === 'ChoXacNhan' && (
        <TouchableOpacity style={styles.huyDonBtn} onPress={handleHuyDon} disabled={dangHuy}>
          {dangHuy ? <ActivityIndicator color={COLORS.danger} /> : <Text style={styles.huyDonBtnText}>Huỷ đơn</Text>}
        </TouchableOpacity>
      )}

      <TouchableOpacity style={styles.datLaiBtn} onPress={handleDatLai}>
        <Text style={styles.datLaiBtnText}>🔁 Đặt lại</Text>
      </TouchableOpacity>

      {order.trangThai === 'HoanTat' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Đánh giá</Text>
          {daDanhGia ? (
            <Text style={styles.infoText}>
              Bạn đã đánh giá {'⭐'.repeat(soSaoDaDanh)} — Cảm ơn bạn!
            </Text>
          ) : (
            <>
              <View style={styles.starRow}>
                {[1, 2, 3, 4, 5].map((n) => (
                  <TouchableOpacity key={n} onPress={() => setPickSao(n)}>
                    <Text style={styles.star}>{n <= pickSao ? '⭐' : '☆'}</Text>
                  </TouchableOpacity>
                ))}
              </View>
              <TextInput
                style={styles.nhanXetInput}
                placeholder="Nhận xét (không bắt buộc)"
                placeholderTextColor={COLORS.textFaint}
                value={nhanXet}
                onChangeText={setNhanXet}
              />
              <TouchableOpacity
                style={[styles.guiDanhGiaBtn, pickSao === 0 && { opacity: 0.5 }]}
                onPress={handleGuiDanhGia}
                disabled={pickSao === 0 || dangGui}
              >
                {dangGui ? <ActivityIndicator color="#fff" /> : <Text style={styles.guiDanhGiaBtnText}>Gửi đánh giá</Text>}
              </TouchableOpacity>
            </>
          )}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 16 },
  maHoaDon: { fontWeight: '700', fontSize: 16, color: COLORS.text },
  ngay: { fontSize: 12, color: COLORS.textFaint },
  timeline: { paddingLeft: 4 },
  timelineStep: { flexDirection: 'row', alignItems: 'flex-start' },
  timelineRow: { alignItems: 'center', width: 20 },
  dot: { width: 12, height: 12, borderRadius: 6, backgroundColor: COLORS.divider },
  dotActive: { backgroundColor: COLORS.primary },
  line: { width: 2, height: 28, backgroundColor: COLORS.divider },
  lineActive: { backgroundColor: COLORS.primary },
  stepLabel: { fontSize: 13, color: COLORS.textFaint, marginLeft: 10, marginTop: -2, marginBottom: 14 },
  stepLabelActive: { color: COLORS.text, fontWeight: '600' },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: COLORS.primary, marginBottom: 8 },
  infoText: { fontSize: 15, color: COLORS.text, lineHeight: 20 },
  infoSub: { fontSize: 13, color: COLORS.textMuted, marginTop: 4 },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.divider,
  },
  itemThumb: { width: 44, height: 44, borderRadius: 8, backgroundColor: COLORS.divider, marginRight: 10 },
  itemThumbPlaceholder: {
    width: 44,
    height: 44,
    borderRadius: 8,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  itemThumbPlaceholderText: { fontSize: 16, fontWeight: '700', color: COLORS.primary },
  itemName: { fontSize: 14, fontWeight: '600', color: COLORS.text },
  itemSub: { fontSize: 12, color: COLORS.textMuted, marginTop: 2 },
  itemPrice: { fontSize: 14, color: COLORS.text, marginLeft: 8 },
  totalRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 12 },
  totalLabel: { fontSize: 15, fontWeight: '700', color: COLORS.text },
  totalValue: { fontSize: 16, fontWeight: '700', color: COLORS.primary },
  thanhToanBtn: {
    backgroundColor: COLORS.primary,
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 12,
  },
  thanhToanBtnText: { color: '#fff', fontWeight: '700', fontSize: 15 },
  huyDonBtn: {
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.danger,
  },
  huyDonBtnText: { color: COLORS.danger, fontWeight: '700', fontSize: 15 },
  datLaiBtn: {
    backgroundColor: COLORS.primaryTint,
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: 'center',
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.primary,
  },
  datLaiBtnText: { color: COLORS.primary, fontWeight: '700', fontSize: 15 },
  starRow: { flexDirection: 'row', gap: 6, marginBottom: 12 },
  star: { fontSize: 28 },
  nhanXetInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 12,
    fontSize: 14,
  },
  guiDanhGiaBtn: { backgroundColor: COLORS.primary, borderRadius: 8, paddingVertical: 12, alignItems: 'center' },
  guiDanhGiaBtnText: { color: '#fff', fontWeight: '700' },
});
