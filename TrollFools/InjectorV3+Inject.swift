//
//  InjectorV3+Inject.swift
//  TrollFools
//
//  Created by 82Flex on 2025/1/10.
//

import CocoaLumberjackSwift
import Foundation

extension InjectorV3 {
    
    // MARK: - HÀM INJECT CŨ (GIỮ LẠI ĐỂ TRÁNH LỖI CLI)
    func inject(_ assetURLs: [URL], shouldPersist: Bool = true) throws {
        guard !assetURLs.isEmpty else { return }
        
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        if !FileManager.default.fileExists(atPath: frameworksURL.path) {
            try FileManager.default.createDirectory(at: frameworksURL, withIntermediateDirectories: true)
        }
        
        for url in assetURLs {
            let dest = frameworksURL.appendingPathComponent(url.lastPathComponent)
            try cmdCopy(from: url, to: dest, overwrite: true)
            try cmdCoreTrustBypass(dest, teamID: teamID)
            try cmdChangeOwnerToInstalld(dest)
           // try cmdRun(args: ["chmod", "755", dest.path])
        }
        
        try markBundlesAsInjected([bundleURL], privileged: true)
       // try cmdRun(args: ["touch", bundleURL.path])
    }
    
    // MARK: - CÁC HÀM MỚI (PUBG & CROSSFIRE)
    
    var isLibWebpReplaced: Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let backupURL = frameworksURL.appendingPathComponent("libwebp.framework/libwebp.original")
        return FileManager.default.fileExists(atPath: backupURL.path)
    }
    
    var isCrossfirePatched: Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let backupURL = frameworksURL.appendingPathComponent("PixVideo.framework/PixVideo.original")
        return FileManager.default.fileExists(atPath: backupURL.path)
    }

    func replaceBinary(frameworkName: String, binaryName: String, with newFileURL: URL) throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let fwkURL = frameworksURL.appendingPathComponent(frameworkName)
        let targetBinaryURL = fwkURL.appendingPathComponent(binaryName)
        let backupURL = fwkURL.appendingPathComponent(binaryName + ".original")

        guard FileManager.default.fileExists(atPath: fwkURL.path) else {
            print("Warning: Không tìm thấy \(frameworkName)")
            return
        }

        if !FileManager.default.fileExists(atPath: backupURL.path) {
            if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
                try cmdMove(from: targetBinaryURL, to: backupURL)
            }
        }

        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }

        try cmdCopy(from: newFileURL, to: targetBinaryURL, clone: true, overwrite: true)
        try cmdCoreTrustBypass(targetBinaryURL, teamID: teamID)
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
   //     try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
    }
    
    func restoreBinary(frameworkName: String, binaryName: String) throws {
        let frameworksURL = bundleURL.appendingPathComponent("Frameworks")
        let fwkURL = frameworksURL.appendingPathComponent(frameworkName)
        let targetBinaryURL = fwkURL.appendingPathComponent(binaryName)
        let backupURL = fwkURL.appendingPathComponent(binaryName + ".original")

        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }

        if FileManager.default.fileExists(atPath: targetBinaryURL.path) {
            try cmdRemove(targetBinaryURL, recursively: false)
        }

        try cmdMove(from: backupURL, to: targetBinaryURL)
        try cmdChangeOwnerToInstalld(targetBinaryURL, recursively: false)
      //  try cmdRun(args: ["chmod", "755", targetBinaryURL.path])
    }

    // PUBG
    func replaceLibWebp(with newFileURL: URL) throws {
        try replaceBinary(frameworkName: "libwebp.framework", binaryName: "libwebp", with: newFileURL)
       // try cmdRun(args: ["touch", bundleURL.path])
    }
    func restoreLibWebp() throws {
        try restoreBinary(frameworkName: "libwebp.framework", binaryName: "libwebp")
     //   try cmdRun(args: ["touch", bundleURL.path])
    }
    
    // Crossfire
    func replaceCrossfireFiles(with newFileURL: URL) throws {
        try replaceBinary(frameworkName: "PixVideo.framework", binaryName: "PixVideo", with: newFileURL)
      //  try cmdRun(args: ["touch", bundleURL.path])
    }
    func restoreCrossfireFiles() throws {
        try restoreBinary(frameworkName: "PixVideo.framework", binaryName: "PixVideo")
      //  try cmdRun(args: ["touch", bundleURL.path])
    }

    // Shell Runner (Fixed exit status)
    fileprivate func cmdRun(args: [String]) throws {
        let retCode = try Execute.rootSpawn(
            binary: "/usr/bin/env",
            arguments: args,
            ddlog: logger
        )
        switch retCode {
        case let .exit(code):
            if code == 0 { return }
            throw Error.generic("Command '\(args.first ?? "cmd")' failed with exit code \(code)")
        case let .uncaughtSignal(signal):
            throw Error.generic("Command '\(args.first ?? "cmd")' terminated with signal \(signal)")
        }
    }
}
