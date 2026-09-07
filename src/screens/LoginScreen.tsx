import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { kiemTraSdt, dangNhapMatKhau, guiOtp, kiemTraOtp, xacNhanOtp, KhachHangLoginResponse } from '../api';
import { COLORS } from '../theme';
import KeyboardAvoider from '../components/KeyboardAvoider';

// SĐT Việt Nam: 10 số, bắt đầu bằng 0.
const PHONE_REGEX = /^0\d{9}$/;

// Khớp OtpResendCooldownSeconds phía backend.
const OTP_RESEND_COOLDOWN_SECONDS = 60;

type Props = {
  onLoggedIn: (data: KhachHangLoginResponse) => void;
};

// SĐT đã có mật khẩu -> đăng nhập 1 bước (password). SĐT chưa có mật khẩu (mới hoặc khách cũ do
// staff tạo, chưa từng dùng app) -> gửi OTP tự quản lý (backend gửi qua Zalo ZNS, chưa duyệt template
// thì tự fallback qua Bark) rồi đặt mật khẩu, tránh phải xác thực lại mỗi lần mở app sau này.
type Step = 'phone' | 'password' | 'otpCode' | 'otpPassword';

export default function LoginScreen({ onLoggedIn }: Props) {
  const [step, setStep] = useState<Step>('phone');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  // Backend đã chặn gửi lại dưới 60s (KhachHangAuthService.OtpResendCooldownSeconds) và giới hạn 5
  // mã/ngày/SĐT. Đếm ngược ở đây chỉ để khách thấy phải chờ bao lâu, thay vì bấm liên tục rồi nhận
  // thông báo lỗi — và để không đốt phí quota mã trong ngày vì bấm nhầm.
  const [resendConLai, setResendConLai] = useState(0);
  const [focusedField, setFocusedField] = useState<string | null>(null);

  useEffect(() => {
    if (resendConLai <= 0) return;
    const t = setTimeout(() => setResendConLai(s => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendConLai]);

  const resetFields = () => {
    setPassword('');
    setOtpCode('');
    setNewPassword('');
    setConfirmPassword('');
    setError('');
  };

  const sendOtp = async () => {
    const result = await guiOtp(phone);
    if (!result.isSuccess) {
      setError(result.message || 'Không gửi được mã xác thực.');
      return;
    }
    setStep('otpCode');
  };

  const continuePhone = async () => {
    if (!phone) {
      setError('Nhập số điện thoại.');
      return;
    }
    if (!PHONE_REGEX.test(phone)) {
      setError('Số điện thoại không hợp lệ.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const result = await kiemTraSdt(phone);
      if (!result.isSuccess) {
        setError(result.message || 'Không kiểm tra được số điện thoại.');
        return;
      }
      if (result.data) {
        setStep('password');
      } else {
        await sendOtp();
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  const submitPassword = async () => {
    if (!password) {
      setError('Nhập mật khẩu.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const result = await dangNhapMatKhau(phone, password);
      if (result.isSuccess && result.data) {
        onLoggedIn(result.data);
      } else {
        setError(result.message || 'Đăng nhập thất bại.');
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  // Kiểm tra mã không tiêu (kiem-tra-otp) trước khi cho qua màn đặt mật khẩu — chặn sớm mã sai thay
  // vì để khách gõ xong mật khẩu mới biết mã sai ở bước cuối. Mã thật sự bị tiêu ở xacNhanOtp.
  const continueOtpCode = async () => {
    if (!otpCode.trim()) {
      setError('Nhập mã xác thực.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const result = await kiemTraOtp(phone, otpCode.trim());
      if (result.isSuccess && result.data) {
        setStep('otpPassword');
      } else {
        setError(result.message || 'Mã xác thực không đúng hoặc đã hết hạn.');
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  const submitOtpPassword = async () => {
    if (!newPassword || !confirmPassword) {
      setError('Nhập đầy đủ mật khẩu.');
      return;
    }
    // Backend (KhachHangAuthService.MatKhauToiThieu) mới là nơi ép thật — chỗ này chỉ để khách biết
    // sớm trước khi gọi API. Đổi số ở đây thì phải đổi cả bên backend.
    if (newPassword.length < 6) {
      setError('Mật khẩu tối thiểu 6 ký tự.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('Mật khẩu nhập lại không khớp.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const result = await xacNhanOtp(phone, otpCode.trim(), newPassword);
      if (result.isSuccess && result.data) {
        onLoggedIn(result.data);
      } else {
        setError(result.message || 'Xác nhận thất bại.');
      }
    } catch {
      setError('Không kết nối được server.');
    } finally {
      setLoading(false);
    }
  };

  const resendOtp = async () => {
    if (resendConLai > 0) return;
    setLoading(true);
    setError('');
    try {
      await sendOtp();
      setError('Đã gửi lại mã xác thực.');
      setResendConLai(OTP_RESEND_COOLDOWN_SECONDS);
    } catch {
      setError('Không gửi được mã xác thực.');
    } finally {
      setLoading(false);
    }
  };

  const backToPhone = () => {
    setStep('phone');
    resetFields();
  };

  const canSubmitPhone = PHONE_REGEX.test(phone);
  const canSubmitPassword = password.length > 0;
  const canSubmitOtp = otpCode.trim().length > 0;
  const canSubmitOtpPassword = newPassword.length > 0 && confirmPassword.length > 0;

  return (
    <LinearGradient
      colors={[COLORS.primary, 'rgba(30,78,140,0.75)']}
      style={styles.container}
    >
      <KeyboardAvoider>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <View style={styles.hero}>
            <Text style={styles.heroTitle}>Đenn Coffee</Text>
            <Text style={styles.heroSubtitle}>Quán nhỏ cảm ơn to</Text>
          </View>

          <View style={styles.card}>
          {error ? (
            <View style={styles.errorBanner}>
              <Ionicons name="warning" size={16} color={COLORS.danger} />
              <Text style={styles.errorText}>{error}</Text>
            </View>
          ) : null}

          {step === 'phone' && (
            <>
              <FieldBox icon="call-outline" focused={focusedField === 'phone'}>
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Số điện thoại"
                  placeholderTextColor={COLORS.textFaint}
                  keyboardType="number-pad"
                  maxLength={10}
                  value={phone}
                  onChangeText={(t) => setPhone(t.replace(/[^0-9]/g, ''))}
                  onFocus={() => setFocusedField('phone')}
                  onBlur={() => setFocusedField(null)}
                  autoCapitalize="none"
                  textContentType="telephoneNumber"
                  autoComplete="tel"
                />
              </FieldBox>
              <PrimaryButton label="Tiếp tục" loading={loading} disabled={loading || !canSubmitPhone} onPress={continuePhone} />
            </>
          )}

          {step === 'password' && (
            <>
              <FieldBox icon="checkmark-circle-outline">
                <Text style={styles.fieldStaticText}>{phone}</Text>
              </FieldBox>
              <FieldBox icon="lock-closed-outline" focused={focusedField === 'password'}>
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Mật khẩu"
                  placeholderTextColor={COLORS.textFaint}
                  secureTextEntry={!showPassword}
                  value={password}
                  onChangeText={setPassword}
                  onFocus={() => setFocusedField('password')}
                  onBlur={() => setFocusedField(null)}
                  autoFocus
                  textContentType="password"
                  autoComplete="current-password"
                />
                <TouchableOpacity onPress={() => setShowPassword((v) => !v)} hitSlop={8}>
                  <Ionicons name={showPassword ? 'eye-off-outline' : 'eye-outline'} size={20} color={COLORS.textMuted} />
                </TouchableOpacity>
              </FieldBox>
              <PrimaryButton label="Đăng nhập" loading={loading} disabled={loading || !canSubmitPassword} onPress={submitPassword} />
              <TouchableOpacity onPress={backToPhone} style={styles.linkBtn}>
                <Text style={styles.linkText}>Đổi số khác</Text>
              </TouchableOpacity>
            </>
          )}

          {step === 'otpCode' && (
            <>
              <FieldBox icon="keypad-outline" focused={focusedField === 'otpCode'}>
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Mã xác thực (SMS)"
                  placeholderTextColor={COLORS.textFaint}
                  keyboardType="number-pad"
                  maxLength={6}
                  value={otpCode}
                  onChangeText={setOtpCode}
                  onFocus={() => setFocusedField('otpCode')}
                  onBlur={() => setFocusedField(null)}
                  autoFocus
                  textContentType="oneTimeCode"
                  autoComplete="sms-otp"
                />
              </FieldBox>
              <PrimaryButton label="Tiếp tục" loading={loading} disabled={loading || !canSubmitOtp} onPress={continueOtpCode} />
              <TouchableOpacity
                onPress={resendOtp}
                style={styles.linkBtn}
                disabled={loading || resendConLai > 0}
              >
                <Text style={[styles.linkText, resendConLai > 0 && styles.linkTextDisabled]}>
                  {resendConLai > 0 ? `Gửi lại mã sau ${resendConLai}s` : 'Gửi lại mã'}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={backToPhone} style={styles.linkBtn}>
                <Text style={styles.linkText}>Đổi số khác</Text>
              </TouchableOpacity>
            </>
          )}

          {step === 'otpPassword' && (
            <>
              <FieldBox icon="lock-closed-outline" focused={focusedField === 'newPassword'}>
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Mật khẩu mới"
                  placeholderTextColor={COLORS.textFaint}
                  secureTextEntry={!showNewPassword}
                  value={newPassword}
                  onChangeText={setNewPassword}
                  onFocus={() => setFocusedField('newPassword')}
                  onBlur={() => setFocusedField(null)}
                  autoFocus
                  textContentType="newPassword"
                  autoComplete="new-password"
                />
                <TouchableOpacity onPress={() => setShowNewPassword((v) => !v)} hitSlop={8}>
                  <Ionicons name={showNewPassword ? 'eye-off-outline' : 'eye-outline'} size={20} color={COLORS.textMuted} />
                </TouchableOpacity>
              </FieldBox>
              <FieldBox icon="lock-closed-outline" focused={focusedField === 'confirmPassword'}>
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Nhập lại mật khẩu mới"
                  placeholderTextColor={COLORS.textFaint}
                  secureTextEntry={!showNewPassword}
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  onFocus={() => setFocusedField('confirmPassword')}
                  onBlur={() => setFocusedField(null)}
                  textContentType="newPassword"
                  autoComplete="new-password"
                />
              </FieldBox>
              <PrimaryButton label="Xác nhận" loading={loading} disabled={loading || !canSubmitOtpPassword} onPress={submitOtpPassword} />
              <TouchableOpacity onPress={() => setStep('otpCode')} style={styles.linkBtn}>
                <Text style={styles.linkText}>Quay lại</Text>
              </TouchableOpacity>
            </>
          )}
        </View>
      </ScrollView>
      </KeyboardAvoider>
    </LinearGradient>
  );
}

function FieldBox({
  icon,
  focused,
  children,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  focused?: boolean;
  children: React.ReactNode;
}) {
  return (
    <View style={[styles.fieldBox, focused && styles.fieldBoxFocused]}>
      <Ionicons name={icon} size={20} color={focused ? COLORS.primary : COLORS.textMuted} style={styles.fieldIcon} />
      {children}
    </View>
  );
}

function PrimaryButton({
  label,
  loading,
  disabled,
  onPress,
}: {
  label: string;
  loading: boolean;
  disabled: boolean;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity
      style={[styles.button, disabled && styles.buttonDisabled]}
      onPress={onPress}
      disabled={disabled}
    >
      {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.buttonText}>{label}</Text>}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.primary,
  },
  scroll: {
    flexGrow: 1,
    alignItems: 'center',
    paddingTop: 120,
    paddingHorizontal: 28,
    paddingBottom: 28,
  },
  hero: {
    alignItems: 'center',
    marginBottom: 32,
  },
  heroTitle: {
    fontSize: 34,
    fontWeight: '700',
    color: '#fff',
  },
  heroSubtitle: {
    marginTop: 8,
    fontSize: 15,
    fontWeight: '500',
    color: 'rgba(255,255,255,0.85)',
  },
  card: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: '#fff',
    borderRadius: 24,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.18,
    shadowRadius: 24,
    elevation: 8,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    alignSelf: 'stretch',
    backgroundColor: 'rgba(198,40,40,0.1)',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 16,
  },
  errorText: {
    color: COLORS.danger,
    fontWeight: '600',
    fontSize: 13,
    flexShrink: 1,
  },
  fieldBox: {
    flexDirection: 'row',
    alignItems: 'center',
    width: '100%',
    height: 50,
    backgroundColor: '#F2F2F7',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(60,60,67,0.15)',
    paddingHorizontal: 14,
    marginBottom: 14,
  },
  fieldBoxFocused: {
    borderColor: COLORS.primary,
    borderWidth: 1.5,
  },
  fieldIcon: {
    marginRight: 10,
  },
  fieldInput: {
    flex: 1,
    fontSize: 16,
    color: COLORS.text,
    height: '100%',
  },
  fieldStaticText: {
    flex: 1,
    fontSize: 16,
    color: COLORS.text,
  },
  devHint: {
    fontSize: 13,
    color: COLORS.warning,
    marginBottom: 16,
  },
  button: {
    width: '100%',
    height: 52,
    backgroundColor: COLORS.primary,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
    shadowColor: COLORS.primary,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.35,
    shadowRadius: 12,
    elevation: 4,
  },
  buttonDisabled: {
    backgroundColor: 'rgba(30,78,140,0.35)',
    shadowOpacity: 0,
    elevation: 0,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  linkBtn: {
    marginTop: 16,
    alignItems: 'center',
  },
  linkText: {
    color: COLORS.primary,
    fontWeight: '600',
  },
  linkTextDisabled: {
    color: COLORS.textFaint,
  },
});
