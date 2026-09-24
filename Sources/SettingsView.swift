import SwiftUI

/// Port từ SettingsScreen.tsx — ví/hạng thành viên, địa chỉ đã lưu. Các thao tác bảo mật/tài khoản
/// (đổi mật khẩu, thiết bị đăng nhập, đăng xuất, xoá tài khoản) đã tách sang TaiKhoanBaoMatView,
/// mở qua icon bánh răng ở MainTabView (chỉ hiện khi đang ở tab này) — tránh trộn với ví/địa chỉ.
struct SettingsView: View {
    @Binding var isLoggedIn: Bool
    var notificationBell: AnyView
    var accountSettingsGear: AnyView

    @Environment(\.openURL) private var openURL

    @State private var diaChiList: [DiaChiKhachHang] = []
    // Hiện ĐẦY ĐỦ cả địa chỉ nhân viên nhập qua Desktop lẫn khách tự thêm (đổi lại 2026-09-24 — trước
    // đó từng ẩn hẳn địa chỉ nhân viên ở card này, nhưng khách mới cài app lần đầu nhìn thấy trống dù
    // quán đã có sẵn địa chỉ từ lịch sử đặt hàng, gây cảm giác thiếu sót). Nút sửa/xoá vẫn tự ẩn với
    // địa chỉ nhân viên nhập qua `item.coTheXoa` bên dưới — khách chỉ được XEM/CHỌN mặc định, không
    // sửa/xoá được địa chỉ không phải do mình tạo.
    private var diaChiHienThi: [DiaChiKhachHang] { diaChiList }
    @State private var vi: KhachHangVi?
    @State private var loading = true

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
    @State private var showCongNoHienTai = false

    // Gradient tối + màu đặc trưng từng hạng — khớp phong cách thẻ hạng thành viên các app lớn
    // (Shopee/ShopBack: nền tối, chữ nổi bật) thay vì badge nhỏ trên nền trắng như trước. Lấy từ
    // Theme.hangColors (2026-09-16) — cùng 1 nguồn màu với Theme.primary/primaryDark toàn app, tránh
    // 2 nơi định nghĩa lệch nhau.
    private var hangGradient: [String: [Color]] {
        Theme.hangColors.mapValues { [$0.primary, $0.dark] }
    }
    private let hangIcon: [String: String] = [
        "Kim Cương": "💎", "Vàng": "🥇", "Bạc": "🥈", "Thành Viên": "🌱",
    ]

    var body: some View {
        VStack(spacing: 0) {
            accountHeader
            settingsList
        }
        // Xu và Công nợ nằm CHUNG 1 row của List (2 Button sibling trong xuCongNoCard). ROOT CAUSE
        // THẬT SỰ (sau 2 lần sửa sai hướng ở tầng navigationDestination/state): List coi row có nhiều
        // Button mặc định là "1 vùng chạm", chỉ route gesture cho 1 control — bấm nút đầu vẫn kích
        // hoạt nút cuối. Fix đúng nằm ở .buttonStyle(.plain) trên từng Button (xem xuContent/
        // congNoContent), không phải ở navigationDestination — giữ nguyên 2 modifier tách theo subview
        // (fix 2026-09-23 lần 2) vì đúng hướng, chỉ thiếu buttonStyle (fix 2026-09-23 lần 3, ĐÃ XONG).
        .task { await load() }
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
        .alert(diaChiEditingId == nil ? "Thêm địa chỉ" : "Sửa địa chỉ", isPresented: $showDiaChiForm) {
            TextField("Địa chỉ giao hàng", text: $diaChiFormText)
            Button("Lưu") {
                let text = diaChiFormText.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                if let id = diaChiEditingId {
                    Task { await suaDiaChi(id, diaChi: text) }
                } else {
                    Task { await themDiaChi(text) }
                }
            }
            Button("Huỷ", role: .cancel) {}
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
            List {
                if let vi {
                    cardRow(topExtra: 6) { diemHangCard(vi) }
                    cardRow { xuCongNoCard(vi) }
                }

                cardRow { thongTinCaNhanCard }
                cardRow { danhGiaCard }
            }
            .cardListBackground()
            .refreshable { await load() }
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
                Button { showEditTen = true } label: {
                    HStack(spacing: 4) {
                        Text(Prefs.tenKhachHang ?? "Khách").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        Image(systemName: "pencil").font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 11))
                    Text(diaChiMacDinhText).font(.system(size: 12)).lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            notificationBell
            accountSettingsGear
        }
        .padding(.horizontal)
        .padding(.vertical, HeaderBarMetrics.verticalPadding)
        .frame(minHeight: HeaderBarMetrics.rowHeight)
        .background(Theme.primaryGradient.ignoresSafeArea(edges: .top))
    }

