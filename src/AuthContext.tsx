import { createContext, useContext } from 'react';

type AuthContextValue = {
  tenKhachHang: string;
  logout: () => Promise<void>;
};

export const AuthContext = createContext<AuthContextValue>({
  tenKhachHang: '',
  logout: async () => {},
});

export function useAuth() {
  return useContext(AuthContext);
}
