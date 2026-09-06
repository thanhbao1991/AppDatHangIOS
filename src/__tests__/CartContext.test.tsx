/**
 * Giỏ hàng là nơi ra con số khách nhìn thấy trước khi bấm đặt. Backend vẫn ép lại giá theo catalog
 * khi đặt thật, nên sai ở đây không làm khách bị tính sai tiền — nhưng làm khách thấy một đằng trả
 * một nẻo, nên vẫn phải khoá bằng test.
 */
import TestRenderer, { act } from 'react-test-renderer';
import { CartProvider, useCart } from '../CartContext';

// Harness tự viết thay cho renderHook của @testing-library/react-native: bản v14 chạy với React 19
// trả về object không có `result`, nên không dùng được. Ở đây chỉ cần một component con đọc context
// rồi ghi ra ngoài — đủ để test toàn bộ hành vi giỏ hàng mà không phụ thuộc thư viện thứ ba.
function dungGioHang() {
  const ref: { current: ReturnType<typeof useCart> } = { current: null as any };

  function Probe() {
    ref.current = useCart();
    return null;
  }

  act(() => {
    TestRenderer.create(
      <CartProvider>
        <Probe />
      </CartProvider>
    );
  });

  return { result: ref };
}

const traSua = {
  sanPhamBienTheId: 'bt-1',
  tenSanPham: 'Trà sữa',
  tenBienThe: 'M',
  giaBan: 30000,
  soLuong: 1,
  toppings: [],
};

describe('CartContext', () => {
  it('giỏ mới thì rỗng', () => {
    const { result } = dungGioHang();

    expect(result.current.items).toHaveLength(0);
    expect(result.current.totalCount).toBe(0);
    expect(result.current.totalPrice).toBe(0);
  });

  it('cộng tiền topping vào từng ly', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem({
        ...traSua,
        soLuong: 2,
        toppings: [
          { id: 'tp-1', ten: 'Trân châu', gia: 5000 },
          { id: 'tp-2', ten: 'Pudding', gia: 7000 },
        ],
      });
    });

    // 2 ly × (30.000 + 5.000 + 7.000)
    expect(result.current.totalPrice).toBe(84000);
    expect(result.current.totalCount).toBe(2);
  });

  // Cùng một món chọn 2 lần với ghi chú/topping khác nhau phải là 2 dòng riêng, không bị gộp —
  // nếu gộp thì khách mất ly đã chọn topping riêng.
  it('thêm cùng món hai lần tạo hai dòng riêng biệt', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem({ ...traSua, ghiChu: 'ít đá' });
    });
    act(() => {
      result.current.addItem({ ...traSua, ghiChu: 'nhiều đá' });
    });

    expect(result.current.items).toHaveLength(2);
    expect(result.current.items[0].key).not.toBe(result.current.items[1].key);
  });

  it('đổi số lượng thì tính lại tổng', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem(traSua);
    });
    act(() => {
      result.current.setQuantity(result.current.items[0].key, 3);
    });

    expect(result.current.totalCount).toBe(3);
    expect(result.current.totalPrice).toBe(90000);
  });

  it('giảm số lượng về 0 thì xoá dòng khỏi giỏ', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem(traSua);
    });
    act(() => {
      result.current.setQuantity(result.current.items[0].key, 0);
    });

    expect(result.current.items).toHaveLength(0);
    expect(result.current.totalPrice).toBe(0);
  });

  it('xoá đúng dòng được chọn, không đụng dòng còn lại', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem({ ...traSua, tenSanPham: 'Trà sữa' });
    });
    act(() => {
      result.current.addItem({ ...traSua, tenSanPham: 'Cà phê', giaBan: 25000 });
    });
    act(() => {
      result.current.removeItem(result.current.items[0].key);
    });

    expect(result.current.items).toHaveLength(1);
    expect(result.current.items[0].tenSanPham).toBe('Cà phê');
    expect(result.current.totalPrice).toBe(25000);
  });

  it('xoá sạch giỏ sau khi đặt hàng xong', () => {
    const { result } = dungGioHang();

    act(() => {
      result.current.addItem(traSua);
      result.current.addItem(traSua);
    });
    act(() => {
      result.current.clear();
    });

    expect(result.current.items).toHaveLength(0);
    expect(result.current.totalCount).toBe(0);
  });
});
