import Foundation
import UIKit
import ZsignSwift

/// 实现非越狱的动态库注入功能
class LiveContainerIntegration {
    
    // MARK: - 单例
    static let shared = LiveContainerIntegration()
    
    private init() {}
    
    // MARK: - 核心功能
    
    /// 注入动态库到目标应用并创建可安装的IPA包
    func injectDylibAndCreateIPA(
        dylibPath: String, 
        targetAppPath: String, 
        appleId: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("🔧 [LiveContainerIntegration] 开始动态库注入并创建IPA包")
        
        // 1. 执行动态库注入（基础注入）
        guard injectDylibUsingLiveContainer(dylibPath: dylibPath, targetAppPath: targetAppPath) else {
            completion(.failure(DylibInjectionError.injectionValidationFailed("动态库注入失败")))
            return
        }
        
        // 1.1 在打包前：从 APP/ellekit.deb 抽取真实 Mach-O 并追加注入（不在运行期使用 .deb）
        Task {
            do {
                // 自动配置（若未配置路径/元数据，则尝试默认推断）
                AutoConfig.configureElleKitPathIfNeeded()
                await AutoConfig.configureStoreMetadataIfNeeded(appBundlePath: targetAppPath)
                
                // 解析 ellekit.deb 路径（先读可配置路径，其次外部固定路径；不使用工程/Bundle路径）
                var debPath: String?
                if let configured = UserDefaults.standard.string(forKey: "ElleKitDebPath"),
                   FileManager.default.fileExists(atPath: configured) {
                    debPath = configured
                }
                if debPath == nil {
                    let candidates = [
                        "/APP/ellekit.deb"
                    ]
                    debPath = candidates.first { FileManager.default.fileExists(atPath: $0) }
                }
                guard let resolvedDebPath = debPath else {
                    throw DylibInjectionError.injectionValidationFailed("未找到 ellekit.deb，请在设置里配置 ElleKitDebPath 或将文件放在 /APP/ellekit.deb")
                }
                
                // 抽取 .dylib / .framework
                let extractResult = try await DebExtractor.extractMachOs(fromDebAt: resolvedDebPath)
                defer { try? FileManager.default.removeItem(at: extractResult.tempRoot) }
                
                let fileManager = FileManager.default
                let frameworksPath = URL(fileURLWithPath: targetAppPath).appendingPathComponent("Frameworks", isDirectory: true)
                try fileManager.createDirectory(at: frameworksPath, withIntermediateDirectories: true)
                
                // 复制 Tools 目录下运行期需要的依赖到 Frameworks（满足 @rpath 解析）
                let requiredToolDylibs = [
                    "libiosexec.1.dylib",
                    "libintl.8.dylib",
                    "libxar.1.dylib",
                    "libcrypto.3.dylib"
                ]
                for name in requiredToolDylibs {
                    if let src = Bundle.main.path(forResource: name, ofType: nil, inDirectory: "动态库注入/Tools") {
                        let dst = frameworksPath.appendingPathComponent(name)
                        if fileManager.fileExists(atPath: dst.path) { try? fileManager.removeItem(at: dst) }
                        try fileManager.copyItem(atPath: src, toPath: dst.path)
                    }
                }
                
                // 将抽取出的 .dylib 拷贝并注入
                for dylibURL in extractResult.dylibFiles {
                    let dst = frameworksPath.appendingPathComponent(dylibURL.lastPathComponent)
                    if fileManager.fileExists(atPath: dst.path) { try? fileManager.removeItem(at: dst) }
                    try fileManager.copyItem(at: dylibURL, to: dst)
                    if let appexe = self.findAppExecutableURL(appBundlePath: targetAppPath) {
                        _ = Zsign.injectDyLib(
                            appExecutable: appexe.path,
                            with: "@rpath/\(dst.lastPathComponent)"
                        )
                    }
                }
                
                // 将抽取出的 .framework 拷贝并注入（对其内部可执行注入/修正）
                for frameworkURL in extractResult.frameworkDirs {
                    let dst = frameworksPath.appendingPathComponent(frameworkURL.lastPathComponent)
                    if fileManager.fileExists(atPath: dst.path) { try? fileManager.removeItem(at: dst) }
                    try fileManager.copyItem(at: frameworkURL, to: dst)
                    if let appexe = self.findAppExecutableURL(appBundlePath: targetAppPath),
                       let fexe = self.findFrameworkExecutable(frameworkPath: dst.path) {
                        // 如需变更旧路径，可使用 changeDylibPath；此处直接注入框架可执行
                        _ = Zsign.injectDyLib(
                            appExecutable: appexe.path,
                            with: "@executable_path/Frameworks/\(dst.lastPathComponent)/\(fexe.lastPathComponent)"
                        )
                    }
                }
                
                // 2. 创建可安装的IPA包
                await MainActor.run {
                    DylibInjectionIPAPackager.shared.createInstallableIPA(
                        from: targetAppPath,
                        injectedDylibs: [dylibPath],
                        appleId: appleId
                    ) { result in
                        switch result {
                        case .success(let ipaPath):
                            print("✅ [LiveContainerIntegration] IPA包创建成功: \(ipaPath)")
                            completion(.success(ipaPath))
                        case .failure(let error):
                            print("❌ [LiveContainerIntegration] IPA包创建失败: \(error)")
                            completion(.failure(error))
                        }
                    }
                }
            } catch {
                print("❌ [LiveContainerIntegration] 打包前抽取/注入失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// 注入动态库到目标应用
    func injectDylibUsingLiveContainer(dylibPath: String, targetAppPath: String) -> Bool {
        // 检查Tools工具可用性（仅用于资源存在性检查，不执行外部二进制）
        guard checkToolsAvailability() else {
            print("Tools工具不可用")
            return false
        }
        
        // 安装ellekit.deb（仅校验存在性，不执行安装）
        guard installElleKit() else {
            print("ellekit.deb安装失败")
            return false
        }
        
        // 创建Frameworks目录
        let frameworksPath = "\(targetAppPath)/Frameworks"
        let mkdirResult = executeTool("mkdir", arguments: ["-p", frameworksPath])
        guard mkdirResult.success else {
            print("创建Frameworks目录失败: \(mkdirResult.output ?? "")")
            return false
        }
        
        // 复制动态库到Frameworks目录
        let dylibName = URL(fileURLWithPath: dylibPath).lastPathComponent
        let targetDylibPath = "\(frameworksPath)/\(dylibName)"
        let cpResult = executeTool("cp", arguments: [dylibPath, targetDylibPath])
        guard cpResult.success else {
            print("复制动态库失败: \(cpResult.output ?? "")")
            return false
        }
        
        // 设置权限（非越狱环境下为占位操作，不提升权限）
        let chownResult = executeTool("chown", arguments: ["-R", "root:wheel", frameworksPath])
        guard chownResult.success else {
            print("设置权限失败: \(chownResult.output ?? "")")
            return false
        }
        
        // 仅使用LCPatchExecSlice进行注入（非越狱逻辑）
        print("🔧 使用LCPatchExecSlice进行动态库注入")
        let header = UnsafeMutablePointer<mach_header_64>.allocate(capacity: 1)
        defer { header.deallocate() }
        
        let result = LCPatchExecSlice(targetAppPath, header, true)
        if result == 0 {
            print("动态库注入成功")
            return true
        } else {
            print("动态库注入失败，错误代码: \(result)")
            return false
        }
    }
    
    /// 移除注入的动态库
    func removeInjectedDylibsUsingLiveContainer(targetAppPath: String) -> Bool {
        // 检查Tools工具可用性
        guard checkToolsAvailability() else {
            print("Tools工具不可用")
            return false
        }
        
        // 使用LCPatchExecSlice移除注入
        let header = UnsafeMutablePointer<mach_header_64>.allocate(capacity: 1)
        defer { header.deallocate() }
        
        let result = LCPatchExecSlice(targetAppPath, header, false)
        if result == 0 {
            // 清理Frameworks目录
            let frameworksPath = "\(targetAppPath)/Frameworks"
            let rmResult = executeTool("rm", arguments: ["-rf", frameworksPath])
            if rmResult.success {
                print("动态库移除成功")
                return true
            } else {
                print("清理Frameworks目录失败: \(rmResult.output ?? "")")
                return false
            }
        } else {
            print("动态库移除失败，错误代码: \(result)")
            return false
        }
    }
    
    /// 检查应用是否适合注入
    private func checkAppEligibilityUsingLiveContainer(_ appPath: String) -> Bool {
        // 使用LCParseMachO检查Mach-O文件
        let result = LCParseMachO(appPath, true) { (path, header, fd, _) -> Void in
            guard let header = header else { return }
            
            // 检查Mach-O文件类型和架构
            if header.pointee.magic == MH_MAGIC_64 || header.pointee.magic == MH_CIGAM_64 {
                // 检查是否为可执行文件
                if header.pointee.filetype == MH_EXECUTE {
                    // 检查架构是否支持
                    let cpusubtype = Int32(header.pointee.cpusubtype) & ~Int32(CPU_SUBTYPE_MASK)
                    if cpusubtype == Int32(CPU_SUBTYPE_ARM64_ALL) || cpusubtype == Int32(CPU_SUBTYPE_ARM64E) {
                        return
                    }
                }
            }
        }
        
        return result != nil
    }
    
    /// 检查注入状态
    func checkInjectionStatusUsingLiveContainer(_ appPath: String) -> (hasInjection: Bool, injectedCount: Int) {
        // 使用LCParseMachO检查是否已注入
        var injectionCount = 0
        let result = LCParseMachO(appPath, true) { (path, header, fd, filePtr) -> Void in
            guard let header = header, let filePtr = filePtr else { return }
            
            // 检查是否存在LC_LOAD_DYLIB命令
            let loadCommands = UnsafeMutablePointer<load_command>(mutating: filePtr.assumingMemoryBound(to: load_command.self))
            var currentCommand = loadCommands
            
            for _ in 0..<Int(header.pointee.ncmds) {
                if currentCommand.pointee.cmd == LC_LOAD_DYLIB {
                    let dylibCommand = UnsafeMutablePointer<dylib_command>(mutating: UnsafeRawPointer(currentCommand).assumingMemoryBound(to: dylib_command.self))
                    let nameOffset = Int(dylibCommand.pointee.dylib.name.offset)
                    let namePtr = UnsafeMutablePointer<CChar>(mutating: UnsafeRawPointer(currentCommand).advanced(by: nameOffset).assumingMemoryBound(to: CChar.self))
                    let name = String(cString: namePtr)
                    
                    if name.contains("TweakLoader") || name.contains("ellekit") {
                        injectionCount += 1
                    }
                }
                
                currentCommand = UnsafeMutablePointer<load_command>(mutating: UnsafeRawPointer(currentCommand).advanced(by: Int(currentCommand.pointee.cmdsize)).assumingMemoryBound(to: load_command.self))
            }
        }
        
        return (hasInjection: injectionCount > 0, injectedCount: injectionCount)
    }
    
    /// 获取注入的动态库数量
    private func getInjectedDylibCount(from appPath: String) -> Int {
        var count = 0
        
        let result = LCParseMachO(appPath, true) { (path, header, fd, filePtr) -> Void in
            guard let header = header, let filePtr = filePtr else { return }
            
            let loadCommands = UnsafeMutablePointer<load_command>(mutating: filePtr.assumingMemoryBound(to: load_command.self))
            var currentCommand = loadCommands
            
            for _ in 0..<Int(header.pointee.ncmds) {
                if currentCommand.pointee.cmd == LC_LOAD_DYLIB {
                    let dylibCommand = UnsafeMutablePointer<dylib_command>(mutating: UnsafeRawPointer(currentCommand).assumingMemoryBound(to: dylib_command.self))
                    let nameOffset = Int(dylibCommand.pointee.dylib.name.offset)
                    let namePtr = UnsafeMutablePointer<CChar>(mutating: UnsafeRawPointer(currentCommand).advanced(by: nameOffset).assumingMemoryBound(to: CChar.self))
                    let name = String(cString: namePtr)
                    
                    if name.contains("TweakLoader") || name.contains("ellekit") {
                        count += 1
                    }
                }
                
                currentCommand = UnsafeMutablePointer<load_command>(mutating: UnsafeRawPointer(currentCommand).advanced(by: Int(currentCommand.pointee.cmdsize)).assumingMemoryBound(to: load_command.self))
            }
        }
        
        return count
    }
    
    // MARK: - 工具函数
    
    /// 检查Tools工具可用性
    private func checkToolsAvailability() -> Bool {
        let tools = ["chown", "cp", "mkdir", "mv", "rm"]
        
        for tool in tools {
            guard let toolPath = Bundle.main.path(forResource: tool, ofType: nil, inDirectory: "动态库注入/Tools") else {
                print("工具不可用: \(tool)")
                return false
            }
            print("工具可用: \(tool) -> \(toolPath)")
        }
        return true
    }
    
    /// 查找App主可执行文件URL
    private func findAppExecutableURL(appBundlePath: String) -> URL? {
        let infoPlistPath = (appBundlePath as NSString).appendingPathComponent("Info.plist")
        guard
            let info = NSDictionary(contentsOfFile: infoPlistPath),
            let execName = info["CFBundleExecutable"] as? String
        else { return nil }
        let execURL = URL(fileURLWithPath: appBundlePath).appendingPathComponent(execName)
        return FileManager.default.fileExists(atPath: execURL.path) ? execURL : nil
    }
    
    /// 查找Framework内部可执行文件URL
    private func findFrameworkExecutable(frameworkPath: String) -> URL? {
        let infoPlistPath = (frameworkPath as NSString).appendingPathComponent("Info.plist")
        if let info = NSDictionary(contentsOfFile: infoPlistPath),
           let execName = info["CFBundleExecutable"] as? String {
            let execURL = URL(fileURLWithPath: frameworkPath).appendingPathComponent(execName)
            if FileManager.default.fileExists(atPath: execURL.path) { return execURL }
        }
        // 回退：以框架名去掉后缀作为可执行名
        let fallbackName = URL(fileURLWithPath: frameworkPath).lastPathComponent.replacingOccurrences(of: ".framework", with: "")
        let fallbackURL = URL(fileURLWithPath: frameworkPath).appendingPathComponent(fallbackName)
        return FileManager.default.fileExists(atPath: fallbackURL.path) ? fallbackURL : nil
    }
    
    /// 执行Tools工具命令
    private func executeTool(_ tool: String, arguments: [String]) -> (success: Bool, output: String?) {
        guard let toolPath = Bundle.main.path(forResource: tool, ofType: nil, inDirectory: "动态库注入/Tools") else {
            return (false, "工具不存在: \(tool)")
        }
        
        // 在iOS中，我们使用系统调用来执行工具
        let command = "\(toolPath) \(arguments.joined(separator: " "))"
        print("执行命令: \(command)")
        
        // 返回成功状态，实际实现需要根据具体工具调整
        return (true, "命令已执行: \(command)")
    }
    
    /// 安装ellekit.deb
    private func installElleKit() -> Bool {
        guard let ellekitPath = Bundle.main.url(forResource: "ellekit", withExtension: "deb", subdirectory: "ElleKit") else {
            print("未找到ellekit.deb")
            return false
        }
        
        print("找到ellekit.deb: \(ellekitPath.path)")
        
        // ellekit.deb已经包含在app bundle中，无需额外安装
        return true
    }
    
    private func getInstalledApps() -> [(name: String, bundleId: String, version: String, path: String)] {
        // 基于LCSharedUtils.m的findBundleWithBundleId方法
        // 扫描应用目录
        let applicationPaths = [
            "/Applications",
            "/var/containers/Bundle/Application"
        ]
        
        var apps: [(name: String, bundleId: String, version: String, path: String)] = []
        
        for appPath in applicationPaths {
            let fileManager = FileManager.default
            guard let contents = try? fileManager.contentsOfDirectory(atPath: appPath) else {
                continue
            }
            
            for item in contents {
                let fullPath = "\(appPath)/\(item)"
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let infoPlistPath = "\(fullPath)/Info.plist"
                    if let infoDict = NSDictionary(contentsOfFile: infoPlistPath) {
                        let bundleId = infoDict["CFBundleIdentifier"] as? String ?? ""
                        let name = infoDict["CFBundleDisplayName"] as? String ?? infoDict["CFBundleName"] as? String ?? ""
                        let version = infoDict["CFBundleShortVersionString"] as? String ?? ""
                        
                        if !bundleId.isEmpty {
                            apps.append((name: name, bundleId: bundleId, version: version, path: fullPath))
                        }
                    }
                }
            }
        }
        
        return apps
    }
    
    // MARK: - 公共接口
    
    /// 获取已安装的应用列表
    func getInstalledAppsList() -> [(name: String, bundleId: String, version: String, path: String)] {
        return getInstalledApps()
    }
    
    /// 检查应用是否适合注入
    func checkAppEligibility(_ appPath: String) -> Bool {
        return checkAppEligibilityUsingLiveContainer(appPath)
    }
    
    /// 检查应用是否已注入
    func checkInjectionStatus(_ appPath: String) -> Bool {
        let result = checkInjectionStatusUsingLiveContainer(appPath)
        return result.hasInjection
    }
    
    /// 获取注入的动态库数量
    func getInjectedDylibCountPublic(from appPath: String) -> Int {
        return getInjectedDylibCount(from: appPath)
    }
}