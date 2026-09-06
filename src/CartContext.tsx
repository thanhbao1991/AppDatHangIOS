import { createContext, useContext, useMemo, useState } from 'react';

export type CartTopping = { id: string; ten: string; gia: number };
export type CartItem = {
  key: string; // random id nội bộ, không phải id backend
  sanPhamBienTheId: string;
  tenSanPham: string;
  tenBienThe: string;
  giaBan: number;
  soLuong: number;
  ghiChu?: string;
  toppings: CartTopping[];
};

type CartContextValue = {
  items: CartItem[];
  addItem: (item: Omit<CartItem, 'key'>) => void;
  removeItem: (key: string) => void;
  setQuantity: (key: string, soLuong: number) => void;
  clear: () => void;
  totalCount: number;
  totalPrice: number;
};

const CartContext = createContext<CartContextValue | null>(null);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);

  const addItem = (item: Omit<CartItem, 'key'>) => {
    setItems((prev) => [...prev, { ...item, key: `${Date.now()}-${Math.random()}` }]);
  };
  const removeItem = (key: string) => {
    setItems((prev) => prev.filter((i) => i.key !== key));
  };
  // soLuong <= 0 xoá luôn dòng đó — khớp hành vi nút "-" ở CheckoutScreen khi về 0.
  const setQuantity = (key: string, soLuong: number) => {
    if (soLuong <= 0) {
      removeItem(key);
      return;
    }
    setItems((prev) => prev.map((i) => (i.key === key ? { ...i, soLuong } : i)));
  };
  const clear = () => setItems([]);

  const totalCount = useMemo(() => items.reduce((s, i) => s + i.soLuong, 0), [items]);
  const totalPrice = useMemo(
    () =>
      items.reduce(
        (s, i) => s + i.soLuong * (i.giaBan + i.toppings.reduce((ts, t) => ts + t.gia, 0)),
        0,
      ),
    [items],
  );

  return (
    <CartContext.Provider value={{ items, addItem, removeItem, setQuantity, clear, totalCount, totalPrice }}>
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart phải dùng trong CartProvider');
  return ctx;
}
