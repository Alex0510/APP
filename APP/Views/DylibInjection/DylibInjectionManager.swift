// DylibInjectionManager.swift
// of pxx917144686
// 动态库注入管理类

import Foundation
import UIKit
import MachO

class DylibInjectionManager: ObservableObject {
    @Published var injectionStatus: String = "准备就绪"
    @Published var isInjecting: Bool = false
    @Published var availableDylibs: [DylibFile] = []
    @Published var installedApps: [InstalledApp] = []
    @Published var injectionLogs: [InjectionLog] = []
    
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let tweaksPath: URL
    
    init() {
        tweaksPath = documentsPath.appendingPathComponent("Tweaks")
        setupTweaksDirectory()
        loadAvailableDylibs()
        loadInstalledApps()
        initializeTrollFools()
    }
    
    private func setupTweaksDirectory() {
        if !fileManager.fileExists(atPath: tweaksPath.path) {
            try? fileManager.createDirectory(at: tweaksPath, withIntermediateDirectories: true)
        }
    }
    
    private func initializeTrollFools() {
        // 初始化LiveContainer环境
        addLog("初始化LiveContainer环境", type: .info)
        
        // 检查LiveContainer工具是否可用
        let toolsAvailable = checkLiveContainerTools()
        if toolsAvailable {
            addLog("LiveContainer工具检查通过", type: .success)
        } else {
            addLog("LiveContainer工具检查失败", type: .warning)
        }
        
        addLog("LiveContainer环境初始化完成", type: .success)
    }
    
    private func checkLiveContainerTools() -> Bool {
        // 检查LiveContainer需要的工具 (不使用CoreTrust绕过)
        // 注意：在iOS 17+上，CoreTrust绕过是不可能的，必须使用正常签名
        let tools = ["chown", "cp", "mkdir", "mv", "rm"]
        var allAvailable = true
        
        for tool in tools {
            let toolPath = Bundle.main.path(forResource: tool, ofType: nil, inDirectory: "动态库注入/Tools")
            if toolPath != nil {
                addLog("工具 \(tool) 可用", type: .info)
            } else {
                addLog("工具 \(tool) 不可用", type: .warning)
                allAvailable = false
            }
        }
        
        // 检查ellekit.deb
        if let ellekitPath = Bundle.main.path(forResource: "ellekit", ofType: "deb") {
            addLog("ElleKit.deb 可用: \(ellekitPath)", type: .success)
        } else {
            addLog("ElleKit.deb 不可用，将使用CydiaSubstrate", type: .warning)
        }
        
        // 检查动态库文件
        let dylibFiles = ["libintl.8.dylib", "libiosexec.1.dylib", "libxar.1.dylib"]
        for dylib in dylibFiles {
            let dylibPath = Bundle.main.path(forResource: dylib, ofType: nil, inDirectory: "动态库注入/Tools")
            if dylibPath != nil {
                addLog("动态库 \(dylib) 可用", type: .info)
            } else {
                addLog("动态库 \(dylib) 不可用", type: .warning)
            }
        }
        
        // 检查LiveContainer核心文件
        let coreFiles = ["LCMachOUtils.m", "TweakLoader.m", "Dyld.m"]
        for file in coreFiles {
            let filePath = Bundle.main.path(forResource: file, ofType: nil, inDirectory: "动态库注入")
            if filePath != nil {
                addLog("核心文件 \(file) 可用", type: .info)
            } else {
                addLog("核心文件 \(file) 不可用", type: .warning)
                allAvailable = false
            }
        }
        
        addLog("注意：不使用CoreTrust绕过，使用正常代码签名流程", type: .info)
        
        return allAvailable
    }
    
