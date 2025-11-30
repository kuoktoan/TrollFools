//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct OptionView: View {
    let app: App

    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State var isImporterPresented = false
    @State var isImporterSelected = false
    @State var isEjectAlertPresented = false // Thêm dòng này

    @State var isWarningPresented = false
    @State var temporaryResult: Result<[URL], any Error>?

    @State var isSettingsPresented = false
    @State var importerResult: Result<[URL], any Error>?

    @State var numberOfPlugIns: Int = 0

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    init(_ app: App) {
        self.app = app
    }

    var body: some View {
        if #available(iOS 15, *) {
            wrappedContent
                .alert(
                    NSLocalizedString("Notice", comment: ""),
                    isPresented: $isWarningPresented,
                    presenting: temporaryResult
                ) { result in
                    Button {
                        importerResult = result
                        isImporterSelected = true
                    } label: {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    Button(role: .destructive) {
                        importerResult = result
                        isImporterSelected = true
                        isWarningHidden = true
                    } label: {
                        Text(NSLocalizedString("Continue and Don’t Show Again", comment: ""))
                    }
                    Button(role: .cancel) {
                        temporaryResult = nil
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    if case let .success(urls) = $0 {
                        Text(Self.warningMessage(urls))
                    }
                }
        } else {
            wrappedContent
        }
    }

    var wrappedContent: some View {
        content.toolbar { toolbarContent }
    }

    var content: some View {
        VStack(spacing: 80) {
            HStack {
                Spacer()

                Button {
                    isImporterPresented = true
                } label: {
                    OptionCell(option: .attach, detachCount: 0)
                }
                .accessibilityLabel(NSLocalizedString("Inject", comment: ""))

                Spacer()

                // --- DÁN CODE MỚI NÀY VÀO ---
                Button {
                    // Nếu có plugin thì mới hiện bảng hỏi xóa
                    if numberOfPlugIns > 0 {
                        isEjectAlertPresented = true
                    }
                } label: {
                    OptionCell(option: .detach, detachCount: numberOfPlugIns)
                }
                .disabled(numberOfPlugIns == 0) // Mờ đi nếu không có plugin
                .alert(NSLocalizedString("Eject All", comment: ""), isPresented: $isEjectAlertPresented) {
                    Button(role: .destructive) {
                        performEjectAll()
                    } label: {
                        Text(NSLocalizedString("Confirm", comment: ""))
                    }
                    Button(role: .cancel) { } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    Text(NSLocalizedString("Are you sure you want to eject all plug-ins? This action cannot be undone.", comment: ""))
                }
                // -----------------------------

                Spacer()
            }
        }
        .padding()
        .navigationTitle(app.name)
        .background(Group {
            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case let .success(urls):
                        InjectView(app, urlList: urls
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }))
                    case let .failure(error):
                        FailureView(
                            title: NSLocalizedString("Error", comment: ""),
                            error: error
                        )
                    }
                }
            } label: { }
        })
        .onAppear {
            recalculatePlugInCount()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                .init(filenameExtension: "dylib")!,
                .init(filenameExtension: "deb")!,
                .bundle,
                .framework,
                .package,
                .zip,
            ],
            allowsMultipleSelection: true
        ) {
            result in
            switch result {
            case let .success(theSuccess):
                if #available(iOS 15, *) {
                    if !isWarningHidden && theSuccess.contains(where: { $0.pathExtension.lowercased() == "deb" }) {
                        temporaryResult = result
                        isWarningPresented = true
                        return
                    }
                }
                fallthrough
            case .failure:
                importerResult = result
                isImporterSelected = true
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if verticalSizeClass == .compact {
                Button {
                    isSettingsPresented = true
                } label: {
                    Label(NSLocalizedString("Advanced Settings", comment: ""),
                          systemImage: "gear")
                }
            }
        }
    }

    static func warningMessage(_ urls: [URL]) -> String {
        guard let firstDylibName = urls.first(where: { $0.pathExtension.lowercased() == "deb" })?.lastPathComponent else {
            fatalError("No debian package found.")
        }
        return String(format: NSLocalizedString("You’ve selected at least one Debian Package “%@”. We’re here to remind you that it will not work as it was in a jailbroken environment. Please make sure you know what you’re doing.", comment: ""), firstDylibName)
    }

    private func recalculatePlugInCount() {
        var urls = [URL]()
        urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
        let enabledNames = urls.map { $0.lastPathComponent }
        urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }
        numberOfPlugIns = urls.count
    }

    private func performEjectAll() {
        // Lấy danh sách tất cả plugin đang có
        var urls = [URL]()
        urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
        let enabledNames = urls.map { $0.lastPathComponent }
        urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }

        guard !urls.isEmpty else { return }

        // Thực hiện Eject
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                // Cài đặt các thông số nếu cần
                if injector.appID.isEmpty { injector.appID = app.bid }
                if injector.teamID.isEmpty { injector.teamID = app.teamID }
                
                // Gọi lệnh Eject All
                try injector.eject(urls, shouldDesist: true)
                
                DispatchQueue.main.async {
                    app.reload()
                    recalculatePlugInCount()
                }
            } catch {
                print("Error ejecting: \(error)")
            }
        }
    }
}
