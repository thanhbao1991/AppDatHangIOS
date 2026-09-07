import SwiftUI

/// Port từ MenuScreen.tsx (bản RN cũ), sau đó đổi sang layout sidebar 2 cột (cột trái = nhóm,
/// cột phải = món) theo chuẩn app trà sữa/cà phê Việt Nam (Phúc Long, ToCoToco, Gong Cha...) —
/// hợp hơn Section cuộn dọc hay chip ngang khi có ~17 nhóm. Modal chọn size/topping/ghi chú →
/// .sheet(), tìm không dấu qua timKiem đã chuẩn hoá sẵn từ server.
struct MenuView: View {
    @EnvironmentObject var cart: CartStore
    @Binding var path: [HomeRoute]

    @State private var loading = true
    @State private var error = ""
    @State private var sanPhams: [SanPham] = []
    @State private var nhoms: [NhomSanPham] = []
    @State private var toppings: [Topping] = []
    @State private var query = ""
    @State private var picking: SanPham?
    @State private var selectedNhomId: String = ""

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

    /// Toàn bộ nhóm có món (không lọc theo tìm kiếm) — nguồn cho sidebar, luôn hiện đủ để bấm
    /// chuyển nhóm bất kể đang lọc gì ở cột phải.
    private var sections: [(nhom: NhomSanPham, items: [SanPham])] {
        var byNhom: [String: [SanPham]] = [:]
        for sp in sanPhams { byNhom[sp.nhomSanPhamId ?? "", default: []].append(sp) }
        var result = nhoms
            .filter { byNhom[$0.id] != nil }
            .sorted { $0.ten.localizedStandardCompare($1.ten) == .orderedAscending }
            .map { (nhom: $0, items: byNhom[$0.id] ?? []) }
        if let khac = byNhom[""] {
            result.append((nhom: NhomSanPham(id: "", ten: "Khác"), items: khac))
        }
        return result
    }

    private var selectedItems: [SanPham] {
        sections.first(where: { $0.nhom.id == selectedNhomId })?.items ?? []
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                            lyBiMatBanner

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

            if cart.totalCount > 0 {
                Button {
                    path.append(.checkout)
                } label: {
                    HStack {
                        Text("\(cart.totalCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                        Text("Xem giỏ hàng").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        Spacer()
                        Text(formatTien(cart.totalPrice)).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Theme.primaryDark)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 12).padding(.bottom, 8)
                }
            }
        }
        .task { if sanPhams.isEmpty { await load() } }
        .sheet(item: $picking) { sp in
            ProductPickerSheet(sanPham: sp, toppings: toppings, cart: cart) { picking = nil }
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
                    } label: {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(isSelected ? Theme.primary : Color.clear)
                                .frame(width: 3)
                            Text(section.nhom.ten)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? Theme.primary : .primary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.trailing, 6)
                        }
                        .background(isSelected ? Theme.primaryTint.opacity(0.5) : Color.clear)
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
                    Text(item.ten).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    if let minPrice {
                        Text(prices.count > 1 ? "Từ \(formatTien(minPrice))" : formatTien(minPrice))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.primary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundColor(Theme.primary).font(.system(size: 22))
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
        let (sp, nhom, top) = await (spTask, nhomTask, topTask)
        sanPhams = sp.filter { !$0.ngungBan && $0.storeFoodId != nil && !$0.khongLenStore }
        nhoms = nhom
        toppings = top.filter { !$0.ngungBan }
        if sanPhams.isEmpty && sp.isEmpty { error = "" }
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
    let onDone: () -> Void

    @State private var bienThe: SanPhamBienThe?
    @State private var toppingIds: Set<String> = []
    @State private var soLuong = 1
    @State private var ghiChu = ""
    @State private var tab: Int = 0

    private let quickNoteGroups: [(title: String, notes: [String])] = [
        ("Đường", ["Không đường", "Ít ngọt", "Ngọt", "Nhiều ngọt", "Đường riêng"]),
        ("Đá", ["Không đá", "Ít đá", "Vừa đá", "Nhiều đá", "Đá riêng"]),
        ("Trà", ["Không trà", "Trà nóng", "Trà đá"]),
    ]

    private var activeNotes: Set<String> {
        Set(ghiChu.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if let hinhAnh = sanPham.hinhAnh, let url = URL(string: hinhAnh) {
                            AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color(white: 0.93) }
                                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Text(sanPham.ten).font(.system(size: 17, weight: .bold))
                    }
                }

                Section("Chọn size") {
                    ForEach(sanPham.bienThe) { b in
                        Button {
                            bienThe = b
                        } label: {
                            HStack {
                                Text("\(b.tenBienThe) — \(formatTien(b.giaBan))")
                                Spacer()
                                if bienThe?.id == b.id { Image(systemName: "checkmark").foregroundColor(Theme.primary) }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                if !toppings.isEmpty {
                    Section {
                        Picker("", selection: $tab) {
                            Text("Ghi chú").tag(0)
                            Text("Topping\(toppingIds.isEmpty ? "" : " (\(toppingIds.count))")").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if !toppings.isEmpty && tab == 1 {
                    Section("Topping") {
                        ForEach(toppings) { t in
                            Button {
                                if toppingIds.contains(t.id) { toppingIds.remove(t.id) } else { toppingIds.insert(t.id) }
                            } label: {
                                HStack {
                                    Text(t.ten).foregroundColor(.primary)
                                    Spacer()
                                    Text("+\(formatTien(t.gia))").foregroundColor(.secondary).font(.system(size: 12))
                                    Image(systemName: toppingIds.contains(t.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(toppingIds.contains(t.id) ? Theme.primary : Theme.textFaint)
                                }
                            }
                        }
                    }
                } else {
                    Section("Ghi chú") {
                        TextField("Ghi chú món...", text: $ghiChu)
                        ForEach(quickNoteGroups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textFaint)
                                HStack {
                                    ForEach(group.notes, id: \.self) { note in
                                        let active = activeNotes.contains(note)
                                        Button(note) { toggleNote(note) }
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 8).padding(.vertical, 6)
                                            .background(active ? Theme.primary : Color(white: 0.95))
                                            .foregroundColor(active ? .white : Theme.textMuted)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Số lượng") {
                    HStack {
                        Button { soLuong = max(1, soLuong - 1) } label: { Image(systemName: "minus.circle") }
                        Spacer()
                        Text("\(soLuong)").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Button { soLuong += 1 } label: { Image(systemName: "plus.circle") }
                    }
                    .tint(Theme.primary)
                }
            }
            .navigationTitle("Thêm món")
            .navigationBarTitleDisplayMode(.inline)
            .brandNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Huỷ", action: onDone) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thêm giỏ · \(bienThe != nil ? formatTien(bienThe!.giaBan * Double(soLuong)) : "")") { confirmAdd() }
                        .disabled(bienThe == nil)
                }
            }
        }
        .onAppear {
            bienThe = sanPham.bienThe.first(where: \.macDinh) ?? sanPham.bienThe.first
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
