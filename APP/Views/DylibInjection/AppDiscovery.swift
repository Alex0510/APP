import Foundation
// AppDiscovery.swift
// of pxx917144686
// 应用发现器，用于发现和管理已安装的应用

import UIKit

/// 应用发现器，用于发现和管理已安装的应用
class AppDiscovery {
    
    // MARK: - 数据结构
    struct AppInfo {
        let bundleId: String
        let name: String
        let version: String
        let executablePath: String
        let bundlePath: String
        let iconPath: String?
        let isSystemApp: Bool
        let isInstalled: Bool
        let canInject: Bool
        let injectionReason: String?
    }
    
    // MARK: - 单例
    static let shared = AppDiscovery()
    
    private init() {}
    
    // MARK: - 发现已安装的应用
    func discoverInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        
        // 使用LiveContainer技术发现已安装的应用
        // 通过扫描/Applications目录和用户应用目录
        let applicationPaths = [
            "/Applications",
            "/var/containers/Bundle/Application"
        ]
        
        for appPath in applicationPaths {
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: appPath)
                for item in contents {
                    let fullPath = "\(appPath)/\(item)"
                    if let appInfo = analyzeAppBundle(at: fullPath) {
                        apps.append(appInfo)
                    }
                }
            } catch {
                print("无法访问目录 \(appPath): \(error)")
            }
        }
        
        return apps
    }
    
    // MARK: - 分析应用Bundle
    private func analyzeAppBundle(at path: String) -> AppInfo? {
        // 检查是否为.app目录
        guard path.hasSuffix(".app") else { return nil }
        
        // 读取Info.plist
        let infoPlistPath = "\(path)/Info.plist"
        guard let infoDict = NSDictionary(contentsOfFile: infoPlistPath) else { return nil }
        
        guard let bundleId = infoDict["CFBundleIdentifier"] as? String,
              let name = infoDict["CFBundleDisplayName"] as? String ?? infoDict["CFBundleName"] as? String,
              let version = infoDict["CFBundleShortVersionString"] as? String else {
            return nil
        }
        
        // 查找可执行文件
        let executableName = infoDict["CFBundleExecutable"] as? String ?? name
        let executablePath = "\(path)/\(executableName)"
        
        // 检查是否为系统应用
        let isSystemApp = path.hasPrefix("/Applications") && !path.contains("var/containers")
        
        return AppInfo(
            bundleId: bundleId,
            name: name,
            version: version,
            executablePath: executablePath,
            bundlePath: path,
            iconPath: "\(path)/AppIcon60x60@2x.png",
            isSystemApp: isSystemApp,
            isInstalled: true,
            canInject: canInjectIntoApp(bundleId: bundleId),
            injectionReason: getInjectionReason(bundleId: bundleId)
        )
    }
    
    // MARK: - 检查应用是否已安装
    private func checkIfAppIsInstalled(bundleId: String) -> Bool {
        // 尝试打开应用来检查是否已安装
        if let url = URL(string: "\(bundleId)://") {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }
    
    // MARK: - 检查是否可以注入
    private func canInjectIntoApp(bundleId: String) -> Bool {
        // 系统应用通常不能注入
        if isSystemApp(bundleId: bundleId) {
            return false
        }
        
        // 检查应用是否支持注入
        // 这里可以添加更多的检查逻辑
        return true
    }
    
    // MARK: - 获取注入原因
    private func getInjectionReason(bundleId: String) -> String? {
        if isSystemApp(bundleId: bundleId) {
            return "系统应用不支持注入"
        }
        
        if !checkIfAppIsInstalled(bundleId: bundleId) {
            return "应用未安装"
        }
        
        return nil
    }
    
    // MARK: - 检查是否为系统应用
    private func isSystemApp(bundleId: String) -> Bool {
        let systemAppPrefixes = [
            "com.apple.",
            "com.apple.system.",
            "com.apple.springboard",
            "com.apple.mobile.",
            "com.apple.UIKit"
        ]
        
        return systemAppPrefixes.contains { bundleId.hasPrefix($0) }
    }
    
    
    // MARK: - 搜索应用
    func searchApps(query: String) -> [AppInfo] {
        let allApps = discoverInstalledApps()
        
        if query.isEmpty {
            return allApps
        }
        
        return allApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.bundleId.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - 按类别获取应用
    func getAppsByCategory(_ category: AppCategory) -> [AppInfo] {
        let allApps = discoverInstalledApps()
        
        switch category {
        case .social:
            return allApps.filter { app in
                ["微信", "QQ", "抖音", "快手", "微博", "小红书"].contains(app.name)
            }
        case .shopping:
            return allApps.filter { app in
                ["淘宝", "支付宝", "京东", "拼多多", "美团"].contains(app.name)
            }
        case .entertainment:
            return allApps.filter { app in
                ["网易云音乐", "QQ音乐", "酷狗音乐", "爱奇艺", "腾讯视频"].contains(app.name)
            }
        case .games:
            return allApps.filter { app in
                ["王者荣耀", "和平精英", "原神", "崩坏", "阴阳师"].contains(app.name)
            }
        case .tools:
            return allApps.filter { app in
                ["Safari", "邮件", "日历", "备忘录", "计算器"].contains(app.name)
            }
        case .all:
            return allApps
        }
    }
    
    // MARK: - 获取应用详细信息
    func getAppDetails(bundleId: String) -> AppInfo? {
        let apps = discoverInstalledApps()
        return apps.first { $0.bundleId == bundleId }
    }
    
    // MARK: - 验证应用可执行文件
    func validateAppExecutable(bundleId: String) -> (isValid: Bool, error: String?) {
        guard let appInfo = getAppDetails(bundleId: bundleId) else {
            return (false, "应用不存在")
        }
        
        let fileManager = FileManager.default
        
        // 检查可执行文件是否存在
        guard fileManager.fileExists(atPath: appInfo.executablePath) else {
            return (false, "可执行文件不存在")
        }
        
        // 检查文件权限
        guard fileManager.isReadableFile(atPath: appInfo.executablePath) else {
            return (false, "可执行文件不可读")
        }
        
        // 使用MachOAnalyzer验证文件
        let result = MachOAnalyzer.canInjectIntoMachO(at: appInfo.executablePath)
        return (result.canInject, result.reason)
    }
}

// MARK: - 应用分类
enum AppCategory: String, CaseIterable {
    case all = "全部"
    case social = "社交"
    case shopping = "购物"
    case entertainment = "娱乐"
    case games = "游戏"
    case tools = "工具"
    
    var icon: String {
        switch self {
        case .all:
            return "apps.iphone"
        case .social:
            return "person.2"
        case .shopping:
            return "cart"
        case .entertainment:
            return "music.note"
        case .games:
            return "gamecontroller"
        case .tools:
            return "wrench.and.screwdriver"
        }
    }
}
