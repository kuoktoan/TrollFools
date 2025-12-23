//
//  InjectorV3+Inject.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation

extension InjectorV3 {
    enum Strategy: String, CaseIterable {
        case lexicographic
        case fast
        case preorder
        case postorder

        var localizedDescription: String {
            switch self {
            case .lexicographic: NSLocalizedString("Lexicographic", comment: "")
            case .fast: NSLocalizedString("Fast", comment: "")
            case .preorder: NSLocalizedString("Pre-order", comment: "")
            case .postorder: NSLocalizedString("Post-order", comment: "")
            }
        }
    }

    // MARK: - Instance Methods

    func inject(_ assetURLs: [URL], shouldPersist: Bool) throws {
        let preparedAssetURLs = try preprocessAssets(assetURLs)

        precondition(!preparedAssetURLs.isEmpty, "No asset to inject.")
        terminateApp()

        try injectBundles(preparedAssetURLs
            .filter { $0.pathExtension.lowercased() == "bundle" })

        try injectDylibsAndFrameworks(preparedAssetURLs
            .filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "framework" })

        if shouldPersist {
            try persist(preparedAssetURLs)
        }
    }

    // MARK: - Private Methods

    fileprivate func injectBundles(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        for assetURL in assetURLs {
            let targetURL = bundleURL.appendingPathComponent(assetURL.lastPathComponent)

            try cmdCopy(from: assetURL, to: targetURL, clone: true, overwrite: true)
            try cmdChangeOwnerToInstalld(targetURL, recursively: true)
        }
    }

    fileprivate func injectDylibsAndFrameworks(_ assetURLs: [URL]) throws {
        guard !assetURLs.isEmpty else {
            return
        }

        try assetURLs.forEach {
            try standardizeLoadCommandDylibToSubstrate($0)
            try applyCoreTrustBypass($0)
        }

        // --- ĐÃ SỬA: Comment dòng này để không chuẩn bị CydiaSubstrate ---
        // let substrateFwkURL = try prepareSubstrate()
        // ----------------------------------------------------------------

        guard let targetMachO = try locateAvailableMachO() else {
            DDLogError("All Mach-Os are protected", ddlog: logger)

            throw Error.generic(NSLocalizedString("No eligible framework found.\n\nIt is usually not a bug with TrollFools itself, but rather with the target app. You may re-install that from App Store. You can’t use TrollFools with apps installed via “Asspp” or tweaks like “NoAppThinning”.", comment: ""))
        }

        DDLogInfo("Best matched Mach-O is \(targetMachO.path)", ddlog: logger)

        // --- ĐÃ SỬA: Chỉ copy assetURLs (file mod), không kèm substrateFwkURL nữa ---
        // CŨ: let resourceURLs: [URL] = [substrateFwkURL] + assetURLs
        let resourceURLs: [URL] = assetURLs
        // ----------------------------------------------------------------------------

        try makeAlternate(targetMachO)
        do {
            try copyfiles(resourceURLs)
            for assetURL in assetURLs {
                try insertLoadCommandOfAsset(assetURL, to: targetMachO)
            }
            try applyCoreTrustBypass(targetMachO)
        } catch {
            try? restoreAlternate(targetMachO)
            try? batchRemove(resourceURLs)
            throw error
        }
    }

    // MARK: - Core Trust

    fileprivate func applyCoreTrustBypass(_ target: URL) throws {
        let isFramework = checkIsBundle(target)

        let machO: URL
        if isFramework {
            machO = try locateExecutableInBundle(target)
        } else {
            machO = target
        }

        try cmdCoreTrustBypass(machO, teamID: teamID)
        try cmdChangeOwnerToInstalld(target, recursively: isFramework)
    }

    // MARK: - Cydia Substrate

    fileprivate static let substrateZipURL = findResource(substrateFwkName, fileExtension: "zip")

    fileprivate func prepareSubstrate() throws -> URL {
        try FileManager.default.unzipItem(at: Self.substrateZipURL, to: temporaryDirectoryURL)

        let fwkURL = temporaryDirectoryURL.appendingPathComponent(Self.substrateFwkName)
        try markBundlesAsInjected([fwkURL], privileged: false)

        let machO = fwkURL.appendingPathComponent(Self.substrateName)

        try cmdCoreTrustBypass(machO, teamID: teamID)
        try cmdChangeOwnerToInstalld(fwkURL, recursively: true)

        return fwkURL
    }

    fileprivate func standardizeLoadCommandDylibToSubstrate(_ assetURL: URL) throws {
        let machO: URL
        if checkIsBundle(assetURL) {
            machO = try locateExecutableInBundle(assetURL)
        } else {
            machO = assetURL
        }

        let dylibs = try loadedDylibsOfMachO(machO)
        for dylib in dylibs {
            if Self.ignoredDylibAndFrameworkNames.firstIndex(where: { dylib.lowercased().hasSuffix("/\($0)") }) != nil {
                try cmdChangeLoadCommandDylib(machO, from: dylib, to: "@executable_path/Frameworks/\(Self.substrateFwkName)/\(Self.substrateName)")
            }
        }
    }

    // MARK: - Load Commands

    func loadCommandNameOfAsset(_ assetURL: URL) throws -> String {
        var name = "@rpath/"

        if checkIsBundle(assetURL) {
            precondition(assetURL.pathExtension == "framework", "Invalid framework: \(assetURL.path)")
            let machO = try locateExecutableInBundle(assetURL)
            name += machO.pathComponents.suffix(2).joined(separator: "/") // @rpath/XXX.framework/XXX
            precondition(name.contains(".framework/"), "Invalid framework name: \(name)")
        } else {
            precondition(assetURL.pathExtension == "dylib", "Invalid dylib: \(assetURL.path)")
            name += assetURL.lastPathComponent
            precondition(name.hasSuffix(".dylib"), "Invalid dylib name: \(name)") // @rpath/XXX.dylib
        }

        return name
    }

    fileprivate func insertLoadCommandOfAsset(_ assetURL: URL, to target: URL) throws {
        let name = try loadCommandNameOfAsset(assetURL)

        try cmdInsertLoadCommandRuntimePath(target, name: "@executable_path/Frameworks")
        try cmdInsertLoadCommandDylib(target, name: name, weak: useWeakReference)
        try standardizeLoadCommandDylib(target, to: name)
    }

    fileprivate func standardizeLoadCommandDylib(_ target: URL, to name: String) throws {
        precondition(name.hasPrefix("@rpath/"), "Invalid dylib name: \(name)")

        let itemName = String(name[name.index(name.startIndex, offsetBy: 7)...])
        let dylibs = try loadedDylibsOfMachO(target)

        for dylib in dylibs {
            if dylib.hasSuffix("/" + itemName) {
                try cmdChangeLoadCommandDylib(target, from: dylib, to: name)
            }
        }
    }

    // MARK: - Path Clone

    fileprivate func copyfiles(_ assetURLs: [URL]) throws {
        let targetURLs = assetURLs.map {
            frameworksDirectoryURL.appendingPathComponent($0.lastPathComponent)
        }

        for (assetURL, targetURL) in zip(assetURLs, targetURLs) {
            try cmdCopy(from: assetURL, to: targetURL, clone: true, overwrite: true)
            try cmdChangeOwnerToInstalld(targetURL, recursively: checkIsDirectory(assetURL))
        }
    }

    fileprivate func batchRemove(_ assetURLs: [URL]) throws {
        try assetURLs.forEach {
            try cmdRemove($0, recursively: checkIsDirectory($0))
        }
    }

    // MARK: - Path Finder

    fileprivate func locateAvailableMachO() throws -> URL? {
        try frameworkMachOsInBundle(bundleURL)
            .first { try !isProtectedMachO($0) }
    }

    fileprivate static func findResource(_ name: String, fileExtension: String) -> URL {
        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        if let firstArg = ProcessInfo.processInfo.arguments.first {
            let execURL = URL(fileURLWithPath: firstArg)
                .deletingLastPathComponent()
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)
            if FileManager.default.isReadableFile(atPath: execURL.path) {
                return execURL
            }
        }
        if let tfProxy = LSApplicationProxy(forIdentifier: Constants.gAppIdentifier),
           let tfBundleURL = tfProxy.bundleURL()
        {
            let execURL = tfBundleURL
                .appendingPathComponent(name)
                .appendingPathExtension(fileExtension)
            if FileManager.default.isReadableFile(atPath: execURL.path) {
                return execURL
            }
        }
        fatalError("Unable to locate resource \(name)")
    }

    // Tên file gốc và file backup
    static let libWebpBinaryName = "libwebp"
    static let libWebpBackupName = "libwebp.original" // File backup sẽ tên là này

    // Kiểm tra xem đã thay thế (đã inject) chưa bằng cách tìm file backup
    var isLibWebpReplaced: Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let webpFwkURL = frameworksURL.appendingPathComponent("libwebp.framework")
        let backupURL = webpFwkURL.appendingPathComponent(Self.libWebpBackupName)
        return FileManager.default.fileExists(atPath: backupURL.path)
    }

    // Hàm thực hiện thay thế (Inject)
    func replaceLibWebp(with newFileURL: URL) throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let webpFwkURL = frameworksURL.appendingPathComponent("libwebp.framework")
        let targetBinaryURL = webpFwkURL.appendingPathComponent(Self.libWebpBinaryName)
        let backupURL = webpFwkURL.appendingPathComponent(Self.libWebpBackupName)

        // 1. Kiểm tra folder Framework có tồn tại không
        guard FileManager.default.fileExists(atPath: webpFwkURL.path) else {
            throw Error.generic("App này không có libwebp.framework!")
        }

        // 2. Backup file gốc (Nếu chưa backup)
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            // Đổi tên file gốc thành file .original
            try cmdMove(from: targetBinaryURL, to: backupURL)
        }

        // 3. Copy file mới vào đè lên vị trí file gốc
        // Trước tiên xóa file gốc (hoặc file mod cũ) nếu còn tồn tại
        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }
        
        try cmdCopy(from: newFileURL, to: targetBinaryURL, clone: true, overwrite: true)

        // 4. Cấp quyền quan trọng (Chown/Chmod) để App không bị Crash
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
        try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
        
        // Đánh dấu folder là đã thay đổi (để cập nhật icon cache nếu cần)
        try cmdRun(args: ["touch", bundleURL.path])
    }

    // Hàm khôi phục (Eject)
    func restoreLibWebp() throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let webpFwkURL = frameworksURL.appendingPathComponent("libwebp.framework")
        let targetBinaryURL = webpFwkURL.appendingPathComponent(Self.libWebpBinaryName)
        let backupURL = webpFwkURL.appendingPathComponent(Self.libWebpBackupName)

        // Chỉ khôi phục nếu file backup tồn tại
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return 
        }

        // 1. Xóa file mod đang chạy
        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }

        // 2. Đổi tên file backup về lại tên gốc
        try cmdMove(from: backupURL, to: targetBinaryURL)

        // 3. Cấp lại quyền cho chắc chắn
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
        try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
        
        // Đánh dấu folder
        try cmdRun(args: ["touch", bundleURL.path])
    }

    // --- BẮT ĐẦU ĐOẠN CODE BỔ SUNG ---
    
    /// Hàm thực thi lệnh Shell (cmdRun) bị thiếu
    fileprivate func cmdRun(args: [String]) throws {
        let receipt = AuxiliaryExecute.spawn(command: "/usr/bin/env", args: args)
        
        // --- SỬA Ở ĐÂY: Dùng .exitStatus thay vì .exitCode ---
        if receipt.exitStatus != 0 {
            throw Error.generic("Command failed: \(args.joined(separator: " "))\nOutput: \(receipt.stderr)")
        }
    }

    // --- KẾT THÚC ĐOẠN CODE BỔ SUNG ---
}
