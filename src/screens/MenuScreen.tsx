import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Modal,
  RefreshControl,
  SectionList,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { getNhomSanPhamList, getSanPhamList, getToppingList, NhomSanPham, SanPham, SanPhamBienThe, Topping } from '../api';
import { useCart } from '../CartContext';
import { COLORS } from '../theme';

// Bỏ dấu tiếng Việt để tìm không cần gõ đúng dấu (vd "tra sua" vẫn khớp "Trà Sữa") — menu hơn
// 200 món, cuộn tay tìm không khả thi.
function normalizeVN(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/gi, 'd')
    .toLowerCase()
    .trim();
}

export default function MenuScreen() {
  const navigation = useNavigation<any>();
  const { addItem, totalCount, totalPrice } = useCart();

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [sanPhams, setSanPhams] = useState<SanPham[]>([]);
  const [nhoms, setNhoms] = useState<NhomSanPham[]>([]);
  const [toppings, setToppings] = useState<Topping[]>([]);
  const [query, setQuery] = useState('');

  const [picking, setPicking] = useState<SanPham | null>(null);
  const [pickBienThe, setPickBienThe] = useState<SanPhamBienThe | null>(null);
  const [pickToppingIds, setPickToppingIds] = useState<string[]>([]);
  const [pickSoLuong, setPickSoLuong] = useState(1);
  const [pickGhiChu, setPickGhiChu] = useState('');
  // 'note' | 'topping' — học theo màn "Thêm món" của AppQuanLyIOS (ProductPickerPanel): 2 tab thay
  // vì xếp chồng, đỡ cuộn dài khi topping nhiều. Tab Ghi chú trước vì món nào cũng có thể cần chỉnh
  // đường/đá, topping chỉ áp dụng một số món.
  const [pickTab, setPickTab] = useState<'note' | 'topping'>('note');

  const load = async (silent = false) => {
    if (!silent) setLoading(true);
    setError('');
    try {
      const [spRes, nhomRes, topRes] = await Promise.all([getSanPhamList(), getNhomSanPhamList(), getToppingList()]);
      if (spRes.isSuccess && spRes.data)
        setSanPhams(spRes.data.filter((s) => !s.ngungBan && s.storeFoodId != null));
      if (nhomRes.isSuccess && nhomRes.data) setNhoms(nhomRes.data);
      if (topRes.isSuccess && topRes.data) setToppings(topRes.data.filter((t) => !t.ngungBan));
      if (!spRes.isSuccess) setError(spRes.message || 'Không tải được menu.');
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await load(true);
    setRefreshing(false);
  };

  useEffect(() => {
    load();
  }, []);

  const filteredSanPhams = useMemo(() => {
    const q = normalizeVN(query);
    if (!q) return sanPhams;
    // So với timKiem (đã chuẩn hoá + gồm cả viết tắt/tên đầy đủ sẵn từ server) thay vì chỉ so
    // `ten` — mới khớp được kiểu gõ tắt (vd "cf") lẫn gõ đầy đủ (vd "cà phê") cho cùng 1 món.
    return sanPhams.filter((sp) => (sp.timKiem || normalizeVN(sp.ten)).includes(q));
  }, [sanPhams, query]);

  const sections = useMemo(() => {
    const byNhom = new Map<string, SanPham[]>();
    for (const sp of filteredSanPhams) {
      const key = sp.nhomSanPhamId ?? '';
      if (!byNhom.has(key)) byNhom.set(key, []);
      byNhom.get(key)!.push(sp);
    }
    return nhoms
      .filter((n) => byNhom.has(n.id))
      .sort((a, b) => a.ten.localeCompare(b.ten, 'vi'))
      .map((n) => ({ title: n.ten, data: byNhom.get(n.id)! }))
      .concat(
        byNhom.has('') ? [{ title: 'Khác', data: byNhom.get('')! }] : [],
      );
  }, [filteredSanPhams, nhoms]);

  // Gợi ý upsell "+Xđ lên size lớn hơn" — size kế tiếp rẻ nhất trong các size còn đắt hơn size
  // đang chọn, thuần hiển thị (không gọi API), chỉ nhằm gợi ý khách nâng cấp ngay lúc chọn món.
  const upsellSize = useMemo(() => {
    if (!picking || !pickBienThe) return null;
    const dat = picking.bienThe
      .filter((b) => b.giaBan > pickBienThe.giaBan)
      .sort((a, b) => a.giaBan - b.giaBan)[0];
    if (!dat) return null;
    return { bienThe: dat, chenhLech: dat.giaBan - pickBienThe.giaBan };
  }, [picking, pickBienThe]);

  const openPicker = (sp: SanPham) => {
    setPicking(sp);
    setPickBienThe(sp.bienThe.find((b) => b.macDinh) ?? sp.bienThe[0] ?? null);
    setPickToppingIds([]);
    setPickSoLuong(1);
    setPickGhiChu('');
    setPickTab('note');
  };

  const confirmAdd = () => {
    if (!picking || !pickBienThe) return;
    const chosenToppings = toppings.filter((t) => pickToppingIds.includes(t.id));
    addItem({
      sanPhamBienTheId: pickBienThe.id,
      tenSanPham: picking.ten,
      tenBienThe: pickBienThe.tenBienThe,
      giaBan: pickBienThe.giaBan,
      soLuong: pickSoLuong,
      ghiChu: pickGhiChu.trim() || undefined,
      toppings: chosenToppings.map((t) => ({ id: t.id, ten: t.ten, gia: t.gia })),
    });
    setPicking(null);
  };

  const toggleTopping = (id: string) => {
    setPickToppingIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  // Nhóm ghi chú nhanh — khớp quickNoteGroups của ProductPickerPanel (AppQuanLyIOS) để nhân viên
  // và khách nhìn thấy đúng các lựa chọn quen thuộc.
  const quickNoteGroups: { title: string; notes: string[] }[] = [
    { title: 'Đường', notes: ['Không đường', 'Ít ngọt', 'Ngọt', 'Nhiều ngọt', 'Đường riêng'] },
    { title: 'Đá', notes: ['Không đá', 'Ít đá', 'Vừa đá', 'Nhiều đá', 'Đá riêng'] },
    { title: 'Trà', notes: ['Không trà', 'Trà nóng', 'Trà đá'] },
  ];

  const activeNotes = useMemo(
    () => new Set(pickGhiChu.split(',').map((s) => s.trim()).filter(Boolean)),
    [pickGhiChu],
  );

  const toggleNote = (note: string) => {
    const notes = pickGhiChu.split(',').map((s) => s.trim()).filter(Boolean);
    const idx = notes.indexOf(note);
    if (idx >= 0) notes.splice(idx, 1);
    else notes.push(note);
    setPickGhiChu(notes.join(', '));
  };

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={COLORS.primary} size="large" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>{error}</Text>
        <TouchableOpacity style={styles.retryBtn} onPress={() => load()}>
          <Text style={styles.retryText}>Thử lại</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: COLORS.bg }}>
      <View style={styles.searchBar}>
        <Text style={styles.searchIcon}>⌕</Text>
        <TextInput
          style={styles.searchInput}
          placeholder="Tìm món..."
          placeholderTextColor={COLORS.textFaint}
          value={query}
          onChangeText={setQuery}
          autoCorrect={false}
          returnKeyType="search"
          clearButtonMode="while-editing"
        />
      </View>

      <TouchableOpacity
        style={styles.lyBiMatBanner}
        activeOpacity={0.85}
        onPress={() => navigation.navigate('LyBiMat')}
      >
        <Text style={styles.lyBiMatEmoji}>🎁</Text>
        <View style={{ flex: 1 }}>
          <Text style={styles.lyBiMatTitle}>Ly Bí Mật — chỉ 25.000đ</Text>
          <Text style={styles.lyBiMatDesc}>Bốc ngẫu nhiên 1 món, có thể trúng món giá cao hơn nhiều!</Text>
        </View>
        <Text style={styles.lyBiMatArrow}>›</Text>
      </TouchableOpacity>

      {sections.length === 0 ? (
        <View style={styles.center}>
          <Text style={{ color: COLORS.textMuted }}>Không tìm thấy món nào.</Text>
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.id}
          stickySectionHeadersEnabled
          keyboardShouldPersistTaps="handled"
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} colors={[COLORS.primary]} />}
          renderSectionHeader={({ section }) => (
            <View style={styles.sectionHeaderWrap}>
              <View style={styles.sectionHeaderAccent} />
              <Text style={styles.sectionHeader}>{section.title}</Text>
            </View>
          )}
          renderItem={({ item }) => {
          const prices = item.bienThe.map((b) => b.giaBan);
          const minPrice = prices.length > 0 ? Math.min(...prices) : null;
          const priceLabel =
            minPrice === null
              ? ''
              : prices.length > 1
              ? `Từ ${minPrice.toLocaleString('vi-VN')}đ`
              : `${minPrice.toLocaleString('vi-VN')}đ`;
          return (
            <TouchableOpacity style={styles.productCard} activeOpacity={0.7} onPress={() => openPicker(item)}>
              {item.hinhAnh ? (
                <Image source={{ uri: item.hinhAnh }} style={styles.thumb} resizeMode="cover" />
              ) : (
                <View style={styles.thumbPlaceholder}>
                  <Text style={styles.thumbPlaceholderText}>{item.ten.trim().charAt(0).toUpperCase()}</Text>
                </View>
              )}
              <View style={styles.productInfo}>
                <Text style={styles.productName} numberOfLines={2}>
                  {item.ten}
                </Text>
                <Text style={styles.productPrice}>{priceLabel}</Text>
              </View>
              <View style={styles.addBtn}>
                <Text style={styles.addBtnText}>+</Text>
              </View>
            </TouchableOpacity>
          );
        }}
          contentContainerStyle={{ paddingBottom: totalCount > 0 ? 92 : 16 }}
        />
      )}

      {totalCount > 0 && (
        <TouchableOpacity style={styles.cartBar} activeOpacity={0.85} onPress={() => navigation.navigate('Checkout')}>
          <View style={styles.cartBarBadge}>
            <Text style={styles.cartBarBadgeText}>{totalCount}</Text>
          </View>
          <Text style={styles.cartBarText}>Xem giỏ hàng</Text>
          <Text style={styles.cartBarPrice}>{totalPrice.toLocaleString('vi-VN')}đ</Text>
        </TouchableOpacity>
      )}

      <Modal visible={!!picking} transparent animationType="slide" onRequestClose={() => setPicking(null)}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <View style={styles.modalHandle} />
            <View style={styles.modalHeaderRow}>
              {picking?.hinhAnh ? (
                <Image source={{ uri: picking.hinhAnh }} style={styles.modalThumb} resizeMode="cover" />
              ) : (
                <View style={styles.modalThumbPlaceholder}>
                  <Text style={styles.thumbPlaceholderText}>{picking?.ten.trim().charAt(0).toUpperCase()}</Text>
                </View>
              )}
              <Text style={styles.modalTitle} numberOfLines={2}>
                {picking?.ten}
              </Text>
            </View>

            <Text style={styles.modalLabel}>Chọn size</Text>
            <View style={styles.optionRow}>
              {picking?.bienThe.map((b) => (
                <TouchableOpacity
                  key={b.id}
                  style={[styles.optionChip, pickBienThe?.id === b.id && styles.optionChipActive]}
                  onPress={() => setPickBienThe(b)}
                >
                  <Text style={[styles.optionChipText, pickBienThe?.id === b.id && styles.optionChipTextActive]}>
                    {b.tenBienThe} — {b.giaBan.toLocaleString('vi-VN')}đ
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
            {upsellSize && (
              <TouchableOpacity onPress={() => setPickBienThe(upsellSize.bienThe)}>
                <Text style={styles.upsellHint}>
                  💡 Chỉ +{upsellSize.chenhLech.toLocaleString('vi-VN')}đ để lên {upsellSize.bienThe.tenBienThe}
                </Text>
              </TouchableOpacity>
            )}

            {toppings.length > 0 && (
              <View style={styles.tabRow}>
                <TouchableOpacity
                  style={[styles.tabBtn, pickTab === 'note' && styles.tabBtnActive]}
                  onPress={() => setPickTab('note')}
                >
                  <Text style={[styles.tabBtnText, pickTab === 'note' && styles.tabBtnTextActive]}>Ghi chú</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.tabBtn, pickTab === 'topping' && styles.tabBtnActive]}
                  onPress={() => setPickTab('topping')}
                >
                  <Text style={[styles.tabBtnText, pickTab === 'topping' && styles.tabBtnTextActive]}>
                    Topping{pickToppingIds.length > 0 ? ` (${pickToppingIds.length})` : ''}
                  </Text>
                </TouchableOpacity>
              </View>
            )}

            {toppings.length > 0 && pickTab === 'topping' ? (
              <>
                <View style={styles.optionRow}>
                  {toppings.map((t) => (
                    <TouchableOpacity
                      key={t.id}
                      style={[styles.optionChip, pickToppingIds.includes(t.id) && styles.optionChipActive]}
                      onPress={() => toggleTopping(t.id)}
                    >
                      <Text style={[styles.optionChipText, pickToppingIds.includes(t.id) && styles.optionChipTextActive]}>
                        {t.ten} (+{t.gia.toLocaleString('vi-VN')}đ)
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
                {pickToppingIds.length === 0 && (
                  <Text style={styles.upsellHint}>
                    💡 Thêm topping chỉ từ +{Math.min(...toppings.map((t) => t.gia)).toLocaleString('vi-VN')}đ
                  </Text>
                )}
              </>
            ) : (
              <>
                <TextInput
                  style={styles.noteInput}
                  placeholder="Ghi chú món..."
                  placeholderTextColor={COLORS.textFaint}
                  value={pickGhiChu}
                  onChangeText={setPickGhiChu}
                />
                <View style={styles.optionRow}>
                  {quickNoteGroups.flatMap((g) => g.notes).map((note) => (
                    <TouchableOpacity
                      key={note}
                      style={[styles.optionChip, activeNotes.has(note) && styles.optionChipActive]}
                      onPress={() => toggleNote(note)}
                    >
                      <Text style={[styles.optionChipText, activeNotes.has(note) && styles.optionChipTextActive]}>
                        {note}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}

            <Text style={styles.modalLabel}>Số lượng</Text>
            <View style={styles.qtyRow}>
              <TouchableOpacity style={styles.qtyBtn} onPress={() => setPickSoLuong((n) => Math.max(1, n - 1))}>
                <Text style={styles.qtyBtnText}>-</Text>
              </TouchableOpacity>
              <Text style={styles.qtyValue}>{pickSoLuong}</Text>
              <TouchableOpacity style={styles.qtyBtn} onPress={() => setPickSoLuong((n) => n + 1)}>
                <Text style={styles.qtyBtnText}>+</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.modalCancelBtn} onPress={() => setPicking(null)}>
                <Text style={styles.modalCancelText}>Huỷ</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.modalConfirmBtn} onPress={confirmAdd} disabled={!pickBienThe}>
                <Text style={styles.modalConfirmText}>
                  Thêm vào giỏ{pickBienThe ? ` · ${(pickBienThe.giaBan * pickSoLuong).toLocaleString('vi-VN')}đ` : ''}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, backgroundColor: COLORS.bg },
  error: { color: COLORS.danger, marginBottom: 12, textAlign: 'center' },
  retryBtn: { backgroundColor: COLORS.primary, borderRadius: 10, paddingVertical: 10, paddingHorizontal: 20 },
  retryText: { color: '#fff', fontWeight: '600' },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    marginHorizontal: 12,
    marginTop: 10,
    marginBottom: 2,
    borderRadius: 12,
    paddingHorizontal: 12,
    height: 42,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  searchIcon: { fontSize: 18, color: COLORS.textFaint, marginRight: 6 },
  searchInput: { flex: 1, fontSize: 15, color: COLORS.text, padding: 0 },
  lyBiMatBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    marginHorizontal: 12,
    marginTop: 10,
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#FFD9A0',
  },
  lyBiMatEmoji: { fontSize: 26, marginRight: 10 },
  lyBiMatTitle: { fontSize: 14, fontWeight: '700', color: '#8A5300' },
  lyBiMatDesc: { fontSize: 11, color: '#A3712E', marginTop: 2 },
  lyBiMatArrow: { fontSize: 22, color: '#B8860B', marginLeft: 6 },
  sectionHeaderWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.bg,
    paddingHorizontal: 16,
    paddingTop: 18,
    paddingBottom: 8,
  },
  sectionHeaderAccent: { width: 4, height: 16, borderRadius: 2, backgroundColor: COLORS.primary, marginRight: 8 },
  sectionHeader: { color: COLORS.text, fontWeight: '700', fontSize: 16, letterSpacing: 0.2 },
  productCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    marginHorizontal: 12,
    marginBottom: 8,
    borderRadius: 14,
    padding: 10,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
    elevation: 1,
  },
  thumb: { width: 64, height: 64, borderRadius: 10, backgroundColor: COLORS.divider },
  thumbPlaceholder: {
    width: 64,
    height: 64,
    borderRadius: 10,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
  },
  thumbPlaceholderText: { fontSize: 22, fontWeight: '700', color: COLORS.primary },
  productInfo: { flex: 1, marginLeft: 12 },
  productName: { fontSize: 15, fontWeight: '600', color: COLORS.text, lineHeight: 20 },
  productPrice: { fontSize: 13, color: COLORS.primary, fontWeight: '600', marginTop: 4 },
  addBtn: {
    width: 30,
    height: 30,
    borderRadius: 15,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 8,
  },
  addBtnText: { color: '#fff', fontSize: 18, fontWeight: '700', lineHeight: 20 },
  cartBar: {
    position: 'absolute',
    left: 12,
    right: 12,
    bottom: 12,
    backgroundColor: COLORS.primaryDark,
    borderRadius: 14,
    paddingVertical: 14,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
  cartBarBadge: {
    backgroundColor: 'rgba(255,255,255,0.2)',
    borderRadius: 12,
    minWidth: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
  cartBarBadgeText: { color: '#fff', fontWeight: '700', fontSize: 13 },
  cartBarText: { color: '#fff', fontWeight: '700', fontSize: 15, marginLeft: 10, flex: 1 },
  cartBarPrice: { color: '#fff', fontWeight: '700', fontSize: 15 },
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.45)', justifyContent: 'flex-end' },
  modalCard: { backgroundColor: '#fff', borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: 20, paddingTop: 10 },
  modalHandle: { width: 40, height: 4, borderRadius: 2, backgroundColor: COLORS.divider, alignSelf: 'center', marginBottom: 14 },
  modalHeaderRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  modalThumb: { width: 56, height: 56, borderRadius: 10, backgroundColor: COLORS.divider },
  modalThumbPlaceholder: {
    width: 56,
    height: 56,
    borderRadius: 10,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalTitle: { fontSize: 17, fontWeight: '700', color: COLORS.text, marginLeft: 12, flex: 1 },
  modalLabel: { fontSize: 13, color: COLORS.textMuted, marginTop: 14, marginBottom: 8, fontWeight: '600' },
  tabRow: {
    flexDirection: 'row',
    marginTop: 14,
    backgroundColor: COLORS.divider,
    borderRadius: 10,
    padding: 3,
  },
  tabBtn: { flex: 1, paddingVertical: 8, borderRadius: 8, alignItems: 'center' },
  tabBtnActive: { backgroundColor: '#fff' },
  tabBtnText: { fontSize: 13, fontWeight: '600', color: COLORS.textMuted },
  tabBtnTextActive: { color: COLORS.text },
  noteInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 14,
    color: COLORS.text,
    marginTop: 10,
    marginBottom: 8,
  },
  optionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  upsellHint: { fontSize: 12, color: COLORS.primary, fontWeight: '600', marginTop: 6 },
  optionChip: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  optionChipActive: { backgroundColor: COLORS.primary, borderColor: COLORS.primary },
  optionChipText: { color: COLORS.text, fontSize: 13, fontWeight: '500' },
  optionChipTextActive: { color: '#fff' },
  qtyRow: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  qtyBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: COLORS.primaryTint,
    alignItems: 'center',
    justifyContent: 'center',
  },
  qtyBtnText: { fontSize: 20, fontWeight: '700', color: COLORS.primary },
  qtyValue: { fontSize: 16, fontWeight: '700', minWidth: 24, textAlign: 'center' },
  modalActions: { flexDirection: 'row', marginTop: 22, gap: 12 },
  modalCancelBtn: { flex: 1, paddingVertical: 13, alignItems: 'center', borderRadius: 12, borderWidth: 1, borderColor: COLORS.border },
  modalCancelText: { color: COLORS.textMuted, fontWeight: '600' },
  modalConfirmBtn: { flex: 2, paddingVertical: 13, alignItems: 'center', borderRadius: 12, backgroundColor: COLORS.primary },
  modalConfirmText: { color: '#fff', fontWeight: '700' },
});
