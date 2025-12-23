//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/7/19.
//

import Combine
import SwiftUI

final class AppListModel: ObservableObject {
    @Published var applications: [App] = []
    @Published var filteredApplications: [App] = []
    @Published var unsupportedCount: Int = 0

    @Published var searchText: String = ""
    @Published var filterOption: FilterOption = .all
    @Published var activeScopeApps: [String: [App]] = [:]

    private var cancellables = Set<AnyCancellable>()
    
    // --- KHÔI PHỤC CÁC BIẾN CẦN THIẾT ---
    static let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#"
    private static let allowedCharacterSet = CharacterSet(charactersIn: allowedCharacters)
    // ------------------------------------

    init() {
        $searchText
            .combineLatest($applications, $filterOption)
            .debounce(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText, applications, filterOption in
                self?.filterApplications(searchText: searchText, applications: applications, filterOption: filterOption)
            }
            .store(in: &cancellables)

        reload()
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
    
    // --- KHÔI PHỤC HÀM NÀY ĐỂ FIX LỖI AppListView ---
    func rebuildIconCache() {
        // Logic giả lập để tránh lỗi build, hoặc reload lại list
        reload()
    }

    private func filterApplications(searchText: String, applications: [App], filterOption: FilterOption) {
        let filtered = applications.filter { app in
            let matchesSearchText = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bid.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilterOption: Bool
            switch filterOption {
            case .all:
                matchesFilterOption = true
            case .user:
                matchesFilterOption = app.type == "User"
            case .system:
                matchesFilterOption = app.type == "System"
            }

            return matchesSearchText && matchesFilterOption
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let grouped = Self.groupedAppList(filtered)
            DispatchQueue.main.async {
                self.filteredApplications = filtered
                self.activeScopeApps = grouped
            }
        }
    }

    // --- LOGIC LỌC PUBG & CROSSFIRE CỦA BẠN (Đã tích hợp vào đây) ---
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

                // 1. Logic lọc Crossfire/PUBG
                let isPubg = localizedName.localizedCaseInsensitiveContains("PUBG MOBILE")
                let isCrossfire = id == "com.vnggames.cfl.crossfirelegends" || localizedName.localizedCaseInsensitiveContains("Crossfire")

                guard isPubg || isCrossfire else {
                    return nil
                }

                guard !id.hasPrefix("wiki.qaq.") && !id.hasPrefix("com.82flex.") && !id.hasPrefix("ch.xxtou.") else {
                    return nil
                }

                guard !excludedIdentifiers.contains(id) else {
                    return nil
                }

                // 2. Logic đổi tên
                var finalName = localizedName

                if isPubg {
                    let lowerId = id.lowercased()
                    if lowerId.contains("vn") {
                        finalName = "PUBG MOBILE (VN)"
                    } else if lowerId.contains("ig") {
                        finalName = "PUBG MOBILE (GL)"
                    } else if lowerId.contains("kr") {
                        finalName = "PUBG MOBILE (KR)"
                    } else if lowerId.contains("rekoo") {
                        finalName = "PUBG MOBILE (TW)"
                    } else {
                        finalName = "PUBG MOBILE (GL)"
                    }
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

                guard app.isRemovable else {
                    return nil
                }

                return app
            }

        let filteredApps = allApps
            .filter { $0.isSystem || InjectorV3.main.checkIsEligibleAppBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count

        return filteredApps
    }

    // --- KHÔI PHỤC CÁC HÀM BỊ THIẾU (openInFilza, groupedAppList) ---

    func openInFilza(_ url: URL) {
        guard let filzaURL = URL(string: "filza://\(url.path)") else { return }
        UIApplication.shared.open(filzaURL)
    }

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

        // Loại bỏ các nhóm rỗng
        for (key, value) in groupedApps {
            if value.isEmpty {
                groupedApps.removeValue(forKey: key)
            }
        }

        return groupedApps
    }
}
