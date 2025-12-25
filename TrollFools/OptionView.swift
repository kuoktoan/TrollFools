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
    
    // --- MỚI: QUẢN LÝ DOWNLOAD ---
    @StateObject var downloadManager = DownloadManager()
    // ----------------------------

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    init(_ app: App) {
        self.app = app
    }

    var body: some View {
        ZStack { // --- MỚI: ZStack để hiện Overlay ---
            
            // 1. NỘI DUNG CHÍNH (Giao diện cũ)
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
                    // Disable tương tác khi đang tải
                    .disabled(isDownloading)
                    .blur(radius: isDownloading ? 3 : 0) // Làm mờ nền khi tải
            } else {
                wrappedContent
                    .disabled(isDownloading)
                    .blur(radius: isDownloading ? 3 : 0)
            }
            
            // 2. BẢNG THÔNG BÁO TIẾN TRÌNH (OVERLAY)
            if isDownloading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // Spinner
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(1.5)
                    
                    VStack(spacing: 8) {
                        Text("Starting ...")
                            .font(.headline)
                            .bold()
                        
                        Text("Please Do Not Exit The App")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Thanh Progress Bar & Phần trăm
                    VStack(spacing: 5) {
                        ProgressView(value: downloadManager.progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 8)
                        
                        Text("\(Int(downloadManager.progress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                }
                .padding(30)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .shadow(radius: 20)
                .frame(maxWidth: 300)
                .transition(.scale)
            }
        }
        // ALERT SUCCESS
        .alert(isPresented: $isSuccessAlertPresented) {
            Alert(
                title: Text(NSLocalizedString("Complete", comment: "")),
                message: Text(NSLocalizedString(successMessage, comment: "")),
                dismissButton: .default(Text("OK"))
            )
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
                Button {
                    downloadAndReplace()
                } label: {
                    OptionCell(option: .attach, detachCount: 0)
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
        // Reset progress
        downloadManager.progress = 0.0
        isDownloading = true
        
        // Sử dụng Task để chạy bất đồng bộ (Async/Await)
        Task {
            if app.bid == "com.vnggames.cfl.crossfirelegends" {
                await downloadAndReplaceCrossfire()
            } else {
                await downloadAndReplaceLibWebp()
            }
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

    // MARK: - PUBG (Async)
    private func downloadAndReplaceLibWebp() await {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/KAMUI/App") else { return }
        
        do {
            // Tải về (từ 0% -> 100%)
            let localURL = try await downloadManager.download(url: url)
            
            // Inject
            let injector = try InjectorV3(app.url)
            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }

            try injector.replaceLibWebp(with: localURL)
            try? FileManager.default.removeItem(at: localURL)

            DispatchQueue.main.async {
                self.isDownloading = false
                app.reload()
                self.successMessage = "Start Hack Success"
                self.isSuccessAlertPresented = true
                self.recalculatePlugInCount()
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
        }
    }
    
    // MARK: - CROSSFIRE (Async - 2 Files)
    private func downloadAndReplaceCrossfire() await {
        guard let urlPix = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/KAMUI/PixVideo") else { return }
        guard let urlAnogs = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/anogs") else { return }
        
        do {
            // 1. Tải PixVideo (Chiếm 50% thanh tiến trình: từ 0.0 -> 0.5)
            let localPix = try await downloadManager.download(url: urlPix, multiplier: 0.5, offset: 0.0)
            
            // 2. Tải anogs (Chiếm 50% thanh tiến trình: từ 0.5 -> 1.0)
            let localAnogs = try await downloadManager.download(url: urlAnogs, multiplier: 0.5, offset: 0.5)
            
            // 3. Inject
            let injector = try InjectorV3(app.url)
            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }
            
            try injector.replaceCrossfireFiles(pixVideoURL: localPix, anogsURL: localAnogs)
            
            // Dọn dẹp
            try? FileManager.default.removeItem(at: localPix)
            try? FileManager.default.removeItem(at: localAnogs)

            DispatchQueue.main.async {
                self.isDownloading = false
                app.reload()
                self.successMessage = "Start Hack Success"
                self.isSuccessAlertPresented = true
                self.recalculatePlugInCount()
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
        }
    }
    // MARK: - Download Manager Helper
class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0.0
    private var continuation: CheckedContinuation<URL, Error>?
    
    // Hệ số để chia progress (VD: tải 2 file thì file 1 là 0-50%, file 2 là 50-100%)
    var progressMultiplier: Double = 1.0
    var progressOffset: Double = 0.0

    func download(url: URL, multiplier: Double = 1.0, offset: Double = 0.0) async throws -> URL {
        self.progressMultiplier = multiplier
        self.progressOffset = offset
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Copy file tạm ra chỗ khác để không bị xóa mất
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempURL)
            continuation?.resume(returning: tempURL)
        } catch {
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            let currentProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            // Tính toán progress tổng dựa trên offset (cho trường hợp tải nhiều file)
            self.progress = self.progressOffset + (currentProgress * self.progressMultiplier)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
        }
    }
}
}
