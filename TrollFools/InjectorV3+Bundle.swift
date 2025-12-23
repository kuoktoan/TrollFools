//
//  InjectorV3+Bundle.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation
import OrderedCollections

extension InjectorV3 {
    // MARK: - Constants

    static let ignoredDylibAndFrameworkNames: Set<String> = [
        "cydiasubstrate", "cydiasubstrate.framework", "ellekit", "ellekit.framework",
        "libsubstrate.dylib", "libsubstitute.dylib", "libellekit.dylib",
    ]

    static let substrateName = "CydiaSubstrate"
    static let substrateFwkName = "CydiaSubstrate.framework"

    fileprivate static let infoPlistName = "Info.plist"
    fileprivate static let injectedMarkerName = ".troll-fools"

    // MARK: - Instance Methods

    var hasInjectedAsset: Bool {
        // Kiểm tra xem có file dylib, marker HOẶC file mod game hay không
        !injectedAssetURLsInBundle(bundleURL).isEmpty || isLibWebpReplaced || isCrossfirePatched
    }

    // ... (Giữ nguyên các hàm frameworkMachOsInBundle, injectedAssetURLsInBundle, markBundlesAsInjected...)

    // MARK: - Check Status Methods

    func checkIsInjectedAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }

        // 1. Kiểm tra cách cũ (file .troll-fools)
        if checkIsInjectedBundle(target) { return true }
        
        // 2. Kiểm tra thủ công file backup của 2 game
        let frameworksURL = target.appendingPathComponent("Frameworks")

        // Check PUBG
        let webpBackup = frameworksURL.appendingPathComponent("libwebp.framework/libwebp.original")
        if FileManager.default.fileExists(atPath: webpBackup.path) { return true }
        
        // Check Crossfire
        let cfBackup = frameworksURL.appendingPathComponent("PixVideo.framework/PixVideo.original")
        if FileManager.default.fileExists(atPath: cfBackup.path) { return true }
        
        return false
    }

    func checkIsInjectedBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        let markerURL = target.appendingPathComponent(Self.injectedMarkerName)
        return FileManager.default.fileExists(atPath: markerURL.path)
    }

    // ... (Giữ nguyên các hàm checkIsBundle, checkIsDirectory...)
    
    // Hàm phụ trợ (giữ nguyên để không lỗi file khác)
    func checkIsEligibleAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        let frameworksURL = target.appendingPathComponent("Frameworks")
        return !((try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil).isEmpty) ?? true)
    }
    
    // ... (Các hàm hỗ trợ Bundle, locateExecutableInBundle... giữ nguyên từ bản gốc)
}
