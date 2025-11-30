//
//  FailureView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct FailureView: View {

    let title: String
    let error: Error?

    // ĐÃ XÓA: Biến logFileURL và isLogsPresented không còn cần thiết nữa

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text(title)
                .font(.title)
                .bold()

            if let error {
                Text(error.localizedDescription)
                    .font(.title3)
            }

            // ĐÃ XÓA: Nút "View Logs" đã được loại bỏ khỏi đây
        }
        .padding()
        .multilineTextAlignment(.center)
        // ĐÃ XÓA: Phần .sheet để hiển thị logs cũng đã được loại bỏ
    }
}

#Preview {
    FailureView(
        title: "Hello, World!",
        error: nil
    )
}
