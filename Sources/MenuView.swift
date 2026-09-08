import SwiftUI

/// Port từ MenuScreen.tsx (bản RN cũ), sau đó đổi sang layout sidebar 2 cột (cột trái = nhóm,
/// cột phải = món) theo chuẩn app trà sữa/cà phê Việt Nam (Phúc Long, ToCoToco, Gong Cha...) —
/// hợp hơn Section cuộn dọc hay chip ngang khi có ~17 nhóm. Modal chọn size/topping/ghi chú →
/// .sheet(), tìm không dấu qua timKiem đã chuẩn hoá sẵn từ server.
struct MenuView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    @Binding var selectedTab: AppTab

    @State private var loading = true
    @State private var error = ""
    @State private var sanPhams: [SanPham] = []
    @State private var nhoms: [NhomSanPham] = []
    @State private var toppings: [Topping] = []
    @State private var query = ""
    @State private var picking: SanPham?
    @State private var selectedNhomId: String = ""
    @State private var monHayMua: [FavoriteItem] = []

    /// Nhớ mục khách chọn lần cuối — mở app lại vào thẳng mục đó thay vì luôn về nhóm đầu tiên.
    private static let selectedNhomKey = "menu.selectedNhomId"

    private func normalizeVN(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d", options: .caseInsensitive)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    /// true khi đang gõ tìm kiếm — chuyển sang danh sách phẳng xuyên nhóm, ẩn sidebar (kết quả
    /// có thể nằm ở nhiều nhóm khác nhau nên bó theo 1 nhóm đang chọn không hợp lý lúc này).
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var searchResults: [SanPham] {
        let q = normalizeVN(query)
        return sanPhams.filter { ($0.timKiem ?? normalizeVN($0.ten)).lowercased().contains(q) }
    }

    /// Nhóm lặt vặt/ít món — gom chung 1 mục "#" đặt cuối sidebar thay vì mỗi nhóm 1 dòng riêng
    /// chiếm chỗ cột trái.
    private static let nhomGomChung: Set<String> = ["Ăn Vặt", "Khác", "Nước Lon", "Thuốc lá"]

    /// SF Symbol cho từng nhóm sidebar, khớp Ten thật trong bảng NhomSanPhams (VPS, 8/9) — nhóm nào
    /// không có trong map (mở rộng sau này) rơi về defaultNhomIcon. Cố ý chọn khác nhau cho từng
    /// nhóm hiện diện riêng ở sidebar (4 nhóm gom chung vào "#Khác" không cần phân biệt nên vẫn để
    /// trùng thoải mái) — dùng cả biến thể outline (không .fill) để đủ icon phân biệt vì SF Symbols
    /// không có đủ icon "đúng nghĩa đồ uống" cho từng loại, ưu tiên phân biệt hình dạng hơn khớp
    /// nghĩa 100%.
    private static let nhomIcons: [String: String] = [
        "Ăn Vặt": "fork.knife",
        "Bạc Xỉu": "mug.fill",
        "Ca Cao": "mug",
        "Cà Phê": "cup.and.saucer.fill",
        "Đá Xay": "snowflake",
        "Khác": "ellipsis.circle",
        "Latte": "cup.and.saucer",
        "Nước Ép": "carrot.fill",
        "Nước Lon": "shippingbox.fill",
        "Sinh Tố": "drop.fill",
        "Soda": "wineglass.fill",
        "Sữa Chua": "shippingbox.fill",
        "Sữa Tươi": "takeoutbag.and.cup.and.straw",
        "Thuốc lá": "exclamationmark.triangle.fill",
        "Trà": "leaf.circle.fill",
        "Trà Hiện Đại": "leaf",
        "Trà Sữa": "takeoutbag.and.cup.and.straw.fill",
        "Trà Truyền Thống": "leaf.fill",
        "Yêu thích": "heart.fill",
    ]
    private static let defaultNhomIcon = "circle.grid.2x2.fill"
    private static let yeuThichNhomId = "yeu-thich"

    /// Món khớp monHayMua (3 món khách mua nhiều nhất, từ /dat-hang/vi — cùng nguồn dữ liệu tab Cài
    /// đặt đang hiện "Hay gọi") — chỉ khớp theo TÊN sản phẩm vì backend không trả kèm id, khớp cả
    /// khi không tìm thấy biến thể tương ứng (mở picker vẫn chọn được size khác). Giữ thứ tự theo
    /// monHayMua, loại trùng nếu 1 sản phẩm xuất hiện ở nhiều biến thể trong danh sách yêu thích.
    private var favoriteSanPhams: [SanPham] {
        var seen = Set<String>()
        var result: [SanPham] = []
        for fav in monHayMua {
            guard let sp = sanPhams.first(where: { $0.ten == fav.tenSanPham }), !seen.contains(sp.id) else { continue }
            seen.insert(sp.id)
            result.append(sp)
        }
        return result
    }

    /// Toàn bộ nhóm có món (không lọc theo tìm kiếm) — nguồn cho sidebar, luôn hiện đủ để bấm
    /// chuyển nhóm bất kể đang lọc gì ở cột phải.
    private var sections: [(nhom: NhomSanPham, items: [SanPham])] {
        var byNhom: [String: [SanPham]] = [:]
        for sp in sanPhams { byNhom[sp.nhomSanPhamId ?? "", default: []].append(sp) }

        var gomChung: [SanPham] = byNhom[""] ?? []
        var result: [(nhom: NhomSanPham, items: [SanPham])] = []
        for nhom in nhoms {
            guard let items = byNhom[nhom.id] else { continue }
            if Self.nhomGomChung.contains(nhom.ten) {
                gomChung.append(contentsOf: items)
            } else {
                result.append((nhom: nhom, items: items))
            }
        }
        result.sort { $0.nhom.ten.localizedStandardCompare($1.nhom.ten) == .orderedAscending }

        if !gomChung.isEmpty {
            result.append((nhom: NhomSanPham(id: "#", ten: "Khác"), items: gomChung))
        }

        let favs = favoriteSanPhams
        if !favs.isEmpty {
            result.insert((nhom: NhomSanPham(id: Self.yeuThichNhomId, ten: "Yêu thích"), items: favs), at: 0)
        }
        return result
    }

    private var selectedItems: [SanPham] {
        sections.first(where: { $0.nhom.id == selectedNhomId })?.items ?? []
    }

    /// Theo quy định pháp luật, thuốc lá chỉ bán cho người từ 18 tuổi trở lên — dùng để bật cảnh
    /// báo + bắt xác nhận độ tuổi trước khi thêm giỏ ở ProductPickerSheet.
    private var thuocLaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Thuốc lá" }.map(\.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thanh tìm kiếm gradient tràn lên status bar — khớp DaySearchBar(tinted: true) của
            // tab Hoá đơn bên AppQuanLyIOS, thay .searchable() hệ thống (khác style, thụt xuống
            // dưới navigationTitle).
            SearchBar(text: $query, placeholder: "Tìm món...")

            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !error.isEmpty {
                    VStack(spacing: 12) {
                        Text(error).foregroundColor(Theme.danger)
                        Button("Thử lại") { Task { await load() } }
                            .buttonStyle(.borderedProminent).tint(Theme.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSearching {
                    List(searchResults) { sp in productRow(sp) }
                        .listStyle(.plain)
                } else {
                    VStack(spacing: 0) {
                        // Ly Bí Mật tạm ẩn (2026-09-08) — đang cân nhắc lại luồng gộp chung giỏ
                        // hàng thay vì tạo đơn riêng ngay khi bốc, xem lyBiMatBanner bên dưới.

                        HStack(spacing: 0) {
                            nhomSidebar
                            Divider()
                            List { ForEach(selectedItems) { sp in productRow(sp) } }
                                .listStyle(.plain)
                                .id(selectedNhomId)
                        }
                    }
                    .refreshable { await load(silent: true) }
                }
            }
        }
        .task { if sanPhams.isEmpty { await load() } }
        .sheet(item: $picking) { sp in
            ProductPickerSheet(
                sanPham: sp,
                toppings: toppings,
                cart: cart,
                isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? "")
            ) { picking = nil }
        }
    }

    private var lyBiMatBanner: some View {
        Button {
            path.append(.lyBiMat)
        } label: {
            HStack(spacing: 10) {
                Text("🎁").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ly Bí Mật — chỉ 25.000đ").font(.system(size: 14, weight: .bold)).foregroundColor(Color(red: 0.54, green: 0.33, blue: 0)).multilineTextAlignment(.leading)
                    Text("Bốc ngẫu nhiên 1 món, có thể trúng món giá cao hơn nhiều!").font(.system(size: 11)).foregroundColor(Color(red: 0.64, green: 0.44, blue: 0.18)).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Color(red: 0.72, green: 0.53, blue: 0.04))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(red: 1, green: 0.953, blue: 0.878))
        }
        .buttonStyle(.plain)
    }

    /// Cột trái: danh sách nhóm cố định, bấm chọn thì cột phải đổi danh sách món — khớp trải
    /// nghiệm quen thuộc của khách hàng trà sữa/cà phê thay vì cuộn dọc qua từng Section.
    private var nhomSidebar: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sections, id: \.nhom.id) { section in
                    let isSelected = section.nhom.id == selectedNhomId
                    Button {
                        selectedNhomId = section.nhom.id
                        UserDefaults.standard.set(section.nhom.id, forKey: Self.selectedNhomKey)
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(isSelected ? Theme.primary : Color.clear)
                                .frame(width: 3)
                            Image(systemName: Self.nhomIcons[section.nhom.ten] ?? Self.defaultNhomIcon)
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? Theme.primary : .secondary)
                                .frame(width: 16)
                            Text(section.nhom.ten)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? Theme.primary : .primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.trailing, 6)
                        }
                        .frame(minHeight: 44)
                        .background(isSelected ? Theme.primaryTint.opacity(0.5) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 92)
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private func productRow(_ item: SanPham) -> some View {
        let prices = item.bienThe.map(\.giaBan)
        let minPrice = prices.min()
        Button { picking = item } label: {
            HStack(spacing: 12) {
                if let hinhAnh = item.hinhAnh, let url = URL(string: hinhAnh) {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                        .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.primaryTint).frame(width: 56, height: 56)
                        .overlay(Text(item.ten.trimmingCharacters(in: .whitespaces).prefix(1).uppercased()).foregroundColor(Theme.primary).fontWeight(.bold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.ten)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let minPrice {
                        Text(prices.count > 1 ? "Từ \(formatTien(minPrice))" : formatTien(minPrice))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    }
                }
                Spacer()
            }
        }
        .foregroundColor(.primary)
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true }
        error = ""
        async let spTask = APIClient.shared.getSanPhamList()
        async let nhomTask = APIClient.shared.getNhomSanPhamList()
        async let topTask = APIClient.shared.getToppingList()
        async let viTask = APIClient.shared.getVi()
        let (sp, nhom, top, vi) = await (spTask, nhomTask, topTask, viTask)
        sanPhams = sp.filter { !$0.ngungBan && $0.storeFoodId != nil && !$0.khongLenStore }
        nhoms = nhom
        toppings = top.filter { !$0.ngungBan }
        monHayMua = vi?.monHayMua ?? []
        if sanPhams.isEmpty && sp.isEmpty { error = "" }
        if selectedNhomId.isEmpty, let saved = UserDefaults.standard.string(forKey: Self.selectedNhomKey) {
            selectedNhomId = saved
        }
        if !sections.contains(where: { $0.nhom.id == selectedNhomId }) {
            selectedNhomId = sections.first?.nhom.id ?? ""
        }
        loading = false
    }
}

