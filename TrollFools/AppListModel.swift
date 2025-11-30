//
//  AppListModel.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import Combine
import OrderedCollections
import SwiftUI

final class AppListModel: ObservableObject {

    static let isLegacyDevice: Bool = { UIScreen.main.fixedCoordinateSpace.bounds.height <= 736.0 }()
    static let hasTrollStore: Bool = { LSApplicationProxy(forIdentifier: "com.opa334.TrollStore") != nil }()
    
    private var _allApplications: [App] = []

    let selectorURL: URL?
    var isSelectorMode: Bool { selectorURL != nil }

    @Published var activeScopeApps: OrderedDictionary<String, [App]> = [:]
    @Published var unsupportedCount: Int = 0
    @Published var isRebuildNeeded: Bool = false

    lazy var isFilzaInstalled: Bool = {
        if let filzaURL {
            UIApplication.shared.canOpenURL(filzaURL)
        } else {
            false
        }
    }()
    private let filzaURL = URL(string: "filza://view")

    private let applicationChanged = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(selectorURL: URL? = nil) {
        self.selectorURL = selectorURL
        reload()

        applicationChanged
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            darwinCenter,
            Unmanaged.passRetained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = Unmanaged<AppListModel>
                    .fromOpaque(observer!)
                    .takeUnretainedValue() as AppListModel? else { return }
                observer.applicationChanged.send()
            },
            "com.apple.LaunchServices.ApplicationsChanged" as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(darwinCenter, Unmanaged.passUnretained(self).toOpaque(), nil, nil)
    }

    func reload() {
        let allApplications = Self.fetchApplications(&unsupportedCount)
        allApplications.forEach { $0.appList = self }
        _allApplications = allApplications
        performFilter()
    }

    /// CHỈ HIỂN THỊ PUBG MOBILE
    func performFilter() {
        let filtered = _allApplications.filter { $0.name == "PUBG MOBILE" }

        // Không group luôn, để key rỗng ""
        activeScopeApps = ["": filtered]
    }

    private static let excludedIdentifiers: Set<String> = [
        "com.opa334.Dopamine",
        "org.coolstar.SileoStore",
        "xyz.willy.Zebra",
    ]

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

                // loại package nội bộ
                guard !id.hasPrefix("wiki.qaq."),
                      !id.hasPrefix("com.82flex."),
                      !id.hasPrefix("ch.xxtou.") else { return nil }

                // loại Dopamine / Sileo…
                guard !excludedIdentifiers.contains(id) else { return nil }

                let shortVersionString: String? = proxy.shortVersionString()
                let app = App(
                    bid: id,
                    name: localizedName,
                    type: appType,
                    teamID: teamID,
                    url: url,
                    version: shortVersionString
                )

                if app.isUser && app.isFromApple { return nil }
                guard app.isRemovable else { return nil }

                return app
            }

        let filteredApps = allApps
            .filter { $0.isSystem || InjectorV3.main.checkIsEligibleAppBundle($0.url) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        unsupportedCount = allApps.count - filteredApps.count
        return filteredApps
    }
}


// MARK: Utilities

extension AppListModel {
    func openInFilza(_ url: URL) {
        guard let filzaURL else { return }

        let fileURL: URL
        if #available(iOS 16, *) {
            fileURL = filzaURL.appending(path: url.path)
        } else {
            fileURL = URL(string: filzaURL.absoluteString +
                (url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
            )!
        }

        UIApplication.shared.open(fileURL)
    }

    func rebuildIconCache() {
        DispatchQueue.global(qos: .userInitiated).async {
            LSApplicationWorkspace.default().openApplication(withBundleID: "com.opa334.TrollStore")
        }
    }
}
