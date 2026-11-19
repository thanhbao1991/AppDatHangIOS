import SwiftUI
import UIKit

/// Một nhóm ở cột món tab Thực đơn: tiêu đề nhóm + các món của nhóm.
struct NhomCotMon: Equatable {
    let nhom: NhomSanPham
    let items: [SanPham]
}

/// Yêu cầu cuộn cột món tới 1 nhóm (bấm cột trái) — `tick` tăng mỗi lần bấm nên bấm lại đúng nhóm cũ vẫn cuộn.
struct YeuCauCuonNhom: Equatable {
    let id: String
    let tick: Int
}

/// Cột món tab Thực đơn = UICollectionView (19/11/2026), thay ScrollView + VStack.
///
/// Vì sao (chủ quán: "tab Đơn hàng cũng có ảnh sao vuốt không giật"): tab Đơn hàng là `List` — UIKit tái dùng ô, chỉ vài
/// thẻ đang hiện là tồn tại. Cột món cũ là ScrollView + VStack thường (bỏ LazyVStack vì nó ĐOÁN vị trí → bấm nhóm lệch,
/// món đè tiêu đề) nên dựng sẵn cả ~226 dòng, ảnh mỗi dòng bọc 1 LazyVStack (~240 khung lazy phải theo dõi khi cuộn),
/// cuộn qua tiêu đề nhóm là vẽ lại cả MenuView.
///
/// Ở đây dòng món cao CỐ ĐỊNH `MenuView.rowHeight`, tiêu đề cao cố định `MenuView.categoryHeaderHeight` → toạ độ mọi nhóm
/// tính thẳng ra (`Coordinator.dinhNhom`), bấm nhóm nhảy đúng kể cả nhóm chưa từng hiện — không chỗ nào phải đoán chiều
/// cao. Chỉ ô đang hiện (+ vài ô chuẩn bị trước) tồn tại, ô cuộn khuất được dùng lại; nội dung ô vẫn là SwiftUI
/// (UIHostingConfiguration). Cột trái chọn theo nhóm nằm ở mép trên cột — chỉ khi KHÁCH tự cuộn.
///
/// Mỗi nhóm = 2 section: section tiêu đề (1 ô) + section món (thẻ trắng bo góc có bóng = decoration view `TheNhomNen`).
/// ⚠️ Toạ độ trong `Coordinator.tinhToaDo` phải khớp `taoLayout` — đổi chiều cao/khoảng cách ở chỗ này thì sửa cả chỗ kia.
struct CotMonView<TieuDe: View, Dong: View, TrangThai: Equatable>: UIViewRepresentable {
    let nhoms: [NhomCotMon]
    /// Thứ ngoài dữ liệu món làm đổi nội dung dòng (tim, giá riêng, Flash Sale…) — đổi thì vẽ lại các ô đang có.
    let trangThai: TrangThai
    let nhomDangChon: String
    let yeuCauCuon: YeuCauCuonNhom?
    let tieuDe: (NhomCotMon) -> TieuDe
    let dong: (_ mon: SanPham, _ laCuoi: Bool) -> Dong
    /// Khách tự cuộn, nhóm ở mép trên cột đổi → cột trái chọn theo.
    let onNhomTrenCung: (String) -> Void
    let onKeoLamMoi: () async -> Void

