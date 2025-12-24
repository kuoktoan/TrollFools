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
    
    @State var isWarningPresented = false
    @State var temporaryResult: Result<[URL], any Error>?

    @State var isSettingsPresented = false
    @State var isDownloading = false
    @State var importerResult: Result<[URL], any Error>?

    @State var numberOfPlugIns: Int = 0
    @State var isWebPInjected: Bool = false
    
    @State var isSuccessAlertPresented = false
    @State var successMessage = ""

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
                    } label: { Text(NSLocalizedString("Continue", comment: "")) }
                    Button(role: .destructive) {
                        importerResult = result
                        isImporterSelected = true
                        isWarningHidden = true
                    } label: { Text(NSLocalizedString("Continue and Don’t Show Again", comment: "")) }
                    Button(role: .cancel) {
                        temporaryResult = nil
                        isWarningPresented = false
                    } label: { Text(NSLocalizedString("Cancel", comment: "")) }
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
        VStack {
            Spacer()

            VStack(spacing: 20) {
                // START BUTTON
                // --- NÚT START ---
                Button {
                    downloadAndReplace()
                } label: {
                    ZStack {
                        // 1. Nút gốc (Ẩn đi khi đang tải)
                        OptionCell(option: .attach, detachCount: 0)
                            .opacity(isDownloading ? 0 : 1)
                        
                        // 2. Hiển thị khi đang tải (Spinner + Text)
                        if isDownloading {
                            VStack(spacing: 8) { // Khoảng cách giữa spinner và chữ
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.2) // Phóng to spinner một chút cho đẹp
                                
                                Text("Starting ...\nPlease Do Not Exit The App")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .multilineTextAlignment(.center) // Căn giữa
                                    .foregroundColor(.gray) // Màu chữ (có thể đổi thành .primary hoặc .blue)
                                    .fixedSize(horizontal: false, vertical: true) // Đảm bảo chữ không bị cắt ngang
                            }
                            // Thêm background mờ nhẹ để chữ dễ đọc hơn (tuỳ chọn)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                                    .shadow(radius: 5)
                            )
                        }
                    }
                }
                .disabled(isDownloading || isWebPInjected)
                .frame(maxWidth: .infinity)

                // STOP BUTTON
                Button {
                    performRestore()
                } label: {
                    OptionCell(option: .detach, detachCount: isWebPInjected ? 1 : 0)
                }
                .disabled(!isWebPInjected)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .alert(isPresented: $isSuccessAlertPresented) {
            Alert(
                title: Text(NSLocalizedString("Complete", comment: "")),
                message: Text(NSLocalizedString(successMessage, comment: "")),
                dismissButton: .default(Text("OK"))
            )
        }
        .padding()
        .navigationTitle(app.name)
        .background(Group {
            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case let .success(urls):
                        InjectView(app, urlList: urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }))
                    case let .failure(error):
                        FailureView(title: NSLocalizedString("Error", comment: ""), error: error)
                    }
                }
            } label: { }
        })
        .onAppear {
            recalculatePlugInCount()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.init(filenameExtension: "dylib")!, .init(filenameExtension: "deb")!, .bundle, .framework, .package, .zip],
            allowsMultipleSelection: true
        ) { result in
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
                Button { isSettingsPresented = true } label: {
                    Label(NSLocalizedString("Advanced Settings", comment: ""), systemImage: "gear")
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
        let injector = try? InjectorV3(app.url)
        var isPatched = false
        if app.bid == "com.vnggames.cfl.crossfirelegends" {
            isPatched = injector?.isCrossfirePatched ?? false
        } else {
            isPatched = injector?.isLibWebpReplaced ?? false
        }
        
        self.isWebPInjected = isPatched
        
        var urls = [URL]()
        urls += InjectorV3.main.injectedAssetURLsInBundle(app.url)
        let enabledNames = urls.map { $0.lastPathComponent }
        urls += InjectorV3.main.persistedAssetURLs(bid: app.bid)
            .filter { !enabledNames.contains($0.lastPathComponent) }
        
        var count = urls.count
        if isPatched { count += 1 }
        
        self.numberOfPlugIns = count
    }

    // MARK: - LOGIC ĐIỀU HƯỚNG
    private func downloadAndReplace() {
        if app.bid == "com.vnggames.cfl.crossfirelegends" {
            downloadAndReplaceCrossfire()
        } else {
            downloadAndReplaceLibWebp()
        }
    }
    
    private func performRestore() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                if self.app.bid == "com.vnggames.cfl.crossfirelegends" {
                    try injector.restoreCrossfireFiles()
                    self.successMessage = "Stop Hack Success"
                } else {
                    try injector.restoreLibWebp()
                    self.successMessage = "Stop Hack Success"
                }
                DispatchQueue.main.async {
                    self.app.reload()
                    self.isSuccessAlertPresented = true
                    self.recalculatePlugInCount()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.recalculatePlugInCount() }
                }
            } catch {
                print("Lỗi khôi phục: \(error)")
            }
        }
    }

    // MARK: - PUBG
    private func downloadAndReplaceLibWebp() {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/GAO/App") else { return }
        isDownloading = true
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                DispatchQueue.main.async { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true }
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
                    self.successMessage = "Start Hack Success"
                    self.isSuccessAlertPresented = true
                    self.recalculatePlugInCount()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.recalculatePlugInCount() }
                }
            } catch {
                DispatchQueue.main.async { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true }
            }
        }
        task.resume()
    }
    
    // MARK: - CROSSFIRE (Tải 2 file: PixVideo và anogs)
    private func downloadAndReplaceCrossfire() {
        // 1. LINK TẢI PIXVIDEO
        guard let urlPix = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/GAO/PixVideo") else { return }
        // 2. LINK TẢI ANOGS
        guard let urlAnogs = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/anogs") else { return }
        
        isDownloading = true
        
        // Bước 1: Tải PixVideo
        let taskPix = URLSession.shared.downloadTask(with: urlPix) { localPixURL, response, error in
            if let error = error {
                DispatchQueue.main.async { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true }
                return
            }
            guard let localPixURL = localPixURL else { return }
            
            // Do URLSession sẽ xóa file temp khi closure kết thúc, ta cần copy ra chỗ khác
            let tempPix = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.moveItem(at: localPixURL, to: tempPix)
            
            // Bước 2: Tải anogs (lồng bên trong)
            let taskAnogs = URLSession.shared.downloadTask(with: urlAnogs) { localAnogsURL, response, error in
                if let error = error {
                    DispatchQueue.main.async { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true }
                    return
                }
                guard let localAnogsURL = localAnogsURL else { return }
                
                // Bước 3: Inject cả 2 file
                do {
                    let injector = try InjectorV3(app.url)
                    if injector.appID.isEmpty { injector.appID = app.bid }
                    if injector.teamID.isEmpty { injector.teamID = app.teamID }
                    
                    // Gọi hàm thay thế 2 file
                    try injector.replaceCrossfireFiles(pixVideoURL: tempPix, anogsURL: localAnogsURL)
                    
                    // Xóa file temp PixVideo
                    try? FileManager.default.removeItem(at: tempPix)

                    DispatchQueue.main.async {
                        self.isDownloading = false
                        app.reload()
                        self.successMessage = "Start Hack Success"
                        self.isSuccessAlertPresented = true
                        self.recalculatePlugInCount()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.recalculatePlugInCount() }
                    }
                } catch {
                    DispatchQueue.main.async { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true }
                }
            }
            taskAnogs.resume()
        }
        taskPix.resume()
    }
}