/// Modal chọn size/topping/ghi chú — port từ Modal presentationStyle="pageSheet" trong MenuScreen.tsx.
private struct ProductPickerSheet: View {
    let sanPham: SanPham
    let toppings: [Topping]
    let cart: CartStore
    /// Theo quy định pháp luật, thuốc lá chỉ bán cho người từ 18 tuổi trở lên.
    let isThuocLa: Bool
    let onDone: () -> Void

    @State private var bienThe: SanPhamBienThe?
    @State private var toppingIds: Set<String> = []
    @State private var soLuong = 1
    @State private var ghiChu = ""
    @State private var tab: Int = 0

    // ---- Xác minh 18 tuổi (thuốc lá) ----
    @State private var ngaySinhInfo: SinhNhatInfo?
    @State private var loadingNgaySinh = false
    @State private var dobPicked = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var savingDob = false
    @State private var dobError: String?

    /// Tuổi hiện tại tính từ ngày sinh đã lưu (chuỗi "yyyy-MM-dd..." từ backend) — nil nếu chưa
    /// có ngày sinh hoặc không parse được.
    private func tuoi(from iso: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let date = formatter.date(from: String(iso.prefix(10))) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: Date()).year
    }

    private var duTuoiMuaThuocLa: Bool {
        guard let ns = ngaySinhInfo?.ngaySinh, let t = tuoi(from: ns) else { return false }
        return t >= 18
    }

    private func formatDateVN(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        guard let date = formatter.date(from: String(iso.prefix(10))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "dd/MM/yyyy"
        out.locale = Locale(identifier: "vi_VN")
        return out.string(from: date)
    }

    private let quickNoteGroups: [(title: String, notes: [String])] = [
        ("Đường", ["Không đường", "Ít ngọt", "Ngọt", "Nhiều ngọt", "Đường riêng"]),
        ("Đá", ["Không đá", "Ít đá", "Vừa đá", "Nhiều đá", "Đá riêng"]),
        ("Trà", ["Không trà", "Trà nóng", "Trà đá"]),
    ]

    private var activeNotes: Set<String> {
        Set(ghiChu.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    /// Nhãn rút gọn cho chip ghi chú nhanh — khớp shortNoteLabels bên ProductPickerPanel
    /// (AppQuanLyIOS), chỉ rút "Không" → "Ko" để chip không quá dài, giữ nguyên activeNotes/ghiChu
    /// đầy đủ phía dưới.
    private static let shortNoteLabels: [String: String] = [
        "Không đường": "Ko đường", "Không đá": "Ko đá", "Không trà": "Ko trà",
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            if let hinhAnh = sanPham.hinhAnh, let url = URL(string: hinhAnh) {
                                AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                                    .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Text(sanPham.ten).font(.headline)
                        }

                        if isThuocLa {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Sản phẩm thuốc lá — chỉ bán cho người từ 18 tuổi trở lên theo quy định pháp luật.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.danger)

                                if loadingNgaySinh {
                                    ProgressView()
                                } else if let ns = ngaySinhInfo?.ngaySinh, tuoi(from: ns) != nil {
                                    if duTuoiMuaThuocLa {
                                        Label("Đã xác minh đủ 18 tuổi (ngày sinh \(formatDateVN(ns)))", systemImage: "checkmark.seal.fill")
                                            .foregroundColor(Theme.success)
                                    } else {
                                        Label("Tài khoản chưa đủ 18 tuổi — không thể mua sản phẩm này.", systemImage: "xmark.octagon.fill")
                                            .foregroundColor(Theme.danger)
                                    }
                                } else {
                                    DatePicker("Ngày sinh của bạn", selection: $dobPicked, in: ...Date(), displayedComponents: .date)
                                    if let dobError {
                                        Text(dobError).font(.system(size: 12)).foregroundColor(Theme.danger)
                                    }
                                    Button {
                                        Task { await xacNhanNgaySinh() }
                                    } label: {
                                        if savingDob { ProgressView() } else { Text("Xác nhận ngày sinh") }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(savingDob)
                                }
                            }
                            .padding(12)
                            .background(Theme.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Chip size cuộn ngang — khớp configSection bên ProductPickerPanel
                        // (AppQuanLyIOS) thay vì List hàng riêng từng size.
                        if sanPham.bienThe.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sanPham.bienThe.sorted(by: { $0.giaBan < $1.giaBan })) { b in
                                        let active = bienThe?.id == b.id
                                        Button("\(b.tenBienThe) \(formatTien(b.giaBan))") { bienThe = b }
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(active ? Theme.primary : Theme.textMuted.opacity(0.12))
                                            .foregroundColor(active ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        HStack {
                            Text("Số lượng").font(.subheadline)
                            Spacer()
                            HStack(spacing: 4) {
                                Button { soLuong = max(1, soLuong - 1) } label: { Image(systemName: "minus.circle.fill") }
                                    .disabled(soLuong <= 1)
                                Text("\(soLuong)").font(.subheadline.bold()).frame(minWidth: 20)
                                Button { soLuong += 1 } label: { Image(systemName: "plus.circle.fill") }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(Theme.primary)
                        }

                        if !toppings.isEmpty {
                            Picker("", selection: $tab) {
                                Text("Ghi chú").tag(0)
                                Text("Topping\(toppingIds.isEmpty ? "" : " (\(toppingIds.count))")").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }

                        if !toppings.isEmpty && tab == 1 {
                            toppingSection
                        } else {
                            noteSection
                        }
                    }
                    .padding(16)
                }
                .navigationTitle("Thêm món")
                .navigationBarTitleDisplayMode(.inline)
                .brandNavBar()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onDone) }
                }
            }

            Button {
                confirmAdd()
            } label: {
                Text("Thêm giỏ · \(bienThe != nil ? formatTien(bienThe!.giaBan * Double(soLuong)) : "")")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .controlSize(.large)
            .disabled(bienThe == nil || (isThuocLa && !duTuoiMuaThuocLa))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .onAppear {
            bienThe = sanPham.bienThe.first(where: \.macDinh) ?? sanPham.bienThe.first
        }
        .task {
            guard isThuocLa else { return }
            loadingNgaySinh = true
            ngaySinhInfo = await APIClient.shared.getSinhNhat()
            loadingNgaySinh = false
        }
    }

    /// Chip toggle thay List hàng+checkmark — khớp phong cách toppingSection bên ProductPickerPanel
    /// (AppQuanLyIOS). Giữ nguyên chọn 1/0 (không số lượng riêng từng topping) vì CartTopping của
    /// app khách chưa có field số lượng.
    private var toppingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toppings) { t in
                let active = toppingIds.contains(t.id)
                Button {
                    if active { toppingIds.remove(t.id) } else { toppingIds.insert(t.id) }
                } label: {
                    HStack {
                        Text(t.ten)
                        Spacer()
                        Text("+\(formatTien(t.gia))").font(.system(size: 12))
                        Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(active ? Theme.primary : Theme.textMuted.opacity(0.1))
                    .foregroundColor(active ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Lưới cột theo số nhóm (Đường/Đá/Trà), mỗi nhóm xếp dọc — khớp bố cục noteSection bên
    /// ProductPickerPanel (AppQuanLyIOS).
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ghi chú món...", text: $ghiChu)
                .textFieldStyle(.roundedBorder)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: quickNoteGroups.count), spacing: 10) {
                ForEach(quickNoteGroups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title).font(.system(size: 10)).foregroundColor(Theme.textFaint)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group.notes, id: \.self) { note in
                                let active = activeNotes.contains(note)
                                Button(Self.shortNoteLabels[note] ?? note) { toggleNote(note) }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .background(active ? Theme.primary : Theme.textMuted.opacity(0.1))
                                    .foregroundColor(active ? .white : Theme.textMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
    }

    private func xacNhanNgaySinh() async {
        dobError = nil
        let t = Calendar.current.dateComponents([.year], from: dobPicked, to: Date()).year ?? 0
        guard t >= 18 else {
            dobError = "Bạn chưa đủ 18 tuổi, không thể mua sản phẩm này."
            return
        }
        savingDob = true
        defer { savingDob = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = formatter.string(from: dobPicked)
        let result = await APIClient.shared.capNhatNgaySinh(iso)
        if result.success {
            ngaySinhInfo = await APIClient.shared.getSinhNhat()
        } else {
            dobError = result.message ?? "Lưu ngày sinh thất bại, thử lại."
        }
    }

    private func toggleNote(_ note: String) {
        var notes = ghiChu.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if let idx = notes.firstIndex(of: note) { notes.remove(at: idx) } else { notes.append(note) }
        ghiChu = notes.joined(separator: ", ")
    }

    private func confirmAdd() {
        guard let bienThe else { return }
        let chosen = toppings.filter { toppingIds.contains($0.id) }.map { CartTopping(id: $0.id, ten: $0.ten, gia: $0.gia) }
        cart.addItem(sanPhamBienTheId: bienThe.id, tenSanPham: sanPham.ten, tenBienThe: bienThe.tenBienThe, giaBan: bienThe.giaBan, soLuong: soLuong, ghiChu: ghiChu.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ghiChu, toppings: chosen)
        onDone()
    }
}
