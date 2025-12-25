//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct OptionView: View {
    let app: App
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.presentationMode) var presentationMode

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
    
    @StateObject var downloadManager = DownloadManager()
    @AppStorage("isWarningHidden") var isWarningHidden: Bool = false

    init(_ app: App) { self.app = app }

    static func warningMessage(_ urls: [URL]) -> String {
        guard let firstDylibName = urls.first(where: { $0.pathExtension.lowercased() == "deb" })?.lastPathComponent else {
            return NSLocalizedString("Unknown Debian Package", comment: "")
        }
        return String(format: NSLocalizedString("You’ve selected at least one Debian Package “%@”. We’re here to remind you that it will not work as it was in a jailbroken environment. Please make sure you know what you’re doing.", comment: ""), firstDylibName)
    }

    var body: some View {
        ZStack {
            // 1. NỀN CHUNG
            Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            
            // 2. GIAO DIỆN CHÍNH
            mainInterface
            
            // 3. OVERLAY DOWNLOAD
            if isDownloading {
                downloadOverlay.zIndex(2)
            }
            
            // 4. OVERLAY SUCCESS
            if isSuccessAlertPresented {
                successOverlay.zIndex(3)
            }
        }
    }
    
    @ViewBuilder
    var mainInterface: some View {
        if #available(iOS 15, *) {
            baseContent
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
            baseContent
                .alert(isPresented: $isWarningPresented) {
                    let result = temporaryResult ?? .success([])
                    var msg = ""
                    if case let .success(urls) = result { msg = Self.warningMessage(urls) }
                    
                    return Alert(
                        title: Text(NSLocalizedString("Notice", comment: "")),
                        message: Text(msg),
                        primaryButton: .default(Text(NSLocalizedString("Continue", comment: ""))) {
                            importerResult = result
                            isImporterSelected = true
                        },
                        secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: ""))) {
                            temporaryResult = nil
                            isWarningPresented = false
                        }
                    )
                }
        }
    }
    
    var baseContent: some View {
        content
            .blur(radius: (isDownloading || isSuccessAlertPresented) ? 5 : 0)
            .animation(.easeInOut, value: isDownloading)
            .disabled(isDownloading || isSuccessAlertPresented)
    }
    
    // --- OVERLAY DOWNLOAD ---
    var downloadOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.blue.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "icloud.and.arrow.down.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                VStack(spacing: 10) {
                    Text("Downloading...")
                        .font(.headline)
                        .foregroundColor(Color.primary)
                    Text("Please do not exit the app")
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                }
                
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: CGFloat(downloadManager.progress) * geometry.size.width, height: 8)
                                .animation(.linear, value: downloadManager.progress)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(Int(downloadManager.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
            }
            .padding(30)
            .frame(width: 280)
            .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.95))
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
    }

    // --- OVERLAY SUCCESS ---
    var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation { isSuccessAlertPresented = false }
                }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .shadow(color: Color.green.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 20)
                
                VStack(spacing: 8) {
                    Text("Success!")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(successMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button {
                    withAnimation {
                        isSuccessAlertPresented = false
                    }
                } label: {
                    Text("Awesome!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color(UIColor.systemGreen)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(width: 300)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 25, x: 0, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
    }

    var content: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                
                // HEADER TRẠNG THÁI
                HStack(spacing: 12) {
                    Circle()
                        .fill(isWebPInjected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .shadow(color: (isWebPInjected ? Color.green : Color.red).opacity(0.8), radius: 6)
                    
                    Text(isWebPInjected ? "SYSTEM ACTIVE" : "SYSTEM INACTIVE")
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundColor(isWebPInjected ? .green : .red)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                // NÚT START
                Button {
                    downloadAndReplace()
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Inject Game")
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color(red: 0.0, green: 0.9, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(isDownloading || isWebPInjected)
                .opacity(isWebPInjected ? 0.5 : 1)

                // NÚT STOP
                Button {
                    performRestore()
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Restore Original")
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(!isWebPInjected)
                .opacity(!isWebPInjected ? 0.5 : 1)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        // --- CÁC THIẾT LẬP NAVIGATION QUAN TRỌNG ---
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline) // Tiêu đề nhỏ gọn
        .navigationBarBackButtonHidden(true)    // Ẩn nút Back mặc định (kèm chữ)
        .toolbar {                              // Thêm nút Back tự chế
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    // Dùng chevron.backward để giống iOS nhất
                    Image(systemName: "chevron.backward") 
                        .font(.system(size: 17, weight: .semibold)) // Kích thước và độ đậm chuẩn
                        .foregroundColor(.blue) // Màu xanh chuẩn iOS
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if verticalSizeClass == .compact {
                    Button { isSettingsPresented = true } label: { Label("Settings", systemImage: "gear") }
                }
            }
        }
        // ---------------------------------------------
        .background(Group {
            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case let .success(urls): InjectView(app, urlList: urls)
                    case let .failure(error): FailureView(title: "Error", error: error)
                    }
                }
            } label: { }
        })
        .onAppear { recalculatePlugInCount() }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "dylib")!,
                UTType(filenameExtension: "deb")!,
                UTType.bundle,
                UTType.framework,
                UTType.zip
            ],
            allowsMultipleSelection: true
        ) { result in
             importerResult = result
             isImporterSelected = true
        }
    }

    // --- LOGIC FUNCTIONS ---
    private func recalculatePlugInCount() {
        let injector = try? InjectorV3(app.url)
        var isPatched = false
        if app.bid == "com.vnggames.cfl.crossfirelegends" { isPatched = injector?.isCrossfirePatched ?? false }
        else { isPatched = injector?.isLibWebpReplaced ?? false }
        self.isWebPInjected = isPatched
        self.numberOfPlugIns = isPatched ? 1 : 0
    }

    private func downloadAndReplace() {
        downloadManager.progress = 0.0
        isDownloading = true
        Task {
            if app.bid == "com.vnggames.cfl.crossfirelegends" { await downloadAndReplaceCrossfire() }
            else { await downloadAndReplaceLibWebp() }
        }
    }
    
    private func performRestore() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let injector = try InjectorV3(app.url)
                if self.app.bid == "com.vnggames.cfl.crossfirelegends" { try injector.restoreCrossfireFiles(); self.successMessage = "Restored Crossfire!" }
                else { try injector.restoreLibWebp(); self.successMessage = "Restored PUBG!" }
                DispatchQueue.main.async {
                    self.app.reload()
                    withAnimation { self.isSuccessAlertPresented = true }
                    self.recalculatePlugInCount()
                    NotificationCenter.default.post(name: Notification.Name("TrollFoolsDidUpdateApp"), object: nil)
                }
            } catch { print("Error: \(error)") }
        }
    }

    private func downloadAndReplaceLibWebp() async {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/KAMUI/App") else { return }
        do {
            let localURL = try await downloadManager.download(url: url)
            let injector = try InjectorV3(app.url)
            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }
            try injector.replaceLibWebp(with: localURL)
            try? FileManager.default.removeItem(at: localURL)
            await MainActor.run {
                self.isDownloading = false
                app.reload()
                self.successMessage = "Injected PUBG!"
                withAnimation { self.isSuccessAlertPresented = true }
                self.recalculatePlugInCount()
                NotificationCenter.default.post(name: Notification.Name("TrollFoolsDidUpdateApp"), object: nil)
            }
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
        }
    }
    
    private func downloadAndReplaceCrossfire() async {
        guard let urlPix = URL(string: "LINK_TAI_PIXVIDEO") else { return }
        guard let urlAnogs = URL(string: "LINK_TAI_ANOGS") else { return }
        do {
            let localPix = try await downloadManager.download(url: urlPix, multiplier: 0.5, offset: 0.0)
            let localAnogs = try await downloadManager.download(url: urlAnogs, multiplier: 0.5, offset: 0.5)
            let injector = try InjectorV3(app.url)
            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }
            try injector.replaceCrossfireFiles(pixVideoURL: localPix, anogsURL: localAnogs)
            try? FileManager.default.removeItem(at: localPix); try? FileManager.default.removeItem(at: localAnogs)
            await MainActor.run {
                self.isDownloading = false
                app.reload()
                self.successMessage = "Injected Crossfire!"
                withAnimation { self.isSuccessAlertPresented = true }
                self.recalculatePlugInCount()
                NotificationCenter.default.post(name: Notification.Name("TrollFoolsDidUpdateApp"), object: nil)
            }
        } catch {
            await MainActor.run {
                self.isDownloading = false
                self.importerResult = .failure(error)
                self.isImporterSelected = true
            }
        }
    }
}

// MARK: - Download Manager Helper
class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0.0
    private var continuation: CheckedContinuation<URL, Error>?
    var progressMultiplier: Double = 1.0; var progressOffset: Double = 0.0

    func download(url: URL, multiplier: Double = 1.0, offset: Double = 0.0) async throws -> URL {
        self.progressMultiplier = multiplier; self.progressOffset = offset
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do { try FileManager.default.moveItem(at: location, to: tempURL); continuation?.resume(returning: tempURL) } catch { continuation?.resume(throwing: error) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async { let currentProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite); self.progress = self.progressOffset + (currentProgress * self.progressMultiplier) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { if let error = error { continuation?.resume(throwing: error) } }
}