    // Dùng diaChiHienThi thay vì diaChiList thẳng để header trên cùng luôn khớp đúng danh sách card
    // "Địa chỉ giao hàng" bên dưới đang hiện gì (từ 2026-09-24 cả 2 nơi đều hiện đầy đủ, không lọc
    // riêng nữa) — tránh lặp lại mâu thuẫn 2 chỗ hiện khác nhau như trước (phát hiện 2026-09-23).
    private var diaChiMacDinhText: String {
        (diaChiHienThi.first(where: { $0.isDefault }) ?? diaChiHienThi.first)?.diaChi ?? "Chưa có địa chỉ mặc định"
    }

    // ID số của app trên App Store — CHƯA CÓ THẬT vì app hiện chỉ phân phối qua Sideloadly (xem
    // README), chưa publish lên store. Thay giá trị này khi app thật sự lên App Store, lấy từ URL
    // trang app trong App Store Connect (dạng id1234567890).
    private static let appStoreId = "TODO_APP_STORE_ID"

    /// Mời khách đánh giá — CHỈ mở trang App Store trung lập, KHÔNG kèm bất kỳ quà/voucher/Xu nào
    /// (vi phạm chính sách Apple nếu gắn khuyến khích, và cũng không có API verify ai đã đánh giá).
    private var danhGiaCard: some View {
        cardBox {
            HStack {
                Text("⭐ Thích ứng dụng Đenn?").font(.system(size: 14, weight: .bold))
                Spacer()
            }
            Text("Để lại vài dòng đánh giá giúp Đenn cải thiện app tốt hơn nhé!")
                .font(.system(size: 12)).foregroundColor(Theme.textFaint)
            Button {
                moDanhGia()
            } label: {
                HStack {
                    Text("Đánh giá trên App Store").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Theme.textFaint)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func moDanhGia() {
        guard let url = URL(string: "https://apps.apple.com/app/\(Self.appStoreId)?action=write-review") else { return }
        openURL(url)
    }

    /// Xu (điểm thưởng quy đổi đơn hàng) + Công nợ gộp CHUNG 1 card (2026-09-18, trước là 2 card
    /// riêng) — Xu bên trái, Công nợ bên phải ngăn bởi Divider dọc; khách không có công nợ thì Xu
    /// chiếm trọn card (không có Divider/cột phải).
    private func xuCongNoCard(_ vi: KhachHangVi) -> some View {
        cardBox {
            HStack(alignment: .top, spacing: 16) {
                xuContent(vi)
                if vi.tongNo > 0 {
                    Divider()
                    congNoContent(vi)
                }
            }
        }
    }

    private func xuContent(_ vi: KhachHangVi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Xu khả dụng").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
            Text(formatXu(vi.soDu)).font(.system(size: 24, weight: .bold))
            // Đổi NavigationLink -> Button + state (2026-09-22 tối, xem comment ở navigationDestination
            // phía trên) — không còn tự vẽ chevron, nhưng đây là link dạng text nên vẫn không cần thêm.
            // .buttonStyle(.plain) LÀ CHỖ SAI THẬT SỰ (fix 2026-09-23 lần 3, sau 2 lần đổi kiến trúc
            // navigation không trúng): 2 Button mặc định (không set style) trong CÙNG 1 row của List
            // bị chính List "nuốt" gesture — List coi cả row là 1 vùng chạm và chỉ route tới ĐÚNG 1
            // control bên trong (thường là control cuối cùng), nên bấm nút đầu (Lịch sử Xu) vẫn kích
            // hoạt action của nút sau (Công nợ). .buttonStyle(.plain) tắt hành vi "hàng-là-1-nút" đó
            // của List, trả lại gesture riêng cho từng Button. Đây là bug List quen thuộc của SwiftUI,
            // không phải lỗi ở tầng navigationDestination như 2 lần sửa trước đoán.
            Button { showLichSuXu = true } label: {
                Text("Lịch sử Xu").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationDestination(isPresented: $showLichSuXu) { LichSuViView() }
    }

    private func congNoContent(_ vi: KhachHangVi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Công nợ hiện tại").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textMuted)
            Text(formatTien(vi.tongNo)).font(.system(size: 24, weight: .bold)).foregroundColor(Theme.danger)
            Button { showCongNoHienTai = true } label: {
                Text("Xem chi tiết").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationDestination(isPresented: $showCongNoHienTai) { LichSuCongNoView() }
    }

    /// Card Điểm & Hạng thành viên đi CHUNG một card — Hạng xét theo chi tiêu THÁNG HIỆN TẠI (xem
    /// KhachHangViDto.Hang bên Backend), không liên quan Xu. Thiết kế nền tối gradient theo hạng +
    /// thanh tiến độ "còn Xđ để lên hạng Y" để tạo động lực mua thêm trong tháng (2026-09-14).
    private func diemHangCard(_ vi: KhachHangVi) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HẠNG THÀNH VIÊN")
                        .font(.system(size: 10, weight: .bold)).tracking(1.2)
                        // 0.65 -> 0.78: feedback "text phụ nhỏ màu xám nhạt trên card xanh hơi chìm"
                        // — chữ nhỏ 10pt cần độ tương phản cao hơn văn bản thường để vẫn đọc rõ.
                        .foregroundColor(.white.opacity(0.78))
                    Text("\(hangIcon[vi.hang] ?? "🌱") \(vi.hang)")
                        .font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                }
                Spacer()
            }

            if let hangTiepTheo = vi.hangTiepTheo {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2))
                            Capsule().fill(Color.white)
                                .frame(width: max(8, geo.size.width * vi.phanTramTienDoLenHang))
                        }
                    }
                    .frame(height: 6)
                    // Câu đơn giản thay hẳn cặp nhãn voucher 2 đầu thanh (feedback 2026-09-23 lần 3:
                    // "hơi khó hiểu và nhiều icon quá") — bỏ luôn 2 voucherEndpoint ở đây, chỉ còn
                    // đúng 1 câu số tiền + tên hạng, dễ hiểu ngay không cần suy luận qua vị trí.
                    Text("Cần chi tiêu thêm \(formatTien(vi.conLaiDeLenHang)) để lên hạng \(hangTiepTheo)")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                }
            } else {
                Text("🎉 Hạng cao nhất")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.85))
            }

            // Backend trả -1 (sentinel, xem HoaDonCustomerInfoService) khi khách bị khoá
            // DuocNhanVoucher — hiện tại chỉ 1 số khách được bật (chờ app lên App Store chính thức
            // mới bật cho TẤT CẢ, xem project_voucher_system_2026_09 trong memory). Ẩn hẳn 2 ô điểm
            // thay vì hiện "-1" gây hiểu lầm (phát hiện 2026-09-18 qua ảnh chụp thật).
            // Bỏ icon hạng ở 2 ô điểm (feedback 2026-09-23: "hơi khó hiểu và nhiều icon quá") — card
            // đã có 2 icon hạng ở dòng tiến độ ngay trên rồi, thêm nữa ở đây gây rối không cần thiết.
            if vi.diemThangNay >= 0 {
                HStack(spacing: 12) {
                    statBoxDark(String(format: "%.0f", vi.diemThangNay / 10), "Điểm tháng này")
                    statBoxDark(String(format: "%.0f", vi.diemThangTruoc / 10), "Điểm tháng trước")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: hangGradient[vi.hang] ?? [Theme.primary, Theme.primaryDark],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    /// Gộp tên hiển thị/sinh nhật/địa chỉ vào chung 1 card — trước đây là List Section trơn (chữ nền
    /// trong suốt, không viền/nền trắng) nên trông lạc nhịp so với 3 card Xu/Điểm/Công nợ phía trên.
    private var thongTinCaNhanCard: some View {
        cardBox {
            HStack {
                Text("Địa chỉ giao hàng").font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    diaChiEditingId = nil
                    diaChiFormText = ""
                    showDiaChiForm = true
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
            }
            Divider()

            // "Nhận quà sinh nhật" (+1 lượt quay) đã bỏ hẳn 2026-09-24 (trùng thưởng với voucher sinh
            // nhật) — card này giờ chỉ còn địa chỉ. Khai ngày sinh (cho xác minh tuổi 18+ thuốc lá)
            // nằm riêng ở MenuView. CHỈ ẨN địa chỉ nhân viên nhập (coTheXoa=false) ở ĐÚNG card này —
            // CheckoutView (chọn địa chỉ lúc đặt hàng) vẫn dùng danh sách gốc đầy đủ, không lọc theo
            // yêu cầu.
            if diaChiHienThi.isEmpty {
                Text("Chưa có địa chỉ nào — bấm + để thêm, hoặc nhập ở bước đặt hàng sẽ tự lưu lại.")
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
                        .disabled(item.isDefault)
                        Text(item.diaChi)
                        Spacer()
                        if item.coTheXoa {
                            // 2 nút icon nhỏ đứng sát nhau dễ bấm nhầm — nới padding quanh mỗi icon
                            // (vùng chạm thật lớn hơn hẳn kích thước glyph, gần chuẩn 44pt của Apple
                            // HIG mà không đội hẳn chiều cao dòng lên 44) và giãn spacing riêng giữa
                            // 2 nút xa hơn spacing chung của HStack ngoài.
                            HStack(spacing: 12) {
                                Button {
                                    diaChiEditingId = item.id
                                    diaChiFormText = item.diaChi
                                    showDiaChiForm = true
                                } label: {
                                    Image(systemName: "pencil").foregroundColor(Theme.textFaint)
                                        .padding(10).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button { diaChiChoXoa = item } label: {
                                    Image(systemName: "xmark").foregroundColor(Theme.danger)
                                        .padding(10).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.trailing, -10)
                        }
                    }
                    .frame(minHeight: 36)
                }
            }
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

    /// Biến thể statBox cho nền tối (diemHangCard) — chữ trắng thay vì Theme.primary/textMuted vốn
    /// chỉ đọc được trên nền sáng. `icon` = icon hạng tháng tương ứng (hangIcon[...]), đặt SAU điểm
    /// cho gọn thay vì thêm hẳn 1 dòng chữ hạng riêng.
    private func statBoxDark(_ value: String, _ label: String, icon: String? = nil) -> some View {
        VStack {
            HStack(spacing: 4) {
                Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                if let icon { Text(icon).font(.system(size: 13)) }
            }
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func load() async {
        async let diaChiTask = APIClient.shared.getDiaChiList()
        async let viTask = APIClient.shared.getVi()
        (diaChiList, vi) = await (diaChiTask, viTask)
        if let hang = vi?.hang { KhachHangSession.shared.capNhatHang(hang) }
        loading = false
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
