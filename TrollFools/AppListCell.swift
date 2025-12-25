//
//  AppListCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/7/19.
//

import SwiftUI

struct AppListCell: View {
    let app: App
    @EnvironmentObject var appList: AppListModel

    // --- LOGIC KIỂM TRA TRẠNG THÁI CHÍNH XÁC ---
    var isInjected: Bool {
        // 1. Tạo Injector instance
        guard let injector = try? InjectorV3(app.url) else { return false }

        // 2. Kiểm tra riêng cho Crossfire
        if app.bid == "com.vnggames.cfl.crossfirelegends" {
            // Check xem file gốc đã được backup chưa (nếu có backup tức là đang dùng file mod)
            return injector.isCrossfirePatched
        }

        // 3. Kiểm tra riêng cho PUBG (Tất cả các phiên bản)
        if AppListModel.pubgIds.contains(app.bid) {
            // Check xem libwebp gốc đã được backup chưa
            return injector.isLibWebpReplaced
        }

        // 4. Fallback cho các app khác (nếu có)
        return injector.hasInjectedAsset
    }
    // ---------------------------------------------

    var body: some View {
        HStack(spacing: 16) {
            // 1. ICON APP
            if let icon = UIImage._applicationIconImage(forBundleIdentifier: app.bid, format: 0, scale: UIScreen.main.scale) {
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
                // 2. TÊN APP
                Text(app.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 3. BADGES
                HStack(spacing: 8) {
                    // Badge Version
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
                    
                    // Badge ACTIVE (Chỉ hiện khi isInjected = true)
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
    }
}
