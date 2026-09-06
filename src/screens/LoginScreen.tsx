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
    <KeyboardAvoider style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.logoCircle}>
          <Ionicons name="cafe" size={32} color="#fff" />
        </View>
        <Text style={styles.title}>ĐENN</Text>

        {error ? (
          <View style={styles.errorBanner}>
            <Ionicons name="warning" size={16} color={COLORS.danger} />
            <Text style={styles.errorText}>{error}</Text>
          </View>
        ) : null}

        {step === 'phone' && (
          <>
            <FieldBox icon="call-outline">
              <TextInput
                style={styles.fieldInput}
                placeholder="Số điện thoại"
                placeholderTextColor={COLORS.textFaint}
                keyboardType="number-pad"
                maxLength={10}
                value={phone}
                onChangeText={(t) => setPhone(t.replace(/[^0-9]/g, ''))}
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
            <FieldBox icon="lock-closed-outline">
              <TextInput
                style={styles.fieldInput}
                placeholder="Mật khẩu"
                placeholderTextColor={COLORS.textFaint}
                secureTextEntry={!showPassword}
                value={password}
                onChangeText={setPassword}
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
            <FieldBox icon="keypad-outline">
              <TextInput
                style={styles.fieldInput}
                placeholder="Mã xác thực (SMS)"
                placeholderTextColor={COLORS.textFaint}
                keyboardType="number-pad"
                maxLength={6}
                value={otpCode}
                onChangeText={setOtpCode}
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
            <FieldBox icon="lock-closed-outline">
              <TextInput
                style={styles.fieldInput}
                placeholder="Mật khẩu mới"
                placeholderTextColor={COLORS.textFaint}
                secureTextEntry={!showNewPassword}
                value={newPassword}
                onChangeText={setNewPassword}
                autoFocus
                textContentType="newPassword"
                autoComplete="new-password"
              />
              <TouchableOpacity onPress={() => setShowNewPassword((v) => !v)} hitSlop={8}>
                <Ionicons name={showNewPassword ? 'eye-off-outline' : 'eye-outline'} size={20} color={COLORS.textMuted} />
              </TouchableOpacity>
            </FieldBox>
            <FieldBox icon="lock-closed-outline">
              <TextInput
                style={styles.fieldInput}
                placeholder="Nhập lại mật khẩu mới"
                placeholderTextColor={COLORS.textFaint}
                secureTextEntry={!showNewPassword}
                value={confirmPassword}
                onChangeText={setConfirmPassword}
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
      </ScrollView>
    </KeyboardAvoider>
  );
}

function FieldBox({ icon, children }: { icon: keyof typeof Ionicons.glyphMap; children: React.ReactNode }) {
  return (
    <View style={styles.fieldBox}>
      <Ionicons name={icon} size={20} color={COLORS.textMuted} style={styles.fieldIcon} />
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
    backgroundColor: '#F2F2F7',
  },
  scroll: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 28,
  },
  logoCircle: {
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: COLORS.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
    shadowColor: COLORS.primary,
    shadowOpacity: 0.35,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 6,
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
    letterSpacing: 4,
    color: COLORS.text,
    marginBottom: 24,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    alignSelf: 'stretch',
    width: '100%',
    maxWidth: 360,
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
    maxWidth: 360,
    height: 50,
    backgroundColor: '#fff',
    borderRadius: 14,
    borderWidth: 1,
    borderColor: 'rgba(60,60,67,0.15)',
    paddingHorizontal: 14,
    marginBottom: 14,
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
    maxWidth: 360,
    height: 50,
    backgroundColor: COLORS.primary,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  buttonDisabled: {
    backgroundColor: 'rgba(30,78,140,0.35)',
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