    // MARK: - 动态库管理
    func loadAvailableDylibs() {
        // 从Tweaks目录加载动态库
        do {
            let files = try fileManager.contentsOfDirectory(at: tweaksPath, includingPropertiesForKeys: nil)
            availableDylibs = files.compactMap { url in
                let fileName = url.lastPathComponent
                if fileName.hasSuffix(".dylib") || fileName.hasSuffix(".framework") {
                    return DylibFile(
                        name: fileName,
                        path: url.path,
                        size: getFileSize(url: url),
                        isFramework: fileName.hasSuffix(".framework")
                    )
                }
                return nil
            }
            addLog("加载了 \(availableDylibs.count) 个动态库文件", type: .info)
        } catch {
            addLog("加载动态库文件失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    // MARK: - 应用管理
    func loadInstalledApps() {
        // 发现已安装的应用
        let discoveredApps = LiveContainerIntegration.shared.getInstalledAppsList()
        
        installedApps = discoveredApps.compactMap { appInfo in
            // 检查应用是否适合注入
            let isEligible = LiveContainerIntegration.shared.checkAppEligibility(appInfo.path)
            guard isEligible else { return nil }
            
            // 检查是否已注入
            let isInjected = LiveContainerIntegration.shared.checkInjectionStatus(appInfo.path)
            
            return InstalledApp(
                name: appInfo.name,
                bundleId: appInfo.bundleId,
                version: appInfo.version,
                path: appInfo.path,
                isInjected: isInjected
            )
        }
        
        addLog("发现 \(installedApps.count) 个可注入的应用", type: .info)
    }
    
    // MARK: - 注入操作 (基于LiveContainer非越狱技术)
    func performInjection(app: InstalledApp, dylib: DylibFile) {
        guard !isInjecting else { return }
        
        isInjecting = true
        injectionStatus = "初始化LiveContainer..."
        addLog("开始为应用 \(app.name) 注入动态库 \(dylib.name)", type: .info)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 阶段1: 准备阶段
            DispatchQueue.main.async {
                self.injectionStatus = "验证目标应用..."
                self.addLog("正在验证目标应用: \(app.name)", type: .info)
            }
            
            // 阶段2: 执行注入
            DispatchQueue.main.async {
                self.injectionStatus = "修改Mach-O文件..."
                self.addLog("正在修改Mach-O文件", type: .info)
            }
            
            let result = self.executeInjection(app: app, dylib: dylib)
            
            DispatchQueue.main.async {
                self.isInjecting = false
                
                if result.success {
                    self.injectionStatus = "注入完成"
                    self.addLog("动态库注入成功，使用LiveContainer非越狱技术", type: .success)
                    self.addLog("应用将在下次启动时自动加载tweak", type: .info)
                } else {
                    self.injectionStatus = "注入失败"
                    self.addLog("动态库注入失败: \(result.error ?? "未知错误")", type: .error)
                }
                
                // 3秒后重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.injectionStatus = "准备就绪"
                }
            }
        }
    }
    
    private func executeInjection(app: InstalledApp, dylib: DylibFile) -> (success: Bool, error: String?) {
        // 基于LiveContainer的非越狱动态库注入实现
        
        // 1. 检查应用是否适合注入
        let isEligible = LiveContainerIntegration.shared.checkAppEligibility(app.bundleURL.path)
        guard isEligible else {
            return (false, "应用不适合注入")
        }
        
        // 2. 检查动态库文件是否存在
        let dylibURL = URL(fileURLWithPath: dylib.path)
        guard FileManager.default.fileExists(atPath: dylib.path) else {
            return (false, "动态库文件不存在")
        }
        
        // 3. 执行注入
        let injectionResult = LiveContainerIntegration.shared.injectDylibUsingLiveContainer(
            dylibPath: dylib.path,
            targetAppPath: app.bundleURL.path
        )
        
        // 4. 记录日志
        if injectionResult {
            addLog("动态库注入成功: \(app.name)", type: .success)
            return (true, nil)
        } else {
            addLog("动态库注入失败: \(app.name)", type: .error)
            return (false, "注入失败")
        }
    }
    
    private func getAppExecutablePath(for app: InstalledApp) -> String? {
        // 获取应用的可执行文件路径
        let executablePath = app.bundleURL.appendingPathComponent(app.name).path
        return FileManager.default.fileExists(atPath: executablePath) ? executablePath : nil
    }
    
    // MARK: - 移除注入的动态库
    func removeInjection(from app: InstalledApp) {
        guard !isInjecting else { return }
        
        isInjecting = true
        injectionStatus = "移除注入中..."
        addLog("开始移除应用 \(app.name) 的注入", type: .info)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.executeRemoval(app: app)
            
            DispatchQueue.main.async {
                self.isInjecting = false
                self.injectionStatus = result.success ? "移除完成" : "移除失败"
                
                if result.success {
                    self.addLog("动态库移除成功，", type: .success)
                } else {
                    self.addLog("动态库移除失败: \(result.error ?? "未知错误")", type: .error)
                }
            }
        }
    }
    
    private func executeRemoval(app: InstalledApp) -> (success: Bool, error: String?) {
        // 基于LiveContainer的非越狱动态库移除实现
        
        // 1. 检查应用是否已注入
        let isInjected = LiveContainerIntegration.shared.checkInjectionStatus(app.bundleURL.path)
        guard isInjected else {
            return (false, "应用未注入动态库")
        }
        
        // 2. 执行移除
        let removalResult = LiveContainerIntegration.shared.removeInjectedDylibsUsingLiveContainer(
            targetAppPath: app.bundleURL.path
        )
        
        // 3. 记录日志
        if removalResult {
            addLog("动态库移除成功: \(app.name)", type: .success)
            return (true, nil)
        } else {
            addLog("动态库移除失败: \(app.name)", type: .error)
            return (false, "移除失败")
        }
    }
    
    // MARK: - 文件管理
    func importDylib(from url: URL) {
        let destination = tweaksPath.appendingPathComponent(url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: url, to: destination)
            addLog("成功导入动态库: \(url.lastPathComponent)", type: .success)
            loadAvailableDylibs()
        } catch {
            addLog("导入动态库失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    func deleteDylib(_ dylib: DylibFile) {
        do {
            try fileManager.removeItem(atPath: dylib.path)
            addLog("删除动态库: \(dylib.name)", type: .info)
            loadAvailableDylibs()
        } catch {
            addLog("删除动态库失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    // MARK: - 工具方法
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            // 忽略错误
        }
        return "未知大小"
    }
    
    private func addLog(_ message: String, type: InjectionLogType) {
        let log = InjectionLog(
            message: message,
            type: type,
            timestamp: Date()
        )
        injectionLogs.insert(log, at: 0)
        
        // 限制日志数量
        if injectionLogs.count > 100 {
            injectionLogs = Array(injectionLogs.prefix(100))
        }
    }
}

// MARK: - 数据模型
struct DylibFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: String
    let isFramework: Bool
}

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let version: String
    let path: String
    let isInjected: Bool
    
    init(name: String, bundleId: String, version: String, path: String, isInjected: Bool = false) {
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.path = path
        self.isInjected = isInjected
    }
    
    var bundleURL: URL {
        return URL(fileURLWithPath: path)
    }
}

struct InjectionLog: Identifiable {
    let id = UUID()
    let message: String
    let type: InjectionLogType
    let timestamp: Date
}

enum InjectionLogType {
    case info
    case success
    case error
    case warning
    
    var color: UIColor {
        switch self {
        case .info:
            return .systemBlue
        case .success:
            return .systemGreen
        case .error:
            return .systemRed
        case .warning:
            return .systemOrange
        }
    }
    
    var icon: String {
        switch self {
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .error:
            return "xmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        }
    }
}
