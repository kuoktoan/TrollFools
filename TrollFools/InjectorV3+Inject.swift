//
//  InjectorV3+Inject.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation

extension InjectorV3 {
    
    // --- KIỂM TRA TRẠNG THÁI GAME ---
    
    // Check PUBG (LibWebp)
    var isLibWebpReplaced: Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let webpFwkURL = frameworksURL.appendingPathComponent("libwebp.framework")
        let backupURL = webpFwkURL.appendingPathComponent("libwebp.original")
        return FileManager.default.fileExists(atPath: backupURL.path)
    }
    
    // Check Crossfire (PixVideo)
    var isCrossfirePatched: Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let backupURL = frameworksURL
            .appendingPathComponent("PixVideo.framework")
            .appendingPathComponent("PixVideo.original")
        return FileManager.default.fileExists(atPath: backupURL.path)
    }

    // --- HÀM CHUNG: THAY THẾ BINARY ---
    
    func replaceBinary(frameworkName: String, binaryName: String, with newFileURL: URL) throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let fwkURL = frameworksURL.appendingPathComponent(frameworkName)
        let targetBinaryURL = fwkURL.appendingPathComponent(binaryName)
        let backupURL = fwkURL.appendingPathComponent(binaryName + ".original")

        // 1. Kiểm tra folder framework có tồn tại không
        guard FileManager.default.fileExists(atPath: fwkURL.path) else {
            print("Warning: Không tìm thấy \(frameworkName)")
            return
        }

        // 2. Backup file gốc (chỉ backup 1 lần)
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
                try cmdMove(from: targetBinaryURL, to: backupURL)
            }
        }

        // 3. Xóa file hiện tại (file gốc hoặc file mod cũ)
        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }

        // 4. Copy file mới vào
        try cmdCopy(from: newFileURL, to: targetBinaryURL, clone: true, overwrite: true)

        // 5. Bypass CoreTrust & Ký giả (QUAN TRỌNG ĐỂ KHÔNG CRASH)
        try cmdCoreTrustBypass(targetBinaryURL, teamID: teamID)

        // 6. Cấp quyền
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
        //try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
    }

    // --- HÀM CHUNG: KHÔI PHỤC BINARY ---
    
    func restoreBinary(frameworkName: String, binaryName: String) throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let fwkURL = frameworksURL.appendingPathComponent(frameworkName)
        let targetBinaryURL = fwkURL.appendingPathComponent(binaryName)
        let backupURL = fwkURL.appendingPathComponent(binaryName + ".original")

        // Chỉ khôi phục nếu có file backup
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }

        // Xóa file mod
        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }

        // Đổi tên file backup về như cũ
        try cmdMove(from: backupURL, to: targetBinaryURL)
        
        // Cấp lại quyền
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
        //try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
    }

    // --- CÁC HÀM GỌI CỤ THỂ CHO TỪNG GAME ---
    
    // PUBG
    func replaceLibWebp(with newFileURL: URL) throws {
        try replaceBinary(frameworkName: "libwebp.framework", binaryName: "libwebp", with: newFileURL)
        //try cmdRun(args: ["touch", bundleURL.path]) // Làm mới cache
    }
    
    func restoreLibWebp() throws {
        try restoreBinary(frameworkName: "libwebp.framework", binaryName: "libwebp")
        //try cmdRun(args: ["touch", bundleURL.path])
    }
    
    // Crossfire
    func replaceCrossfireFiles(with newFileURL: URL) throws {
        try replaceBinary(frameworkName: "PixVideo.framework", binaryName: "PixVideo", with: newFileURL)
        //try cmdRun(args: ["touch", bundleURL.path])
    }

    func restoreCrossfireFiles() throws {
        try restoreBinary(frameworkName: "PixVideo.framework", binaryName: "PixVideo")
        //try cmdRun(args: ["touch", bundleURL.path])
    }

    // --- HÀM CHẠY LỆNH SHELL (ĐÃ FIX LỖI EXIT STATUS) ---
    
    fileprivate func cmdRun(args: [String]) throws {
        let retCode = try Execute.rootSpawn(
            binary: "/usr/bin/env",
            arguments: args,
            ddlog: logger
        )

        // Kiểm tra kết quả trả về
        switch retCode {
        case let .exit(code):
            // Code 0 là thành công -> thoát hàm
            if code == 0 { return }
            
            // Code khác 0 -> báo lỗi
            throw Error.generic("Command '\(args.first ?? "cmd")' failed with exit code \(code)")
            
        case let .uncaughtSignal(signal):
            throw Error.generic("Command '\(args.first ?? "cmd")' terminated with signal \(signal)")
        }
    }
}
