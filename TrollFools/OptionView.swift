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
    @State var isDownloading = false
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

                // --- ĐOẠN CODE MỚI ---
                Button {
                    Inject() // Gọi hàm tải file
                } label: {
                    ZStack {
                        OptionCell(option: .attach, detachCount: 0)
                            .opacity(isDownloading ? 0 : 1) // Ẩn nút khi đang tải
                        
                        if isDownloading {
                            ProgressView() // Hiện vòng xoay khi đang tải
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(isDownloading) // Khóa nút khi đang tải
                .accessibilityLabel(NSLocalizedString("Inject", comment: ""))
                // ---------------------

                Spacer()

// --- DÁN ĐOẠN CODE TƯƠNG THÍCH MỌI PHIÊN BẢN NÀY VÀO ---
                Button {
                    if numberOfPlugIns > 0 {
                        isEjectAlertPresented = true
                    }
                } label: {
                    OptionCell(option: .detach, detachCount: numberOfPlugIns)
                }
                .disabled(numberOfPlugIns == 0)
                .alert(isPresented: $isEjectAlertPresented) {
                    Alert(
                        title: Text(NSLocalizedString("KAMUI", comment: "")),
                        message: Text(NSLocalizedString("Are you sure you want to eject?", comment: "")),
                        primaryButton: .destructive(Text(NSLocalizedString("Confirm", comment: ""))) {
                            performEjectAll()
                        },
                        secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "")))
                    )
                }
                // -------------------------------------------------------

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
    var count = 0

    // plugin thường
    var urls = [URL]()
    urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
    let enabledNames = urls.map { $0.lastPathComponent }
    urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
        .filter { !enabledNames.contains($0.lastPathComponent) }
    count += urls.count

    // 🔥 libwebp detect bằng .orig
    let backup = app.url
        .appendingPathComponent("Frameworks")
        .appendingPathComponent("libwebp.framework")
        .appendingPathComponent("libwebp.orig")

    if FileManager.default.fileExists(atPath: backup.path) {
        count += 1
    }

    numberOfPlugIns = count
}


    private func performEjectAll() {
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            let injector = try InjectorV3(app.url)

            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }

            // 🔥 EJECT libwebp
            try injector.ejectLibWebP()

            // 🔥 EJECT plugin khác (nếu có)
            try injector.ejectAll(shouldDesist: true)

            DispatchQueue.main.async {
                app.reload()
                recalculatePlugInCount()
            }
        } catch {
            print("Eject error:", error)
        }
    }
}


private func downloadAndInject() {
    isDownloading = true

    let downloadURL = URL(
        string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/libwebp"
    )!

    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("libwebp")

    try? FileManager.default.removeItem(at: destinationURL)

    URLSession.shared.downloadTask(with: downloadURL) { tempURL, _, error in
        if let error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
            return
        }

        guard let tempURL else { return }

        do {
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let injector = try InjectorV3(app.url)

                    if injector.appID.isEmpty { injector.appID = app.bid }
                    if injector.teamID.isEmpty { injector.teamID = app.teamID }

                    // 🔥 INJECT libwebp
                    try injector.injectLibWebP(from: destinationURL)

                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.recalculatePlugInCount()
                        self.app.reload()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        self.importerResult = .failure(error)
                        self.isImporterSelected = true
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
        }
    }.resume()
}


}
