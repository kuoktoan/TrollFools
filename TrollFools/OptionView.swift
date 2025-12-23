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
    @State var isEjectAlertPresented = false

    @State var isWarningPresented = false
    @State var temporaryResult: Result<[URL], any Error>?

    @State var isSettingsPresented = false
    @State var isDownloading = false
    @State var importerResult: Result<[URL], any Error>?

    @State var numberOfPlugIns: Int = 0
    
    // --- THAY ĐỔI 1: Biến thành @State để SwiftUI theo dõi ---
    @State var isWebPInjected: Bool = false
    // --------------------------------------------------------

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

                // --- NÚT INJECT (Tải và Thay thế) ---
                Button {
                    downloadAndReplaceLibWebp()
                } label: {
                    ZStack {
                        // Ẩn nút nếu đang tải
                        OptionCell(option: .attach, detachCount: 0)
                            .opacity(isDownloading ? 0 : 1)
                        
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                // Khóa nút nếu đang tải HOẶC đã Inject rồi (dựa vào biến @State)
                .disabled(isDownloading || isWebPInjected)

                Spacer()

                // --- NÚT EJECT (Khôi phục) ---
                Button {
                     isEjectAlertPresented = true
                } label: {
                    // Dùng biến @State isWebPInjected để hiện số
                    OptionCell(option: .detach, detachCount: isWebPInjected ? 1 : 0)
                }
                // Chỉ bấm được nếu ĐÃ Inject
                .disabled(!isWebPInjected)
                .alert(isPresented: $isEjectAlertPresented) {
                    Alert(
                        title: Text(NSLocalizedString("KAMUI", comment: "")),
                        message: Text("Khôi phục file libwebp gốc?"),
                        primaryButton: .destructive(Text(NSLocalizedString("Confirm", comment: ""))) {
                            performRestoreLibWebp()
                        },
                        secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "")))
                    )
                }

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

    // --- THAY ĐỔI 2: Cập nhật biến @State trong này ---
    private func recalculatePlugInCount() {
        // 1. Kiểm tra trạng thái LibWebp
        let injector = try? InjectorV3(app.url)
        let webpStatus = injector?.isLibWebpReplaced ?? false
        
        // Cập nhật vào biến State để giao diện tự vẽ lại
        self.isWebPInjected = webpStatus
        
        // 2. Đếm các plugin khác (nếu có)
        var urls = [URL]()
        urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
        let enabledNames = urls.map { $0.lastPathComponent }
        urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }
        
        var count = urls.count
        if webpStatus { count += 1 }
        
        self.numberOfPlugIns = count
    }
    // ------------------------------------------------

    // MARK: - LOGIC TẢI VÀ THAY THẾ
    
    private func downloadAndReplaceLibWebp() {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/libwebp") else { return }
        
        isDownloading = true
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.importerResult = .failure(error)
                    self.isImporterSelected = true
                }
                return
            }
            guard let localURL = localURL else { return }
            do {
                let injector = try InjectorV3(app.url)
                if injector.appID.isEmpty { injector.appID = app.bid }
                if injector.teamID.isEmpty { injector.teamID = app.teamID }

                try injector.replaceLibWebp(with: localURL)

                DispatchQueue.main.async {
                    self.isDownloading = false
                    app.reload()
                    
                    // Kiểm tra ngay lập tức
                    self.recalculatePlugInCount()
                    
                    // Kiểm tra lại lần nữa sau 0.5s để chắc chắn file hệ thống đã cập nhật
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.recalculatePlugInCount()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.importerResult = .failure(error)
                    self.isImporterSelected = true
                }
            }
        }
        task.resume()
    }

    // MARK: - LOGIC KHÔI PHỤC (EJECT)
    
    private func performRestoreLibWebp() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                
                try injector.restoreLibWebp()
                
                DispatchQueue.main.async {
                    app.reload()
                    
                    // --- THAY ĐỔI 3: Kiểm tra 2 lần (Ngay lập tức và trễ 0.5s) ---
                    // Lần 1: Cập nhật ngay để UI phản hồi nhanh
                    self.recalculatePlugInCount()
                    
                    // Lần 2: Cập nhật sau 0.5 giây để đảm bảo file hệ thống đã xóa xong hoàn toàn
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.recalculatePlugInCount()
                    }
                    // -----------------------------------------------------------
                }
            } catch {
                print("Lỗi khôi phục: \(error)")
            }
        }
    }
}