    init(nhoms: [NhomCotMon], trangThai: TrangThai, nhomDangChon: String, yeuCauCuon: YeuCauCuonNhom?,
         @ViewBuilder tieuDe: @escaping (NhomCotMon) -> TieuDe,
         @ViewBuilder dong: @escaping (_ mon: SanPham, _ laCuoi: Bool) -> Dong,
         onNhomTrenCung: @escaping (String) -> Void,
         onKeoLamMoi: @escaping () async -> Void) {
        self.nhoms = nhoms
        self.trangThai = trangThai
        self.nhomDangChon = nhomDangChon
        self.yeuCauCuon = yeuCauCuon
        self.tieuDe = tieuDe
        self.dong = dong
        self.onNhomTrenCung = onNhomTrenCung
        self.onKeoLamMoi = onKeoLamMoi
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UICollectionView {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: Self.taoLayout())
        cv.backgroundColor = UIColor(Theme.bg)
        // Cột nằm giữa màn (dưới tiêu đề "Menu 2026", trên thanh tab) — không để UIKit tự chèn lề vùng an toàn.
        cv.contentInsetAdjustmentBehavior = .never
        cv.contentInset.bottom = MenuView.khoangCachNhom  // khoảng dưới thẻ nhóm cuối, như các nhóm khác
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .onDrag
        cv.allowsSelection = false
        cv.register(OCotMon.self, forCellWithReuseIdentifier: OCotMon.tieuDe)
        cv.register(OCotMon.self, forCellWithReuseIdentifier: OCotMon.mon)
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator

        let lamMoi = UIRefreshControl()
        let coord = context.coordinator
        lamMoi.addAction(UIAction { [weak coord, weak lamMoi] _ in
            Task { @MainActor in
                await coord?.cha.onKeoLamMoi()
                lamMoi?.endRefreshing()
            }
        }, for: .valueChanged)
        cv.refreshControl = lamMoi
        return cv
    }

    func updateUIView(_ cv: UICollectionView, context: Context) {
        cv.backgroundColor = UIColor(Theme.bg)
        context.coordinator.capNhat(self, cv)
    }

