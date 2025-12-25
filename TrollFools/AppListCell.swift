//
//  AppListCell.swift
//  TrollFools
//
//  Created by 82Flex on 2024/10/30.
//

import CocoaLumberjackSwift
import SwiftUI

struct AppListCell: View {
    @EnvironmentObject var appList: AppListModel

    @StateObject var app: App

    @available(iOS 15, *)
    var highlightedName: AttributedString {
        let name = app.name
        var attributedString = AttributedString(name)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

    @available(iOS 15, *)
    var highlightedId: AttributedString {
        let bid = app.bid
        var attributedString = AttributedString(bid)
        if let range = attributedString.range(of: appList.filter.searchKeyword, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributedString[range].foregroundColor = .accentColor
        }
        return attributedString
    }

var body: some View {
        HStack(spacing: 16) {
            // 1. ICON ỨNG DỤNG (Bo tròn đẹp hơn, thêm viền nhẹ)
            if #available(iOS 15, *) {
                Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50) // Tăng kích thước icon
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                Image(uiImage: app.alternateIcon ?? app.icon ?? UIImage())
                    .resizable()
                    .frame(width: 50, height: 50)
                    .cornerRadius(12)
            }

            // 2. TÊN VÀ TRẠNG THÁI
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded)) // Font chữ tròn trịa hiện đại
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Chỉ hiện trạng thái nếu đã Inject
                if app.isInjected || app.hasPersistedAssets {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        // ĐÃ SỬA: Dùng NSLocalizedString
                    // "Patched" thường được dịch là "Đã tiêm/Đã sửa"
                    // "Pending" thường được dịch là "Đang chờ/Chưa kích hoạt"
                    Text(app.isInjected 
                        ? NSLocalizedString("Active", comment: "") 
                        : NSLocalizedString("Active", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    Text(app.version ?? "Unknown Version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 3. MŨI TÊN CHỈ DẪN
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(12) // Khoảng cách nội dung bên trong thẻ
        .background(Color(UIColor.secondarySystemGroupedBackground)) // Màu nền thẻ
        .cornerRadius(16) // Bo góc thẻ
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4) // Đổ bóng nhẹ
        .padding(.vertical, 4) // Khoảng cách giữa các thẻ
    }

    @ViewBuilder
    var cellContextMenu: some View {
        Button {
            launch()
        } label: {
            Label(NSLocalizedString("Launch", comment: ""), systemImage: "command")
        }

        if AppListModel.hasTrollStore && app.isAllowedToAttachOrDetach {
            if app.isDetached {
                Button {
                    do {
                        try InjectorV3(app.url).setMetadataDetached(false)
                        app.reload()
                        appList.isRebuildNeeded = true
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Unlock Version", comment: ""), systemImage: "lock.open")
                }
            } else {
                Button {
                    do {
                        try InjectorV3(app.url).setMetadataDetached(true)
                        app.reload()
                        appList.isRebuildNeeded = true
                    } catch { DDLogError("\(error)", ddlog: InjectorV3.main.logger) }
                } label: {
                    Label(NSLocalizedString("Lock Version", comment: ""), systemImage: "lock")
                }
            }
        }

        Button {
            openInFilza()
        } label: {
            if isFilzaInstalled {
                Label(NSLocalizedString("Show in Filza", comment: ""), systemImage: "scope")
            } else {
                Label(NSLocalizedString("Filza (URL Scheme) Not Installed", comment: ""), systemImage: "xmark.octagon")
            }
        }
        .disabled(!isFilzaInstalled)
    }

    @ViewBuilder
    var cellContextMenuWrapper: some View {
        if #available(iOS 16, *) {
            // iOS 16
            cellContextMenu
        } else {
            if #available(iOS 15, *) { }
            else {
                // iOS 14
                cellContextMenu
            }
        }
    }

    @ViewBuilder
    var cellBackground: some View {
        if #available(iOS 15, *) {
            if #available(iOS 16, *) { }
            else {
                // iOS 15
                Color.clear
                    .contextMenu {
                        if !appList.isSelectorMode {
                            cellContextMenu
                        }
                    }
                    .id(app.isDetached)
            }
        }
    }

    private func launch() {
        LSApplicationWorkspace.default().openApplication(withBundleID: app.bid)
    }

    var isFilzaInstalled: Bool { appList.isFilzaInstalled }

    private func openInFilza() {
        appList.openInFilza(app.url)
    }
}
