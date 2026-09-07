import { useCallback, useState } from 'react';
import { ActivityIndicator, Alert, Platform, ScrollView, Share, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import DateTimePicker, { DateTimePickerEvent } from '@react-native-community/datetimepicker';
import * as Clipboard from 'expo-clipboard';
import { useFocusEffect } from '@react-navigation/native';
import {
  apDungMaGioiThieu,
  capNhatNgaySinh,
  doiTem,
  getGioiThieu,
  getSinhNhat,
  getTheTem,
  GioiThieuInfo,
  nhanQuaSinhNhat,
  quayVongQuay,
  SinhNhatInfo,
  TheTem,
} from '../api';
import { COLORS } from '../theme';

export default function UuDaiScreen() {
  const [theTem, setTheTem] = useState<TheTem | null>(null);
  const [gioiThieu, setGioiThieu] = useState<GioiThieuInfo | null>(null);
  const [sinhNhat, setSinhNhat] = useState<SinhNhatInfo | null>(null);
  const [loading, setLoading] = useState(true);

  const [maNhap, setMaNhap] = useState('');
  const [dangApDung, setDangApDung] = useState(false);
  // Native DateTimePicker (bánh xe chọn ngày của hệ điều hành) thay vì bắt gõ tay "dd/mm/yyyy" —
  // đỡ sai định dạng, không cần regex validate chuỗi nhập.
  const [dobDate, setDobDate] = useState(new Date(2000, 0, 1));
  const [dobChosen, setDobChosen] = useState(false);
  const [showDobPicker, setShowDobPicker] = useState(false);
  const [dangLuuSinhNhat, setDangLuuSinhNhat] = useState(false);
  const [dangDoiTem, setDangDoiTem] = useState(false);
  const [dangQuay, setDangQuay] = useState(false);
  const [ketQuaQuay, setKetQuaQuay] = useState<string | null>(null);

  const load = useCallback(async () => {
    const [temRes, gtRes, snRes] = await Promise.all([getTheTem(), getGioiThieu(), getSinhNhat()]);
    if (temRes.isSuccess && temRes.data) setTheTem(temRes.data);
    if (gtRes.isSuccess && gtRes.data) setGioiThieu(gtRes.data);
    if (snRes.isSuccess && snRes.data) setSinhNhat(snRes.data);
    setLoading(false);
  }, []);

  useFocusEffect(
    useCallback(() => {
      load();
    }, [load]),
  );

  const handleDoiTem = async () => {
    setDangDoiTem(true);
    try {
      const res = await doiTem();
      if (res.isSuccess && res.data) {
        setTheTem(res.data);
        Alert.alert('Thành công', 'Đã đổi thưởng! Báo nhân viên để nhận ly miễn phí.');
      } else {
        Alert.alert('Chưa đủ điều kiện', res.message);
      }
    } finally {
      setDangDoiTem(false);
    }
  };

  // "Chia sẻ mã dưới đây" trước chỉ hiện text tĩnh, không thao tác nào thật — dùng thẳng Share/
  // Clipboard có sẵn trong React Native/Expo (native share sheet + clipboard hệ thống) thay vì bắt
  // khách tự bôi đen chép tay.
  const handleCopyMaGioiThieu = async () => {
    if (!gioiThieu) return;
    await Clipboard.setStringAsync(gioiThieu.maGioiThieu);
    Alert.alert('Đã sao chép', `Mã ${gioiThieu.maGioiThieu} đã được chép vào clipboard.`);
  };

  const handleShareMaGioiThieu = async () => {
    if (!gioiThieu) return;
    try {
      await Share.share({
        message: `Đặt món qua app Đenn Coffee bằng mã giới thiệu của mình "${gioiThieu.maGioiThieu}" là cả hai đều nhận thưởng nhé!`,
      });
    } catch {
      // Người dùng huỷ share sheet — không cần báo lỗi.
    }
  };

  const handleApDungMa = async () => {
    if (!maNhap.trim()) return;
    setDangApDung(true);
    try {
      const res = await apDungMaGioiThieu(maNhap.trim());
      Alert.alert(res.isSuccess ? 'Thành công' : 'Không áp dụng được', res.message);
      if (res.isSuccess) {
        setMaNhap('');
        load();
      }
    } finally {
      setDangApDung(false);
    }
  };

  const handleLuuSinhNhat = async () => {
    if (!dobChosen) {
      Alert.alert('Chưa chọn ngày', 'Chọn ngày sinh trước khi lưu.');
      return;
    }
    setDangLuuSinhNhat(true);
    try {
      const res = await capNhatNgaySinh(dobDate.toISOString());
      if (res.isSuccess) {
        setDobChosen(false);
        load();
      } else {
        Alert.alert('Lỗi', res.message);
      }
    } finally {
      setDangLuuSinhNhat(false);
    }
  };

  const onChangeDob = (event: DateTimePickerEvent, selected?: Date) => {
    if (Platform.OS === 'android') setShowDobPicker(false);
    if (event.type === 'dismissed') return;
    if (selected) {
      setDobDate(selected);
      setDobChosen(true);
    }
  };

  const handleNhanQua = async () => {
    const res = await nhanQuaSinhNhat();
    Alert.alert(res.isSuccess ? '🎂 Chúc mừng!' : 'Chưa nhận được', res.message);
    if (res.isSuccess) load();
  };

  const handleQuay = async () => {
    setDangQuay(true);
    setKetQuaQuay(null);
    try {
      const res = await quayVongQuay();
      if (res.isSuccess && res.data) {
        setKetQuaQuay(res.data.label);
      } else {
        Alert.alert('Chưa quay được', res.message);
      }
    } finally {
      setDangQuay(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={COLORS.primary} size="large" />
      </View>
    );
  }

  return (
    <ScrollView style={{ flex: 1, backgroundColor: COLORS.bg }} contentContainerStyle={{ padding: 16 }}>
      {theTem && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>🧋 Thẻ sưu tập ly</Text>
          <Text style={styles.cardDesc}>
            Mua đủ {theTem.mocThuong} đơn được đổi 1 phần thưởng — báo nhân viên khi đủ điều kiện.
          </Text>
          <View style={styles.stampRow}>
            {Array.from({ length: theTem.mocThuong }).map((_, i) => (
              <Text key={i} style={styles.stamp}>
                {i < theTem.temHienTai ? '🧋' : '⚪'}
              </Text>
            ))}
          </View>
          <Text style={styles.stampProgress}>
            {theTem.temHienTai}/{theTem.mocThuong} — đã đổi {theTem.soLanDaDoiThuong} lần
          </Text>
          {theTem.duDieuKienDoiThuong && (
            <TouchableOpacity style={styles.primaryBtn} onPress={handleDoiTem} disabled={dangDoiTem}>
              {dangDoiTem ? <ActivityIndicator color="#fff" /> : <Text style={styles.primaryBtnText}>Đổi thưởng ngay</Text>}
            </TouchableOpacity>
          )}
        </View>
      )}

      {gioiThieu && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>👥 Giới thiệu bạn bè</Text>
          <Text style={styles.cardDesc}>Chia sẻ mã dưới đây — cả bạn và bạn bè đều nhận thưởng khi họ nhập mã.</Text>
          <View style={styles.maBox}>
            <Text style={styles.maText}>{gioiThieu.maGioiThieu}</Text>
            <TouchableOpacity onPress={handleCopyMaGioiThieu} hitSlop={8} style={styles.maIconBtn}>
              <Text style={styles.maIconBtnText}>📋</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={handleShareMaGioiThieu} hitSlop={8} style={styles.maIconBtn}>
              <Text style={styles.maIconBtnText}>↗️</Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.cardSub}>Đã giới thiệu {gioiThieu.soNguoiDaGioiThieu} người</Text>

          {!gioiThieu.daDuocGioiThieu && (
            <>
              <Text style={[styles.cardSub, { marginTop: 12 }]}>Được bạn bè giới thiệu? Nhập mã của họ:</Text>
              <View style={styles.applyRow}>
                <TextInput
                  style={styles.applyInput}
                  placeholder="Nhập mã giới thiệu"
                  placeholderTextColor={COLORS.textFaint}
                  value={maNhap}
                  onChangeText={(t) => setMaNhap(t.toUpperCase())}
                  autoCapitalize="characters"
                />
                <TouchableOpacity style={styles.applyBtn} onPress={handleApDungMa} disabled={dangApDung}>
                  {dangApDung ? <ActivityIndicator color="#fff" /> : <Text style={styles.applyBtnText}>Áp dụng</Text>}
                </TouchableOpacity>
              </View>
            </>
          )}
        </View>
      )}

      {sinhNhat && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>🎂 Sinh nhật</Text>
          {sinhNhat.ngaySinh ? (
            <>
              <Text style={styles.cardDesc}>
                Ngày sinh: {new Date(sinhNhat.ngaySinh).toLocaleDateString('vi-VN')}
              </Text>
              {sinhNhat.dangTrongThangSinhNhat && !sinhNhat.daNhanQuaNamNay && (
                <TouchableOpacity style={styles.primaryBtn} onPress={handleNhanQua}>
                  <Text style={styles.primaryBtnText}>🎁 Nhận quà sinh nhật</Text>
                </TouchableOpacity>
              )}
              {sinhNhat.daNhanQuaNamNay && <Text style={styles.cardSub}>Đã nhận quà năm nay rồi, hẹn năm sau nhé!</Text>}
            </>
          ) : (
            <>
              <Text style={styles.cardDesc}>Nhập ngày sinh để nhận quà mừng sinh nhật mỗi năm.</Text>
              <View style={styles.applyRow}>
                <TouchableOpacity style={styles.dobBtn} onPress={() => setShowDobPicker(true)}>
                  <Text style={dobChosen ? styles.dobBtnText : styles.dobBtnPlaceholder}>
                    {dobChosen ? dobDate.toLocaleDateString('vi-VN') : 'Chọn ngày sinh'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.applyBtn}
                  onPress={handleLuuSinhNhat}
                  disabled={dangLuuSinhNhat || !dobChosen}
                >
                  {dangLuuSinhNhat ? <ActivityIndicator color="#fff" /> : <Text style={styles.applyBtnText}>Lưu</Text>}
                </TouchableOpacity>
              </View>
              {showDobPicker && (
                <DateTimePicker
                  value={dobDate}
                  mode="date"
                  display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                  maximumDate={new Date()}
                  onChange={onChangeDob}
                />
              )}
              {Platform.OS === 'ios' && showDobPicker && (
                <TouchableOpacity style={styles.dobDoneBtn} onPress={() => setShowDobPicker(false)}>
                  <Text style={styles.dobDoneBtnText}>Xong</Text>
                </TouchableOpacity>
              )}
            </>
          )}
        </View>
      )}

      <View style={styles.card}>
        <Text style={styles.cardTitle}>🎡 Vòng quay may mắn</Text>
        <Text style={styles.cardDesc}>Mỗi ngày 1 lượt quay miễn phí — thử vận may nhận thưởng vào ví!</Text>
        {ketQuaQuay && <Text style={styles.ketQuaQuay}>{ketQuaQuay}</Text>}
        <TouchableOpacity style={styles.primaryBtn} onPress={handleQuay} disabled={dangQuay}>
          {dangQuay ? <ActivityIndicator color="#fff" /> : <Text style={styles.primaryBtnText}>Quay ngay 🎲</Text>}
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: COLORS.divider,
  },
  cardTitle: { fontSize: 16, fontWeight: '700', color: COLORS.text, marginBottom: 6 },
  cardDesc: { fontSize: 13, color: COLORS.textMuted, lineHeight: 18, marginBottom: 10 },
  cardSub: { fontSize: 12, color: COLORS.textFaint },
  stampRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 4, marginBottom: 8 },
  stamp: { fontSize: 22 },
  stampProgress: { fontSize: 12, color: COLORS.textMuted, marginBottom: 10 },
  maBox: {
    flexDirection: 'row',
    backgroundColor: COLORS.primaryTint,
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 16,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    marginBottom: 8,
  },
  maText: { fontSize: 22, fontWeight: '700', color: COLORS.primary, letterSpacing: 4 },
  maIconBtn: { padding: 4 },
  maIconBtnText: { fontSize: 18 },
  applyRow: { flexDirection: 'row', gap: 8, marginTop: 8 },
  applyInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 14,
  },
  applyBtn: { backgroundColor: COLORS.primary, borderRadius: 8, paddingHorizontal: 18, justifyContent: 'center' },
  applyBtnText: { color: '#fff', fontWeight: '700' },
  dobBtn: {
    flex: 1,
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    paddingHorizontal: 12,
    justifyContent: 'center',
  },
  dobBtnText: { fontSize: 14, color: COLORS.text },
  dobBtnPlaceholder: { fontSize: 14, color: COLORS.textFaint },
  dobDoneBtn: { alignSelf: 'flex-end', paddingVertical: 8, paddingHorizontal: 4 },
  dobDoneBtnText: { color: COLORS.primary, fontWeight: '700' },
  primaryBtn: { backgroundColor: COLORS.primary, borderRadius: 8, paddingVertical: 12, alignItems: 'center', marginTop: 4 },
  primaryBtnText: { color: '#fff', fontWeight: '700' },
  ketQuaQuay: { fontSize: 16, fontWeight: '700', color: COLORS.primary, textAlign: 'center', marginBottom: 10 },
});