    /// Section chẵn = tiêu đề nhóm, section lẻ = món của nhóm đó. Cao tuyệt đối (.absolute) nên UIKit không tự đo ô.
    private static func taoLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { section, _ in
            let laTieuDe = section % 2 == 0
            let co = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                            heightDimension: .absolute(laTieuDe ? MenuView.categoryHeaderHeight : MenuView.rowHeight))
            let item = NSCollectionLayoutItem(layoutSize: co)
            if !laTieuDe {
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: MenuView.leTheNhom, bottom: 0, trailing: MenuView.leTheNhom)
            }
            let s = NSCollectionLayoutSection(group: NSCollectionLayoutGroup.vertical(layoutSize: co, subitems: [item]))
            if laTieuDe {
                // Khoảng cách giữa thẻ nhóm trên và tiêu đề nhóm dưới — nhóm đầu sát đỉnh cột.
                s.contentInsets = NSDirectionalEdgeInsets(top: section == 0 ? 0 : MenuView.khoangCachNhom, leading: 0, bottom: 0, trailing: 0)
            } else {
                // Section món không có lề → khung nền = đúng vùng các ô món, chỉ thụt 2 bên khớp lề ô.
                let nen = NSCollectionLayoutDecorationItem.background(elementKind: TheNhomNen.kind)
                nen.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: MenuView.leTheNhom, bottom: 0, trailing: MenuView.leTheNhom)
                nen.zIndex = -1  // luôn nằm DƯỚI ô món (mặc định 0 = ngang ô, thứ tự vẽ không chắc)
                s.decorationItems = [nen]
            }
            return s
        }
        layout.register(TheNhomNen.self, forDecorationViewOfKind: TheNhomNen.kind)
        return layout
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        /// Bản CotMonView mới nhất (closure dựng tiêu đề/dòng đọc trạng thái MenuView hiện tại).
        fileprivate(set) var cha: CotMonView
        private var nhoms: [NhomCotMon]
        private var trangThai: TrangThai
        /// y đỉnh tiêu đề từng nhóm (nội dung bắt đầu ở 0) + tổng chiều cao — tính thẳng từ chiều cao cố định.
        private var dinhNhom: [CGFloat] = []
        private var tongCao: CGFloat = 0
        /// Tăng mỗi khi nội dung ô đổi — ô chuẩn bị trước theo bản cũ thì cấu hình lại trước khi hiện.
        private var phienBan = 0
        private var tickDaCuon: Int
        /// Chỉ số nhóm cột trái đang chọn — chỉ báo lên khi nhóm ở mép trên cột khác nhóm này.
        private var nhomDaBao: Int?

        init(_ cha: CotMonView) {
            self.cha = cha
            nhoms = cha.nhoms
            trangThai = cha.trangThai
            // Yêu cầu cuộn có từ trước khi cột này được dựng (vd vừa thoát ô tìm món) thì bỏ qua — cột mới bắt đầu ở đỉnh.
            tickDaCuon = cha.yeuCauCuon?.tick ?? 0
            super.init()
            tinhToaDo()
            nhomDaBao = nhoms.firstIndex { $0.nhom.id == cha.nhomDangChon }
        }

        func capNhat(_ moi: CotMonView, _ cv: UICollectionView) {
            cha = moi
            let cauTrucDoi = moi.nhoms.count != nhoms.count || zip(moi.nhoms, nhoms).contains { a, b in
                a.nhom.id != b.nhom.id || !a.items.elementsEqual(b.items, by: { $0.id == $1.id })
            }
            if cauTrucDoi {
                // Nhóm/món thêm bớt (bấm tim → mục Yêu thích đổi, tải lại thực đơn): giữ nguyên chỗ khách đang xem — trừ
                // khi đang ở đỉnh (mới mở app có Yêu thích thì vẫn hiện Yêu thích ở đầu như cũ).
                let neo = diemNeo(cv)
                nhoms = moi.nhoms
                trangThai = moi.trangThai
                phienBan += 1
                tinhToaDo()
                cv.reloadData()
                if let neo, let g = nhoms.firstIndex(where: { $0.nhom.id == neo.id }) {
                    cv.layoutIfNeeded()
                    cv.contentOffset = CGPoint(x: 0, y: kep(dinhNhom[g] + neo.lech, cv))  // gán thẳng: không cắt đà đang trôi
                }
            } else if moi.nhoms != nhoms || moi.trangThai != trangThai {
                nhoms = moi.nhoms
                trangThai = moi.trangThai
                phienBan += 1
                for ip in cv.indexPathsForVisibleItems {
                    if let o = cv.cellForItem(at: ip) as? OCotMon { cauHinh(o, ip) }
                }
            }
            nhomDaBao = nhoms.firstIndex { $0.nhom.id == moi.nhomDangChon }

            if let yc = moi.yeuCauCuon, yc.tick != tickDaCuon {
                tickDaCuon = yc.tick
                if let g = nhoms.firstIndex(where: { $0.nhom.id == yc.id }) {
                    cv.layoutIfNeeded()
                    // Nhóm cuối ngắn hơn cột thì dừng ở đáy cột (kep), tiêu đề nằm thấp hơn đỉnh — như bản cũ.
                    cv.setContentOffset(CGPoint(x: 0, y: kep(dinhNhom[g], cv)), animated: true)
                }
            }
        }

        // MARK: Toạ độ

        /// Khớp taoLayout: [tiêu đề][món × rowHeight], giữa 2 nhóm cách khoangCachNhom; nhóm đầu ở 0.
        private func tinhToaDo() {
            var y: CGFloat = 0
            dinhNhom = []
            for (i, n) in nhoms.enumerated() {
                if i > 0 { y += MenuView.khoangCachNhom }
                dinhNhom.append(y)
                y += MenuView.categoryHeaderHeight + CGFloat(n.items.count) * MenuView.rowHeight
            }
            tongCao = y
        }

        /// Nhóm chứa toạ độ y (tính cả khoảng cách dưới thẻ của nó) — nil khi chưa có nhóm nào.
        private func nhomTai(_ y: CGFloat) -> Int? {
            guard !dinhNhom.isEmpty else { return nil }
            return dinhNhom.lastIndex(where: { $0 <= y }) ?? 0
        }

        /// Nhóm đang ở mép trên cột + đã cuộn vào nhóm đó bao nhiêu — nil khi đang ở đỉnh.
        private func diemNeo(_ cv: UICollectionView) -> (id: String, lech: CGFloat)? {
            let y = cv.contentOffset.y
            guard y > 0, let g = nhomTai(y) else { return nil }
            return (nhoms[g].nhom.id, y - dinhNhom[g])
        }

        /// Kẹp vào khoảng cuộn hợp lệ.
        private func kep(_ y: CGFloat, _ cv: UICollectionView) -> CGFloat {
            min(max(0, y), max(0, tongCao + cv.contentInset.bottom - cv.bounds.height))
        }

        // MARK: Dữ liệu

        func numberOfSections(in cv: UICollectionView) -> Int { nhoms.count * 2 }

        func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            section % 2 == 0 ? 1 : nhoms[section / 2].items.count
        }

        func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
            let o = cv.dequeueReusableCell(withReuseIdentifier: ip.section % 2 == 0 ? OCotMon.tieuDe : OCotMon.mon, for: ip) as! OCotMon
            cauHinh(o, ip)
            return o
        }

        /// `.id(...)`: ô tái dùng cho món KHÁC thì SwiftUI coi là view mới — bỏ @State của món cũ (ảnh đã tải trong
        /// CachedAsyncImage…), không thì ảnh món cũ hiện thoáng qua trên dòng mới tới khi ảnh mới tải xong. Cùng món (vẽ
        /// lại vì tim/giá đổi) thì giữ nguyên, SwiftUI chỉ so dữ liệu.
        private func cauHinh(_ o: OCotMon, _ ip: IndexPath) {
            let cha = self.cha
            let n = nhoms[ip.section / 2]
            if ip.section % 2 == 0 {
                o.contentConfiguration = UIHostingConfiguration { cha.tieuDe(n).id(n.nhom.id) }.margins(.all, 0)
            } else {
                let mon = n.items[ip.item]
                let laCuoi = ip.item == n.items.count - 1
                o.contentConfiguration = UIHostingConfiguration { cha.dong(mon, laCuoi).id(mon.id) }.margins(.all, 0)
            }
            o.phienBan = phienBan
        }

        func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt ip: IndexPath) {
            if let o = cell as? OCotMon, o.phienBan != phienBan { cauHinh(o, ip) }
        }

        func collectionView(_ cv: UICollectionView, shouldHighlightItemAt ip: IndexPath) -> Bool { false }

        // MARK: Cột trái chọn theo

        func scrollViewDidScroll(_ sv: UIScrollView) {
            // Chỉ khi KHÁCH tự cuộn (đang chạm / đang trôi) — cuộn do bấm cột trái thì nhóm đã được chọn sẵn, không ghi đè.
            guard sv.isTracking || sv.isDecelerating, let g = nhomTai(sv.contentOffset.y + 1) else { return }
            baoNhom(g)
        }

        func scrollViewDidScrollToTop(_ sv: UIScrollView) {
            if !nhoms.isEmpty { baoNhom(0) }
        }

        private func baoNhom(_ g: Int) {
            guard g != nhomDaBao else { return }
            nhomDaBao = g
            cha.onNhomTrenCung(nhoms[g].nhom.id)
        }
    }
}

/// Ô cột món — nhớ phiên bản nội dung lúc cấu hình để ô chuẩn bị trước (prefetch) bị cũ được cấu hình lại trước khi hiện.
private final class OCotMon: UICollectionViewCell {
    static let tieuDe = "tieu-de"
    static let mon = "mon"
    var phienBan = -1
}

/// Thẻ trắng bo góc có bóng nhẹ sau các món của 1 nhóm — cùng kiểu `tkThe` (TaiKhoanUI.swift). Có shadowPath nên GPU
/// không phải dò hình bóng theo từng điểm ảnh mỗi khung hình (thẻ nhóm dài tới ~2.300pt).
private final class TheNhomNen: UICollectionReusableView {
    static let kind = "the-nhom-nen"

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = TK.bo
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: TK.bo).cgPath
    }
}
