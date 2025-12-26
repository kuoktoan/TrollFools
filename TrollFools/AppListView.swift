//
//  AppListView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import OrderedCollections
import SwiftUI
import SwiftUIIntrospect

typealias Scope = AppListModel.Scope

struct AppListView: View {
    let isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad

    @StateObject var searchViewModel = AppListSearchModel()
    @EnvironmentObject var appList: AppListModel
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State var selectorOpenedURL: URLIdentifiable? = nil
    @State var selectedIndex: String? = nil

    @State var isWarningPresented = false
    @State var temporaryOpenedURL: URLIdentifiable? = nil

    @State var latestVersionString: String?

    @AppStorage("isAdvertisementHiddenV2")
    var isAdvertisementHidden: Bool = false

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    var shouldShowAdvertisement: Bool {
        !isAdvertisementHidden &&
            !appList.filter.isSearching &&
            !appList.filter.showPatchedOnly &&
            !appList.isRebuildNeeded &&
            !appList.isSelectorMode
    }

    var appString: String {
        let appNameString = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "KAMUI"
        let appVersionString = String(
            format: "v%@ (%@)",
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        )

        let appStringFormat = """
        %@ %@
        %@ © 2024-%d %@
        """

        return String(
            format: appStringFormat,
            appNameString, appVersionString,
            NSLocalizedString("Copyright", comment: ""),
            Calendar.current.component(.year, from: Date()),
            NSLocalizedString("Lessica, huami1314, iosdump and other contributors", comment: "")
        )
    }

    var body: some View {
        if #available(iOS 15, *) {
            content
                .alert(
                    NSLocalizedString("Notice", comment: ""),
                    isPresented: $isWarningPresented,
                    presenting: temporaryOpenedURL
                ) { result in
                    Button {
                        selectorOpenedURL = result
                    } label: {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    Button(role: .destructive) {
                        selectorOpenedURL = result
                        isWarningHidden = true
                    } label: {
                        Text(NSLocalizedString("Continue and Don’t Show Again", comment: ""))
                    }
                    Button(role: .cancel) {
                        temporaryOpenedURL = nil
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    Text(OptionView.warningMessage([$0.url]))
                }
        } else {
            content
        }
    }

    var content: some View {
        styledNavigationView
            .animation(.easeOut, value: appList.activeScopeApps.keys)
            .sheet(item: $selectorOpenedURL) { urlWrapper in
                AppListView()
                    .environmentObject(AppListModel(selectorURL: urlWrapper.url))
            }
            .onOpenURL { url in
                let ext = url.pathExtension.lowercased()
                guard url.isFileURL,
                      ext == "dylib" || ext == "deb" || ext == "zip"
                else {
                    return
                }

                let urlIdent = URLIdentifiable(url: preprocessURL(url))
                if #available(iOS 15, *) {
                    if !isWarningHidden && ext == "deb" {
                        temporaryOpenedURL = urlIdent
                        isWarningPresented = true
                        return
                    }
                }

                selectorOpenedURL = urlIdent
            }
            .onAppear {
                if Double.random(in: 0 ..< 1) < 0.1 {
                    isAdvertisementHidden = false
                }

                CheckUpdateManager.shared.checkUpdateIfNeeded { latestVersion, _ in
                    DispatchQueue.main.async {
                        withAnimation {
                            latestVersionString = latestVersion?.tagName
                        }
                    }
                }
            }
    }

    @ViewBuilder
    var styledNavigationView: some View {
        if isPad {
            navigationView
                .navigationViewStyle(.automatic)
        } else {
            navigationView
                .navigationViewStyle(.stack)
        }
    }

    var navigationView: some View {
        NavigationView {
            ScrollViewReader { reader in
                ZStack {
                    // Gọi trực tiếp listView, không qua refreshableListView nữa
                    listView
                }
            }

            // Detail view shown when nothing has been selected
            if !appList.isSelectorMode {
                PlaceholderView()
            }
        }
    }

    var listView: some View {
        ZStack {
            // 1. LỚP NỀN TRÀN VIỀN
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            // 2. CẤU TRÚC GIAO DIỆN CHÍNH (VStack)
            VStack(spacing: 0) {
                
                // --- PHẦN HEADER CỐ ĐỊNH (KHÔNG CUỘN) ---
                HStack(alignment: .center) {
                    // Tiêu đề
                    Text(NSLocalizedString("GAO Loader", comment: ""))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // NÚT RELOAD THỦ CÔNG (Duy nhất)
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        appList.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(10)
                            .background(Circle().fill(Color.blue.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                // Padding top để tránh tai thỏ (vì đã dùng edgesIgnoringSafeArea cho nền)
                .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20)
                .padding(.bottom, 15)
                .background(Color(UIColor.systemGroupedBackground)) // Nền trùng màu để che nội dung khi cuộn
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 5) // Bóng đổ nhẹ ngăn cách header
                .zIndex(1) // Đảm bảo luôn nằm trên list

                // --- PHẦN NỘI DUNG CUỘN (SCROLLVIEW) ---
                ScrollView {
                    VStack(spacing: 20) {
                        // DANH SÁCH GAME
                        LazyVStack(spacing: 0) {
                            ForEach(appList.activeScopeApps.keys.elements, id: \.self) { key in
                                ForEach(appList.activeScopeApps[key] ?? [], id: \.bid) { app in
                                    NavigationLink {
                                        if appList.isSelectorMode, let selectorURL = appList.selectorURL {
                                            InjectView(app, urlList: [selectorURL])
                                        } else {
                                            OptionView(app)
                                        }
                                    } label: {
                                        AppListCell(app: app)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10) // Khoảng cách với Header
                        
                        // FOOTER
                        if let version = latestVersionString {
                            Text("Latest version: \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 40)
                        }
                    }
                }
                // TẮT RELOAD KHI KÉO (Bằng cách không thêm modifier .refreshable)
            }
            .edgesIgnoringSafeArea(.top) // Để Header tự xử lý padding top
        }
        .navigationBarHidden(true)
    }

    private func preprocessURL(_ url: URL) -> URL {
        let isInbox = url.path.contains("/Documents/Inbox/")
        guard isInbox else {
            return url
        }
        let fileNameNoExt = url.deletingPathExtension().lastPathComponent
        let fileNameComps = fileNameNoExt.components(separatedBy: CharacterSet(charactersIn: "._- "))
        guard let lastComp = fileNameComps.last, fileNameComps.count > 1, lastComp.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return url
        }
        let newURL = url.deletingLastPathComponent()
            .appendingPathComponent(String(fileNameNoExt.prefix(fileNameNoExt.count - lastComp.count - 1)))
            .appendingPathExtension(url.pathExtension)
        do {
            try? FileManager.default.removeItem(at: newURL)
            try FileManager.default.copyItem(at: url, to: newURL)
            return newURL
        } catch {
            return url
        }
    }
}

struct URLIdentifiable: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
