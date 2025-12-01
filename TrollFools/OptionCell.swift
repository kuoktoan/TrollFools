//
//  OptionCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import SwiftUI

struct OptionCell: View {
    let option: Option
    let detachCount: Int

    var body: some View {
        HStack {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Text
            Text(titleText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Số lượng plugin (nếu là nút xóa)
            if option == .detach && detachCount > 0 {
                Text("\(detachCount)")
                    .font(.caption.bold())
                    .foregroundColor(Color.red)
                    .padding(6)
                    .background(Circle().fill(Color.white))
            }
        }
        .padding()
        .frame(height: 80) // Chiều cao nút
        .background(
            // MÀU GRADIENT TUYỆT ĐẸP
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: shadowColor.opacity(0.4), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Logic chọn màu sắc và icon
    var isInject: Bool { option == .attach }
    
    var iconName: String {
        if #available(iOS 16, *) {
            return isInject ? "syringe.fill" : "trash.fill"
        } else {
            return isInject ? "arrow.down.circle.fill" : "trash.fill"
        }
    }
    
    var titleText: String {
        return isInject ? "Inject" : "Eject"
    }
    
    var gradientColors: [Color] {
        if isInject {
            // Màu xanh ngọc -> Xanh dương (Cho nút Inject)
            return [Color(hex: "00b09b"), Color(hex: "96c93d")]
        } else {
            // Màu Cam -> Đỏ (Cho nút Eject)
            return [Color(hex: "ff512f"), Color(hex: "dd2476")]
        }
    }
    
    var shadowColor: Color {
        return isInject ? .green : .red
    }
}

// Extension nhỏ để dùng mã màu Hex cho đẹp
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
