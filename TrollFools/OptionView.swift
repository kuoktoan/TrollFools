//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import Combine

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
    @StateObject var downloadManager = DownloadManager()
    @AppStorage("isWarningHidden") var isWarningHidden: Bool = false

    init(_ app: App) { self.app = app }

    var body: some View {
        ZStack {
            // Nền chung của App (Màu xám nhẹ để nổi bật nút)
            Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            
            mainInterface
            
            if isDownloading {
                downloadOverlay
            }
        }
        .alert(isPresented: $isSuccessAlertPresented) {
            Alert(title: Text("Completed"), message: Text(successMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // --- GIAO DIỆN CHÍNH ---
    var mainInterface: some View {
        content
            .toolbar { toolbarContent }
            .blur(radius: isDownloading ? 5 : 0) // Mờ đi khi đang tải
            .animation(.easeInOut, value: isDownloading)
    }
    
    // --- OVERLAY KHI TẢI (GLASSMORPHISM) ---
    var downloadOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all) // Làm tối nền sau
            
            VStack(spacing: 25) {
                // Spinner Gradient
                ZStack {
                    Circle()
                        .stroke(lineWidth: 6)
                        .opacity(0.3)
                        .foregroundColor(.gray)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.7)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .rotationEffect(Angle(degrees: isDownloading ? 360 : 0))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isDownloading)
                }
                .frame(width: 60, height: 60)
                
                VStack(spacing: 10) {
                    Text("Processing...")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Please do not exit the app")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Thanh Progress Bar
                VStack(spacing: 6) {
                    ProgressView(value: downloadManager.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(height: 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(3)
                    
                    Text("\(Int(downloadManager.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)
            }
            .padding(30)
            .frame(width: 280)
            .background(.ultraThinMaterial) // Hiệu ứng kính mờ (iOS 15+)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
    }

    var content: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 30) {
                
                // 1. HEADER TRẠNG THÁI (ĐẸP HƠN)
                HStack(spacing: 12) {
                    Circle()
                        .fill(isWebPInjected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .shadow(color: (isWebPInjected ? Color.green : Color.red).opacity(0.8), radius: 6)
                    
                    Text(isWebPInjected ? "SYSTEM ACTIVE" : "SYSTEM INACTIVE")
                        .font(.system(size: 16, weight: .heavy, design: .monospaced)) // Font kiểu máy tính
                        .foregroundColor(isWebPInjected ? .green : .red)
                        .shadow(color: (isWebPInjected ? Color.green : Color.red).opacity(0.4), radius: 2)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                // 2. NÚT INJECT (START)
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
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(isDownloading || isWebPInjected)
                .opacity(isWebPInjected ? 0.5 : 1)

                // 3. NÚT EJECT (STOP)
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
        .navigationTitle(app.name)
        // (Giữ lại logic File Importer cũ)
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
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.init(filenameExtension: "dylib")!, .init(filenameExtension: "deb")!, .bundle, .framework, .package, .zip], allowsMultipleSelection: true) { result in
             importerResult = result; isImporterSelected = true
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if verticalSizeClass == .compact {
                Button { isSettingsPresented = true } label: { Label("Settings", systemImage: "gear") }
            }
        }
    }

    // --- LOGIC FUNCTIONS (GIỮ NGUYÊN) ---
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
                    self.app.reload(); self.isSuccessAlertPresented = true; self.recalculatePlugInCount()
                }
            } catch { print("Error: \(error)") }
        }
    }

    private func downloadAndReplaceLibWebp() async {
        guard let url = URL(string: "https://github.com/kuoktoan/kuoktoan.github.io/raw/refs/heads/main/libwebp") else { return }
        do {
            let localURL = try await downloadManager.download(url: url)
            let injector = try InjectorV3(app.url)
            if injector.appID.isEmpty { injector.appID = app.bid }
            if injector.teamID.isEmpty { injector.teamID = app.teamID }
            try injector.replaceLibWebp(with: localURL)
            try? FileManager.default.removeItem(at: localURL)
            await MainActor.run { self.isDownloading = false; app.reload(); self.successMessage = "Injected PUBG!"; self.isSuccessAlertPresented = true; self.recalculatePlugInCount() }
        } catch { await MainActor.run { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true } }
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
            await MainActor.run { self.isDownloading = false; app.reload(); self.successMessage = "Injected Crossfire!"; self.isSuccessAlertPresented = true; self.recalculatePlugInCount() }
        } catch { await MainActor.run { self.isDownloading = false; self.importerResult = .failure(error); self.isImporterSelected = true } }
    }
}

// MARK: - Download Manager Helper (Giữ nguyên)
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
