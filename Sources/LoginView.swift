import SwiftUI

/// Port từ LoginScreen.tsx (bản RN cũ). SĐT đã có mật khẩu → đăng nhập 1 bước; SĐT chưa có mật khẩu
/// (mới hoặc khách cũ do staff tạo, chưa từng dùng app) → gửi OTP (Zalo ZNS/Bark) rồi đặt mật khẩu.
private enum LoginStep { case phone, password, otpCode, otpPassword }

// Khớp OtpResendCooldownSeconds phía backend.
private let otpResendCooldown = 60

struct LoginView: View {
    @Binding var isLoggedIn: Bool

    @State private var step: LoginStep = .phone
    @State private var phone = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var loading = false
    @State private var error = ""
    @State private var resendConLai = 0
    @FocusState private var focusedField: String?

    private let phoneRegex = try! NSRegularExpression(pattern: "^0\\d{9}$")
    private var isPhoneValid: Bool { phoneRegex.firstMatch(in: phone, range: NSRange(phone.startIndex..., in: phone)) != nil }

    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.primary, Theme.primary.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Đenn Coffee")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Quán nhỏ cảm ơn to")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.top, 120)

                    VStack(spacing: 14) {
                        if !error.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error).font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Theme.danger)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        switch step {
                        case .phone: phoneStep
                        case .password: passwordStep
                        case .otpCode: otpCodeStep
                        case .otpPassword: otpPasswordStep
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
            }
        }
        .onReceive(resendTimer) { _ in
            if resendConLai > 0 { resendConLai -= 1 }
        }
    }

    // MARK: - Steps

    private var phoneStep: some View {
        VStack(spacing: 14) {
            fieldBox(icon: "phone") {
                TextField("Số điện thoại", text: $phone)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: "phone")
                    .onChange(of: phone) { phone = String($0.filter(\.isNumber).prefix(10)) }
            }
            primaryButton("Tiếp tục", disabled: loading || !isPhoneValid) { Task { await continuePhone() } }
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 14) {
            fieldBox(icon: "checkmark.circle") { Text(phone) }
            fieldBox(icon: "lock") {
                Group {
                    if showPassword { TextField("Mật khẩu", text: $password) }
                    else { SecureField("Mật khẩu", text: $password) }
                }
                .focused($focusedField, equals: "password")
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundColor(Theme.textMuted)
                }
            }
            primaryButton("Đăng nhập", disabled: loading || password.isEmpty) { Task { await submitPassword() } }
            Button("Đổi số khác") { backToPhone() }.foregroundColor(Theme.primary).fontWeight(.semibold)
        }
    }

    private var otpCodeStep: some View {
        VStack(spacing: 14) {
            fieldBox(icon: "number") {
                TextField("Mã xác thực (SMS)", text: $otpCode)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: "otpCode")
                    .onChange(of: otpCode) { otpCode = String($0.filter(\.isNumber).prefix(6)) }
            }
            primaryButton("Tiếp tục", disabled: loading || otpCode.trimmingCharacters(in: .whitespaces).isEmpty) {
                Task { await continueOtpCode() }
            }
            Button(resendConLai > 0 ? "Gửi lại mã sau \(resendConLai)s" : "Gửi lại mã") { Task { await resendOtp() } }
                .foregroundColor(resendConLai > 0 ? Theme.textFaint : Theme.primary)
                .fontWeight(.semibold)
                .disabled(loading || resendConLai > 0)
            Button("Đổi số khác") { backToPhone() }.foregroundColor(Theme.primary).fontWeight(.semibold)
        }
    }

    private var otpPasswordStep: some View {
        VStack(spacing: 14) {
            fieldBox(icon: "lock") {
                Group {
                    if showNewPassword { TextField("Mật khẩu mới", text: $newPassword) }
                    else { SecureField("Mật khẩu mới", text: $newPassword) }
                }
                .focused($focusedField, equals: "newPassword")
                Button { showNewPassword.toggle() } label: {
                    Image(systemName: showNewPassword ? "eye.slash" : "eye").foregroundColor(Theme.textMuted)
                }
            }
            fieldBox(icon: "lock") {
                Group {
                    if showNewPassword { TextField("Nhập lại mật khẩu mới", text: $confirmPassword) }
                    else { SecureField("Nhập lại mật khẩu mới", text: $confirmPassword) }
                }
                .focused($focusedField, equals: "confirmPassword")
            }
            primaryButton("Xác nhận", disabled: loading || newPassword.isEmpty || confirmPassword.isEmpty) {
                Task { await submitOtpPassword() }
            }
            Button("Quay lại") { step = .otpCode }.foregroundColor(Theme.primary).fontWeight(.semibold)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func fieldBox<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.textMuted).frame(width: 20)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func primaryButton(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading { ProgressView().tint(.white) }
                else { Text(label).fontWeight(.semibold) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(.white)
            .background(disabled ? Theme.primary.opacity(0.35) : Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(disabled)
    }

    // MARK: - Actions

    private func resetFields() {
        password = ""; otpCode = ""; newPassword = ""; confirmPassword = ""; error = ""
    }

    private func backToPhone() {
        step = .phone
        resetFields()
    }

    private func sendOtp() async -> Bool {
        let result = await APIClient.shared.guiOtp(phone)
        if !result.isSuccess {
            error = result.message ?? "Không gửi được mã xác thực."
            return false
        }
        return true
    }

    private func continuePhone() async {
        guard isPhoneValid else { error = "Số điện thoại không hợp lệ."; return }
        loading = true; error = ""
        defer { loading = false }
        let result = await APIClient.shared.kiemTraSdt(phone)
        guard result.isSuccess else {
            error = result.message ?? "Không kiểm tra được số điện thoại."
            return
        }
        if result.data == true {
            step = .password
        } else if await sendOtp() {
            step = .otpCode
        }
    }

    private func submitPassword() async {
        loading = true; error = ""
        defer { loading = false }
        let result = await APIClient.shared.dangNhapMatKhau(soDienThoai: phone, matKhau: password)
        if result.isSuccess, result.data != nil {
            isLoggedIn = true
        } else {
            error = result.message ?? "Đăng nhập thất bại."
        }
    }

    private func continueOtpCode() async {
        loading = true; error = ""
        defer { loading = false }
        let code = otpCode.trimmingCharacters(in: .whitespaces)
        let result = await APIClient.shared.kiemTraOtp(soDienThoai: phone, otp: code)
        if result.isSuccess, result.data == true {
            step = .otpPassword
        } else {
            error = result.message ?? "Mã xác thực không đúng hoặc đã hết hạn."
        }
    }

    private func submitOtpPassword() async {
        guard newPassword.count >= 6 else { error = "Mật khẩu tối thiểu 6 ký tự."; return }
        guard newPassword == confirmPassword else { error = "Mật khẩu nhập lại không khớp."; return }
        loading = true; error = ""
        defer { loading = false }
        let code = otpCode.trimmingCharacters(in: .whitespaces)
        let result = await APIClient.shared.xacNhanOtp(soDienThoai: phone, otp: code, matKhau: newPassword)
        if result.isSuccess, result.data != nil {
            isLoggedIn = true
        } else {
            error = result.message ?? "Xác nhận thất bại."
        }
    }

    private func resendOtp() async {
        guard resendConLai <= 0 else { return }
        loading = true; error = ""
        defer { loading = false }
        if await sendOtp() {
            error = "Đã gửi lại mã xác thực."
            resendConLai = otpResendCooldown
        }
    }
}
