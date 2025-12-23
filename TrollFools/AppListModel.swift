//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/7/19.
//

import Combine
import SwiftUI

// --- ĐỊNH NGHĨA CÁC ENUM BỊ THIẾU ---
enum FilterOption {
    case all
    case user
    case system
}

// Model cho bộ lọc tìm kiếm
struct FilterModel {
    var searchKeyword: String = ""
    var showPatchedOnly: Bool = false
    var isSearching: Bool { !searchKeyword.isEmpty }
}
// ------------------------------------

final class AppListModel: ObservableObject {
    
    // --- ĐỊNH NGHĨA SCOPE & CONSTANTS ---
    enum Scope: String, CaseIterable {
        case all
        case user
        case system
    }
    
    static let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#"
    private static let allowedCharacterSet = CharacterSet(charactersIn: allowedCharacters)
    
    // Các Bundle ID cần loại bỏ (Fix lỗi excludedIdentifiers)
    static let excludedIdentifiers: Set<String> = [
        "com.apple.webapp",
        "com.82flex.TrollFools",
    ]
    
    // Kiểm tra TrollStore (Fix lỗi hasTrollStore)
    static var hasTrollStore: Bool {
        // Kiểm tra đơn giản đường dẫn TS
        return FileManager.default.fileExists(atPath: "/Applications/TrollStore.app") 
            || FileManager.default.fileExists(atPath: "/var/containers/Bundle/Application/TrollStore.app")
    }

    // --- CÁC BIẾN PUBLISHED (QUAN TRỌNG CHO VIEW) ---
    @Published var applications: [App] = []
    @Published var filteredApplications: [App] = []
    @Published var activeScopeApps: [String: [App]] = [:]
    @Published var unsupportedCount: Int = 0

    // Các biến trạng thái View đang thiếu
    @Published var filter = FilterModel() 
    @Published var filterOption: FilterOption = .all
    @Published var activeScope: Scope = .all
    @Published var isSelectorMode: Bool = false 
    @Published var selectorURL: URL? = nil
    @Published var isRebuildNeeded: Bool = false

    // Kiểm tra Filza
    var isFilzaInstalled: Bool {
        return UIApplication.shared.canOpenURL(URL(string: "filza://")!)
    }

    private var cancellables = Set<AnyCancellable>()

    // --- INIT ---
    init() {
        // Init mặc định
        setupBindings()
        reload()
    }
    
    // Init cho chế độ Selector (Fix lỗi InjectView)
    init(selectorURL: URL?) {
        self.isSelectorMode = true
        self.selectorURL = selectorURL
        setupBindings()
        reload()
    }
    
