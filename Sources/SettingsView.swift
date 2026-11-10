import StoreKit
import SwiftUI

/// Port từ SettingsScreen.tsx — ví/hạng thành viên, địa chỉ đã lưu. Các thao tác bảo mật/tài khoản
/// (đổi mật khẩu, thiết bị đăng nhập, đăng xuất, xoá tài khoản) đã tách sang TaiKhoanBaoMatView,
/// mở qua icon bánh răng ở MainTabView (chỉ hiện khi đang ở tab này) — tránh trộn với ví/địa chỉ.
struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    var notificationBell: AnyView
    var accountSettingsGear: AnyView

    @Environment(\.requestReview) private var requestReview

    @State private var diaChiList: [DiaChiKhachHang] = BoNhoTam.diaChiList ?? []
    // Hiện ĐẦY ĐỦ cả địa chỉ nhân viên nhập qua Desktop lẫn khách tự thêm (đổi lại 2026-09-24 — trước
    // đó từng ẩn hẳn địa chỉ nhân viên ở card này, nhưng khách mới cài app lần đầu nhìn thấy trống dù
    // quán đã có sẵn địa chỉ từ lịch sử đặt hàng, gây cảm giác thiếu sót). Nút sửa/xoá vẫn tự ẩn với
    // địa chỉ nhân viên nhập qua `item.coTheXoa` bên dưới — khách chỉ được XEM/CHỌN mặc định, không
    // sửa/xoá được địa chỉ không phải do mình tạo.
    private var diaChiHienThi: [DiaChiKhachHang] { diaChiList }
    // Có dữ liệu lần trước (BoNhoTam) thì hiện ngay, không vòng xoay — load() tải lại rồi thay vào.
    @State private var vi: KhachHangVi? = BoNhoTam.vi
    @State private var loading = BoNhoTam.vi == nil
    @State private var moBangXepHang = false
    #if DEV_LOGIN
    @State private var xemTruocNgay1 = false
    @State private var chucMungXemTruoc: QuaChucMung?
    @State private var quaXemTruocConLai: [QuaChucMung] = []
    /// Không tự dùng, chỉ đổi giá trị để buộc nhãn nút "🧪 Xem trước..." vẽ lại (SeasonalEvent.previewOverride
    /// là static var, không tự kích hoạt lại body).
    @State private var seasonalPreviewTick = 0
    #endif
    /// Màu dịp lễ (Theme.primary/bg) là static var — đổi dịp (load() hoặc nút xem trước bắn .christmasPreviewToggled)
    /// thì tăng tick để vẽ lại card hạng + nền ngay, không phải đổi tab rồi quay lại (feedback 2026-11-07).
    @State private var themeTick = 0
    @State private var themeDangVe: SeasonalTheme? = SeasonalEvent.active

    @State private var alertMessage: (title: String, message: String)?
    @State private var diaChiChoXoa: DiaChiKhachHang?
    // nil = đang thêm mới, non-nil = đang sửa đúng id đó — dùng chung 1 alert TextField cho cả 2 thao
    // tác (giống pattern showEditTen bên dưới), tránh 2 sheet/alert gần như giống hệt nhau.
    @State private var showDiaChiForm = false
    @State private var diaChiEditingId: String?
    @State private var diaChiFormText: String = ""

    @State private var tenHienThi: String = Prefs.tenKhachHang ?? ""
    @State private var dangLuuTen = false
    @State private var showEditTen = false

    @State private var avatarUrl: String? = Prefs.avatarUrl
    @State private var dangUploadAvatar = false

    @State private var showLichSuXu = false
    @State private var showNapXu = false
    @State private var showCongNoHienTai = false

    // Ngày sinh — tái dùng đúng field/API đã có cho xác minh tuổi 18+ (MenuView), chỉ thêm chỗ khai
    // ở tab Tài khoản cho khách nào chưa mua sản phẩm thuốc lá cũng khai được (để hưởng voucher sinh
    // nhật). Chống lạm dụng nằm ở BACKEND (GamificationService.CapNhatNgaySinhAsync): chỉ cho khai
    // 1 LẦN DUY NHẤT, sửa lại phải nhờ nhân viên qua Desktop — UI ở đây chỉ ẩn form sau khi đã có.
    @State private var ngaySinhInfo: SinhNhatInfo? = BoNhoTam.ngaySinhInfo
    @State private var loadingNgaySinh = false
    @State private var dobPicked = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var savingDob = false
    @State private var dobError: String?
    /// Bánh xe wheel chiếm rất nhiều chỗ dọc (feedback 2026-09-27: "bao giờ bấm mới hiện cái này
    /// ra chứ" — trước hiện thẳng luôn, chiếm hết card) — giờ chỉ bung ra khi bấm "Sửa"/"Khai ngay",
    /// mặc định thu gọn.
    @State private var showDobPicker = false

    // Gradient tối + màu đặc trưng từng hạng — khớp phong cách thẻ hạng thành viên các app lớn
    // (Shopee/ShopBack: nền tối, chữ nổi bật) thay vì badge nhỏ trên nền trắng như trước. Lấy từ
    // Theme.hangColors (2026-09-16) — cùng 1 nguồn màu với Theme.primary/primaryDark toàn app, tránh
    // 2 nơi định nghĩa lệch nhau.
    private var hangGradient: [String: [Color]] {
        Theme.hangColors.mapValues { [$0.primary, $0.dark] }
    }
    private let hangIcon: [String: String] = [
        "Kim Cương": "💎", "Vàng": "🌟", "Bạc": "⭐", "Thành Viên": "🌱",
    ]

    #if DEV_LOGIN
    private var seasonalPreviewLabel: String {
        _ = seasonalPreviewTick // buộc đọc lại mỗi lần body vẽ lại do tick đổi
        guard let event = SeasonalEvent.previewOverride else { return "🧪 Xem trước dịp lễ" }
        return "🧪 Đang xem: \(event.previewTen) (bấm để đổi/tắt)"
    }
    #endif

    var body: some View {
        let _ = themeTick
        VStack(spacing: 0) {
            accountHeader
            settingsList
        }
        .onReceive(NotificationCenter.default.publisher(for: .christmasPreviewToggled)) { _ in
            guard SeasonalEvent.active != themeDangVe else { return }
            themeDangVe = SeasonalEvent.active
            themeTick += 1
        }
        // (Lịch sử) Xu và Công nợ từng nằm CHUNG 1 row của List (2 Button sibling trong xuCongNoCard). ROOT CAUSE
        // THẬT SỰ (sau 2 lần sửa sai hướng ở tầng navigationDestination/state): List coi row có nhiều
        // Button mặc định là "1 vùng chạm", chỉ route gesture cho 1 control — bấm nút đầu vẫn kích
        // hoạt nút cuối. Fix đúng nằm ở .buttonStyle(.plain) trên từng Button (xem xuContent/
        // congNoContent), không phải ở navigationDestination — giữ nguyên 2 modifier tách theo subview
        // (fix 2026-09-23 lần 2) vì đúng hướng, chỉ thiếu buttonStyle (fix 2026-09-23 lần 3, ĐÃ XONG).
        .task { await load() }
        .onDisappear { luuBoNhoTam() } // giữ cả thay đổi sau load (thêm/xoá địa chỉ, khai ngày sinh…)
        #if DEV_LOGIN
        .fullScreenCover(item: $chucMungXemTruoc) { t in
            ChucMungHangView(qua: t) {
                chucMungXemTruoc = nil
                if !quaXemTruocConLai.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    chucMungXemTruoc = quaXemTruocConLai.removeFirst()
                }
            }
            .id(t.id)
        }
        #endif
        .popupHost { host in
            host
                .alert(alertMessage?.title ?? "", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                    Button("OK") {}
                } message: {
                    Text(alertMessage?.message ?? "")
                }
                .confirmationDialog(
                    "Xoá địa chỉ \"\(diaChiChoXoa?.diaChi ?? "")\"?",
                    isPresented: Binding(get: { diaChiChoXoa != nil }, set: { if !$0 { diaChiChoXoa = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Xoá", role: .destructive) {
                        if let id = diaChiChoXoa?.id { Task { await xoaDiaChi(id) } }
                    }
                    Button("Huỷ", role: .cancel) {}
                }
                .alert("Đổi tên hiển thị", isPresented: $showEditTen) {
                    TextField("Tên hiển thị trong app", text: $tenHienThi)
                    Button("Lưu") { Task { await luuTenHienThi() } }
                    Button("Huỷ", role: .cancel) { tenHienThi = Prefs.tenKhachHang ?? "" }
                } message: {
                    Text("Để trống + Lưu sẽ xoá biệt danh, quay lại tên thật lưu ở quán.")
                }
        }
        .sheet(isPresented: $moBangXepHang) { BangXepHangView() }
        .sheet(isPresented: $showDiaChiForm) {
            DiaChiFormSheet(
                initialText: diaChiFormText,
                isEditing: diaChiEditingId != nil,
                onSave: { text in
                    showDiaChiForm = false
                    if let id = diaChiEditingId {
                        Task { await suaDiaChi(id, diaChi: text) }
                    } else {
                        Task { await themDiaChi(text) }
                    }
                },
                onCancel: { showDiaChiForm = false }
            )
        }
    }

    // loading nằm NGOÀI List (không phải 1 row trong List) — trước đây đặt ProgressView làm row
    // đầu List khiến nó bị giới hạn trong chiều cao 1 row + có đường kẻ phân cách List tự vẽ bên
    // dưới, trông khác hẳn fullScreenLoading() ở mọi tab khác (phát hiện 2026-09-18 qua ảnh chụp
    // thật: cùng là loading nhưng tab Tài khoản hiện nhỏ/lệch trên, các tab khác thì giữa màn hình).
    @ViewBuilder
    private var settingsList: some View {
        if loading {
            fullScreenLoading()
        } else {
            // Thiết kế lại 09/11/2026: ScrollView + thẻ TK (TaiKhoanUI.swift) thay List — đồng bộ với thẻ hạng/bảng xếp
            // hạng và các màn con. Không còn lỗi "nhiều Button trong 1 row List" vì không dùng List nữa.
            ScrollView {
              VStack(spacing: TK.khoangCach) {
                if let vi {
                    #if DEV_LOGIN
                    // 2 nút xem trước đã dời vào icon tia chớp trên header, trước chuông (devMenu, chủ quán 09/11/2026).
                    ruongXuCard(xemTruocNgay1 ? XemTruocNgay1.vi(vi) : vi)
                    #else
                    ruongXuCard(vi)
                    #endif
                    xuCard(vi)
                    if vi.tongNo > 0 { congNoCard(vi) }
                }

                thongTinCaNhanCard
                ngaySinhCard
                danhGiaCard
              }
              .tkManHinh()
            }
            .background(Theme.bg)
            // Dựng lại cả List khi dịp đổi (card hạng, nút Nạp Xu… đều lấy màu dịp) — chỉ khi dịp THẬT SỰ đổi nên
            // mở lại app cùng dịp không bị nhảy vị trí cuộn.
            .id(themeTick)
            // Task rời: kéo làm mới đổi state làm SwiftUI huỷ task refreshable → request bị cancel → dữ liệu về rỗng.
            .refreshable { await Task { await load() }.value }
        }
    }

    /// Thay TitleBar chữ trơn — avatar+tên (nội dung card đầu tiên cũ) đưa lên chung thanh top cùng
    /// khu vực chuông/bánh răng (2026-09-18), thay vì nằm thành 1 card riêng trong danh sách bên dưới.
    /// Dòng phụ dưới tên đổi từ "Bấm vào ảnh để đổi avatar" sang địa chỉ mặc định của khách (thông
    /// tin hữu ích hơn ngay chỗ dễ thấy nhất) — sửa tên giờ bấm trực tiếp vào tên (icon bút chì), sửa
    /// địa chỉ vẫn ở card Thông tin cá nhân bên dưới như cũ.
    private var accountHeader: some View {
        HStack(spacing: 14) {
            AvatarPickerView(avatarUrl: avatarUrl, uploading: dangUploadAvatar) { data in
                Task { await uploadAvatar(data) }
            }
            VStack(alignment: .leading, spacing: 2) {
                // 19/10/2026: icon bút chì trơn sau tên khó nhận ra là "sửa tên" → nút viên thuốc có chữ.
                // Khách chưa đặt tên (tên trống / chỉ là SĐT) thì ghi "Đặt tên" để mời đặt.
                // 26/10/2026: tên dài bị "Nguyễn Ng..." vì chung hàng với nút → tên 1 hàng riêng (tối đa 2
                // dòng), nút "Sửa tên" xuống hàng dưới địa chỉ.
                Button { showEditTen = true } label: {
                    Text(Prefs.tenKhachHang ?? "Khách").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 11))
                    Text(diaChiMacDinhText).font(.system(size: 12)).lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.85))
                Button { showEditTen = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil").font(.system(size: 10, weight: .semibold))
                        Text(chuaDatTen ? "Đặt tên" : "Sửa tên").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
            #if DEV_LOGIN
            devMenu
            #endif
            notificationBell
            accountSettingsGear
        }
        .padding(.horizontal)
        .padding(.top, HeaderBarMetrics.verticalPadding)
        .padding(.bottom, HeaderBarMetrics.verticalPadding + SeasonalGarland.extraBottom)
        .frame(minHeight: HeaderBarMetrics.rowHeight)
        .background(HeaderBackground())
    }

    #if DEV_LOGIN
    /// Icon tia chớp trên header (chỉ bản dev) — gom 2 nút "Xem trước ngày 1 tháng sau" + "Xem trước dịp lễ".
    private var devMenu: some View {
        Menu {
            Button(xemTruocNgay1 ? "🧪 Tắt xem trước ngày 1" : "🧪 Xem trước ngày 1 tháng sau") { batTatXemTruocNgay1() }
                .disabled(vi == nil)
            Button(seasonalPreviewLabel) { xoayXemTruocDipLe() }
        } label: {
            Image(systemName: xemTruocNgay1 || SeasonalEvent.previewOverride != nil ? "bolt.fill" : "bolt")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
        }
        // Chữ mục menu theo màu chủ đạo — header bọc .tint(.white) (xem popupHost) sẽ làm chữ trắng vô hình.
        .tint(Theme.primary)
        .accessibilityLabel("Xem trước")
    }

    private func batTatXemTruocNgay1() {
        guard let vi else { return }
        xemTruocNgay1.toggle()
        if xemTruocNgay1 {
            quaXemTruocConLai = XemTruocNgay1.qua(vi)
            if !quaXemTruocConLai.isEmpty { chucMungXemTruoc = quaXemTruocConLai.removeFirst() }
        }
    }

    /// Bấm xoay vòng qua từng dịp rồi về "tắt" — gộp các dịp vào 1 nút.
    private func xoayXemTruocDipLe() {
        if let current = SeasonalEvent.previewOverride,
           let idx = SeasonalTheme.allCases.firstIndex(of: current),
           idx + 1 < SeasonalTheme.allCases.count {
            SeasonalEvent.previewOverride = SeasonalTheme.allCases[idx + 1]
        } else if SeasonalEvent.previewOverride == nil {
            SeasonalEvent.previewOverride = SeasonalTheme.allCases.first
        } else {
            SeasonalEvent.previewOverride = nil
        }
        Theme.applyNavBarAppearance()
        SeasonalEvent.capNhatIcon()
        seasonalPreviewTick += 1
        NotificationCenter.default.post(name: .christmasPreviewToggled, object: nil)
        Task {
            await SeasonalEvent.taiXemTruoc()
            // Màn chào của dịp vừa chọn (sau khi có câu chúc thật) — để xem trước, không đợi tới dịp.
            if SeasonalEvent.previewOverride != nil {
                NotificationCenter.default.post(name: .xemTruocSplash, object: nil)
            }
        }
    }
    #endif

    private var chuaDatTen: Bool {
        let ten = (Prefs.tenKhachHang ?? "").trimmingCharacters(in: .whitespaces)
        return ten.isEmpty || ten.allSatisfy { $0.isNumber || $0 == "+" || $0 == " " }
    }

    // Dùng diaChiHienThi thay vì diaChiList thẳng để header trên cùng luôn khớp đúng danh sách card
    // "Địa chỉ giao hàng" bên dưới đang hiện gì (từ 2026-09-24 cả 2 nơi đều hiện đầy đủ, không lọc
    // riêng nữa) — tránh lặp lại mâu thuẫn 2 chỗ hiện khác nhau như trước (phát hiện 2026-09-23).
    private var diaChiMacDinhText: String {
        (diaChiHienThi.first(where: { $0.isDefault }) ?? diaChiHienThi.first)?.diaChi ?? "Chưa có địa chỉ mặc định"
    }

    /// Mời khách đánh giá — popup đánh giá chuẩn của iOS (StoreKit requestReview), KHÔNG kèm bất kỳ
    /// quà/voucher/Xu nào (vi phạm chính sách Apple nếu gắn khuyến khích). requestReview không
    /// cần App Store id, iOS tự quyết định có hiện popup hay không (tối đa 3 lần/năm) nên không bị spam.
    /// Thẻ "Khác": chỉ còn Đánh giá App Store — chủ quán 10/11/2026 bỏ "Thể lệ Xu" khỏi thẻ này (vẫn mở được ở
    /// Tài khoản & bảo mật, màn Nạp Xu và hộp quà Ưu đãi).
    private var danhGiaCard: some View {
        VStack(spacing: 0) {
            Button { moDanhGia() } label: {
                TKDong(icon: "star.fill", mau: .yellow, tieuDe: "Đánh giá Đenn trên App Store")
            }
            .buttonStyle(.plain)
        }
        .tkThe(dem: 12)
    }

    private func moDanhGia() {
        requestReview()
    }

    /// Xu và Công nợ: 2 card riêng cùng kiểu SoDuCard với card Xu tab Ưu đãi (2026-10-26, trước gộp chung
    /// 1 card chia 2 cột). Công nợ chỉ hiện khi đang nợ.
    /// Ví Xu (09/11/2026, đổi vị trí theo chủ quán): hàng trên = số dư + "Xem chi tiết ›" (mở Lịch sử Xu) cùng kiểu thẻ
    /// Công nợ; hàng dưới = dòng "Nạp Xu" (nhãn khuyến mãi bên phải).
    private func xuCard(_ vi: KhachHangVi) -> some View {
        VStack(spacing: 0) {
            Button { showLichSuXu = true } label: {
                HStack(alignment: .center, spacing: 12) {
                    // Chủ quán 09/11/2026: icon đồng xu ảnh lạc lõng → ô icon TK (ví, cam) cùng kiểu ô icon thẻ Công nợ.
                    TKIcon(ten: "wallet.pass.fill", mau: .orange, co: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ví Xu").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                        (Text(SoDuCard.so(vi.soDu)).font(.system(size: 24, weight: .heavy, design: .rounded))
                            + Text(" Xu").font(.system(size: 14, weight: .bold)))
                            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    Text("Xem chi tiết").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
            // Chủ quán 09/11/2026: dòng Nạp Xu gom 2 bên thành 1 nút — nút gradient full ngang, nhãn "🎁 Có Xu tặng" nằm trong nút.
            Button { showNapXu = true } label: {
                HStack(spacing: 8) {
                    Text("Nạp Xu").font(.system(size: 15, weight: .bold))
                    if let nhan = vi.nhanNapXu {
                        Text(nhan)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Theme.xuTangChu)
                            .lineLimit(1)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Theme.xuTangNen))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 9)
                .background(Theme.primaryGradient)
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .tkThe(dem: 14)
        .navigationDestination(isPresented: $showLichSuXu) { LichSuViView() }
        .navigationDestination(isPresented: $showNapXu) { NapXuView(onXong: { showNapXu = false }) }
        .onChange(of: showNapXu) { dangMo in
            if !dangMo { Task { await load() } }
        }
    }

    private func congNoCard(_ vi: KhachHangVi) -> some View {
        Button { showCongNoHienTai = true } label: {
            HStack(spacing: 12) {
                TKIcon(ten: "exclamationmark.circle.fill", mau: Theme.danger, co: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Công nợ").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textMuted)
                    (Text(SoDuCard.so(vi.tongNo)).font(.system(size: 24, weight: .heavy, design: .rounded))
                        + Text(" đ").font(.system(size: 14, weight: .bold)))
                        .monospacedDigit().foregroundColor(Theme.danger)
                }
                Spacer(minLength: 8)
                Text("Xem chi tiết").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tkThe(dem: 14)
        .navigationDestination(isPresented: $showCongNoHienTai) { LichSuCongNoView() }
    }

    /// Card Điểm & Hạng thành viên đi CHUNG một card — Hạng xét theo chi tiêu THÁNG HIỆN TẠI (xem
    /// KhachHangViDto.Hang bên Backend), không liên quan Xu. Thiết kế nền tối gradient theo hạng +
    /// thanh tiến độ "còn Xđ để lên hạng Y" để tạo động lực mua thêm trong tháng (2026-09-14).
    /// Thưởng hạng bằng Xu (từ 11/2026). Freeship KHÔNG hiện trên thẻ (chủ quán 2026-11-07).
    /// Tiến độ THÁNG (chủ quán 08/11/2026): thanh chạy theo số ngày đã qua trong tháng (giờ Việt Nam), bên phải là
    /// Xu sẽ được cộng ngày 1 tháng sau = chi tiêu tháng này × 10k/300k (đơn app + đơn tại quán, backend
    /// HangKhachHang.ThuongXuTheoChiTieu → thuongXuHangHienTai).
    private static func tienDoThang(_ now: Date = Date()) -> (phanTram: Double, conLai: Int, ngayNhan: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        let ngay = cal.component(.day, from: now)
        let soNgay = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let thangSau = cal.date(byAdding: .month, value: 1, to: now).map { cal.component(.month, from: $0) } ?? 1
        return (Double(ngay) / Double(soNgay), soNgay - ngay + 1, "1/\(thangSau)")
    }

    private static let vangXu = Color(red: 1.0, green: 0.80, blue: 0.25)

    /// Cột "Đặt qua app [x2]" | "Đặt tại quầy" (10/11/2026 chủ quán: 2 cột cạnh nhau, CÙNG một style — lấy cột quầy làm
    /// chuẩn: nền xám nhạt, icon tròn trắng, nhãn + số Xu xám, dòng phụ hổ phách). App: dòng phụ "2.900 × 2" (gốc bằng mức
    /// quầy, app gấp đôi); quầy: gợi ý "Nếu đặt qua app: …". Câu chữ lấy từ backend (NoiDung).
    private func cotXuApp(_ xu: Double) -> some View {
        cotXu(icon: "iphone.gen3", nhan: NoiDung.text("theHangApp"), xu: xu, x2: true,
              phu: xu > 0 ? "\(formatSo((xu / 2).rounded(.down))) × 2" : nil)
    }

    private func cotXuQuay(_ xu: Double) -> some View {
        cotXu(icon: "storefront", nhan: NoiDung.text("theHangQuay"), xu: xu, x2: false,
              phu: xu > 0 ? NoiDung.text("theHangGoiYApp").replacingOccurrences(of: "{xu}", with: formatXu(xu * 2)) : nil)
    }

    private func cotXu(icon: String, nhan: String, xu: Double, x2: Bool, phu: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textFaint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white))
                Text(nhan)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if x2 {
                    Spacer(minLength: 0)
                    Text("x2")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.35, green: 0.22, blue: 0.0))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Self.vangXu))
                }
            }
            Text(formatXu(xu))
                .font(.system(size: 20, weight: .heavy)).monospacedDigit().foregroundColor(Theme.textMuted)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(phu ?? " ")
                .font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundColor(Theme.xuTangChu)
                .lineLimit(2).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.96)))
    }

    private func formatSo(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = "."; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }

    /// Nội dung popup ⓘ trên thẻ hạng.
    private func thongTinHang(_ vi: KhachHangVi) -> String {
        // Cách tính Xu nằm hết trong hangGhiChu ở backend (09/11/2026) — đổi tỉ lệ không phải nộp lại store.
        var dong = ["Tháng này: App \(formatXu(vi.xuDonAppThangNay ?? 0)) · Quầy \(formatXu(vi.xuDonQuayThangNay ?? 0))."]
        dong.append(NoiDung.hangGhiChu)
        return dong.joined(separator: "\n\n")
    }

    /// Thẻ RƯƠNG XU (chủ quán 09/11/2026: "xu tích thành heo đất tích tích", heo Gemini xấu → "dùng rương cũng được") — tách
    /// khỏi thẻ hạng. Ảnh rương Gemini (Assets RuongXu), đồng Xu rơi vào rương theo nhịp + rương nảy nhẹ khi nhận xu. Số lớn = Xu tích tháng này (app + quầy),
    /// "Mở rương sau X ngày" = ngày 1 tháng sau cộng vào ví. Dưới là 2 cột app ×2 | quầy (10/11/2026). ⓘ mở cách tính (Guideline 5.3.2).
    private func ruongXuCard(_ vi: KhachHangVi) -> some View {
        let t = Self.tienDoThang()
        let xuApp = vi.xuDonAppThangNay ?? vi.thuongXuHangHienTai ?? 0
        let xuQuay = vi.xuDonQuayThangNay ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            // Xu tăng so với lần xem trước → xu bay chui vào rương + số đếm chạy (RuongXuDau, TaiKhoanUI.swift).
            RuongXuDau(xu: xuApp + xuQuay, tieuDePhai: AnyView(topNhan(vi)), onInfo: { alertMessage = ("Xu tích luỹ", thongTinHang(vi)) }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 10, weight: .bold))
                    Text(NoiDung.text("ruongXuMoSau").replacingOccurrences(of: "{ngay}", with: "\(t.conLai)"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Theme.xuTangChu)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(Theme.xuTangNen))
            }
            HStack(alignment: .top, spacing: 10) {
                cotXuApp(xuApp)
                cotXuQuay(xuQuay)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .tkThe(dem: 16)
    }

    /// Nhãn Top trên thẻ Rương Xu (09/11/2026: bỏ thẻ hạng, đưa Top xuống đây). Mọi khách đều có: trong top 10 hiện "Top N",
    /// ngoài top 10 / chưa xếp hạng "Xem BXH" (10/11/2026, thay "Top ?" nghe như chưa hoàn thiện). Có giải (theo thuongXu server) thì vàng + cúp, còn lại tông chủ đạo nhạt. Chạm mở bảng xếp hạng.
    private func topNhan(_ vi: KhachHangVi) -> some View {
        Button { moBangXepHang = true } label: {
            let top = vi.topShipper ?? vi.topKhach
            let viTri = top?.viTri
            // Có giải theo server (10/11/2026: Top khách 1–10 đều có quà, shipper 1–4) — không tự đoán ngưỡng.
            let coGiai = (top?.thuongXu ?? 0) > 0
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").font(.system(size: 11, weight: .bold))
                Text(viTri.map { $0 <= 10 ? "Top \($0)" : "Xem BXH" } ?? "Xem BXH")
                    .font(.system(size: 13, weight: .heavy))
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).opacity(0.7)
            }
            .foregroundColor(coGiai ? Color(red: 0.35, green: 0.22, blue: 0.0) : Theme.primary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(coGiai ? AnyShapeStyle(Self.vangXu) : AnyShapeStyle(Theme.primaryTint)))
        }
        .buttonStyle(.plain)
    }

    /// Gộp tên hiển thị/sinh nhật/địa chỉ vào chung 1 card — trước đây là List Section trơn (chữ nền
    /// trong suốt, không viền/nền trắng) nên trông lạc nhịp so với 3 card Xu/Điểm/Công nợ phía trên.
    private var thongTinCaNhanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TKTieuDe(icon: "mappin.and.ellipse", mau: .blue, tieuDe: "Địa chỉ giao hàng") {
                Button {
                    diaChiEditingId = nil
                    diaChiFormText = ""
                    showDiaChiForm = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Thêm").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.primaryTint))
                }
                .buttonStyle(.plain)
            }

            // "Nhận quà sinh nhật" (+1 lượt quay) đã bỏ hẳn 2026-09-24 (trùng thưởng với voucher sinh
            // nhật) — card này giờ chỉ còn địa chỉ. Khai ngày sinh (cho xác minh tuổi 18+ thuốc lá)
            // nằm riêng ở MenuView. CHỈ ẨN địa chỉ nhân viên nhập (coTheXoa=false) ở ĐÚNG card này —
            // CheckoutView (chọn địa chỉ lúc đặt hàng) vẫn dùng danh sách gốc đầy đủ, không lọc theo
            // yêu cầu.
            if diaChiHienThi.isEmpty {
                Text("Chưa có địa chỉ — bấm Thêm để thêm")
                    .font(.system(size: 13)).foregroundColor(Theme.textFaint)
            } else {
                ForEach(diaChiHienThi) { item in
                    // minHeight cố định — hàng CÓ nút sửa/xoá (padding 10 quanh icon) cao hơn hẳn
                    // hàng KHÔNG có (chỉ sao + chữ), khiến VStack spacing nhìn "không đều" giữa các
                    // dòng dù spacing thật ra vẫn cố định (chỉ là bounding box mỗi hàng khác nhau).
                    HStack(alignment: .center, spacing: 8) {
                        // Icon sao rỗng/đầy thay cho ký tự "★ " chỉ có ở địa chỉ mặc định trước đây —
                        // giờ MỌI địa chỉ đều có chỗ cho icon (đầy = mặc định, rỗng = chưa). Bỏ hẳn
                        // dòng chữ "Đặt làm mặc định" cho gọn — bấm THẲNG vào icon sao rỗng để đặt
                        // làm mặc định, sao đầy thì không bấm được nữa (đã là mặc định).
                        Button {
                            if !item.isDefault { Task { await datMacDinh(item.id) } }
                        } label: {
                            Image(systemName: item.isDefault ? "star.fill" : "star")
                                .foregroundColor(item.isDefault ? Theme.primary : Theme.textFaint)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        // KHÔNG dùng .disabled: SwiftUI làm mờ label của nút disabled (sao đầy bị nhạt).
                        // allowsHitTesting chặn bấm mà giữ nguyên màu.
                        .allowsHitTesting(!item.isDefault)
                        // Bấm thẳng vào chữ địa chỉ để sửa (thay cho icon bút riêng) — chỉ khi khách
                        // tự tạo được (coTheXoa), địa chỉ nhân viên nhập chỉ xem/chọn mặc định.
                        Group {
                            if item.coTheXoa {
                                Button {
                                    diaChiEditingId = item.id
                                    diaChiFormText = item.diaChi
                                    showDiaChiForm = true
                                } label: {
                                    Text(item.diaChi).foregroundColor(.primary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(item.diaChi)
                            }
                        }
                        Spacer()
                        if item.coTheXoa {
                            Button { diaChiChoXoa = item } label: {
                                Image(systemName: "xmark").foregroundColor(Theme.danger)
                                    .padding(10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, -10)
                        }
                    }
                    .frame(minHeight: 36)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item.isDefault ? Theme.primaryTint : Theme.bg))
                }
            }
        }
        .tkThe()
    }


    /// Card khai ngày sinh — cùng dữ liệu/API với MenuView (xác minh tuổi thuốc lá), thêm ở đây để
    /// khách khai được ngay từ tab Tài khoản thay vì phải chờ mua sản phẩm thuốc lá mới thấy form.
    /// Cho tự SỬA lại (không chỉ khai lần đầu) miễn CHƯA nhận voucher sinh nhật trong năm nay
    /// (ngaySinhInfo.coTheSua, xem GamificationService.CapNhatNgaySinhAsync) — chặn đúng lúc đã ăn
    /// quà năm nay mới là ăn gian đổi ngày sinh để canh trúng tháng, còn lại (nhập sai lúc đầu, hoặc
    /// chưa tới lượt nhận quà năm nay) không cần làm khó khách phải nhờ nhân viên.
    private var ngaySinhCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TKTieuDe(icon: "gift.fill", mau: .pink, tieuDe: "Ngày sinh")

            if loadingNgaySinh {
                ProgressView()
            } else if let ns = ngaySinhInfo?.ngaySinh, ngaySinhInfo?.coTheSua == false {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Sinh nhật: \(formatNgaySinh(ns))", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13)).foregroundColor(Theme.success)
                    Text(NoiDung.text("sinhNhatDaNhan"))
                        .font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
                .padding(.leading, 40)
            } else if !showDobPicker {
                // Thu gọn mặc định — wheel chiếm rất nhiều chỗ dọc, chỉ bung ra khi bấm (feedback
                // 2026-09-27: "bao giờ bấm mới hiện cái này ra chứ", trước hiện thẳng luôn).
                HStack {
                    if let ns = ngaySinhInfo?.ngaySinh {
                        Label("Sinh nhật: \(formatNgaySinh(ns))", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13)).foregroundColor(Theme.success)
                    } else {
                        Text("Chưa nhập").font(.system(size: 13)).foregroundColor(Theme.textFaint)
                    }
                    Spacer()
                    Button { showDobPicker = true } label: {
                        Text(ngaySinhInfo?.ngaySinh == nil ? "Nhập ngay" : "Sửa")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(Theme.primaryTint))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 40)
            } else {
                // .wheel thay cho style mặc định (.compact) — trước đây bấm vào mở lịch dạng LƯỚI
                // NGÀY-TRONG-THÁNG (graphical), phải bấm header "tháng 9 năm 1991" thêm 1 lần mới ra
                // được bộ chọn nhanh, rất khó chọn năm sinh xa (feedback kèm ảnh chụp 2026-09-27:
                // "cho calendar hiển thị ngày tháng năm, bỏ qua calendar lịch trong tháng"). Wheel hiện
                // sẵn 3 cột ngày/tháng/năm cuộn thẳng, không qua bước lịch lưới nào cả.
                DatePicker("", selection: $dobPicked, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(maxHeight: 140)
                    .clipped()
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                HStack(spacing: 10) {
                    Button { showDobPicker = false; dobError = nil } label: {
                        Text("Huỷ").font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(Theme.bg))
                    }
                    .buttonStyle(.plain)
                    .disabled(savingDob)
                    Button {
                        Task { await xacNhanNgaySinh() }
                    } label: {
                        Group { if savingDob { ProgressView().tint(.white) } else { Text("Lưu").font(.system(size: 15, weight: .bold)) } }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(Theme.primaryGradient))
                    }
                    .buttonStyle(.plain)
                    .disabled(savingDob)
                }
                if let dobError {
                    Text(dobError).font(.system(size: 12)).foregroundColor(Theme.danger)
                }
            }
        }
        .tkThe()
    }

    private func formatNgaySinh(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let date = formatter.date(from: String(iso.prefix(10))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "dd/MM/yyyy"
        return out.string(from: date)
    }

    private func xacNhanNgaySinh() async {
        dobError = nil
        savingDob = true
        defer { savingDob = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = formatter.string(from: dobPicked)
        let result = await APIClient.shared.capNhatNgaySinh(iso)
        if result.success {
            ngaySinhInfo = await APIClient.shared.getSinhNhat()
            showDobPicker = false
        } else {
            dobError = result.message ?? "Lưu ngày sinh thất bại, thử lại."
        }
    }

    private func statBox(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.primary)
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func load() async {
        loadingNgaySinh = ngaySinhInfo == nil
        async let diaChiTask = APIClient.shared.getDiaChiListOpt()
        async let viTask = APIClient.shared.getVi()
        async let ngaySinhTask = APIClient.shared.getSinhNhat()
        let (dc, viMoi, ns) = await (diaChiTask, viTask, ngaySinhTask)
        // 09/11/2026 (ảnh chụp chủ quán): lần mở đầu đôi khi ví trả nil (mạng/phiên chưa sẵn) → tab mất thẻ hạng/Ví Xu/
        // Công nợ tới khi kéo làm mới. Thử lại tối đa 2 lần; lỗi thì GIỮ dữ liệu cũ, không xoá về rỗng.
        var viTai = viMoi
        var lan = 0
        while viTai == nil && lan < 2 && !Task.isCancelled {
            lan += 1
            try? await Task.sleep(nanoseconds: 800_000_000)
            viTai = await APIClient.shared.getVi()
        }
        if let viTai { vi = viTai }
        // Địa chỉ lỗi (nil) → giữ danh sách cũ; thử lại 1 lần trước khi bỏ cuộc.
        var dcTai = dc
        if dcTai == nil { dcTai = await APIClient.shared.getDiaChiListOpt() }
        if let dcTai { diaChiList = dcTai }
        if ns != nil { ngaySinhInfo = ns }
        if let hang = vi?.hang { KhachHangSession.shared.capNhatHang(hang) }
        // Nạp sẵn DatePicker theo đúng ngày sinh đã khai (nếu có) — để lúc mở form sửa (coTheSua=true)
        // khách thấy đúng ngày cũ thay vì luôn nhảy về mặc định "18 năm trước".
        if let ns = ngaySinhInfo?.ngaySinh {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
            if let parsed = formatter.date(from: String(ns.prefix(10))) { dobPicked = parsed }
        }
        loadingNgaySinh = false
        loading = false
        luuBoNhoTam()
    }

    private func luuBoNhoTam() {
        if let vi { BoNhoTam.vi = vi }
        BoNhoTam.diaChiList = diaChiList
        if let ngaySinhInfo { BoNhoTam.ngaySinhInfo = ngaySinhInfo }
    }


    private func uploadAvatar(_ data: Data) async {
        dangUploadAvatar = true
        defer { dangUploadAvatar = false }
        let (url, message) = await APIClient.shared.uploadAvatar(imageData: data)
        if let url {
            // Backend giữ nguyên tên file (id.ext) mỗi lần đổi avatar nên URL không đổi — gắn query
            // cache-bust để AsyncImage tải lại ngay, không phải thoát app mở lại mới thấy ảnh mới
            // (cùng bug đã gặp ở màn Ảnh menu bên AppQuanLyIOS).
            let bustedUrl = url + "?v=\(Int(Date().timeIntervalSince1970))"
            avatarUrl = bustedUrl
            Prefs.avatarUrl = bustedUrl
        } else {
            alertMessage = ("Lỗi", message ?? "")
        }
    }

    private func luuTenHienThi() async {
        let ten = tenHienThi.trimmingCharacters(in: .whitespaces)
        dangLuuTen = true
        defer { dangLuuTen = false }
        let res = await APIClient.shared.capNhatTenHienThi(ten.isEmpty ? nil : ten)
        if res.success {
            Prefs.tenKhachHang = ten.isEmpty ? nil : ten
            tenHienThi = ten
        } else {
            alertMessage = ("Lỗi", res.message ?? "")
        }
    }

    private func themDiaChi(_ diaChi: String) async {
        let result = await APIClient.shared.themDiaChi(diaChi)
        if result.success {
            diaChiList = await APIClient.shared.getDiaChiList()
        } else {
            alertMessage = ("Lỗi", result.message ?? "")
        }
    }

    private func suaDiaChi(_ id: String, diaChi: String) async {
        let result = await APIClient.shared.suaDiaChi(id, diaChi: diaChi)
        if result.success {
            diaChiList = await APIClient.shared.getDiaChiList()
        } else {
            alertMessage = ("Lỗi", result.message ?? "")
        }
    }

    private func xoaDiaChi(_ id: String) async {
        let result = await APIClient.shared.xoaDiaChi(id)
        if result.success { diaChiList.removeAll { $0.id == id } }
    }

    private func datMacDinh(_ id: String) async {
        let result = await APIClient.shared.datDiaChiMacDinh(id)
        if result.success {
            diaChiList = diaChiList.map { DiaChiKhachHang(id: $0.id, diaChi: $0.diaChi, isDefault: $0.id == id, lat: $0.lat, long: $0.long, coTheXoa: $0.coTheXoa) }
        }
    }
}

#if DEV_LOGIN
/// CHỈ bản dev (9.9.0): giả lập thẻ hạng + màn chúc mừng như khách sẽ thấy ngày 1 tháng sau — chi tiêu
/// tháng mới về 0 (hạng Thành Viên), hạng tháng này thành "hạng tháng trước", nhận Xu thưởng theo hạng đó
/// (khớp GetViAsync + ThuongHangThangService bên Backend). Dựng qua JSON vì KhachHangVi toàn `let`.
enum XemTruocNgay1 {
    /// Màn chúc mừng như ngày 1: quà hạng theo hạng hiện tại + (shipper) quà Top theo vị trí hiện tại.
    static func qua(_ v: KhachHangVi) -> [QuaChucMung] {
        var json: [String: Any] = [
            "soDu": 0, "diemThangNay": 0, "diemThangTruoc": 0, "duocNhanVoucher": false, "daNhanVoucher": false,
            "tongNo": 0, "tongChiTieuThangNay": 0, "hang": "Thành Viên", "hangThangTruoc": "", "yeuThichSanPhamIds": [String](), "conLaiDeLenHang": 0, "phanTramTienDoLenHang": 0,
        ]
        if let h = choNhanHang(v) { json["thuongHangThang"] = h }
        if let t = v.topShipper, t.thuongXu > 0 {
            json["thuongTopShipper"] = ["viTri": t.viTri, "thangDat": thangNay(), "soXu": t.thuongXu, "daNhan": false] as [String: Any]
        }
        if let t = v.topKhach, t.thuongXu > 0 {
            json["thuongTopKhach"] = ["viTri": t.viTri, "thangDat": thangNay(), "soXu": t.thuongXu, "daNhan": false] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let gia = try? JSONDecoder().decode(KhachHangVi.self, from: data) else { return [] }
        return ChucMungHang.quaCho(gia)
    }

    private static func thangNay() -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: Date())
        return "\(c.month!)/\(c.year!)"
    }

    private static func choNhanHang(_ v: KhachHangVi) -> [String: Any]? {
        guard let xu = v.thuongXuHangHienTai, xu > 0, let t = vi(v).thuongHangThang else { return nil }
        return ["id": t.id, "hang": t.hang, "thangDat": t.thangDat, "soXu": xu, "conLai": xu, "hetHan": t.hetHan, "daNhan": false]
    }

    static func vi(_ v: KhachHangVi) -> KhachHangVi {
        let cal = Calendar(identifier: .gregorian)
        let dauThangSau = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: Date()))!)!
        let cuoiThangSau = cal.date(byAdding: DateComponents(month: 1, day: -1), to: dauThangSau)!
        let c = cal.dateComponents([.year, .month, .day], from: cuoiThangSau)
        let homNay = cal.dateComponents([.year, .month], from: Date())
        let xu = v.thuongXuHangHienTai ?? 0
        var json: [String: Any] = [
            "soDu": v.soDu + xu, "diemThangNay": 0, "diemThangTruoc": v.diemThangNay,
            "duocNhanVoucher": v.duocNhanVoucher, "daNhanVoucher": v.daNhanVoucher, "tongNo": v.tongNo,
            "laShipper": v.laShipper ?? false, "tongChiTieuThangNay": 0,
            "hang": "Thành Viên", "hangThangTruoc": v.hang, "hangTiepTheo": "Bạc",
            "conLaiDeLenHang": 300000, "phanTramTienDoLenHang": 0,
            "thuongXuHangHienTai": 0, "thuongXuHangTiepTheo": 10000,
            "yeuThichSanPhamIds": v.yeuThichSanPhamIds,
        ]
        if let mienShip = v.mienShipThangSau { json["mienShip"] = mienShip }
        if xu > 0 {
            json["thuongHangThang"] = [
                "id": "xem-truoc-\(UUID().uuidString)", "hang": v.hang,
                "thangDat": "\(homNay.month!)/\(homNay.year!)", "soXu": xu, "conLai": xu,
                "hetHan": String(format: "%04d-%02d-%02dT00:00:00", c.year!, c.month!, c.day!),
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let gia = try? JSONDecoder().decode(KhachHangVi.self, from: data) else { return v }
        return gia
    }
}
#endif
