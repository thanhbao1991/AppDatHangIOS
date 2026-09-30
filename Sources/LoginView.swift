import SwiftUI

/// Port từ LoginScreen.tsx (bản RN cũ). SĐT đã có mật khẩu → đăng nhập 1 bước; SĐT chưa có mật khẩu
/// (mới hoặc khách cũ do staff tạo, chưa từng dùng app) → gửi OTP (Zalo ZNS) rồi đặt mật khẩu.
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
            // Trước [primary, primary.opacity(0.75)] — cùng 1 màu khác độ mờ, nhìn gần như phẳng.
            Theme.primaryGradient
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
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                    )
                }
                .padding(28)
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
            #if DEV_LOGIN
            devKhachSearch
            #else
            fieldBox(icon: "phone") {
                TextField("Số điện thoại Zalo", text: $phone)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: "phone")
                    .onChange(of: phone) { phone = String($0.filter(\.isNumber).prefix(10)) }
            }
            // OTP chỉ gửi qua Zalo ZNS (backend đã gỡ SMS 2026-09-29) — số không dùng Zalo sẽ không
            // bao giờ nhận được mã, nên nói rõ ngay từ bước nhập SĐT.
            Text("Mã xác thực sẽ được gửi qua Zalo, vui lòng nhập số điện thoại đang dùng Zalo.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            primaryButton("Tiếp tục", disabled: loading || !isPhoneValid) { Task { await continuePhone() } }
            #endif
        }
    }

    #if DEV_LOGIN
    @State private var devQuery = ""
    @State private var devKetQua: [APIClient.DevKhach] = []
    @State private var devSearchTask: Task<Void, Never>?

    private var devKhachSearch: some View {
        VStack(spacing: 8) {
            fieldBox(icon: "magnifyingglass") {
                TextField("Tìm khách theo tên", text: $devQuery)
                    .autocorrectionDisabled()
                    .onChange(of: devQuery) { q in
                        devSearchTask?.cancel()
                        devSearchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if Task.isCancelled { return }
                            let r = await APIClient.shared.devTimKhach(q)
                            if Task.isCancelled { return }
                            devKetQua = r.data ?? []
                            if !r.isSuccess { error = r.message ?? "" }
                        }
                    }
            }
            ForEach(devKetQua) { k in
                Button {
                    phone = k.soDienThoai
                    Task { await continuePhone() }
                } label: {
                    HStack {
                        Text(k.ten).fontWeight(.semibold)
                        Spacer()
                        Text(k.soDienThoai).foregroundColor(Theme.textMuted)
                    }
                    .padding(.vertical, 6)
                }
                .disabled(loading)
                Divider()
            }
        }
    }
    #endif

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
            // Quên mật khẩu = đi lại đúng luồng OTP → đặt mật khẩu mới như lần đăng ký đầu. Backend
            // (KhachHangAuthService.CompletePhoneVerifiedLoginAsync) thấy SĐT đã có mật khẩu + gửi kèm
            // mật khẩu mới sau OTP đúng thì đặt lại và thu hồi mọi phiên cũ.
            Button("Quên mật khẩu?") { Task { await forgotPassword() } }
                .foregroundColor(Theme.primary).fontWeight(.semibold)
                .disabled(loading)
            Button("Đổi SĐT khác") { backToPhone() }.foregroundColor(Theme.primary).fontWeight(.semibold)
        }
    }

    private var otpCodeStep: some View {
        VStack(spacing: 14) {
            fieldBox(icon: "number") {
                TextField("Mã xác thực (Zalo)", text: $otpCode)
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
            Button("Đổi SĐT khác") { backToPhone() }.foregroundColor(Theme.primary).fontWeight(.semibold)
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
        let isFocused = focusedField != nil && fieldBoxFocusIcons.contains(icon)
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(isFocused ? Theme.primary : Theme.textMuted).frame(width: 20)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isFocused ? Theme.primary : Color(.separator).opacity(0.4), lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    /// fieldBox không nhận field id riêng cho border focus (khác fieldContainer AppQuanLyIOS nhận
    /// isFocused tường minh) — set rỗng vì mỗi icon chỉ dùng ở 1 field tại 1 thời điểm hiển thị nên
    /// so theo icon vẫn đúng, tránh phải sửa lại chữ ký gọi ở 4 step.
    private var fieldBoxFocusIcons: Set<String> {
        guard let focusedField else { return [] }
        switch focusedField {
        case "phone": return ["phone"]
        case "password": return ["lock"]
        case "otpCode": return ["number"]
        case "newPassword", "confirmPassword": return ["lock"]
        default: return []
        }
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
            .background(Theme.primaryGradient.opacity(disabled ? 0.35 : 1))
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
        #if DEV_LOGIN
        // Bản ipa nội bộ của chủ quán: vào thẳng bằng SĐT, không OTP/mật khẩu (xem build-ios.yml, cờ DEV_LOGIN).
        let dev = await APIClient.shared.devDangNhap(soDienThoai: phone)
        if dev.isSuccess, dev.data != nil { isLoggedIn = true } else { error = dev.message ?? "Đăng nhập thất bại." }
        return
        #endif
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

    private func forgotPassword() async {
        loading = true; error = ""
        defer { loading = false }
        password = ""
        if await sendOtp() {
            resendConLai = otpResendCooldown
            step = .otpCode
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
