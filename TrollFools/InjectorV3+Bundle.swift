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

    func markBundlesAsInjected(_ bundles: [URL], privileged: Bool = false) throws {
        for bundle in bundles {
            guard checkIsBundle(bundle) else { continue }
            let markerURL = bundle.appendingPathComponent(Self.injectedMarkerName)
            if !FileManager.default.fileExists(atPath: markerURL.path) {
                if privileged {
                    try cmdRun(args: ["touch", markerURL.path])
                } else {
                    FileManager.default.createFile(atPath: markerURL.path, contents: nil)
                }
            }
        }
    }

    // MARK: - Check Status Methods

    func checkIsInjectedAppBundle(_ target: URL) -> Bool {
        guard checkIsBundle(target) else { return false }
        if checkIsInjectedBundle(target) { return true }
        
        // Kiểm tra thủ công file backup của 2 game
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

    // --- CÁC HÀM LOCATE MÀ INJECTORV3.INIT() ĐANG GỌI ---
    
    // (Định nghĩa hàm này ở ngoài class, nhưng trong file này để tiện)
    // Hoặc đưa vào extension InjectorV3

    // Đưa vào extension InjectorV3 cho đúng chuẩn swift
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
    
    // Wrapper instance method
    func locateExecutableInBundle(_ bundleURL: URL) throws -> URL {
        return try Self.locateExecutableInBundle(bundleURL)
    }

    static func locateFrameworksDirectoryInBundle(_ bundleURL: URL) throws -> URL {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        // Chỉ check tồn tại, không check directory bằng hàm instance để tránh lỗi static
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: frameworksURL.path, isDirectory: &isDir) && isDir.boolValue else {
             throw Error.generic("Failed to locate Frameworks directory in bundle: \(bundleURL.lastPathComponent)")
        }
        return frameworksURL
    }
    
    // Wrapper instance method
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
    
    // Wrapper instance method
    func identifierOfBundle(_ bundleURL: URL) throws -> String {
        return try Self.identifierOfBundle(bundleURL)
    }

    func loadCommandNameOfAsset(_ assetURL: URL) throws -> String {
        return "@rpath/\(assetURL.lastPathComponent)"
    }
}