    private func setupBindings() {
        // Lắng nghe thay đổi từ filter và scope để lọc danh sách
        $filter.map { $0.searchKeyword }
            .combineLatest($applications, $activeScope, $filter.map { $0.showPatchedOnly })
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] keyword, apps, scope, showPatched in
                self?.filterApplications(keyword: keyword, applications: apps, scope: scope, showPatchedOnly: showPatched)
            }
            .store(in: &cancellables)
    }

    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            var unsupportedCount = 0
            let apps = Self.fetchApplications(&unsupportedCount)
            DispatchQueue.main.async {
                self.applications = apps
                self.unsupportedCount = unsupportedCount
            }
        }
    }
    
    func rebuildIconCache() {
        reload()
    }
    
    func openInFilza(_ url: URL) {
        guard let filzaURL = URL(string: "filza://\(url.path)") else { return }
        UIApplication.shared.open(filzaURL)
    }

    // --- LOGIC LỌC ỨNG DỤNG ---
    private func filterApplications(keyword: String, applications: [App], scope: Scope, showPatchedOnly: Bool) {
        let filtered = applications.filter { app in
            // 1. Lọc theo từ khóa
            let matchesKeyword = keyword.isEmpty ||
                app.name.localizedCaseInsensitiveContains(keyword) ||
                app.bid.localizedCaseInsensitiveContains(keyword)
            
            // 2. Lọc theo Scope (User/System)
            let matchesScope: Bool
            switch scope {
            case .all: matchesScope = true
            case .user: matchesScope = app.type == "User"
            case .system: matchesScope = app.type == "System"
            }
            
            // 3. Lọc theo Patched (Đã inject hay chưa)
            let matchesPatched = !showPatchedOnly || (InjectorV3(try! InjectorV3(app.url).bundleURL).hasInjectedAsset)

            return matchesKeyword && matchesScope && matchesPatched
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let grouped = Self.groupedAppList(filtered)
            DispatchQueue.main.async {
                self.filteredApplications = filtered
                self.activeScopeApps = grouped
            }
        }
    }

    // --- LOGIC GỐC + PUBG/CROSSFIRE ---
    private static func fetchApplications(_ unsupportedCount: inout Int) -> [App] {
        let allApps: [App] = LSApplicationWorkspace.default()
            .allApplications()
            .compactMap { proxy in
                guard let id = proxy.applicationIdentifier(),
                      let url = proxy.bundleURL(),
                      let teamID = proxy.teamID(),
                      let appType = proxy.applicationType(),
                      let localizedName = proxy.localizedName()
                else {
                    return nil
                }

                // --- 1. LOGIC CROSSFIRE & PUBG ---
                let isPubg = localizedName.localizedCaseInsensitiveContains("PUBG MOBILE")
                let isCrossfire = id == "com.vnggames.cfl.crossfirelegends" || localizedName.localizedCaseInsensitiveContains("Crossfire")

                guard isPubg || isCrossfire else {
                    return nil
                }
                // ---------------------------------

                // Filter blacklist
                guard !id.hasPrefix("wiki.qaq.") && !id.hasPrefix("com.82flex.") && !id.hasPrefix("ch.xxtou.") else {
                    return nil
                }
                guard !Self.excludedIdentifiers.contains(id) else {
                    return nil
                }

                // --- 2. LOGIC ĐỔI TÊN ---
                var finalName = localizedName
                if isPubg {
                    let lowerId = id.lowercased()
                    if lowerId.contains("vn") { finalName = "PUBG MOBILE (VN)" }
                    else if lowerId.contains("ig") { finalName = "PUBG MOBILE (GL)" }
                    else if lowerId.contains("kr") { finalName = "PUBG MOBILE (KR)" }
                    else if lowerId.contains("rekoo") { finalName = "PUBG MOBILE (TW)" }
                    else { finalName = "PUBG MOBILE (GL)" }
                } else if isCrossfire {
                    finalName = "Crossfire Legends"
                }

                let shortVersionString: String? = proxy.shortVersionString()
                
                let app = App(
                    bid: id,
                    name: finalName,
                    type: appType,
                    teamID: teamID,
                    url: url,
                    version: shortVersionString
                )

                guard app.isRemovable else { return nil }
                return app
            }

        let filteredApps = allApps
            .filter { $0.isSystem || InjectorV3.main.checkIsEligibleAppBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count
        return filteredApps
    }

    // --- HÀM HELPER GROUP LIST ---
    static func groupedAppList(_ applications: [App]) -> [String: [App]] {
        var groupedApps: [String: [App]] = [:]
        for char in allowedCharacters {
            groupedApps[String(char)] = []
        }
        groupedApps["#"] = []

        for app in applications {
            if let firstChar = app.name.first, let scalar = firstChar.unicodeScalars.first {
                if !allowedCharacterSet.contains(scalar) {
                    groupedApps["#"]?.append(app)
                    continue
                }
                groupedApps[String(firstChar).uppercased()]?.append(app)
            } else {
                groupedApps["#"]?.append(app)
            }
        }

        // Xóa key rỗng
        for (key, value) in groupedApps {
            if value.isEmpty {
                groupedApps.removeValue(forKey: key)
            }
        }
        return groupedApps
    }
}
