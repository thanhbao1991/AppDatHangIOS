import SwiftUI

/// contentMargins(.top, 0, for: .scrollContent) chỉ có từ iOS 17 — bọc qua modifier riêng để gọi
/// có điều kiện (#available) mà không phải rải if/else khắp nơi gọi nó.
private struct ZeroTopContentMargin: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentMargins(.top, 0, for: .scrollContent)
        } else {
            content
        }
    }
}

/// Port từ MenuScreen.tsx (bản RN cũ), sau đó đổi sang layout sidebar 2 cột (cột trái = nhóm,
/// cột phải = món) theo chuẩn app trà sữa/cà phê Việt Nam (Phúc Long, ToCoToco, Gong Cha...) —
/// hợp hơn Section cuộn dọc hay chip ngang khi có ~17 nhóm. Modal chọn size/topping/ghi chú →
/// .sheet(), tìm không dấu qua timKiem đã chuẩn hoá sẵn từ server.
struct MenuView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]
    @Binding var selectedTab: AppTab
    var notificationBell: AnyView

    @State private var loading = true
    @State private var error = ""
    @State private var sanPhams: [SanPham] = []
    @State private var nhoms: [NhomSanPham] = []
    @State private var toppings: [Topping] = []
    @State private var query = ""
    @State private var picking: SanPham?
    @State private var selectedNhomId: String = ""
    /// true trong lúc đang scrollTo do BẤM sidebar (không phải khách tự cuộn tay) — chặn header
    /// .onAppear (do chính animation cuộn gây ra) ghi đè lại lựa chọn giữa chừng, gây nhấp nháy.
    @State private var isJumpingToSection = false
    /// Yêu cầu scrollTo tới 1 nhóm — kèm `tick` tăng dần để .onChange bên List LUÔN bắt được kể cả
    /// bấm lại đúng nhóm cũ (vd khách cuộn tay đi chỗ khác rồi bấm lại đúng nhóm đang chọn, muốn
    /// cuộn về) — String đơn thuần sẽ không đổi giá trị nên .onChange không fire lại được.
    private struct ScrollRequest: Equatable { let id: String; let tick: Int }
    @State private var scrollRequest: ScrollRequest?
    @State private var monHayMua: [FavoriteItem] = []
    /// SanPhamId theo bán chạy giảm dần (30 ngày gần nhất) — xem APIClient.getBanChayIds.
    @State private var banChayIds: [String] = []


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

    /// Emoji dự phòng cho từng nhóm — dùng khi nhóm không có món nào có ảnh thật (xem
    /// nhomImageUrl/pickNhomImages bên dưới, ưu tiên hiện ảnh món thật hơn emoji). Chọn theo đúng
    /// nghĩa đồ uống của từng nhóm, tránh trùng giữa các nhóm hiện diện riêng ở sidebar (4 nhóm gom
    /// chung vào "#Khác" không cần phân biệt nên vẫn để trùng thoải mái).
    private static let nhomIcons: [String: String] = [
        "Ăn Vặt": "🥫",
        "Bạc Xỉu": "🥃",
        "Ca Cao": "🧉",
        "Cà Phê": "☕",
        "Đá Xay": "🍧",
        "Khác": "🥫",
        "Latte": "🍶",
        "Nước Ép": "🍊",
        "Nước Lon": "🥫",
        "Sinh Tố": "🍓",
        "Soda": "🥤",
        "Sữa Chua": "🥣",
        "Sữa Tươi": "🥛",
        "Thuốc lá": "🥫",
        "Trà": "🍃",
        "Trà Hiện Đại": "🍹",
        "Trà Sữa": "🧋",
        "Trà Truyền Thống": "🍵",
        "Yêu thích": "❤️",
    ]
    private static let defaultNhomIcon = "🥤"
    private static let yeuThichNhomId = "yeu-thich"

    /// Chiều cao CỐ ĐỊNH dùng chung cho hàng nhóm bên sidebar (nhomSidebar) VÀ header nhóm bên cột
    /// phải (sectionHeader) — trước đây mỗi bên tự co theo nội dung (sidebar minHeight 44, header
    /// card ~50pt, header rỗng ~33pt) nên 2 bên lệch chiều cao ở hàng đầu tiên, nhìn mất cân đối.
    private static let categoryHeaderHeight: CGFloat = 52

    /// Tên hiển thị rút gọn ở sidebar — hiện không có nhóm nào cần rút gọn (giữ tên đầy đủ, dựa vào
    /// minimumScaleFactor bên nhomSidebar để tên dài vẫn vừa khung hẹp).
    private static let nhomShortLabels: [String: String] = [:]

    /// Món khớp monHayMua (3 món khách mua nhiều nhất, từ /dat-hang/vi) — chỉ khớp theo TÊN sản
    /// phẩm vì backend không trả kèm id, khớp cả
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

    /// SanPhamId → hạng bán chạy (0 = bán chạy nhất) — món không có trong banChayIds rơi về cuối.
    private var banChayRank: [String: Int] {
        var m: [String: Int] = [:]
        for (i, id) in banChayIds.enumerated() { m[id] = i }
        return m
    }

    /// Sắp món trong 1 nhóm theo bán chạy giảm dần, giữ nguyên thứ tự gốc giữa các món cùng hạng
    /// (chưa có lượt bán/chưa nằm trong top 30 ngày).
    private func sortedByBanChay(_ items: [SanPham]) -> [SanPham] {
        let rank = banChayRank
        return items.enumerated().sorted { a, b in
            let ra = rank[a.element.id] ?? Int.max
            let rb = rank[b.element.id] ?? Int.max
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
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
                result.append((nhom: nhom, items: sortedByBanChay(items)))
            }
        }
        result.sort { $0.nhom.ten.localizedStandardCompare($1.nhom.ten) == .orderedAscending }

        if !gomChung.isEmpty {
            result.append((nhom: NhomSanPham(id: "#", ten: "Khác"), items: sortedByBanChay(gomChung)))
        }

        // Luôn hiện mục "Yêu thích" đầu sidebar kể cả khi chưa có món nào — rỗng thì cột phải tự
        // hiện dòng thông báo (xem productList) thay vì ẩn hẳn mục đi.
        result.insert((nhom: NhomSanPham(id: Self.yeuThichNhomId, ten: "Yêu thích"), items: favoriteSanPhams), at: 0)
        return result
    }

    /// Theo quy định pháp luật, thuốc lá chỉ bán cho người từ 18 tuổi trở lên — dùng để bật cảnh
    /// báo + bắt xác nhận độ tuổi trước khi thêm giỏ ở ProductPickerSheet.
    private var thuocLaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Thuốc lá" }.map(\.id))
    }

    /// Món Sinh Tố/Đá Xay luôn phải xay cùng đá nên chip ghi chú nhanh "Không đá" vô nghĩa với
    /// nhóm này — disable để tránh khách chọn nhầm rồi báo pha sai.
    private var khongChoKhongDaNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Sinh Tố" || $0.ten == "Đá Xay" }.map(\.id))
    }

    /// Chip ghi chú nhanh nhóm "Trà" (Không trà/Trà nóng/Trà đá) chỉ có ý nghĩa với món pha có trà đi
    /// kèm (Cà Phê — thường có lựa chọn kèm/không kèm trà) — nhóm khác (Trà Sữa, Sinh Tố...) hiện
    /// chip này chỉ gây rối vì không áp dụng.
    private var caPheNhomIds: Set<String> {
        Set(nhoms.filter { $0.ten == "Cà Phê" }.map(\.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thanh tìm kiếm gradient tràn lên status bar — khớp DaySearchBar(tinted: true) của
            // tab Hoá đơn bên AppQuanLyIOS, thay .searchable() hệ thống (khác style, thụt xuống
            // dưới navigationTitle).
            SearchBar(text: $query, placeholder: "Tìm món...", trailing: notificationBell)

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
                    // List (UITableView) .plain tự ghim (pin) header của Section khi cuộn — không
                    // cần hack GeometryReader/preference như lần thử trước (đo minY thủ công mới là
                    // phần KHÔNG ổn định, không phải do dùng Section). Theo dõi "đang xem nhóm nào"
                    // vẫn qua .onAppear trên header (vòng đời thật của List, đáng tin cậy).
                    //
                    // QUAN TRỌNG: ScrollViewReader chỉ bọc riêng List — KHÔNG bọc chung với sidebar
                    // (sidebar có ScrollView riêng của nó). Từng thử bọc chung 1 ScrollViewReader
                    // quanh cả HStack (2 vùng cuộn cùng lúc trong 1 reader) và bấm sidebar không
                    // cuộn được List — tách hẳn ra để proxy.scrollTo không còn mơ hồ vùng cuộn nào.
                    HStack(spacing: 0) {
                        nhomSidebar(onTap: { id in
                            isJumpingToSection = true
                            selectedNhomId = id
                            scrollRequest = ScrollRequest(id: id, tick: (scrollRequest?.tick ?? 0) + 1)
                        })
                        Divider()
                        ScrollViewReader { proxy in
                            List {
                                ForEach(Array(sections.enumerated()), id: \.element.nhom.id) { index, section in
                                    Section {
                                        if section.nhom.id == Self.yeuThichNhomId && section.items.isEmpty {
                                            yeuThichEmptyState
                                                .listRowInsets(EdgeInsets())
                                                .listRowBackground(sectionBackground(index))
                                        } else {
                                            ForEach(section.items) { sp in
                                                productRow(sp)
                                                    .listRowInsets(EdgeInsets())
                                                    .listRowBackground(sectionBackground(index))
                                            }
                                        }
                                    } header: {
                                        sectionHeader(section.nhom, items: section.items)
                                            .id(section.nhom.id)
                                            .onAppear {
                                                guard !isJumpingToSection else { return }
                                                selectedNhomId = section.nhom.id
                                            }
                                    }
                                    .listRowInsets(EdgeInsets())
                                }
                            }
                            .listStyle(.plain)
                            // sectionHeaderTopPadding (AppDatHangIOSApp.init) chỉ chắc ăn khi List
                            // còn backing bằng UITableView (iOS 16) — từ iOS 17 SwiftUI có thể đổi
                            // sang UICollectionView khiến property đó vô tác dụng, khoảng trống vẫn
                            // còn. Thêm contentMargins(top: 0) cho iOS 17+ để phủ luôn trường hợp đó.
                            .modifier(ZeroTopContentMargin())
                            // contentMargins(top: 0) chỉ có hiệu lực thật sự sau khi List đã chạy
                            // qua 1 lần layout/cuộn — lúc mới mở tab (chưa cuộn tay lần nào) khoảng
                            // trống cũ vẫn còn thấy thoáng qua. "Nhử" 1 lần scrollTo về đúng section
                            // đầu ngay khi có dữ liệu — không animate, khách không thấy gì nhảy —
                            // để ép layout tính lại đúng từ đầu.
                            .onAppear {
                                guard let firstId = sections.first?.nhom.id else { return }
                                DispatchQueue.main.async { proxy.scrollTo(firstId, anchor: .top) }
                            }
                            .onChange(of: scrollRequest) { req in
                                guard let req else { return }
                                withAnimation { proxy.scrollTo(req.id, anchor: .top) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isJumpingToSection = false }
                            }
                            // Kéo-thả refresh cũng làm List layout lại từ đầu → khoảng trống cũ tái
                            // xuất hiện y hệt lúc mới mở tab — nhử lại đúng cách như .onAppear ở trên.
                            .refreshable {
                                await load(silent: true)
                                if let firstId = sections.first?.nhom.id {
                                    DispatchQueue.main.async { proxy.scrollTo(firstId, anchor: .top) }
                                }
                            }
                            // (Đã thử bắt thêm DragGesture(minimumDistance: 0) để vá nốt trường hợp
                            // kéo nhẹ chưa đủ trigger refresh — nhưng dù dùng simultaneousGesture,
                            // nó vẫn đè mất tap vào Button từng hàng món trong List. Bỏ hẳn: ưu
                            // tiên chức năng thêm món hoạt động đúng hơn khoảng trắng cosmetic hiếm
                            // gặp lúc kéo dở dang.)
                        }
                    }
                }
            }
        }
        .task { if sanPhams.isEmpty { await load() } }
        .sheet(item: $picking) { sp in
            ProductPickerSheet(
                sanPham: sp,
                toppings: toppings,
                isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                khongChoKhongDa: khongChoKhongDaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                showTraNote: caPheNhomIds.contains(sp.nhomSanPhamId ?? ""),
                onConfirm: { bienThe, soLuong, ghiChu, toppings in
                    cart.addItem(sanPhamBienTheId: bienThe.id, tenSanPham: sp.ten, tenBienThe: bienThe.tenBienThe, giaBan: bienThe.giaBan, soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: sp.hinhAnh)
                }
            ) { picking = nil }
        }
    }

    /// Hiện khi khách chưa có món hay mua nào (monHayMua rỗng) — thay vì để trống trơn, giải thích
    /// vì sao mục "Yêu thích" chưa có gì và món sẽ tự xuất hiện sau khi khách đặt hàng.
    private var yeuThichEmptyState: some View {
        VStack(spacing: 8) {
            Text("💕")
                .font(.system(size: 30))
            Text("Món hay gọi sẽ hiện ở đây!")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    /// Màu nền xen kẽ giữa 2 nhóm liền kề trong menu — chỉ khác biệt nhẹ (không phải màu sắc rực) để
    /// không cạnh tranh với ảnh/tên món, chỉ đủ giúp mắt nhận ra ranh giới khi cuộn nhanh.
    private func sectionBackground(_ index: Int) -> Color {
        index % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground).opacity(0.5)
    }

    /// Header đầu mỗi nhóm — dùng làm header của Section trong List nên tự ghim (pinned) khi cuộn
    /// (hành vi mặc định của UITableView .plain style, không cần code thêm). Gộp luôn "bốc ngẫu
    /// nhiên" vào chung header (thay vì 1 row riêng bên dưới như trước) — cùng icon nhóm, bấm
    /// thẳng vào cả header là bốc random 1 món trong nhóm. Rỗng (mục Yêu thích lúc chưa có món
    /// hay mua) thì hiện tên nhóm trơn, không bấm được.
    private func sectionHeader(_ nhom: NhomSanPham, items: [SanPham]) -> some View {
        Group {
            if items.isEmpty {
                HStack(spacing: 6) {
                    Text(Self.nhomIcons[nhom.ten] ?? Self.defaultNhomIcon)
                        .font(.system(size: 14))
                    Text(nhom.ten).font(.system(size: 14, weight: .bold)).foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: Self.categoryHeaderHeight)
                .background(.bar)
            } else {
                Button {
                    picking = items.randomElement()
                } label: {
                    // Card full-width, KHÔNG ôm sát nội dung nữa — pill phải nằm cố định 1 vị trí
                    // (mép phải) xuyên suốt mọi nhóm khi cuộn, quan trọng hơn việc tránh khoảng
                    // trống co giãn giữa tên nhóm ngắn/dài và pill (chấp nhận đánh đổi).
                    HStack(spacing: 10) {
                        Text(Self.nhomIcons[nhom.ten] ?? Self.defaultNhomIcon)
                            .font(.system(size: 16))
                            .frame(width: 30, height: 30)
                            .background(Theme.primaryTint)
                            .clipShape(Circle())
                        // Tên nhóm làm nhãn card, không .uppercased() — chữ hoa toàn bộ đọc như
                        // tên danh mục hơn là lời mời bấm. Hành động thật dồn vào pill bên phải.
                        Text(nhom.ten)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        // Pill nêu đúng hành động — thay icon shuffle đơn thuần trước đây, để
                        // nhìn là ra ngay 1 nút bấm thật.
                        Text("Chọn ngẫu nhiên")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .frame(height: Self.categoryHeaderHeight)
                    // Nền tint fill sát mép luôn (không còn card nổi thụt lề/bo góc/shadow như
                    // trước) — tint khác hẳn nền trắng của list món phía dưới là đủ để phân biệt,
                    // không cần thêm lớp viền.
                    .background(Theme.primaryTint)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Cột trái: danh sách nhóm cố định — bấm thì báo `onTap` để cột phải tự cuộn tới đúng section
    /// (không lọc ẩn nhóm khác) qua ScrollViewReader riêng của chính nó, xem body.
    private func nhomSidebar(onTap: @escaping (String) -> Void) -> some View {
        ScrollViewReader { sidebarProxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(sections, id: \.nhom.id) { section in
                        let isSelected = section.nhom.id == selectedNhomId
                        Button {
                            onTap(section.nhom.id)
                        } label: {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(isSelected ? Theme.primary : Color.clear)
                                    .frame(width: 3)
                                // "#" ghép liền chữ đầu bằng Text concatenation (+) thay vì Text
                                // riêng có .frame(width:) — frame cố định tạo khoảng trắng 2 bên "#"
                                // làm mất cảm giác hashtag dính liền kiểu "#BạcXỉu".
                                (Text("#")
                                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? Theme.primary : .secondary)
                                    + Text(Self.nhomShortLabels[section.nhom.ten] ?? section.nhom.ten)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? Theme.primary : .primary))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.trailing, 4)
                            }
                            .frame(height: Self.categoryHeaderHeight)
                            .background(isSelected ? Theme.primaryTint.opacity(0.5) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 84)
            .background(Color(.secondarySystemGroupedBackground))
            // Khách tự cuộn tay bên phải → header row .onAppear đổi selectedNhomId theo → tự cuộn
            // sidebar theo để mục đang chọn luôn nằm trong tầm nhìn, không bắt khách tự kéo tìm.
            .onChange(of: selectedNhomId) { id in
                withAnimation { sidebarProxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func productRow(_ item: SanPham) -> some View {
        let prices = item.bienThe.map(\.giaBan)
        let minPrice = prices.min()
        Button { picking = item } label: {
            HStack(spacing: 12) {
                if let hinhAnh = item.hinhAnh, let url = URL(string: hinhAnh) {
                    CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                        .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.primaryTint).frame(width: 56, height: 56)
                        .overlay(Text(item.ten.trimmingCharacters(in: .whitespaces).prefix(1).uppercased()).foregroundColor(Theme.primary).fontWeight(.bold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.ten)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let minPrice {
                        Text(prices.count > 1 ? "Từ \(formatTien(minPrice))" : formatTien(minPrice))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .foregroundColor(.primary)
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true }
        error = ""
        // getSanPhamListResult() (khác getSanPhamList() ở CheckoutView) để phân biệt được "thực đơn
        // thật sự trống" với "mất mạng/server lỗi" — trước đây getSanPhamList() nuốt hẳn lỗi thành []
        // rỗng, khiến nhánh hiện lỗi + nút "Thử lại" ở body KHÔNG BAO GIỜ chạy tới dù mất mạng thật:
        // khách chỉ thấy menu trống trơn, không biết là do lỗi hay quán chưa có món nào.
        async let spTask = APIClient.shared.getSanPhamListResult()
        async let nhomTask = APIClient.shared.getNhomSanPhamList()
        async let topTask = APIClient.shared.getToppingList()
        async let viTask = APIClient.shared.getVi()
        async let banChayTask = APIClient.shared.getBanChayIds()
        let (spResult, nhom, top, vi, banChay) = await (spTask, nhomTask, topTask, viTask, banChayTask)
        let sp = spResult.data ?? []
        sanPhams = sp.filter { !$0.ngungBan && $0.storeFoodId != nil && !$0.khongLenStore }
        nhoms = nhom
        toppings = top.filter { !$0.ngungBan }
        monHayMua = vi?.monHayMua ?? []
        banChayIds = banChay
        // Chỉ chặn màn bằng lỗi khi KHÔNG có gì để hiện (lần tải đầu thất bại) — refresh (kéo-thả)
        // thất bại khi menu đã có sẵn dữ liệu cũ thì giữ nguyên danh sách đang hiện, không xoá sạch
        // màn hình chỉ vì 1 lần mất mạng thoáng qua.
        if !spResult.isSuccess && sanPhams.isEmpty {
            error = spResult.message ?? "Không tải được thực đơn, vui lòng thử lại."
        }
        // Mục đầu tiên khi mở app luôn là "Yêu thích" (id cố định, luôn có mặt trong sections dù
        // rỗng) — không nhớ nhóm khách chọn lần trước nữa.
        if selectedNhomId.isEmpty {
            selectedNhomId = Self.yeuThichNhomId
        }
        if !sections.contains(where: { $0.nhom.id == selectedNhomId }) {
            selectedNhomId = sections.first?.nhom.id ?? ""
        }
        loading = false
    }
}

/// Modal chọn size/topping/ghi chú — port từ Modal presentationStyle="pageSheet" trong MenuScreen.tsx.
/// Dùng chung cho 2 luồng: THÊM món mới (MenuView, `existing` = nil) và SỬA món đã có trong giỏ
/// (CheckoutView, `existing` = dòng đang sửa) — không tự đụng CartStore, chỉ trả kết quả chọn qua
/// `onConfirm` để nơi gọi tự quyết định addItem hay updateItem.
struct ProductPickerSheet: View {
    let sanPham: SanPham
    let toppings: [Topping]
    /// Theo quy định pháp luật, thuốc lá chỉ bán cho người từ 18 tuổi trở lên.
    let isThuocLa: Bool
    /// Sinh Tố/Đá Xay luôn xay cùng đá — disable chip "Không đá".
    let khongChoKhongDa: Bool
    /// Chỉ món nhóm Cà Phê mới hiện chip ghi chú nhanh "Trà" (Không trà/Trà nóng/Trà đá) — nhóm khác
    /// ẩn hẳn, xem quickNoteGroups.
    let showTraNote: Bool
    /// Dòng đang sửa (size/topping/số lượng/ghi chú cũ) — nil nghĩa là đang thêm món mới.
    var existing: CartItem? = nil
    let onConfirm: (_ bienThe: SanPhamBienThe, _ soLuong: Int, _ ghiChu: String?, _ toppings: [CartTopping]) -> Void
    let onDone: () -> Void

    @State private var bienThe: SanPhamBienThe?
    @State private var toppingQty: [String: Int] = [:]
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

    /// Nhóm "Trà" chỉ hiện cho món Cà Phê (showTraNote) — món khác (Trà Sữa, Sinh Tố...) không có lựa
    /// chọn kèm/không kèm trà nên chip này vô nghĩa, ẩn hẳn thay vì hiện disable.
    private var quickNoteGroups: [(title: String, notes: [String])] {
        var groups: [(title: String, notes: [String])] = [
            ("Đường", ["Không đường", "Ít ngọt", "Ngọt", "Nhiều ngọt", "Đường riêng"]),
            ("Đá", ["Không đá", "Ít đá", "Vừa đá", "Nhiều đá", "Đá riêng"]),
        ]
        if showTraNote {
            groups.append(("Trà", ["Không trà", "Trà nóng", "Trà đá"]))
        }
        return groups
    }

    private var activeNotes: Set<String> {
        Set(ghiChu.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    private var toppingCount: Int { toppingQty.values.reduce(0, +) }

    /// Thành tiền tạm tính gồm cả topping — khớp thanhTienDraft bên ProductPickerPanel (AppQuanLyIOS).
    private var thanhTienDraft: Double {
        guard let bienThe else { return 0 }
        let toppingTien = toppingQty.reduce(0.0) { sum, kv in
            guard let top = toppings.first(where: { $0.id == kv.key }) else { return sum }
            return sum + top.gia * Double(kv.value)
        }
        return bienThe.giaBan * Double(soLuong) + toppingTien
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        if let hinhAnh = sanPham.hinhAnh, let url = URL(string: hinhAnh) {
                            CachedAsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sanPham.ten).font(.headline)

                            // Chip size cuộn ngang, gắn ngay dưới tên món thay vì tách hàng
                            // riêng — khớp configSection bên ProductPickerPanel (AppQuanLyIOS).
                            if sanPham.bienThe.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(sanPham.bienThe.sorted(by: { $0.giaBan < $1.giaBan })) { b in
                                            let active = bienThe?.id == b.id
                                            // Button(String title) { } rồi chain .contentShape() KHÔNG
                                            // đáng tin — vùng chạm thật vẫn co về bounding box chữ trong
                                            // nhiều trường hợp (đã xác nhận qua test thật: bấm trúng chữ
                                            // mới ăn, bấm phần đệm quanh chip thì trượt). Cách CHẮC ĂN
                                            // (khớp sectionHeader bên dưới đã chạy đúng từ trước): dùng
                                            // label closure riêng, đặt .contentShape() NGAY TRONG label
                                            // (sau background/clipShape), .buttonStyle(.plain) áp SAU
                                            // CÙNG ở ngoài Button.
                                            Button {
                                                bienThe = b
                                            } label: {
                                                Text("\(b.tenBienThe) \(formatTien(b.giaBan))")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                                    .background(active ? Theme.primary : Theme.textMuted.opacity(0.12))
                                                    .foregroundColor(active ? .white : .primary)
                                                    .clipShape(Capsule())
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if isThuocLa {
                        VStack(alignment: .leading, spacing: 8) {
                            EmojiLabel("Sản phẩm thuốc lá — chỉ bán cho người từ 18 tuổi trở lên theo quy định pháp luật.", "⚠️")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.danger)

                            if loadingNgaySinh {
                                ProgressView()
                            } else if let ns = ngaySinhInfo?.ngaySinh, tuoi(from: ns) != nil {
                                if duTuoiMuaThuocLa {
                                    EmojiLabel("Đã xác minh đủ 18 tuổi (ngày sinh \(formatDateVN(ns)))", "✅")
                                        .foregroundColor(Theme.success)
                                } else {
                                    EmojiLabel("Tài khoản chưa đủ 18 tuổi — không thể mua sản phẩm này.", "❌")
                                        .foregroundColor(Theme.danger)
                                }
                            } else {
                                // Ép locale vi_VN — máy đặt hệ thống tiếng Anh sẽ hiện DatePicker
                                // kiểu "January 2026"/mm-dd-yyyy giữa 1 màn toàn chữ Việt, lạc quẻ.
                                DatePicker("Ngày sinh của bạn", selection: $dobPicked, in: ...Date(), displayedComponents: .date)
                                    .environment(\.locale, Locale(identifier: "vi_VN"))
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

                    HStack {
                        Text("Số lượng").font(.subheadline)
                        Spacer()
                        // Stepper hệ thống — vùng chạm to hơn hẳn 2 icon minus/plus.circle.fill
                        // trước đây (khó bấm trúng), khớp UI đã dùng cho từng dòng topping. Chỉ cho
                        // giảm về 0 khi đang SỬA món có sẵn trong giỏ (existing != nil) — về 0 rồi
                        // bấm nút dưới cùng sẽ xoá món khỏi giỏ (thay cho nút X riêng đã bỏ). Thêm
                        // mới (existing nil) vẫn giữ tối thiểu 1, "0 món mới" vô nghĩa.
                        Stepper(value: $soLuong, in: (existing == nil ? 1 : 0)...20) {
                            Text("\(soLuong)").fontWeight(.bold)
                        }
                        .fixedSize()
                    }

                    if !toppings.isEmpty {
                        Picker("", selection: $tab) {
                            Text("Ghi chú").tag(0)
                            Text("Topping\(toppingCount > 0 ? " (\(toppingCount))" : "")").tag(1)
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
                .navigationTitle(existing == nil ? "Thêm món" : "Sửa món")
                .navigationBarTitleDisplayMode(.inline)
                .brandNavBar()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onDone) }
                }
            }

            // existing != nil && soLuong == 0 → xoá món (thay cho nút X riêng đã bỏ ở CheckoutView,
            // xem itemRow) — đổi hẳn chữ + màu nút thành "Xoá món" để rõ ý, tránh tưởng nhầm là cập
            // nhật số lượng 0 (vô nghĩa).
            let isDeleting = existing != nil && soLuong == 0
            Button {
                confirmAdd()
            } label: {
                if isDeleting {
                    Text("Xoá món")
                } else {
                    // Trước ghép chuỗi vô điều kiện "· \(...)" — bienThe nil (khung hình đầu tiên
                    // trước khi .onAppear kịp set) thì hiện dấu "·" trơ trọi không có gì theo sau,
                    // nháy 1 khung hình xấu lúc mở sheet. Chỉ ghép " · giá" khi thật sự có giá để hiện.
                    Text(existing == nil ? "Thêm giỏ" : "Cập nhật")
                        + Text(bienThe != nil ? " · \(formatTien(thanhTienDraft))" : "")
                }
            }
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(isDeleting ? Theme.danger : Theme.primary)
            .controlSize(.large)
            .disabled(!isDeleting && (bienThe == nil || (isThuocLa && !duTuoiMuaThuocLa)))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .onAppear {
            if let existing {
                // Ưu tiên khớp đúng id, rồi tới tên biến thể — "Đặt lại" (OrderDetailView.datLai)
                // copy sanPhamBienTheId từ đơn CŨ, id đó có thể không còn tồn tại nếu biến thể đã bị
                // sửa/tạo lại trên Desktop (SequentialGuid mới) dù sản phẩm/size vẫn còn bán, nên
                // khớp theo tên để vẫn chọn đúng size cũ thay vì rơi về mặc định.
                bienThe = sanPham.bienThe.first(where: { $0.id == existing.sanPhamBienTheId })
                    ?? sanPham.bienThe.first(where: { $0.tenBienThe == existing.tenBienThe })
                    ?? sanPham.bienThe.first(where: \.macDinh) ?? sanPham.bienThe.first
                soLuong = existing.soLuong
                ghiChu = existing.ghiChu ?? ""
                toppingQty = Dictionary(uniqueKeysWithValues: existing.toppings.map { ($0.id, $0.soLuong) })
            } else {
                bienThe = sanPham.bienThe.first(where: \.macDinh) ?? sanPham.bienThe.first
            }
        }
        .task {
            guard isThuocLa else { return }
            loadingNgaySinh = true
            ngaySinhInfo = await APIClient.shared.getSinhNhat()
            loadingNgaySinh = false
        }
    }

    /// Stepper số lượng từng topping — khớp toppingSection bên ProductPickerPanel (AppQuanLyIOS):
    /// hàng phẳng không nền/bo góc, cho chọn nhiều lần cùng 1 topping (vd 2 trân châu) thay vì chỉ
    /// bật/tắt 0-1 như trước.
    private var toppingSection: some View {
        // ScrollView riêng, cao lấp đầy phần còn lại tới nút "Thêm giỏ" — topping nhiều thì cuộn
        // ngay trong vùng này, không kéo cả màn hình thêm món (header/size/số lượng phía trên nay
        // không còn nằm trong ScrollView, cố định).
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(toppings.sorted(by: { $0.gia > $1.gia })) { t in
                    HStack {
                        Text(t.ten)
                        Spacer()
                        Text(formatTien(t.gia)).font(.caption).foregroundColor(Theme.textMuted)
                        Stepper(value: Binding(
                            get: { toppingQty[t.id] ?? 0 },
                            set: { newValue in
                                if newValue <= 0 { toppingQty.removeValue(forKey: t.id) } else { toppingQty[t.id] = newValue }
                            }
                        ), in: 0...20) {
                            Text("\(toppingQty[t.id] ?? 0)").fontWeight(.bold)
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(.trailing, 10)
        }
        .frame(maxHeight: .infinity)
    }

    /// Lưới cột theo số nhóm (Đường/Đá/Trà), mỗi nhóm xếp dọc — khớp bố cục noteSection bên
    /// ProductPickerPanel (AppQuanLyIOS). Ô ghi chú tự do đặt DƯỚI lưới chip (trước đây nằm trên,
    /// dễ bị hiểu nhầm là ô bắt buộc chính), nhiều dòng thay vì TextField 1 dòng cũ.
    private var noteSection: some View {
        // Bọc ScrollView để khớp hành vi với toppingSection (cùng chỗ đứng, đổi qua lại bằng tab)
        // — nội dung thường vừa màn hình nhưng phòng khi bàn phím che TextEditor trên máy nhỏ.
        ScrollView {
            noteSectionContent
        }
        .frame(maxHeight: .infinity)
        // Trước đây gõ ghi chú xong không có cách nào ẩn bàn phím ngoài bấm đúng chip/nút khác —
        // chạm ra vùng trống trong ScrollView không tự ẩn bàn phím như TextField thường thấy.
        .scrollDismissesKeyboard(.interactively)
    }

    private var noteSectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: quickNoteGroups.count), spacing: 10) {
                ForEach(quickNoteGroups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title).font(.system(size: 10)).foregroundColor(Theme.textFaint)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group.notes, id: \.self) { note in
                                let active = activeNotes.contains(note)
                                let disabled = khongChoKhongDa && (note == "Không đá" || note == "Đá riêng")
                                // minHeight 44 = ngưỡng tối thiểu Apple HIG cho vùng chạm — 34 cũ nhỏ
                                // hơn hẳn, đúng lý do khách thấy khó bấm (nhất là 5 chip xếp dọc sát
                                // nhau trong cùng 1 cột, dễ chạm lệch sang chip liền kề).
                                //
                                // Button(String title) { } rồi chain .contentShape() KHÔNG đáng tin —
                                // đã xác nhận qua test thật: bấm trúng CHỮ mới ăn, bấm phần đệm quanh
                                // chip thì trượt, y hệt chip size từng bị. Chuyển sang label closure
                                // riêng, .contentShape() NGAY TRONG label (khớp sectionHeader bên trên
                                // đã chạy đúng), .buttonStyle(.plain) áp SAU CÙNG ở ngoài Button.
                                Button {
                                    toggleNote(note, in: group.notes)
                                } label: {
                                    Text(Self.shortNoteLabels[note] ?? note)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 8)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .background(active ? Theme.primary : Theme.textMuted.opacity(0.1))
                                        .foregroundColor(active ? .white : Theme.textMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(disabled)
                                .opacity(disabled ? 0.4 : 1)
                            }
                        }
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                if ghiChu.isEmpty {
                    Text("Ghi chú món...")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textFaint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $ghiChu)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
            }
            .padding(4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.divider))
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

    /// Mỗi nhóm (Đường/Đá/Trà) chỉ chọn được 1 chip — chọn chip mới trong nhóm sẽ bỏ chip cũ
    /// cùng nhóm (kiểu radio), bấm lại chip đang chọn để bỏ chọn hẳn.
    private func toggleNote(_ note: String, in groupNotes: [String]) {
        var notes = ghiChu.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let wasActive = notes.contains(note)
        notes.removeAll { groupNotes.contains($0) }
        if !wasActive { notes.append(note) }
        ghiChu = notes.joined(separator: ", ")
    }

    private func confirmAdd() {
        guard let bienThe else { return }
        let chosen = toppings.compactMap { t -> CartTopping? in
            guard let qty = toppingQty[t.id], qty > 0 else { return nil }
            return CartTopping(id: t.id, ten: t.ten, gia: t.gia, soLuong: qty)
        }
        onConfirm(bienThe, soLuong, ghiChu.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ghiChu, chosen)
        onDone()
    }
}
