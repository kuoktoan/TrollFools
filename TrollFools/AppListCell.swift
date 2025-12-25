import SwiftUI

struct AppListCell: View {
    let app: App
    @EnvironmentObject var appList: AppListModel

    var body: some View {
        HStack(spacing: 16) {
            // 1. ICON APP (Hiệu ứng nổi 3D nhẹ)
            if let icon = UIImage._applicationIconImage(forBundleIdentifier: app.bid, format: 0, scale: UIScreen.main.scale) {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 4) // Bóng đổ icon
            } else {
                // Placeholder nếu không có icon
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 6) {
                // 2. TÊN APP
                Text(app.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded)) // Font bo tròn hiện đại
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 3. BADGES (Bundle ID & Version)
                HStack(spacing: 8) {
                    // Version Badge
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
                    
                    // Team/ID Text
                    Text(app.teamID.isEmpty ? "System" : app.teamID)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            Spacer()
            
            // 4. MŨI TÊN (Vòng tròn mờ)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(8)
                .background(Circle().fill(Color.gray.opacity(0.1)))
        }
        .padding(16)
        // 5. BACKGROUND THẺ BÀI
        .background(Color(UIColor.secondarySystemGroupedBackground)) // Màu nền tự động theo Dark/Light mode
        .cornerRadius(20) // Bo góc lớn
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4) // Đổ bóng toàn bộ thẻ
        .padding(.vertical, 6) // Khoảng cách giữa các thẻ
    }
}
