//
//  AppListCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/7/19.
//

import SwiftUI
import Combine

struct AppListCell: View {
    let app: App
    @EnvironmentObject var appList: AppListModel
    
    @State private var refreshID = UUID()

    var isInjected: Bool {
        guard let injector = try? InjectorV3(app.url) else { return false }

        if app.bid == "com.vnggames.cfl.crossfirelegends" {
            return injector.isCrossfirePatched
        }

        if AppListModel.pubgIds.contains(app.bid) {
            return injector.isLibWebpReplaced
        }

        return injector.hasInjectedAsset
    }

    var body: some View {
        HStack(spacing: 16) {
            // 1. ICON APP (SỬA LỖI MỜ ẢNH)
            // format: 12 là icon kích thước lớn nhất (High Res)
            if let icon = UIImage._applicationIconImage(forBundleIdentifier: app.bid, format: 12, scale: UIScreen.main.scale) {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 6) {
                // 2. TÊN APP (SỬA LỖI CẮT CHỮ)
                Text(app.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1) // Cho phép xuống dòng tối đa 2 dòng
                    //.minimumScaleFactor(0.8) // Nếu vẫn dài, tự động thu nhỏ chữ xuống 80%
                    //.fixedSize(horizontal: false, vertical: true) // Mở rộng chiều cao nếu cần

                // 3. BADGES
                HStack(spacing: 8) {
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Capsule())
                    }
                    
                    if isInjected {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green)
                            .clipShape(Capsule())
                            .shadow(color: Color.green.opacity(0.4), radius: 3, x: 0, y: 2)
                    }
                }
            }
            
            Spacer()
            
            // 4. MŨI TÊN
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(8)
                .background(Circle().fill(Color.gray.opacity(0.1)))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.vertical, 6)
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TrollFoolsDidUpdateApp"))) { _ in
            self.refreshID = UUID()
        }
    }
}
