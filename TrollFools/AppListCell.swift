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

    // Kiểm tra nhanh xem App này đã được Inject chưa
    var isVerified: Bool {
        // Lưu ý: Việc khởi tạo InjectorV3 ở đây có thể tốn chút tài nguyên, 
        // nhưng với danh sách ngắn thì không sao.
        return (try? InjectorV3(app.url))?.hasInjectedAsset ?? false
    }

    var body: some View {
        HStack(spacing: 16) {
            // 1. ICON APP (Đổ bóng đẹp hơn)
            if let icon = UIImage._applicationIconImage(forBundleIdentifier: app.bid, format: 0, scale: UIScreen.main.scale) {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    // Viền mỏng
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
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

                // 3. INFO BADGES
                HStack(spacing: 6) {
                    // Badge Version
                    if let version = app.version {
                        Text("v\(version)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    
                    // Badge ACTIVE (Chỉ hiện khi đã Inject)
                    if isVerified {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                            Text("ACTIVE")
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green) // Nền xanh lá
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.4), radius: 2, x: 0, y: 1)
                    }
                }
            }
            
            Spacer()
            
            // 4. MŨI TÊN
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.gray.opacity(0.4))
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(18)
        // Hiệu ứng nổi nhẹ
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.vertical, 6)
    }
}
