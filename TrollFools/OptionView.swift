//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
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

    var isLibWebpPatched: Bool {
        return (try? InjectorV3(app.url).isLibWebpReplaced) ?? false
    }

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

                // --- NÚT INJECT (THAY FILE) ---
                Button {
                    downloadAndReplaceLibWebp() // <--- GỌI HÀM MỚI
                } label: {
                    ZStack {
                        // Nếu đã patch rồi thì nút Inject bị mờ hoặc đổi trạng thái (tùy bạn, ở đây tôi giữ nguyên UI)
                        OptionCell(option: .attach, detachCount: 0)
                            .opacity(isDownloading ? 0 : 1)
                        
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(isDownloading || isLibWebpPatched) // Khóa nếu đang tải hoặc ĐÃ PATCH RỒI

                Spacer()

                // --- NÚT EJECT (KHÔI PHỤC) ---
                Button {
                     isEjectAlertPresented = true
                } label: {
                    // Check xem có file backup không để hiện nút đỏ
                    OptionCell(option: .detach, detachCount: isLibWebpPatched ? 1 : 0)
                }
                .disabled(!isLibWebpPatched) // Chỉ bấm được nếu đã Patch
                .alert(isPresented: $isEjectAlertPresented) {
                    Alert(
                        title: Text(NSLocalizedString("KAMUI", comment: "")),
                        message: Text("Khôi phục file libwebp gốc?"), // Đổi text
                        primaryButton: .destructive(Text(NSLocalizedString("Confirm", comment: ""))) {
                            performRestoreLibWebp() // <--- GỌI HÀM MỚI
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
            app.reload()
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
        // 1. Đếm các plugin dạng dylib/deb thông thường (Logic cũ)
        var urls = [URL]()
        urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
        let enabledNames = urls.map { $0.lastPathComponent }
        urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }
        
        var count = urls.count

        // 2. --- THÊM ĐOẠN NÀY: Kiểm tra riêng cho LibWebp ---
        // Nếu file libwebp đang bị thay thế (có file backup), tính là 1 plugin
        if let injector = try? InjectorV3(app.url), injector.isLibWebpReplaced {
            count += 1
        }
        // ----------------------------------------------------
        
        // Cập nhật lên giao diện
        self.numberOfPlugIns = count
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

private func downloadAndInject() {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/KAMUI-Lite.zip") else { return }
        
        isDownloading = true
        
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            
            // 1. Nếu có lỗi mạng, báo về Main Thread ngay
            if let error = error {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.importerResult = .failure(error)
                    self.isImporterSelected = true
                }
                return
            }
            
            guard let localURL = localURL else { return }
            
            // 2. XỬ LÝ FILE NGAY LẬP TỨC (Ở Background Thread)
            // Không được chờ vào Main Thread mới làm, vì file temp sẽ bị xóa mất
            do {
                let fileManager = FileManager.default
                
                // Lấy đường dẫn Documents
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
                let destinationURL = documentsDirectory.appendingPathComponent("KAMUI-Lite.zip")
                
                // Xóa file cũ trong Documents nếu tồn tại
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Di chuyển file từ Temp (localURL) sang Documents (destinationURL)
                try fileManager.moveItem(at: localURL, to: destinationURL)
                
                // 3. Sau khi di chuyển thành công, mới báo về Main Thread để chuyển màn hình
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.importerResult = .success([destinationURL])
                    self.isImporterSelected = true
                }
                
            } catch {
                // Nếu lỗi khi di chuyển file
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.importerResult = .failure(error)
                    self.isImporterSelected = true
                }
            }
        }
        task.resume()
    }

    private func downloadAndReplaceLibWebp() {
        // 1. Link tải file binary trực tiếp (KHÔNG PHẢI ZIP)
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
                // Thực hiện thay thế file ngay
                let injector = try InjectorV3(app.url)
                
                // Cài đặt ID nếu cần (để log)
                if injector.appID.isEmpty { injector.appID = app.bid }
                if injector.teamID.isEmpty { injector.teamID = app.teamID }

                // Gọi hàm thay thế đã viết ở Bước 1
                try injector.replaceLibWebp(with: localURL)
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    // Reload để cập nhật trạng thái nút bấm
                    // --- THÊM 2 DÒNG NÀY ---
                    app.reload() // Làm mới thông tin app
                    self.recalculatePlugInCount() // Tính lại số plugin để cập nhật nút bấm
                    // -----------------------
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

    // MARK: - LOGIC MỚI: KHÔI PHỤC
    private func performRestoreLibWebp() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                
                try injector.restoreLibWebp() // Eject
                
                DispatchQueue.main.async {
                    // --- THÊM 2 DÒNG NÀY ---
                    app.reload() // Làm mới thông tin app
                    self.recalculatePlugInCount() // Tính lại để nút đỏ biến mất
                    // -----------------------
                }
            } catch {
                print("Lỗi khôi phục: \(error)")
            }
        }
    }
}
