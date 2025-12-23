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
        // Kiểm tra marker hoặc file mod của PUBG/Crossfire
        !injectedAssetURLsInBundle(bundleURL).isEmpty || isLibWebpReplaced || isCrossfirePatched
    }

    func frameworkMachOsInBundle(_ target: URL) throws -> [URL] {
        guard checkIsBundle(target) else { return [] }

        let frameworksURL = target.appendingPathComponent("Frameworks")
        guard checkIsDirectory(frameworksURL) else { return [] }

        let frameworks = try FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil)
            .filter { checkIsBundle($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var machOs: [URL] = []
        for framework in frameworks {
            if let machO = try? locateExecutableInBundle(framework) {
                machOs.append(machO)
            }
        }
        return machOs
    }

    func injectedAssetURLsInBundle(_ target: URL) -> [URL] {
        guard checkIsBundle(target) else { return [] }

        let frameworksURL = target.appendingPathComponent("Frameworks")
        guard checkIsDirectory(frameworksURL) else { return [] }

        guard let contents = try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil) else {
            return []
        }

        return contents
            .filter { url in
                let ext = url.pathExtension.lowercased()
                let name = url.lastPathComponent.lowercased()
                let isValidType = ext == "dylib" || ext == "deb" || ext == "bundle" || ext == "framework"
                let isNotIgnored = !Self.ignoredDylibAndFrameworkNames.contains(name)
                return isValidType && isNotIgnored
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // --- MARK: - METHOD GỐC CỦA BẠN (Đã đưa vào đây) ---
    func markBundlesAsInjected(_ bundleURLs: [URL], privileged: Bool) throws {
        let filteredURLs = bundleURLs.filter { checkIsBundle($0) }
        
        // Đoạn này logic gốc là precondition, giữ nguyên
        // precondition(filteredURLs.count == bundleURLs.count, "Not all urls are bundles")

        if privileged {
            let markerURL = temporaryDirectoryURL.appendingPathComponent(Self.injectedMarkerName)
            try Data().write(to: markerURL, options: .atomic)
            
            // Gọi hàm từ InjectorV3+Command.swift (File này phải tồn tại và hàm không được private)
            try cmdChangeOwnerToInstalld(markerURL, recursively: false)

            try filteredURLs.forEach {
                try cmdCopy(
                    from: markerURL,
                    to: $0.appendingPathComponent(Self.injectedMarkerName),
                    clone: true,
                    overwrite: true
                )
            }
        } else {
            try filteredURLs.forEach {
                try Data().write(to: $0.appendingPathComponent(Self.injectedMarkerName), options: .atomic)
            }
        }
    }
    // ----------------------------------------------------

    // MARK: - Check Status Methods

    func checkIsInjectedAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        
        // 1. Check cách cũ
        if checkIsInjectedBundle(target) { return true }
        
        // 2. Check PUBG & Crossfire
        let frameworksURL = target.appendingPathComponent("Frameworks")
        let webpBackup = frameworksURL.appendingPathComponent("libwebp.framework/libwebp.original")
        if FileManager.default.fileExists(atPath: webpBackup.path) { return true }
        
        let cfBackup = frameworksURL.appendingPathComponent("PixVideo.framework/PixVideo.original")
        if FileManager.default.fileExists(atPath: cfBackup.path) { return true }
        
        return false
    }

    func checkIsInjectedBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        let markerURL = target.appendingPathComponent(Self.injectedMarkerName)
        return FileManager.default.fileExists(atPath: markerURL.path)
    }

    // MARK: - File System Helpers

    func checkIsBundle(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "app" || ext == "framework" || ext == "bundle" || ext == "xctest"
    }
    
    func checkIsDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    func checkIsEligibleAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        let frameworksURL = target.appendingPathComponent("Frameworks")
        return !((try? FileManager.default.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil).isEmpty) ?? true)
    }

    // Static Locators
    static func locateExecutableInBundle(_ bundleURL: URL) throws -> URL {
        let infoPlistURL = bundleURL.appendingPathComponent(Self.infoPlistName)
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
              let executableName = infoPlist["CFBundleExecutable"] as? String
        else {
            throw Error.generic("Failed to locate executable in bundle: \(bundleURL.lastPathComponent)")
        }
        return bundleURL.appendingPathComponent(executableName)
    }
    
    func locateExecutableInBundle(_ bundleURL: URL) throws -> URL {
        return try Self.locateExecutableInBundle(bundleURL)
    }

    static func locateFrameworksDirectoryInBundle(_ bundleURL: URL) throws -> URL {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: frameworksURL.path, isDirectory: &isDir) && isDir.boolValue else {
             throw Error.generic("Failed to locate Frameworks directory in bundle: \(bundleURL.lastPathComponent)")
        }
        return frameworksURL
    }
    
    func locateFrameworksDirectoryInBundle(_ bundleURL: URL) throws -> URL {
        return try Self.locateFrameworksDirectoryInBundle(bundleURL)
    }

    static func identifierOfBundle(_ bundleURL: URL) throws -> String {
        let infoPlistURL = bundleURL.appendingPathComponent(Self.infoPlistName)
        guard let infoPlistData = try? Data(contentsOf: infoPlistURL),
              let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
              let identifier = infoPlist["CFBundleIdentifier"] as? String
        else {
            throw Error.generic("Failed to retrieve identifier of bundle: \(bundleURL.lastPathComponent)")
        }
        return identifier
    }
    
    func identifierOfBundle(_ bundleURL: URL) throws -> String {
        return try Self.identifierOfBundle(bundleURL)
    }

    func loadCommandNameOfAsset(_ assetURL: URL) throws -> String {
        return "@rpath/\(assetURL.lastPathComponent)"
    }
}
