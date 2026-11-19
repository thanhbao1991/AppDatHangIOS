import SwiftUI

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
    /// SanPhamId khách TỰ CHỌN yêu thích (nút tim ở productRow) — nguồn cho mục "Yêu thích" ở
    /// sidebar, thay cho cách cũ tính động theo món mua nhiều nhất.
    @State private var yeuThichIds: Set<String> = []
    /// SanPhamId đang gọi API thêm/xoá yêu thích — disable nút tim tương ứng để tránh bấm dồn dập
    /// trong lúc chờ phản hồi.
    @State private var togglingYeuThichIds: Set<String> = []
    /// SanPhamId theo bán chạy giảm dần (30 ngày gần nhất) — xem APIClient.getBanChayIds.
    @State private var banChayIds: [String] = []
    /// "Pha kèm" (19/11/2026): món đang có đơn khác pha → giảm 3K trong 99 giây, xem PhaKemStore. Đọc để vẽ lại khi đổi.
    @ObservedObject private var phaKem = PhaKemStore.shared
    /// Tab dải đề xuất: 0 = Best Sellers (mặc định, chủ quán chốt), 1 = Sale off (chỉ hiện khi có món đang pha).
    @State private var tabDeXuat = 0
    /// Giá riêng của khách đang đăng nhập (key sanPhamBienTheId) — feedback 2026-09-29 "áp giá riêng
    /// vào app". Server đã tính tiền thật theo giá này lúc đặt (DatHangService.DatMonAsync), tải ở
    /// đây chỉ để HIỂN THỊ đúng ngay từ menu, khớp số sẽ bị trừ lúc thanh toán.
    @State private var giaRiengMap: [String: Double] = [:]
    /// Buộc body vẽ lại khi .christmasPreviewToggled bắn (SeasonalEvent.active là static var) — PHẢI đọc
    /// trong body (`let _ =` đầu body), xem ghi chú cùng tên ở MainTabView.
    @State private var seasonalPreviewTick = 0
    /// Màn chúc mừng quà đầu tháng (hạng, Top shipper) — hiện tới khi bấm "Nhận ngay" (ChucMungHang).


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

    /// Emoji đại diện từng nhóm — thử đổi sang ảnh món thật (2026-09-27) nhưng revert lại ngay vì
    /// không ổn (feedback), giữ nguyên emoji tĩnh. Gom về Theme.nhomIcons/defaultNhomIcon (dùng chung
    /// với CheckoutView.itemThumbnail).
    private static let yeuThichNhomId = "yeu-thich"

    /// Chiều cao CỐ ĐỊNH dùng chung cho hàng nhóm bên sidebar (nhomSidebar) VÀ header nhóm bên cột
    /// phải (sectionHeader) — trước đây mỗi bên tự co theo nội dung (sidebar minHeight 44, header
    /// card ~50pt, header rỗng ~33pt) nên 2 bên lệch chiều cao ở hàng đầu tiên, nhìn mất cân đối.
    private static let categoryHeaderHeight: CGFloat = 52
    /// ⚠️ Dòng món cao CỐ ĐỊNH — khung mỗi nhóm ở cột món khai thẳng chiều cao = header + số món × rowHeight (xem
    /// body, 19/11/2026) để iOS biết trước toạ độ mọi nhóm. Thêm thứ gì làm đổi chiều cao dòng/nhóm mà không sửa
    /// khung đó thì món bị cắt/chồng và bấm nhóm lại nhảy lệch.
    fileprivate static let rowHeight: CGFloat = 72
    private static let khoangCachNhom: CGFloat = 8

    /// Tên hiển thị rút gọn ở sidebar — hiện không có nhóm nào cần rút gọn (giữ tên đầy đủ, dựa vào
    /// minimumScaleFactor bên nhomSidebar để tên dài vẫn vừa khung hẹp).
    private static let nhomShortLabels: [String: String] = [:]

    /// Món khách đã bấm tim yêu thích — giữ nguyên thứ tự trong sanPhams (theo nhóm/tên), không
    /// theo thứ tự bấm.
    private var favoriteSanPhams: [SanPham] {
        sanPhams.filter { yeuThichIds.contains($0.id) }
    }

    /// Món nhân viên đánh dấu "Nổi bật" qua AppQuanLyIOS — dải quảng bá riêng NGAY ĐẦU tab Thực đơn
    /// (trên cả sidebar nhóm/Yêu thích), khác favoriteSanPhams ở chỗ đây là quán CHỦ Ý chọn hiện,
    /// không phải khách tự chọn. Thứ tự RANDOM mỗi lần tải (xem load()) — không giới hạn số lượng,
    /// xáo trộn để món nào cũng có cơ hội lên đầu thay vì luôn cùng 1 thứ tự cố định (theo Ten/ThuTu).
    /// Lưu vào @State (không phải computed property) để KHÔNG xáo lại giữa các lần render trong cùng
    /// 1 phiên xem (vd gõ tìm kiếm, bấm tim) — chỉ xáo lại khi thật sự có dữ liệu mới từ load().
    @State private var noiBatSanPhams: [SanPham] = []

    /// Bấm tim ở productRow — cập nhật lạc quan (optimistic) trước, gọi API sau; lỗi thì tự hoàn tác.
    private func toggleYeuThich(_ item: SanPham) {
        let dangYeuThich = yeuThichIds.contains(item.id)
        if dangYeuThich { yeuThichIds.remove(item.id) } else { yeuThichIds.insert(item.id) }
        capNhatSections()
        togglingYeuThichIds.insert(item.id)
        Task {
            let result = dangYeuThich
                ? await APIClient.shared.xoaYeuThich(item.id)
                : await APIClient.shared.themYeuThich(item.id)
            if !result.success {
                if dangYeuThich { yeuThichIds.insert(item.id) } else { yeuThichIds.remove(item.id) }
                capNhatSections()
            }
            togglingYeuThichIds.remove(item.id)
        }
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
    /// Lưu sẵn (19/11/2026, sửa lag) — trước là computed property, MỖI lần body vẽ lại (cuộn qua nhóm…) phải gom +
    /// sắp xếp lại toàn bộ ~200 món 2–3 lần (cột món + sidebar). Gọi capNhatSections() khi món/nhóm/bán chạy/yêu thích đổi.
    @State private var sections: [(nhom: NhomSanPham, items: [SanPham])] = []

    private func capNhatSections() { sections = tinhSections() }

    private func tinhSections() -> [(nhom: NhomSanPham, items: [SanPham])] {
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

        // Chỉ hiện mục "Yêu thích" khi đã có ít nhất 1 món — rỗng thì ẩn hẳn, đỡ chiếm 1 mục sidebar
        // vô nghĩa với khách chưa bấm tim món nào (feedback 2026-09-24).
        if !favoriteSanPhams.isEmpty {
            result.insert((nhom: NhomSanPham(id: Self.yeuThichNhomId, ten: "Yêu thích"), items: favoriteSanPhams), at: 0)
        }
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
        let _ = seasonalPreviewTick
        VStack(spacing: 0) {
            // Thanh tìm kiếm gradient tràn lên status bar — khớp DaySearchBar(tinted: true) của
            // tab Hoá đơn bên AppQuanLyIOS, thay .searchable() hệ thống (khác style, thụt xuống
            // dưới navigationTitle).
            SearchBar(text: $query, placeholder: "Tìm món...", trailing: notificationBell)

            // Banner dịp lễ đang hiệu lực (Tết/Valentine/Giáng sinh/2-9/30-4-1-5) — ẩn lúc đang tìm
            // kiếm giống dải đề xuất bên dưới (xem SeasonalEvent.active).
            if let seasonalTheme = SeasonalEvent.active, !isSearching {
                seasonalBanner(seasonalTheme)
            }

            // Dải "Món quán đề xuất" — NGAY ĐẦU tab, trên cả sidebar nhóm/Yêu thích, vì đây là màn
            // khách mở ra đầu tiên và thấy 100% lượt vào app. Ẩn lúc đang tìm kiếm (kết quả tìm nên
            // chiếm trọn màn, không cạnh tranh chỗ với dải quảng bá không liên quan tới từ khoá gõ).
            if !loading && error.isEmpty && !isSearching {  // luôn hiện (tab Flash sale luôn có, chủ quán 19/11)
                noiBatCarousel
            }

            Group {
                if loading {
                    fullScreenLoading()
                } else if !error.isEmpty {
                    VStack(spacing: 12) {
                        Text(error).foregroundColor(Theme.danger)
                        Button("Thử lại") { Task { await load() } }
                            .buttonStyle(.gradientProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSearching {
                    List(searchResults) { sp in productRow(sp) }
                        .listStyle(.plain)
                } else {
                    // 2026-09-25: đổi từ List(Section) sang ScrollView+LazyVStack — GIỐNG HỆT cách
                    // sidebar bên trái đã làm (ScrollView thường), thay vì List (UITableView/
                    // UICollectionView). Lý do đổi: List luôn có 1 khoảng trống lạ phía trên header
                    // đầu tiên lúc mới mở tab (chỉ tự hết sau khi khách vuốt tay 1 cái), gây LỆCH với
                    // sidebar (ScrollView thường, luôn bám sát đỉnh ngay từ đầu) — đã thử rất nhiều
                    // cách vá (nhử scrollTo nhiều biến thể, can thiệp thẳng UIScrollView.contentInset
                    // qua UIViewRepresentable) đều không ăn, có lần còn làm tệ hơn.
                    //
                    // Ban đầu thử pinnedViews: [.sectionHeaders] để ghim header y hệt List, nhưng
                    // header ghim (nổi đè lên nội dung đã cuộn qua) lộ ra thêm 1 lớp bug khác: nền
                    // header (Theme.primaryTint chỉ đục 12%) để lộ nội dung bên dưới xuyên qua, chồng
                    // lấn/nhoè khi header snap vào vị trí ghim — sau khi thử vá (nền đục hơn, ép chiều
                    // cao cố định) vẫn còn thấy lỗi, BỎ HẲN ghim theo yêu cầu: header giờ cuộn bình
                    // thường như mọi nội dung khác, không còn "dính" ở đỉnh khi cuộn qua — né toàn bộ
                    // lớp bug này, đơn giản và ổn định hơn hẳn.
                    VStack(alignment: .leading, spacing: 0) {
                        // Title ngay trên menu — GIỮ emoji (chủ quán 19/11: chỉ tiêu đề nhóm đổi sang ảnh món).
                        Text("⭐ Menu 2026")
                            .accessibilityIdentifier("tieu-de-menu")  // UITests/BamNhomMenuUITests đo đỉnh cột món từ đây
                            .font(.system(size: 15, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.bg)
                        HStack(spacing: 0) {
                        nhomSidebar(onTap: { id in
                            isJumpingToSection = true
                            selectedNhomId = id
                            scrollRequest = ScrollRequest(id: id, tick: (scrollRequest?.tick ?? 0) + 1)
                        })
                        ScrollViewReader { proxy in
                            ScrollView {
                                // 19/11/2026 — GỐC lỗi bấm nhóm nhảy lệch trên iOS 16–18: trước đây CẢ cột là 1 LazyVStack,
                                // nhóm chưa vẽ thì iOS ĐOÁN chiều cao (nhóm 2 món, nhóm 20 món đoán như nhau) → toạ độ
                                // nhóm xa và cả chiều dài cột đều là số đoán: scrollTo dừng lệch, cuộn tới toạ độ thật thì
                                // rơi ra ngoài phần iOS nghĩ là có nội dung → màn trắng. Bấm lần lượt từ trên xuống thì
                                // đúng vì nhóm nào cũng đã vẽ qua. Giờ: khung nhóm là VStack THƯỜNG, mỗi khung khai
                                // thẳng chiều cao (header + số món × rowHeight) → iOS biết chính xác toạ độ mọi nhóm
                                // ngay từ đầu; món BÊN TRONG mỗi nhóm vẫn là LazyVStack nên chỉ vẽ món đang hiện.
                                VStack(spacing: 0) {
                                    ForEach(sections, id: \.nhom.id) { section in
                                        VStack(spacing: 0) {
                                            // Header bọc LazyVStack riêng để .onAppear chỉ chạy khi header thật sự cuộn
                                            // tới (VStack thường gọi onAppear MỌI header ngay lúc mở) — giữ cách cột trái
                                            // tự chọn nhóm theo cuộn tay như cũ.
                                            LazyVStack(spacing: 0) {
                                                sectionHeader(section.nhom, items: section.items)
                                                    .onAppear {
                                                        guard !isJumpingToSection else { return }
                                                        selectedNhomId = section.nhom.id
                                                    }
                                            }
                                            .frame(height: Self.categoryHeaderHeight)
                                            // Mọi section trong `sections` đều đảm bảo có ít nhất 1 món
                                            // (Yêu thích rỗng bị lọc hẳn khỏi danh sách, xem sections) —
                                            // không cần nhánh rỗng riêng nữa.
                                            // 09/11/2026 (đồng bộ toàn app theo bộ khung TK — KHÔNG theo ảnh mẫu): món
                                            // của mỗi nhóm gom vào 1 thẻ trắng bo 18 có bóng nhẹ, kẻ mảnh giữa các món
                                            // (kiểu nhóm dòng ở tab Tài khoản), trên nền xám Theme.bg.
                                            // 19/11/2026: món là VStack THƯỜNG — LazyVStack ở đây vẫn ĐOÁN vị trí món khi cuộn
                                            // ngược từ dưới lên vào giữa nhóm → món cuối tràn ra khỏi khung, đè tiêu đề nhóm sau.
                                            // Chỉ ẢNH món còn lazy (xem productRow) để không tải hết ảnh lúc mở.
                                            VStack(spacing: 0) {
                                                ForEach(Array(section.items.enumerated()), id: \.offset) { itemIndex, sp in
                                                    productRow(sp)
                                                        // Kẻ giữa các món vẽ bằng overlay (KHÔNG chiếm chiều cao) — chiều
                                                        // cao nhóm phải đúng = số món × rowHeight, xem khung bên dưới.
                                                        .overlay(alignment: .bottom) {
                                                            if itemIndex < section.items.count - 1 {
                                                                Divider().padding(.leading, 84)
                                                            }
                                                        }
                                                        // id ghép section+món — "Bạc Xỉu Đá" xuất hiện ở CẢ mục "Yêu
                                                        // thích" lẫn mục "Bạc Xỉu" thật (cùng 1 sp.id); trùng id giữa
                                                        // 2 section gây lẫn/tráo render (dòng trống).
                                                        .id("\(section.nhom.id)|\(sp.id)")
                                                }
                                            }
                                            .frame(height: CGFloat(section.items.count) * Self.rowHeight, alignment: .top)
                                            .background(
                                                RoundedRectangle(cornerRadius: TK.bo, style: .continuous)
                                                    .fill(Color(.systemBackground))
                                                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                                            )
                                            .padding(.horizontal, 10).padding(.bottom, Self.khoangCachNhom)
                                        }
                                        .id(section.nhom.id)
                                    }
                                }
                            }
                            .onChange(of: scrollRequest) { req in
                                guard let req else { return }
                                // Khung nhóm là VStack thường cao xác định (xem trên) nên scrollTo tính đúng toạ độ
                                // thật, kể cả nhóm xa chưa từng vẽ; nhóm cuối ngắn thì tự dừng ở đáy cột.
                                withAnimation { proxy.scrollTo(req.id, anchor: .top) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    guard scrollRequest?.tick == req.tick else { return }  // khách đã bấm nhóm khác
                                    isJumpingToSection = false
                                }
                            }
                            .background(Theme.bg)
                            .refreshable {
                                await load(silent: true)
                            }
                        }
                        }
                    }
                }
            }
        }
        .task { if sanPhams.isEmpty { await load() } }
        .task { await phaKem.chay() }
        #if DEV_LOGIN
        // 🧪 Xem thử Sale off: 2 món Best Sellers + món đầu nhóm đang chọn, giảm 3K trong 99 giây (chỉ máy này).
        .onReceive(NotificationCenter.default.publisher(for: .xemThuSaleOff)) { _ in
            var ids = noiBatSanPhams.prefix(2).map(\.id)
            if let mon = sections.first(where: { $0.nhom.id == selectedNhomId })?.items.first { ids.append(mon.id) }
            phaKem.batXemThu(ids)
        }
        #endif
        .task { await SeasonalEvent.load() }
        .onReceive(NotificationCenter.default.publisher(for: .christmasPreviewToggled)) { _ in
            seasonalPreviewTick += 1
        }
        // Màn chúc mừng quà đầu tháng đã chuyển lên ContentView (06/11/2026) — hiện ở mọi tab.
        .sheet(item: $picking) { sp in
            ProductPickerSheet(
                sanPham: sp,
                toppings: toppings,
                isThuocLa: thuocLaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                khongChoKhongDa: khongChoKhongDaNhomIds.contains(sp.nhomSanPhamId ?? ""),
                showTraNote: caPheNhomIds.contains(sp.nhomSanPhamId ?? ""),
                giaRiengMap: giaRiengMap,
                giamPhaKem: PhaKemBang.giam(sp.id),
                onConfirm: { bienThe, soLuong, ghiChu, toppings in
                    cart.addItem(sanPhamBienTheId: bienThe.id, tenSanPham: sp.ten, tenBienThe: bienThe.tenBienThe, giaBan: giaHienThi(bienThe), soLuong: soLuong, ghiChu: ghiChu, toppings: toppings, hinhAnh: sp.hinhAnh, sanPhamId: sp.id)
                }
            ) { picking = nil }
        }
    }

    /// Màu nền xen kẽ giữa 2 nhóm liền kề trong menu — chỉ khác biệt nhẹ (không phải màu sắc rực) để
    /// không cạnh tranh với ảnh/tên món, chỉ đủ giúp mắt nhận ra ranh giới khi cuộn nhanh. CỐ Ý KHÔNG
    /// tint theo dịp lễ nữa (thử 2026-11-05, bị chê "mờ ảnh/chữ món") — dòng món luôn giữ trắng/xám hệ
    /// thống để đảm bảo đọc rõ, trang trí dịp lễ chỉ còn ở banner/nav bar/nút CTA.
    private func sectionBackground(_ index: Int) -> Color {
        index % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemGroupedBackground).opacity(0.5)
    }

    /// Header đầu mỗi nhóm — dùng làm header của Section trong List nên tự ghim (pinned) khi cuộn
    /// (hành vi mặc định của UITableView .plain style, không cần code thêm). Nút "Chọn ngẫu nhiên"
    /// GIỮ LẠI (feedback 2026-09-27: bỏ hẳn là quá tay, chỉ cần bớt nổi bật) nhưng đổi hẳn sang dạng
    /// FLAT — icon shuffle + chữ nhỏ màu primary trên nền trong suốt, không còn pill nền đậm
    /// primaryGradient như bản trước, đỡ cạnh tranh thị giác với tên nhóm.
    /// Nền tên nhóm bên phải đổi từ pill ôm sát chữ sang PHỦ FULL cả thanh header (feedback
    /// 2026-09-28 "nền tên nhóm bên phải menu full") — dùng thẳng Theme.primaryTint cho toàn bộ
    /// header thay vì Color(.secondarySystemGroupedBackground) trung tính cũ, nổi bật hơn khớp cột
    /// nhóm sidebar bên trái đã có nền tô đậm cho mục đang chọn.
    private func sectionHeader(_ nhom: NhomSanPham, items: [SanPham]) -> some View {
        HStack(spacing: 8) {
            // 19/11/2026: bỏ emoji nhóm → ảnh 1 món ngẫu nhiên của nhóm (xem anhMuc).
            anhMuc(nhom.id, items, co: 28)
            Text(nhom.ten).font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
                .accessibilityIdentifier("header|\(nhom.ten)")  // UITests/BamNhomMenuUITests
            Spacer()
            if !items.isEmpty {
                Button {
                    picking = items.randomElement()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle").font(.system(size: 11, weight: .semibold))
                        Text("Ngẫu nhiên").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Theme.primary)
                    .padding(.vertical, 6).padding(.leading, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: Self.categoryHeaderHeight, maxHeight: Self.categoryHeaderHeight)
        // 09/11/2026: header không ghim (đã bỏ pinned từ 2026-09-25) nên nằm thẳng trên nền xám Theme.bg, phía dưới là
        // thẻ trắng chứa món của nhóm — không cần nền tô riêng nữa.
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
                            .padding(.leading, 8)
                            .frame(height: Self.categoryHeaderHeight)
                            // 09/11/2026: mục đang chọn là ô bo góc tô nhạt (kiểu ô chọn TK) thay vạch dọc + nền phủ ngang.
                            // 09/11/2026 (chủ quán: trông như lỗi giao diện): cột nền xám liền với nội dung, mục đang chọn là
                            // thẻ trắng nhỏ có bóng nhẹ — cùng kiểu thẻ TK, không còn khối trắng + vạch kẻ dọc.
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? Color(.systemBackground) : Color.clear)
                                    .shadow(color: .black.opacity(isSelected ? 0.06 : 0), radius: 4, y: 1)
                            )
                            .padding(.leading, 8).padding(.trailing, 4).padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // UITests/BamNhomMenuUITests tìm nút nhóm + kiểm nhóm đang chọn qua 2 dòng này.
                        .accessibilityIdentifier("nhom|\(section.nhom.ten)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .frame(width: 88)
            .background(Theme.bg)
            // Khách tự cuộn tay bên phải → header row .onAppear đổi selectedNhomId theo → tự cuộn
            // sidebar theo để mục đang chọn luôn nằm trong tầm nhìn, không bắt khách tự kéo tìm.
            .onChange(of: selectedNhomId) { id in
                withAnimation { sidebarProxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// Icon nhóm (emoji) của 1 món — dùng làm fallback thumbnail khi món chưa có hình, xem
    /// productRow(). Tra theo nhomSanPhamId của món, không phải nhóm đang chọn ở sidebar (khách có
    /// thể đang xem "Yêu thích"/"#Khác" gom nhiều nhóm khác nhau).
    private func nhomIcon(for item: SanPham) -> String {
        guard let id = item.nhomSanPhamId, let ten = nhoms.first(where: { $0.id == id })?.ten else {
            return Theme.defaultNhomIcon
        }
        return Theme.nhomIcons[ten] ?? Theme.defaultNhomIcon
    }

    /// Giá THẬT sẽ bị tính lúc đặt cho 1 biến thể — giá riêng (nếu có) ghi đè giá catalog, khớp
    /// đúng logic server (DatHangService.DatMonAsync). Dùng ở MỌI nơi hiện giá trong tab Thực đơn.
    private func giaHienThi(_ b: SanPhamBienThe) -> Double { giaRiengMap[b.id] ?? b.giaBan }

    /// Giá hiện ở dòng danh sách + có phải size đó đang mang giá riêng hay không. Đổi 2 lần
    /// 2026-09-29:
    /// 1) Bug đầu: coGiaRieng tính bằng contains{} trên MỌI size trong khi giá hiện lại lấy min() —
    ///    món 2 size (vd Findy Cà Phê: Chuẩn giá riêng 40k, L catalog 35k) hiện "35.000 [Giá riêng]"
    ///    — sai cả số lẫn nhãn (size đang hiện giá không hề có giá riêng).
    /// 2) Fix bằng min() đúng cặp thì hết sai nhưng lại gây hiểu lầm khác (feedback kèm ảnh): khách
    ///    có giá riêng CAO hơn catalog ở size mặc định (Chuẩn) thấy dòng list hiện hẳn giá size KHÁC
    ///    (L, rẻ hơn vì không có giá riêng) mà KHÔNG có badge — tưởng đó là giá sẽ trả, vào chọn mới
    ///    biết size Chuẩn đắt hơn. Chốt cuối (feedback "hiện giá size chuẩn"): LUÔN ưu tiên hiện giá
    ///    của size MẶC ĐỊNH (macDinh=true, fallback size đầu tiên nếu không món nào đánh dấu mặc
    ///    định) — khớp đúng size khách sẽ thấy trước tiên khi bấm vào chọn món.
    private func giaMacDinhVaCoGiaRieng(_ item: SanPham) -> (gia: Double, coGiaRieng: Bool)? {
        guard let b = item.bienThe.first(where: { $0.macDinh }) ?? item.bienThe.first else { return nil }
        return (giaHienThi(b), giaRiengMap[b.id] != nil)
    }

    /// Nhãn giá "25K" đè góc dưới phải ảnh món — dùng chung dòng món + thẻ Best Sellers/Sale off. Món pha kèm: giá đã
    /// giảm, nền đỏ. Nền trong 65% để còn thấy ảnh.
    fileprivate static func nhanGiaK(_ gia: Double, giam: Double, co: CGFloat) -> some View {
        Text(giaNghin(gia - giam) + "K")
            .font(.system(size: co, weight: .bold)).foregroundColor(.white)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, co / 3).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(giam > 0 ? Theme.danger : Theme.primary.opacity(0.65)))
    }

    /// Ảnh đại diện đầu mục (thay emoji, chủ quán 19/11/2026): ảnh THẬT logo mới (có bản tách nền, không phải ảnh
    /// mặc định) của 1 món ngẫu nhiên trong mục; mục chưa món nào có → ảnh mặc định ly đá. Ngẫu nhiên theo hạt giống
    /// mỗi lần mở app — đổi giữa các lần mở nhưng không nhảy khi màn vẽ lại.
    private static let hatGiongAnhMuc = UInt64.random(in: 0...UInt64.max)
    private static let anhMacDinhDa = "https://api.denncoffee.com/menu-images-cat/mac-dinh.webp?v=2"
    private static func anhDaiDienMuc(_ khoa: String, _ items: [SanPham]) -> String {
        var thay = Set<String>()
        let co = items.compactMap(\.hinhAnhCat).filter { !$0.contains("/mac-dinh") && thay.insert($0).inserted }
        guard !co.isEmpty else { return anhMacDinhDa }
        var h = hatGiongAnhMuc
        for u in khoa.unicodeScalars { h = h &* 31 &+ UInt64(u.value) }
        return co[Int(h % UInt64(co.count))]
    }

    /// Ảnh ly tách nền KHÔNG vẽ nền theme (chủ quán 19/11: bỏ nền ảnh đầu mục) — chỉ cái ly trong suốt.
    private static func anhLyKhongNen(_ url: String, co: CGFloat) -> some View {
        CachedAsyncImage(url: URL(string: url), kichThuoc: co) { $0.resizable().aspectRatio(contentMode: .fit) } placeholder: { Color.clear }
            .frame(width: co, height: co)
    }

    private func anhMuc(_ khoa: String, _ items: [SanPham], co: CGFloat) -> some View {
        Self.anhLyKhongNen(Self.anhDaiDienMuc(khoa, items), co: co)
    }

    /// Giá theo nghìn, không ".000đ": 25000 → "25", 25500 → "25,5".
    private static func giaNghin(_ gia: Double) -> String {
        let nghin = (gia / 100).rounded() / 10
        return nghin == nghin.rounded()
            ? String(Int(nghin))
            : String(format: "%.1f", nghin).replacingOccurrences(of: ".", with: ",")
    }

    /// Dòng món = MonRow Equatable (19/11/2026, sửa lag): cột món là VStack thường (~200 dòng dựng cùng lúc), mỗi lần
    /// MenuView vẽ lại (cuộn qua nhóm đổi selectedNhomId, Flash sale đổi…) SwiftUI chỉ so dữ liệu từng dòng, dòng nào
    /// không đổi thì bỏ qua — không dựng lại cả 200 dòng.
    private func productRow(_ item: SanPham) -> some View {
        let gia = giaMacDinhVaCoGiaRieng(item)
        return MonRow(
            id: item.id, ten: item.ten, hinhAnh: item.hinhAnh, hinhAnhCat: item.hinhAnhCat,
            gia: gia?.gia, coGiaRieng: gia?.coGiaRieng ?? false, giam: giamPhaKem(item),
            isFavorite: yeuThichIds.contains(item.id), dangDoiTim: togglingYeuThichIds.contains(item.id),
            onChon: { picking = item }, onTim: { toggleYeuThich(item) }
        ).equatable()
    }
}

/// Một dòng món ở cột món tab Thực đơn — xem MenuView.productRow. Chỉ chứa dữ liệu Equatable (closure bỏ qua khi so).
private struct MonRow: View, Equatable {
    let id: String
    let ten: String
    let hinhAnh: String?
    let hinhAnhCat: String?
    let gia: Double?
    let coGiaRieng: Bool
    let giam: Double
    let isFavorite: Bool
    let dangDoiTim: Bool
    let onChon: () -> Void
    let onTim: () -> Void

    static func == (a: MonRow, b: MonRow) -> Bool {
        a.id == b.id && a.ten == b.ten && a.hinhAnh == b.hinhAnh && a.hinhAnhCat == b.hinhAnhCat && a.gia == b.gia
            && a.coGiaRieng == b.coGiaRieng && a.giam == b.giam && a.isFavorite == b.isFavorite && a.dangDoiTim == b.dangDoiTim
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onChon) {
                HStack(spacing: 12) {
                    // 19/11/2026 (thử, chủ quán): giá ĐÈ LÊN đáy ảnh món (nhãn nền màu theme, chữ trắng) — đã thử giá dưới
                    // ảnh (1080) / trên ảnh (1082). Đè lên nên dòng giữ cao 72 như cũ.
                    // Ảnh bọc LazyVStack 1 phần tử, khung cố định: chỉ tải ảnh khi dòng cuộn tới (cột món là VStack thường).
                    // 19/11/2026: đã thử bỏ để đỡ tính toán khi cuộn → app xếp hàng tải ~200 ảnh cùng lúc, ảnh đang hiện
                    // phải chờ cuối, màn trống ảnh (ảnh chụp chủ quán) — GIỮ lại.
                    LazyVStack(spacing: 0) {
                        AnhMonView(hinhAnh: hinhAnh, hinhAnhCat: hinhAnhCat, width: 56, height: 56)
                    }
                    .frame(width: 56, height: 56)
                        // Góc dưới phải, nhãn nhỏ "25K" để che ảnh ít nhất (chủ quán 19/11).
                        .overlay(alignment: .bottomTrailing) {
                            if let gia {
                                // Bỏ ".000đ" (chủ quán 19/11): 25.000 → "25K", lẻ nghìn 25.500 → "25,5K".
                                MenuView.nhanGiaK(gia, giam: giam, co: 9) // pha kèm: giá đã giảm, nền đỏ
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            if giam > 0 { MenuView.nhanGiam(giam, co: 9).padding(2) }
                        }
                        // Nhãn sát mép dưới + mép phải (chủ quán 19/11) — cắt lại theo góc bo của ảnh để góc nhãn không lòi ra.
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        // 19/11/2026 (thử, chủ quán: tên dài thì chữ nhỏ lại): vừa 1 dòng cỡ 15 thì giữ, không vừa
                        // thì xuống cỡ 13 tối đa 2 dòng. Căn trái tường minh — chữ trong Button mặc định căn giữa
                        // (dòng 2 bị thụt vào). Cỡ 13 × 2 dòng vừa rowHeight.
                        ViewThatFits(in: .horizontal) {
                            Text(ten)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(ten)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                        }
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        if coGiaRieng { giaRiengBadge() }
                    }
                    Spacer(minLength: 0)
                }
            }
            .foregroundColor(.primary)
            // Nút tim tách riêng khỏi Button mở picker — bấm tim không được kích hoạt luôn modal chọn
            // size/topping phía trên.
            Button(action: onTim) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(isFavorite ? Theme.primary : .secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(dangDoiTim)
        }
        .padding(.horizontal, 16)
        // maxWidth: .infinity — ra khỏi List (giờ dùng LazyVStack thường) không còn tự ép full-width
        // theo hàng như List nữa, phải tự khai để background(sectionBackground)/Divider phủ hết ngang.
        // Cao CỐ ĐỊNH rowHeight (18/11/2026) để bấm nhóm ở sidebar nhảy chính xác (khung nhóm cao xác định, xem body). Ảnh 56 (giá đè lên ảnh) + đệm 8×2 = 72;
        // mọi chữ trong dòng là cỡ cố định (.system(size:)) nên không bị tràn.
        .frame(maxWidth: .infinity, minHeight: MenuView.rowHeight, maxHeight: MenuView.rowHeight, alignment: .leading)
    }
}

extension MenuView {
    /// Số món hiện trọn vẹn trong dải đề xuất — 3 + hé 1 phần món thứ 4 để khách biết còn cuộn được
    /// tiếp, tránh tưởng đã hết chỉ vì vừa khít đúng 3 món tràn viền phải.
    private static let noiBatCarouselVisibleCount: CGFloat = 3.4
    private static let noiBatCarouselSpacing: CGFloat = 12
    private static let noiBatCarouselPadding: CGFloat = 16

    /// Banner trang trí theo dịp lễ đang hiệu lực (Tết/Valentine/Giáng sinh/2-9/30-4-1-5) — câu chúc
    /// (SeasonalEvent.bannerTitle/bannerSubtitle) lấy thẳng ten/moTa của voucher lễ tết tương ứng ở
    /// Backend, KHÔNG hardcode ở app (xem SeasonalEvent.swift).
    private func seasonalBanner(_ theme: SeasonalTheme) -> some View {
        HStack(spacing: 12) {
            Text(theme.leadingEmoji).font(.system(size: 36))
            VStack(alignment: .leading, spacing: 2) {
                Text(SeasonalEvent.bannerTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(SeasonalEvent.bannerSubtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer()
            Text(theme.trailingEmoji).font(.system(size: 30))
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background {
            LinearGradient(colors: [theme.primary, theme.primaryDark], startPoint: .leading, endPoint: .trailing)
                .overlay {
                    // Hoạ tiết TĨNH ngay trong banner cho cảm giác "hero" đậm đà như app/Dribbble
                    // tham khảo (2026-11-05).
                    Canvas { context, size in
                        var seed: UInt64 = 777
                        func rand() -> CGFloat {
                            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                            return CGFloat(seed >> 33) / CGFloat(1 << 31)
                        }
                        context.opacity = 0.20
                        for _ in 0..<8 {
                            let x = rand() * size.width
                            let y = rand() * size.height
                            let fontSize: CGFloat = 16 + rand() * 14
                            let resolved = context.resolve(Text(theme.patternSymbols.randomElement() ?? "").font(.system(size: fontSize)))
                            context.draw(resolved, at: CGPoint(x: x, y: y), anchor: .center)
                        }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    /// Dải card cuộn ngang cho món "Nổi bật" (SanPham.noiBat, nhân viên tự bật qua Desktop) — xem
    /// noiBatSanPhams. Card gọn hơn productRow (dọc, ảnh lớn hơn) để tách biệt rõ với List món bên
    /// dưới, giống pattern banner đề xuất của Shopee Food/GrabFood.
    private var noiBatCarousel: some View {
        let sale = monSale
        // Tab Flash sale LUÔN hiện kể cả chưa có món (chủ quán 19/11) — trống thì hiện câu giải thích. Mặc định Best Sellers.
        let tab = noiBatSanPhams.isEmpty ? 1 : tabDeXuat
        let ds = tab == 1 ? sale : noiBatSanPhams
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                if !noiBatSanPhams.isEmpty {
                    tabDeXuatTieuDe("🔥 Best Sellers", chon: tab == 0) { tabDeXuat = 0 }
                }
                tabDeXuatTieuDe("⚡ Flash Sale", chon: tab == 1, dem: sale.isEmpty ? nil : sale.count) { tabDeXuat = 1 }
            }
            .padding(.horizontal, 16)
            if ds.isEmpty {
                Text(NoiDung.text("flashSaleTrong"))
                    .font(.system(size: 13)).foregroundColor(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .frame(height: 90 + 6 + 18)
            } else {
            GeometryReader { geo in
                // 3 món trọn vẹn = 3 chiều rộng card + 2 khoảng cách giữa chúng (khoảng cách thứ 3,
                // trước món thứ 4, KHÔNG tính vào vì món thứ 4 chỉ hé 1 phần, không cần đủ khoảng
                // cách chuẩn trước nó để vẫn nhìn "còn tiếp").
                let cardWidth = (geo.size.width - Self.noiBatCarouselPadding * 2 - Self.noiBatCarouselSpacing * 2)
                    / floor(Self.noiBatCarouselVisibleCount)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Self.noiBatCarouselSpacing) {
                        ForEach(ds) { item in
                            deXuatCard(item, cardWidth: cardWidth)
                        }
                    }
                    .padding(.horizontal, Self.noiBatCarouselPadding)
                }
            }
            // Chiều cao cố định cho GeometryReader — nó tự thân không có kích thước "tự nhiên" như
            // VStack thường, phải khai rõ để không chiếm hết phần còn lại của màn hình (GeometryReader
            // mặc định tham lam .frame(maxHeight: .infinity)). Khớp ảnh 90 + spacing 6 + 2 dòng chữ.
            .frame(height: 90 + 6 + 18)
            }
        }
        .padding(.vertical, 10)
        .background(Theme.bg) // 09/11/2026: cùng nền xám toàn app
    }

    /// Tiêu đề tab của dải đề xuất — tab đang chọn chữ đậm + gạch chân màu theme, tab kia chữ xám.
    private func tabDeXuatTieuDe(_ ten: String, chon: Bool, dem: Int? = nil, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(ten)
                        .font(.system(size: 15, weight: chon ? .bold : .semibold))
                        .foregroundColor(chon ? .primary : Theme.textFaint)
                    if let dem {
                        Text("\(dem)")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(Theme.danger))
                    }
                }
                Capsule().fill(chon ? Theme.primary : Color.clear).frame(height: 2)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    /// Thẻ món trong dải đề xuất (Best Sellers / Sale off). Món đang pha kèm: nhãn "-3K", đồng hồ đếm ngược,
    /// giá đỏ + giá cũ gạch ngang.
    private func deXuatCard(_ item: SanPham, cardWidth: CGFloat) -> some View {
        let giam = giamPhaKem(item)
        return Button { picking = item } label: {
            VStack(alignment: .leading, spacing: 6) {
                AnhMonView(hinhAnh: item.hinhAnh, hinhAnhCat: item.hinhAnhCat, width: cardWidth, height: 90)
                    .overlay(alignment: .topLeading) {
                        if giam > 0 { Self.nhanGiam(giam, co: 11).padding(5) }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if giam > 0, let het = PhaKemBang.hetLuc(item.id) {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text("⚡ \(PhaKemStore.demNguoc(het, luc: ctx.date))")
                                    .font(.system(size: 11, weight: .bold).monospacedDigit()).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.black.opacity(0.75)))
                            }
                            .padding(5)
                        }
                    }
                    // 19/11/2026: giá "25K" góc dưới phải ảnh, đồng bộ dòng món (bỏ dòng giá dưới tên).
                    .overlay(alignment: .bottomTrailing) {
                        if let gia = giaMacDinhVaCoGiaRieng(item) { Self.nhanGiaK(gia.gia, giam: giam, co: 11) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                HStack(spacing: 4) {
                    Text(item.ten)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if giaMacDinhVaCoGiaRieng(item)?.coGiaRieng == true { giaRiengBadge() }
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    /// Món đang pha kèm còn trong thực đơn app, sắp hết giờ đứng trước.
    private var monSale: [SanPham] {
        let _ = phaKem.phienBan
        return PhaKemBang.dangPha().compactMap { d in sanPhams.first { $0.id == d.sanPhamId } }
    }

    private func giamPhaKem(_ item: SanPham) -> Double {
        let _ = phaKem.phienBan
        return PhaKemBang.giam(item.id)
    }

    /// Nhãn đỏ "-3K".
    fileprivate static func nhanGiam(_ giam: Double, co: CGFloat) -> some View {
        Text("-\(Int((giam / 1000).rounded()))K")
            .font(.system(size: co, weight: .bold)).foregroundColor(.white)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, co * 0.45).padding(.vertical, 1)
            .background(Capsule().fill(Theme.danger))
    }

    /// Gộp món "Nổi bật" (chọn tay qua AppQuanLyIOS) VÀ top bán chạy 30 ngày (tự động, banChayIds) —
    /// tối đa 5 món chọn tay + lấp đầy phần còn lại tới 10 bằng top bán chạy, bỏ trùng nếu 1 món vừa
    /// được chọn tay vừa đang là top bán chạy (lấy tiếp món bán chạy kế tiếp cho đủ 10). Nhân viên có
    /// thể đã đánh dấu NHIỀU hơn 5 món "Nổi bật" (không giới hạn số lượng ở AppQuanLyIOS) — CHỈ hiện
    /// tối đa 5 trong dải này, không phải giới hạn số món được phép đánh dấu.
    ///
    /// Phần TỰ ĐỘNG lọc thêm giá tối thiểu 25.000đ (2026-09-26, phát hiện qua ảnh chụp thật: Bò Húc/
    /// Cà Phê Đen Đá 20k lọt top vì bán số lượng lớn nhưng giá trị thấp — không đáng "đề xuất" quảng
    /// bá). Phần chọn tay KHÔNG áp ngưỡng này — nhân viên chủ ý chọn thì tôn trọng, dù giá thấp.
    private static let deXuatTuDongGiaToiThieu: Double = 25_000

    private static func tinhDeXuat(sanPhams: [SanPham], banChayIds: [String]) -> [SanPham] {
        let chonTay = Array(sanPhams.filter(\.noiBat).prefix(5))
        let idsChonTay = Set(chonTay.map(\.id))
        let banChay = banChayIds
            .compactMap { id in sanPhams.first { $0.id == id && !idsChonTay.contains($0.id) } }
            .filter { ($0.bienThe.map(\.giaBan).min() ?? 0) >= deXuatTuDongGiaToiThieu }
            .prefix(max(0, 10 - chonTay.count))
        return (chonTay + banChay).shuffled()
    }

    private func load(silent: Bool = false) async {
        let lanDau = selectedNhomId.isEmpty
        // Cache RAM (APIClient.catalogCache, 5 phút) mất sạch mỗi lần app bị kill — khách tắt mở lại
        // app là coi như rỗng, phải chờ network thật xong mới hiện được gì. Lần tải đầu (sanPhams
        // rỗng) thử hiện tạm bản cache ĐĨA cuối cùng (không hạn) ngay lập tức, tắt loading toàn màn
        // hình luôn — network thật vẫn chạy tiếp bên dưới và ghi đè bằng dữ liệu mới khi xong.
        if sanPhams.isEmpty, let snapshot = await APIClient.shared.getMenuDiskSnapshot() {
            sanPhams = snapshot.sanPhams.filter { !$0.ngungBan && $0.storeFoodId != nil && !$0.khongLenStore }
            nhoms = snapshot.nhoms
            toppings = snapshot.toppings.filter { !$0.ngungBan }
            banChayIds = snapshot.banChayIds
            giaRiengMap = snapshot.giaRieng
            noiBatSanPhams = Self.tinhDeXuat(sanPhams: sanPhams, banChayIds: banChayIds)
            capNhatSections()
            if selectedNhomId.isEmpty { selectedNhomId = Self.yeuThichNhomId }
            loading = false
        } else if !silent {
            loading = true
        }
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
        async let giaRiengTask = APIClient.shared.getGiaRieng()
        // 09/11/2026: KHÔNG chờ /vi (API chậm nhất, chỉ để lấy Yêu thích + hạng) cùng thực đơn — áp vi ở cuối hàm.
        let (spResult, nhom, top, banChay, giaRieng) = await (spTask, nhomTask, topTask, banChayTask, giaRiengTask)
        giaRiengMap = giaRieng
        if let viNhanh = BoNhoTam.vi { yeuThichIds = Set(viNhanh.yeuThichSanPhamIds) }
        // Chỉ chặn màn bằng lỗi khi KHÔNG có gì để hiện (lần tải đầu thất bại) — refresh (kéo-thả)
        // hoặc network thật thất bại sau khi đã hiện snapshot đĩa thì giữ NGUYÊN danh sách đang hiện,
        // không ghi đè bằng mảng rỗng chỉ vì 1 lần mất mạng thoáng qua.
        if spResult.isSuccess {
            let sp = spResult.data ?? []
            sanPhams = sp.filter { !$0.ngungBan && $0.storeFoodId != nil && !$0.khongLenStore }
            nhoms = nhom
            toppings = top.filter { !$0.ngungBan }
            banChayIds = banChay
            noiBatSanPhams = Self.tinhDeXuat(sanPhams: sanPhams, banChayIds: banChayIds)
            // Tải ngầm ảnh mọi món vào đĩa (chỉ ảnh chưa có) — cuộn tới đâu cũng có sẵn, không chờ mạng.
            ImageCache.shared.taiNgam(sanPhams.compactMap { URL(string: $0.hinhAnhCat ?? $0.hinhAnh ?? "") })
        } else if sanPhams.isEmpty {
            error = spResult.message ?? "Không tải được thực đơn, vui lòng thử lại."
        }
        // Mục đầu tiên khi mở app ưu tiên "Yêu thích" nếu có món — không nhớ nhóm khách chọn lần
        // trước nữa. Yêu thích rỗng thì không có mặt trong sections (xem sections), dòng if ngay dưới
        // tự rơi về section thật đầu tiên.
        if selectedNhomId.isEmpty {
            selectedNhomId = Self.yeuThichNhomId
        }
        capNhatSections()
        if !sections.contains(where: { $0.nhom.id == selectedNhomId }) {
            selectedNhomId = sections.first?.nhom.id ?? ""
        }
        loading = false
        // Áp /vi sau khi thực đơn đã hiện. Lần đầu chưa có Yêu thích (nên đã rơi về nhóm đầu) mà giờ có → chọn lại Yêu thích.
        if let vi = await viTask {
            BoNhoTam.vi = vi
            let truocRong = yeuThichIds.isEmpty
            yeuThichIds = Set(vi.yeuThichSanPhamIds)
            capNhatSections()
            KhachHangSession.shared.capNhatHang(vi.hang)
            if lanDau && truocRong && !yeuThichIds.isEmpty { selectedNhomId = Self.yeuThichNhomId }
        }
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
    /// Giá riêng của khách đang đăng nhập (key sanPhamBienTheId) — feedback 2026-09-29, xem
    /// MenuView.giaHienThi. Mặc định rỗng cho nơi gọi cũ chưa kịp cập nhật (an toàn, rơi về giá
    /// catalog như trước).
    var giaRiengMap: [String: Double] = [:]
    /// "Pha kèm" đang giảm cho món này (mỗi ly, mọi size) — 0 khi không. Chỉ để HIỆN giá; giỏ hàng tự tính sống theo PhaKemBang.
    var giamPhaKem: Double = 0
    let onConfirm: (_ bienThe: SanPhamBienThe, _ soLuong: Int, _ ghiChu: String?, _ toppings: [CartTopping]) -> Void
    let onDone: () -> Void

    /// Giá THẬT sẽ bị tính — khớp MenuView.giaHienThi, tách riêng vì struct này độc lập không share
    /// state với MenuView.
    private func giaHienThi(_ b: SanPhamBienThe) -> Double { (giaRiengMap[b.id] ?? b.giaBan) - giamPhaKem }

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

    /// Chip biến thể — Size L/XL (khớp "Size L"/lỗi chính tả có thật "Soze L", và riêng "Size XL",
    /// xem isSizeLBienThe/isSizeXLBienThe ở Theme.swift) có giao diện SANG hơn hẳn các size khác khi
    /// active — gradient vàng kim + viền sáng (BỎ icon 👑/👑👑 2026-09-29 theo feedback, chỉ còn giữ
    /// màu sắc "lên đời"), để bấm vào tự thấy khác biệt thay vì chỉ đổi màu nền như chip thường —
    /// mục tiêu: khách quen/thích cảm giác chọn size lớn, khớp 2 voucher ĐỘC LẬP UpsizeL (tặng Size
    /// L) / UpsizeXL (tặng Size XL), mỗi voucher 1 lần/tài khoản, khách có thể nhận CẢ HAI, đang
    /// khuyến khích thói quen này.
    private func isSizeL(_ b: SanPhamBienThe) -> Bool { isSizeLBienThe(b.tenBienThe) }
    private func isSizeXL(_ b: SanPhamBienThe) -> Bool { isSizeXLBienThe(b.tenBienThe) }

    @ViewBuilder
    private func sizeChipLabel(_ b: SanPhamBienThe, active: Bool) -> some View {
        let vip = isSizeL(b) || isSizeXL(b)
        HStack(spacing: 4) {
            // "🏷️" thay cho giaRiengBadge() (Theme.swift) — chip này đổi nền theo trạng thái
            // active/VIP (gradient vàng/primary đặc/xám nhạt), 1 badge nền cố định sẽ lạc tông trên
            // vài nền; icon nhỏ theo màu chữ chip thì luôn hợp.
            Text("\(b.tenBienThe) \(formatTienShort(giaHienThi(b)).uppercased())\(giaRiengMap[b.id] != nil ? " 🏷️" : "")")
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background {
            if vip && active {
                LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.35), Color(red: 0.85, green: 0.62, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if vip {
                LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.35).opacity(0.18), Color(red: 0.85, green: 0.62, blue: 0.12).opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if active {
                Theme.primary
            } else {
                Theme.textMuted.opacity(0.12)
            }
        }
        .foregroundColor(vip && active ? Color(red: 0.35, green: 0.2, blue: 0) : (active ? .white : (vip ? Color(red: 0.6, green: 0.42, blue: 0.05) : .primary)))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(vip ? Color(red: 0.85, green: 0.62, blue: 0.12).opacity(active ? 0.9 : 0.5) : .clear, lineWidth: active && vip ? 1.5 : 1)
        )
        .shadow(color: vip && active ? Color(red: 0.85, green: 0.62, blue: 0.12).opacity(0.5) : .clear, radius: 4, y: 2)
        .contentShape(Rectangle())
    }

    /// Thành tiền tạm tính gồm cả topping — khớp thanhTienDraft bên ProductPickerPanel (AppQuanLyIOS).
    private var thanhTienDraft: Double {
        guard let bienThe else { return 0 }
        let toppingTien = toppingQty.reduce(0.0) { sum, kv in
            guard let top = toppings.first(where: { $0.id == kv.key }) else { return sum }
            return sum + top.gia * Double(kv.value)
        }
        return giaHienThi(bienThe) * Double(soLuong) + toppingTien
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
                        if sanPham.hinhAnh != nil || sanPham.hinhAnhCat != nil {
                            AnhMonView(hinhAnh: sanPham.hinhAnh, hinhAnhCat: sanPham.hinhAnhCat, width: 56, height: 56)
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
                                                sizeChipLabel(b, active: active)
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
                                // .wheel — khớp control ngày sinh bên tab Tài khoản (SettingsView.ngaySinhCard,
                                // feedback 2026-09-28 "thay control này bằng control trong tab khách hàng").
                                // Trước đây dùng style .compact mặc định (nút "ngày 28 thg 9, 2008" bấm ra
                                // popup lịch lưới) — đổi sang wheel 3 cột ngày/tháng/năm cuộn thẳng cho đồng
                                // bộ, dễ chọn năm sinh xa hơn. Ép locale vi_VN — máy đặt hệ thống tiếng Anh
                                // sẽ hiện DatePicker kiểu "January 2026"/mm-dd-yyyy giữa 1 màn toàn chữ Việt,
                                // lạc quẻ.
                                DatePicker("", selection: $dobPicked, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                                    .frame(maxHeight: 140)
                                    .clipped()
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
            // Trước đây .buttonStyle()/.tint() tách 2 dòng nên lần rà soát gradient hoá nút CTA
            // (grep 1 dòng) bỏ sót — nút "Thêm giỏ" vẫn phẳng trong khi mọi CTA khác đã gradient.
            .buttonStyle(.gradientProminent(danger: isDeleting))
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
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .padding(.horizontal, 8).padding(.vertical, 4)
            // 09/11/2026: cùng kiểu ô nhập TK (nền xám bo 12, không viền).
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.bg))
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

