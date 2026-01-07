//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/7/19.
//

import Combine
import SwiftUI
import OrderedCollections

enum FilterOption {
    case all
    case user
    case system
}

struct FilterModel {
    var searchKeyword: String = ""
    var showPatchedOnly: Bool = false
    var isSearching: Bool { !searchKeyword.isEmpty }
}

final class AppListModel: ObservableObject {
    
    enum Scope: String, CaseIterable {
        case all
        case user
        case system
        case troll
    }
    
    // --- CẤU HÌNH DANH SÁCH GAME HỖ TRỢ ---
    static let pubgIds: Set<String> = [
        "com.tencent.ig",       // Global
        "com.rekoo.pubgm",      // Taiwan
        "vn.vng.pubgmobile",    // Vietnam
        "com.pubg.krmobile"     // Korea
    ]
    
    static let crossfireId = "com.vnggames.cfl.crossfirelegends"
    // --------------------------------------
    
    static let excludedIdentifiers: Set<String> = [
        "com.apple.webapp",
        "com.82flex.TrollFools",
    ]
    
    static var hasTrollStore: Bool {
        return FileManager.default.fileExists(atPath: "/Applications/TrollStore.app") 
            || FileManager.default.fileExists(atPath: "/var/containers/Bundle/Application/TrollStore.app")
    }

    @Published var applications: [App] = []
    @Published var filteredApplications: [App] = []
    
    // OrderedDictionary để giữ tương thích với View, nhưng chỉ chứa 1 Key duy nhất
    @Published var activeScopeApps: OrderedDictionary<String, [App]> = [:]
    
    @Published var unsupportedCount: Int = 0

    @Published var filter = FilterModel() 
    @Published var filterOption: FilterOption = .all
    @Published var activeScope: Scope = .all
    @Published var isSelectorMode: Bool = false 
    @Published var selectorURL: URL? = nil
    @Published var isRebuildNeeded: Bool = false

    var isFilzaInstalled: Bool {
        return UIApplication.shared.canOpenURL(URL(string: "filza://")!)
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        reload()
    }
    
    init(selectorURL: URL?) {
        self.isSelectorMode = true
        self.selectorURL = selectorURL
        setupBindings()
        reload()
    }
    
    private func setupBindings() {
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

    private func filterApplications(keyword: String, applications: [App], scope: Scope, showPatchedOnly: Bool) {
        let filtered = applications.filter { app in
            let matchesKeyword = keyword.isEmpty ||
                app.name.localizedCaseInsensitiveContains(keyword) ||
                app.bid.localizedCaseInsensitiveContains(keyword)
            
            let matchesScope: Bool
            switch scope {
            case .all: matchesScope = true
            case .user: matchesScope = app.type == "User"
            case .system: matchesScope = app.type == "System"
            case .troll: matchesScope = app.type == "Troll"
            }
            
            let isInjected = (try? InjectorV3(app.url))?.hasInjectedAsset ?? false
            let matchesPatched = !showPatchedOnly || isInjected

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

    private static func fetchApplications(_ unsupportedCount: inout Int) -> [App] {
        let allApps: [App] = LSApplicationWorkspace.default()
            .allApplications()
            .compactMap { proxy in
                guard let id = proxy.applicationIdentifier(),
                      let url = proxy.bundleURL(),
                      let teamID = proxy.teamID(),
                      let appType = proxy.applicationType(),
                      let localizedName = proxy.localizedName()
                else { return nil }

                // --- 1. LOGIC CHECK BUNDLE ID CHÍNH XÁC ---
                let isPubg = Self.pubgIds.contains(id)
                //let isCrossfire = (id == Self.crossfireId)

                // Chỉ lấy đúng Game trong danh sách
                //guard isPubg || isCrossfire else { return nil }
                guard isPubg else { return nil }
                // -------------------------------------------

                guard !id.hasPrefix("wiki.qaq.") && !id.hasPrefix("com.82flex.") && !id.hasPrefix("ch.xxtou.") else { return nil }
                guard !Self.excludedIdentifiers.contains(id) else { return nil }

                // --- 2. ĐẶT TÊN HIỂN THỊ CHUẨN ---
                var finalName = localizedName
                
                switch id {
                case "com.tencent.ig":
                    finalName = "PUBG MOBILE (GL)"
                case "vn.vng.pubgmobile":
                    finalName = "PUBG MOBILE (VN)"
                case "com.pubg.krmobile":
                    finalName = "PUBG MOBILE (KR)"
                case "com.rekoo.pubgm":
                    finalName = "PUBG MOBILE (TW)"
                case Self.crossfireId:
                    finalName = "Crossfire: Legends (VN)"
                default:
                    break
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

    // --- 3. SỬA HÀM GROUP: BỎ CHIA THEO CHỮ CÁI ---
    static func groupedAppList(_ applications: [App]) -> OrderedDictionary<String, [App]> {
        // Thay vì chia A, B, C... ta gom hết vào 1 Key duy nhất.
        // Điều này khiến danh sách bên phải (Index) biến mất hoặc chỉ còn 1 chấm.
        var groupedApps: OrderedDictionary<String, [App]> = [:]
        
        if !applications.isEmpty {
            // Key rỗng hoặc "Games" để hiển thị tất cả trong 1 section
            groupedApps[""] = applications
        }
        
        return groupedApps
    }
}
