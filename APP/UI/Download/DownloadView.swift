//
//  DownloadView.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/04.
//

import SwiftUI
import Combine
import Foundation
import Network
#if canImport(UIKit)
import UIKit
import SafariServices
#endif
#if canImport(Vapor)
import Vapor
#endif
#if canImport(ZsignSwift)
import ZsignSwift
#endif
#if canImport(ZipArchive)
import ZipArchive
#endif

// 解决View类型冲突
typealias SwiftUIView = SwiftUI.View



// MARK: - Safari WebView
#if canImport(UIKit)
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}
#endif

// MARK: - 必要的类型定义
public enum PackageInstallationError: Error, LocalizedError {
    case invalidIPAFile
    case installationFailed(String)
    case networkError
    case timeoutError
    
    public var errorDescription: String? {
        switch self {
        case .invalidIPAFile:
            return "无效的IPA文件"
        case .installationFailed(let reason):
            return "安装失败: \(reason)"
        case .networkError:
            return "网络错误"
        case .timeoutError:
            return "安装超时"
        }
    }
}

public struct AppInfo {
    public let name: String
    public let version: String
    public let bundleIdentifier: String
    public let path: String
    public let localPath: String?
    
    public init(name: String, version: String, bundleIdentifier: String, path: String, localPath: String? = nil) {
        self.name = name
        self.version = version
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.localPath = localPath
    }
    
    // 兼容性属性
    public var bundleId: String {
        return bundleIdentifier
    }
}

// MARK: - CORS中间件
#if canImport(Vapor)
struct CORSMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Access-Control-Allow-Methods", value: "GET, POST, OPTIONS")
            response.headers.add(name: "Access-Control-Allow-Headers", value: "Content-Type, Authorization")
            return response
        }
    }
}
#endif

// MARK: - HTTP功能器
#if canImport(Vapor)
class SimpleHTTPServer: NSObject {
    public let port: Int
    private let ipaPath: String
    private let appInfo: AppInfo
    private var app: Application?
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "simple.server.queue", qos: .userInitiated)
    private var plistData: Data?
    private var plistFileName: String?
    
    // 使用随机端口范围
    static func randomPort() -> Int {
        return Int.random(in: 4000...8000)
    }
    
    init(port: Int, ipaPath: String, appInfo: AppInfo) {
        self.port = port
        self.ipaPath = ipaPath
        self.appInfo = appInfo
        super.init()
    }
    
    // MARK: - UserDefaults相关方法
    static let userDefaultsKey = "SimpleHTTPServer"
    
    static func getSavedPort() -> Int? {
        return UserDefaults.standard.integer(forKey: "\(userDefaultsKey).port")
    }
    
    static func savePort(_ port: Int) {
        UserDefaults.standard.set(port, forKey: "\(userDefaultsKey).port")
        UserDefaults.standard.synchronize()
    }
    
    func start() {
        NSLog("🚀 [Simple HTTP功能器] 启动功能器，端口: \(port)")
        NSLog("📱 [Simple HTTP功能器] AppInfo: \(appInfo.name) v\(appInfo.version) (\(appInfo.bundleIdentifier))")
        NSLog("📁 [Simple HTTP功能器] IPA路径: \(ipaPath)")
        NSLog("⏰ [Simple HTTP功能器] 启动时间: \(Date())")
        NSLog("🔧 [Simple HTTP功能器] 服务器队列: \(serverQueue.label)")
        print("🚀 [Simple HTTP功能器] 启动功能器，端口: \(port)")
        print("📱 [Simple HTTP功能器] AppInfo: \(appInfo.name) v\(appInfo.version) (\(appInfo.bundleIdentifier))")
        print("📁 [Simple HTTP功能器] IPA路径: \(ipaPath)")
        print("⏰ [Simple HTTP功能器] 启动时间: \(Date())")
        print("🔧 [Simple HTTP功能器] 服务器队列: \(serverQueue.label)")
        
        // 请求本地网络权限
        NSLog("🔐 [Simple HTTP功能器] 开始请求本地网络权限...")
        requestLocalNetworkPermission { [weak self] granted in
            if granted {
                NSLog("✅ [Simple HTTP功能器] 本地网络权限已授予")
                self?.serverQueue.async { [weak self] in
                    self?.startSimpleServer()
                }
            } else {
                NSLog("❌ [Simple HTTP功能器] 本地网络权限被拒绝")
                print("❌ [Simple HTTP功能器] 本地网络权限被拒绝")
            }
        }
    }
    
    private func requestLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // 创建网络监听器来触发权限对话框
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkPermission")
        
        monitor.pathUpdateHandler = { path in
            // 检查网络可用性
            let hasPermission = path.status == .satisfied || path.status == .requiresConnection
            DispatchQueue.main.async {
                completion(hasPermission)
            }
            monitor.cancel()
        }
        
        monitor.start(queue: queue)
        
        // 5秒后超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            monitor.cancel()
            completion(true) // 默认允许继续
        }
    }
    
    private func startSimpleServer() {
        NSLog("🔧 [Simple HTTP功能器] 开始启动服务器...")
        print("🔧 [Simple HTTP功能器] 开始启动服务器...")
        
        do {
            // 创建Vapor应用
            NSLog("📦 [Simple HTTP功能器] 创建Vapor应用...")
            let config = Environment(name: "development", arguments: ["serve"])
            app = Application(config)
            NSLog("✅ [Simple HTTP功能器] Vapor应用创建成功")
            
            // 配置功能器 - 监听所有接口
            NSLog("⚙️ [Simple HTTP功能器] 配置服务器参数...")
            app?.http.server.configuration.port = port
            app?.http.server.configuration.address = .hostname("0.0.0.0", port: port)
            app?.http.server.configuration.tcpNoDelay = true
            app?.http.server.configuration.requestDecompression = .enabled
            app?.http.server.configuration.responseCompression = .enabled
            app?.threadPool = .init(numberOfThreads: 2)
            NSLog("✅ [Simple HTTP功能器] 服务器参数配置完成 - 端口: \(port), 地址: 0.0.0.0")
            
            // 不设置TLS配置，强制HTTP
            app?.http.server.configuration.tlsConfiguration = nil
            NSLog("🔒 [Simple HTTP功能器] TLS配置已禁用，使用HTTP")
            
            // 设置CORS和缓存头
            NSLog("🌐 [Simple HTTP功能器] 设置CORS中间件...")
            app?.middleware.use(CORSMiddleware())
            NSLog("✅ [Simple HTTP功能器] CORS中间件设置完成")
            
            // 设置路由
            NSLog("🛣️ [Simple HTTP功能器] 设置路由...")
            setupSimpleRoutes()
            NSLog("✅ [Simple HTTP功能器] 路由设置完成")
            
            // 启动功能器
            NSLog("🚀 [Simple HTTP功能器] 启动服务器...")
            try app?.run()
            
            isRunning = true
            NSLog("✅ [Simple HTTP功能器] 功能器已启动，端口: \(port)")
            NSLog("🌐 [Simple HTTP功能器] 服务器地址: http://0.0.0.0:\(port)")
            NSLog("📱 [Simple HTTP功能器] 本地访问地址: http://127.0.0.1:\(port)")
            print("✅ [Simple HTTP功能器] 功能器已启动，端口: \(port)")
            print("🌐 [Simple HTTP功能器] 服务器地址: http://0.0.0.0:\(port)")
            print("📱 [Simple HTTP功能器] 本地访问地址: http://127.0.0.1:\(port)")
            
        } catch {
            NSLog("❌ [Simple HTTP功能器] 启动失败: \(error)")
            print("❌ [Simple HTTP功能器] 启动失败: \(error)")
            isRunning = false
        }
    }
    
    private func setupSimpleRoutes() {
        guard let app = app else { 
            NSLog("❌ [Simple HTTP功能器] 无法设置路由，app为nil")
            return 
        }
        
        NSLog("🛣️ [Simple HTTP功能器] 开始设置路由...")
        
        // 健康检查端点
        app.get("health") { req -> String in
            return "OK"
        }
        
        // 提供IPA文件功能
        app.get("ipa", ":filename") { [weak self] req -> Response in
            let filename = req.parameters.get("filename") ?? "nil"
            NSLog("📦 [Simple HTTP功能器] IPA文件请求 - filename: \(filename)")
            
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                NSLog("❌ [Simple HTTP功能器] IPA文件请求失败 - filename: \(filename), 期望: \(self?.appInfo.bundleIdentifier ?? "nil")")
                return Response(status: .notFound)
            }
            
            NSLog("📁 [Simple HTTP功能器] 读取IPA文件: \(self.ipaPath)")
            guard let ipaData = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                NSLog("❌ [Simple HTTP功能器] 无法读取IPA文件: \(self.ipaPath)")
                return Response(status: .notFound)
            }
            
            NSLog("✅ [Simple HTTP功能器] IPA文件读取成功，大小: \(ipaData.count) 字节")
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/octet-stream")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: ipaData)
            
            return response
        }
        
        // 提供IPA文件服务（直接通过bundleIdentifier访问）
        app.get(":filename") { [weak self] req -> Response in
            let filename = req.parameters.get("filename") ?? "nil"
            NSLog("📦 [Simple HTTP功能器] 直接IPA文件请求 - filename: \(filename)")
            
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == "\(self.appInfo.bundleIdentifier).ipa" else {
                NSLog("❌ [Simple HTTP功能器] 直接IPA文件请求失败 - filename: \(filename), 期望: \(self?.appInfo.bundleIdentifier ?? "nil").ipa")
                return Response(status: .notFound)
            }
            
            NSLog("📁 [Simple HTTP功能器] 读取IPA文件: \(self.ipaPath)")
            guard let ipaData = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                NSLog("❌ [Simple HTTP功能器] 无法读取IPA文件: \(self.ipaPath)")
                return Response(status: .notFound)
            }
            
            NSLog("✅ [Simple HTTP功能器] IPA文件读取成功，大小: \(ipaData.count) 字节")
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/octet-stream")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: ipaData)
            
            return response
        }
        
        // 提供Plist文件功能
        app.get("plist", ":filename") { [weak self] req -> Response in
            let filename = req.parameters.get("filename") ?? "nil"
            NSLog("📄 [Simple HTTP服务器] Plist文件请求 - filename: \(filename)")
            
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                NSLog("❌ [Simple HTTP服务器] Plist文件请求失败 - filename: \(filename), 期望: \(self?.appInfo.bundleIdentifier ?? "nil")")
                return Response(status: .notFound)
            }
            
            NSLog("🔧 [Simple HTTP服务器] 生成Plist数据...")
            let plistData = self.generatePlistData()
            NSLog("✅ [Simple HTTP服务器] Plist文件生成成功: \(filename), 大小: \(plistData.count) 字节")
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/xml")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: plistData)
            
            return response
        }
        
        // 提供Plist文件功能（通过base64编码的路径）
        app.get("i", ":encodedPath") { [weak self] req -> Response in
            guard let self = self,
                  let encodedPath = req.parameters.get("encodedPath") else {
                return Response(status: .notFound)
            }
            
            // 解码base64路径
            guard let decodedData = Data(base64Encoded: encodedPath.replacingOccurrences(of: ".plist", with: "")),
                  let decodedPath = String(data: decodedData, encoding: .utf8) else {
                return Response(status: .notFound)
            }
            
            NSLog("📄 [APP] 请求plist文件，解码路径: \(decodedPath)")
            print("📄 请求plist文件，解码路径: \(decodedPath)")
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/xml")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: self.generatePlistData())
            
            return response
        }
        
        // 安装页面路由（保留作为备用）
        app.get("install") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 生成外部manifest URL
            let externalManifestURL = self.generateExternalManifestURL()
            
            // 创建自动安装页面
            let installPage = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>正在安装 \(self.appInfo.name)</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        margin: 0;
                        padding: 20px;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        text-align: center;
                        min-height: 100vh;
                        display: flex;
                        flex-direction: column;
                        justify-content: center;
                        align-items: center;
                    }
                    .container {
                        background: rgba(255, 255, 255, 0.1);
                        padding: 30px;
                        border-radius: 20px;
                        backdrop-filter: blur(10px);
                        max-width: 400px;
                        width: 100%;
                    }
                    .app-icon {
                        width: 80px;
                        height: 80px;
                        background: #007AFF;
                        border-radius: 16px;
                        margin: 0 auto 20px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        font-size: 40px;
                    }
                    .status {
                        margin-top: 20px;
                        font-size: 16px;
                        opacity: 0.9;
                    }
                    .loading {
                        display: inline-block;
                        width: 20px;
                        height: 20px;
                        border: 3px solid rgba(255,255,255,.3);
                        border-radius: 50%;
                        border-top-color: #fff;
                        animation: spin 1s ease-in-out infinite;
                        margin-right: 10px;
                    }
                    @keyframes spin {
                        to { transform: rotate(360deg); }
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="app-icon">📱</div>
                    <h1>\(self.appInfo.name)</h1>
                    <p>版本 \(self.appInfo.version)</p>
                    <p>Bundle ID: \(self.appInfo.bundleIdentifier)</p>
                    
                    <div class="status" id="status">
                        <span class="loading"></span>正在启动安装程序...
                    </div>
                </div>
                
                <script>
                    // 页面加载完成后立即自动执行安装
                    window.onload = function() {
                        console.log('页面加载完成，开始自动安装...');
                        autoInstall();
                    };
                    
                    function autoInstall() {
                        const status = document.getElementById('status');
                        
                        // 使用外部manifest URL
                        const manifestURL = '\(externalManifestURL)';
                        const itmsURL = 'itms-services://?action=download-manifest&url=' + encodeURIComponent(manifestURL);
                        
                        console.log('Manifest URL:', manifestURL);
                        console.log('ITMS URL:', itmsURL);
                        status.innerHTML = '<span class="loading"></span>正在触发安装...';
                        
                        // 直接尝试安装，不测试manifest URL
                        console.log('开始直接安装，跳过manifest URL测试...');
                        status.innerHTML = '<span class="loading"></span>正在触发安装...';
                        
                        // 延迟一点时间确保页面完全加载
                        setTimeout(function() {
                            try {
                                // 方法1: 直接跳转
                                window.location.href = itmsURL;
                                status.innerHTML = '<span class="loading"></span>已启动安装程序...';
                                
                                // 如果跳转成功，3秒后隐藏页面内容
                                setTimeout(function() {
                                    document.body.innerHTML = '<div style="text-align: center; padding: 50px; color: white;"><h2>✅ 查看iPhone桌面显示</h2><p>遇到问题,联系源代码作者 pxx917144686</p></div>';
                                }, 3000);
                                
                            } catch (error) {
                                console.error('方法1失败:', error);
                                status.innerHTML = '安装启动失败，正在尝试其他方法...';
                                
                                // 方法2: 使用iframe
                                try {
                                    const iframe = document.createElement('iframe');
                                    iframe.style.display = 'none';
                                    iframe.src = itmsURL;
                                    document.body.appendChild(iframe);
                                    status.innerHTML = '<span class="loading"></span>通过iframe启动安装...';
                                } catch (error2) {
                                    console.error('方法2失败:', error2);
                                    
                                    // 方法3: 使用window.open
                                    try {
                                        window.open(itmsURL, '_blank');
                                        status.innerHTML = '<span class="loading"></span>通过新窗口启动安装...';
                                    } catch (error3) {
                                        console.error('方法3失败:', error3);
                                        status.innerHTML = '自动安装失败，请手动复制URL: ' + itmsURL;
                                    }
                                }
                            }
                        }, 500);
                    }
                </script>
            </body>
            </html>
            """
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "text/html")
            response.body = .init(string: installPage)
            
            return response
        }
        
        // 图标路由
        app.get("icon", "display") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 返回默认图标或从IPA提取的图标
            let iconData = self.getDefaultIconData()
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "image/png")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: iconData)
            
            return response
        }
        
        app.get("icon", "fullsize") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // 返回默认图标或从IPA提取的图标
            let iconData = self.getDefaultIconData()
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "image/png")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: iconData)
            
            return response
        }
        
        // 测试路由
        app.get("test") { req -> Response in
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "text/plain")
            response.body = .init(string: "Simple HTTP Server is running!")
            return response
        }
        
        // 健康检查路由
        app.get("health") { req -> Response in
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/json")
            response.body = .init(string: "{\"status\":\"healthy\",\"timestamp\":\"\(Date().timeIntervalSince1970)\"}")
            return response
        }
    }
    
    func stop() {
        NSLog("🛑 [Simple HTTP功能器] 停止功能器")
        print("🛑 [Simple HTTP功能器] 停止功能器")
        
        serverQueue.async { [weak self] in
            self?.app?.shutdown()
            self?.isRunning = false
        }
    }
    
    func setPlistData(_ data: Data, fileName: String) {
        self.plistData = data
        self.plistFileName = fileName
        NSLog("✅ [Simple HTTP功能器] 已设置Plist数据: \(fileName)")
        print("✅ [Simple HTTP功能器] 已设置Plist数据: \(fileName)")
    }
    
    // MARK: - 同步获取设备IP地址
    private func getDeviceIPAddressSync() -> String {
        var address: String = "127.0.0.1" // 默认值
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return address }
        guard let firstAddr = ifaddr else { return address }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // 检查接口类型
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // 检查接口名称
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    // 获取IP地址
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        freeifaddrs(ifaddr)
        NSLog("📱 [Simple HTTP功能器] 设备IP地址: \(address)")
        print("📱 设备IP地址: \(address)")
        return address
    }
    
    // MARK: - 生成URL
    private func generateExternalManifestURL() -> String {
        // 创建本地IPA URL
        let localIP = "127.0.0.1"
        let ipaURL = "http://\(localIP):\(port)/\(appInfo.bundleIdentifier).ipa"
        
        // 创建完整的IPA下载URL（包含签名参数）
        let fullIPAURL = "\(ipaURL)?sign=1"
        
        // 使用公共代理服务转发本地URL
        let proxyURL = "https://api.palera.in/genPlist?bundleid=\(appInfo.bundleIdentifier)&name=\(appInfo.bundleIdentifier)&version=\(appInfo.version)&fetchurl=\(fullIPAURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullIPAURL)"
        
        NSLog("🔗 [APP] 外部manifest URL: \(proxyURL)")
        print("🔗 外部manifest URL: \(proxyURL)")
        
        return proxyURL
    }
    
    // MARK: - 生成Plist文件数据
    private func generatePlistData() -> Data {
        NSLog("🔧 [Simple HTTP服务器] 开始生成Plist数据...")
        
        // 使用localhost而不是设备IP地址
        let ipaURL = "http://127.0.0.1:\(port)/\(appInfo.bundleIdentifier).ipa"
        
        NSLog("🔗 [Simple HTTP服务器] 本地IPA URL: \(ipaURL)")
        NSLog("📦 [Simple HTTP服务器] AppInfo: \(appInfo.name) v\(appInfo.version) (\(appInfo.bundleIdentifier))")
        
        // 生成简化的plist内容
        let plistContent: [String: Any] = [
            "items": [[
                "assets": [
                    [
                        "kind": "software-package",
                        "url": ipaURL
                    ]
                ],
                "metadata": [
                    "bundle-identifier": appInfo.bundleIdentifier,
                    "bundle-version": appInfo.version,
                    "kind": "software",
                    "title": appInfo.name
                ]
            ]]
        ]
        
        // 转换为XML格式的plist数据
        guard let plistData = try? PropertyListSerialization.data(
            fromPropertyList: plistContent,
            format: .xml,
            options: .zero
        ) else {
            NSLog("❌ [Simple HTTP功能器] 生成Plist数据失败")
            print("❌ 生成Plist数据失败")
            return Data()
        }
        
        NSLog("📄 [Simple HTTP功能器] 生成Plist文件成功，大小: \(plistData.count) 字节")
        print("📄 生成Plist文件成功，大小: \(plistData.count) 字节")
        NSLog("🔗 [Simple HTTP功能器] 本地IPA URL: \(ipaURL)")
        print("🔗 本地IPA URL: \(ipaURL)")
        
        // 验证 plist 内容
        if let plistString = String(data: plistData, encoding: .utf8) {
            NSLog("📋 [Simple HTTP功能器] Plist内容预览:")
            print("📋 Plist内容预览:")
            NSLog(plistString)
            print(plistString)
        }
        
        return plistData
    }
    
    // MARK: - 图标处理方法
    private func getDisplayImageURL() -> String {
        // 使用本地服务器提供图标
        return "http://127.0.0.1:\(port)/icon/display"
    }
    
    private func getFullSizeImageURL() -> String {
        // 使用本地服务器提供图标
        return "http://127.0.0.1:\(port)/icon/fullsize"
    }
    
    private func getDefaultIconData() -> Data {
        // 动态图标生成实现
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 57, height: 57))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 57, height: 57))
        }
        return image.pngData() ?? Data()
        #else
        // 创建一个简单的1x1像素的PNG数据作为默认图标
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
            0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
            0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
        ])
        return pngData
        #endif
    }
    
    // MARK: - 获取设备IP地址
    private func getDeviceIPAddress() async -> String {
        var address: String = "127.0.0.1" // 默认值
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return address }
        guard let firstAddr = ifaddr else { return address }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // 检查接口类型
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // 检查接口名称
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    // 获取IP地址
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        freeifaddrs(ifaddr)
        NSLog("📱 [SimpleHTTPServer] 设备IP地址: \(address)")
        print("📱 设备IP地址: \(address)")
        
        // 测试本地服务器连接
        testLocalServerConnection(ip: address, port: 4593)
        
        // 测试 plist 和 IPA 文件可访问性
        testInstallationURLs(ip: address, port: 4593)
        
        return address
    }
    
    private func testLocalServerConnection(ip: String, port: Int) {
        NSLog("🔍 [网络测试] 开始测试连接到 \(ip):\(port)")
        print("🔍 [网络测试] 开始测试连接到 \(ip):\(port)")
        
        guard let url = URL(string: "http://\(ip):\(port)/health") else {
            NSLog("❌ [网络测试] 无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("❌ [网络测试] 连接失败: \(error.localizedDescription)")
                    print("❌ [网络测试] 连接失败: \(error.localizedDescription)")
                    
                    // 提供解决建议
                    NSLog("💡 [网络测试] 建议检查:")
                    NSLog("   1. WiFi网络是否正常")
                    NSLog("   2. 设备是否在同一网络")
                    NSLog("   3. 防火墙/路由器设置")
                    NSLog("   4. iOS本地网络权限")
                } else if let httpResponse = response as? HTTPURLResponse {
                    NSLog("✅ [网络测试] 连接成功，状态码: \(httpResponse.statusCode)")
                    print("✅ [网络测试] 连接成功，状态码: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func testInstallationURLs(ip: String, port: Int) {
        NSLog("🔍 [安装测试] 开始测试安装URL可访问性...")
        print("🔍 [安装测试] 开始测试安装URL可访问性...")
        
        // 测试 plist 文件
        let plistURL = "http://\(ip):\(port)/plist/com.tencent.qqmail"
        testURL(plistURL, name: "Plist文件")
        
        // 测试 IPA 文件
        let ipaURL = "http://\(ip):\(port)/ipa/com.tencent.qqmail"
        testURL(ipaURL, name: "IPA文件")
        
        // 测试健康检查
        let healthURL = "http://\(ip):\(port)/health"
        testURL(healthURL, name: "健康检查")
    }
    
    private func testURL(_ urlString: String, name: String) {
        guard let url = URL(string: urlString) else {
            NSLog("❌ [安装测试] \(name) URL无效: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("❌ [安装测试] \(name) 访问失败: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        NSLog("✅ [安装测试] \(name) 访问成功 (状态码: \(httpResponse.statusCode))")
                        if let data = data {
                            NSLog("📊 [安装测试] \(name) 数据大小: \(data.count) 字节")
                        }
                    } else {
                        NSLog("⚠️ [安装测试] \(name) 状态码异常: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
}
#endif

// MARK: - 安装状态
enum AdhocInstallationStatus {
    case idle
    case preparing
    case signing
    case startingServer
    case ready
    case installing
    case completed
    case failed(Error)
    
    var displayText: String {
        switch self {
        case .idle:
            return "准备安装"
        case .preparing:
            return "准备IPA文件..."
        case .signing:
            return "签名中..."
        case .startingServer:
            return "启动安装服务器..."
        case .ready:
            return "准备就绪，点击安装"
        case .installing:
            return "正在安装..."
        case .completed:
            return "安装完成"
        case .failed(let error):
            return "安装失败: \(error.localizedDescription)"
        }
    }
    
    var isInstalling: Bool {
        switch self {
        case .preparing, .signing, .startingServer, .installing:
            return true
        default:
            return false
        }
    }
}



struct DownloadView: SwiftUIView {
    @StateObject private var vm: UnifiedDownloadManager = UnifiedDownloadManager.shared
    @State private var refreshID = UUID()
    @State private var animateCards = false
    @State private var showThemeSelector = false
    @State private var isInstalling = false
    @State private var installProgress: Double = 0.0
    @State private var installStatus = ""
    
    @EnvironmentObject var themeManager: ThemeManager

    var body: some SwiftUIView {
        NavigationView {
            ZStack {
                // 背景
                themeManager.backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部安全区域占位 - 真机适配
                    GeometryReader { geometry in
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 44)
                            .onAppear {
                                print("[DownloadView] 顶部安全区域: \(geometry.safeAreaInsets.top)")
                            }
                    }
                    .frame(height: 44) // 固定高度，避免布局跳动
                    
                    // 内容区域
                    downloadManagementSegmentView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showThemeSelector.toggle()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme == .dark ? .white : .black)
                    }
                }
            }
            .overlay(
                FloatingThemeSelector(isPresented: $showThemeSelector)
            )

        }
        .onAppear {
            // 强制刷新UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[DownloadView] 强制刷新UI")
                withAnimation(.easeInOut(duration: 0.5)) {
                    animateCards = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceRefreshUI"))) { _ in
            // 接收强制刷新通知 - 真机适配
            print("[DownloadView] 接收到强制刷新通知")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                print("[DownloadView] 真机适配强制刷新完成")
                withAnimation(.easeInOut(duration: 0.5)) {
                    animateCards = true
                }
            }
        }
    }
    
    // MARK: - 下载任务分段视图
    var downloadManagementSegmentView: some SwiftUIView {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // 内容区域间距
                Spacer(minLength: 16)
                
                if isInstalling {
                    installationProgressView
                        .scaleEffect(animateCards ? 1 : 0.9)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.spring().delay(0.1), value: animateCards)
                } else if vm.downloadRequests.isEmpty {
                    emptyStateView
                        .scaleEffect(animateCards ? 1 : 0.9)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.spring().delay(0.1), value: animateCards)
                } else {
                    downloadRequestsView
                }
                
                // 添加底部间距，确保内容不会紧贴底部导航栏
                Spacer(minLength: 65)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - 安装方法
    private func startKsignInstallation() {
        guard !isInstalling else { return }
        
        isInstalling = true
        installProgress = 0.0
        installStatus = "准备安装..."
        
        Task {
            do {
                try await performKsignInstallation()
                
                await MainActor.run {
                    installProgress = 1.0
                    installStatus = "安装完成"
                    isInstalling = false
                }
            } catch {
                await MainActor.run {
                    installStatus = "安装失败: \(error.localizedDescription)"
                    isInstalling = false
                }
            }
        }
    }
    
    private func performKsignInstallation() async throws {
        NSLog("🔧 [APP] 开始安装流程")
        print("🔧 开始安装流程")
        
        // 检查是否在模拟器中运行
        #if targetEnvironment(simulator)
        NSLog("⚠️ [APP] 检测到模拟器环境 - 安装可能无法正常工作")
        print("⚠️ 检测到模拟器环境 - 安装可能无法正常工作")
        #else
        NSLog("📱 [APP] 检测到真机环境 - 将使用安装方法")
        print("📱 检测到真机环境 - 将使用安装方法")
        #endif
        
        // 获取实际的IPA文件路径
        let ipaPath = getIPAPath()
        
        await MainActor.run {
            installStatus = "正在验证IPA文件..."
            installProgress = 0.1
        }
        
        // 验证IPA文件路径是否有效
        guard !ipaPath.isEmpty else {
            throw PackageInstallationError.installationFailed("未找到IPA文件，请确保设备上有IPA文件")
        }
        
        // 验证IPA文件是否存在
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw PackageInstallationError.invalidIPAFile
        }
        
        // 从IPA文件中提取应用信息
        let appInfo = try await extractAppInfo(from: ipaPath)
        
        await MainActor.run {
            installStatus = "正在进行签名..."
            installProgress = 0.3
        }
        
        // 执行签名（参考Ksign的SigningHandler流程）
        try await performAdhocSigning(ipaPath: ipaPath, appInfo: appInfo)
        
        await MainActor.run {
            installStatus = "签名成功，准备安装..."
            installProgress = 0.6
        }
        
        // 启动HTTP服务器进行OTA安装（参考Ksign的ServerInstaller）
        #if canImport(Vapor)
        let server = SimpleHTTPServer(
            port: SimpleHTTPServer.randomPort(),
            ipaPath: ipaPath,
            appInfo: appInfo
        )
        
        server.start()
        
        await MainActor.run {
            installStatus = "安装服务器已启动，正在打开安装页面..."
            installProgress = 0.9
        }
        
        // 打开安装页面（参考Ksign的InstallPreviewView）
        if let url = URL(string: "http://127.0.0.1:\(server.port)/install") {
            #if canImport(UIKit)
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
            #endif
        }
        
        await MainActor.run {
            installStatus = "安装页面已打开，请在Safari中完成安装"
            installProgress = 1.0
        }
        
        // 延迟停止服务器
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            server.stop()
        }
        #else
        throw PackageInstallationError.installationFailed("Vapor库不可用，无法启动安装服务器")
        #endif
    }
    
    // MARK: - 获取IPA文件路径
    private func getIPAPath() -> String {
        // 从Documents目录查找IPA文件
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsURL = documentsPath.appendingPathComponent("")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            for file in files {
                if file.pathExtension.lowercased() == "ipa" {
                    NSLog("📁 [APP] 找到IPA文件: \(file.path)")
                    print("📁 找到IPA文件: \(file.path)")
                    return file.path
                }
            }
        } catch {
            NSLog("❌ [APP] 搜索IPA文件失败: \(error)")
            print("❌ 搜索IPA文件失败: \(error)")
        }
        
        // 如果Documents目录没有找到，尝试从Downloads目录查找
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let downloadsURL = downloadsPath.appendingPathComponent("")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: nil)
            for file in files {
                if file.pathExtension.lowercased() == "ipa" {
                    NSLog("📁 [APP] 在Downloads目录找到IPA文件: \(file.path)")
                    print("📁 在Downloads目录找到IPA文件: \(file.path)")
                    return file.path
                }
            }
        } catch {
            NSLog("❌ [APP] 搜索Downloads目录失败: \(error)")
            print("❌ 搜索Downloads目录失败: \(error)")
        }
        
        // 如果都没有找到，抛出错误
        NSLog("❌ [APP] 未找到任何IPA文件")
        print("❌ 未找到任何IPA文件")
        return ""
    }
    
    // MARK: - 从IPA文件提取应用信息
    private func extractAppInfo(from ipaPath: String) async throws -> AppInfo {
        NSLog("📱 [APP] 开始从IPA文件提取应用信息: \(ipaPath)")
        print("📱 开始从IPA文件提取应用信息: \(ipaPath)")
        
        // 创建临时目录来解压IPA文件
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            // 创建临时目录
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 解压IPA文件
            #if canImport(ZipArchive)
            let success = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: tempDir.path)
            guard success else {
                throw PackageInstallationError.installationFailed("IPA文件解压失败")
            }
            #else
            // 如果没有ZipArchive，使用系统方法
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", ipaPath, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw PackageInstallationError.installationFailed("IPA文件解压失败")
            }
            #endif
            
            // 查找Payload目录中的.app文件
            let payloadDir = tempDir.appendingPathComponent("Payload")
            let payloadContents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
            
            guard let appBundle = payloadContents.first(where: { $0.pathExtension == "app" }) else {
                throw PackageInstallationError.installationFailed("未找到.app文件")
            }
            
            // 读取Info.plist文件
            let infoPlistPath = appBundle.appendingPathComponent("Info.plist")
            let infoPlistData = try Data(contentsOf: infoPlistPath)
            let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, format: nil) as! [String: Any]
            
            // 提取应用信息
            let bundleIdentifier = infoPlist["CFBundleIdentifier"] as? String ?? "unknown.bundle.id"
            let appName = infoPlist["CFBundleDisplayName"] as? String ?? infoPlist["CFBundleName"] as? String ?? "Unknown App"
            let version = infoPlist["CFBundleShortVersionString"] as? String ?? infoPlist["CFBundleVersion"] as? String ?? "1.0.0"
            
            NSLog("📱 [APP] 提取的应用信息: \(appName) v\(version) (\(bundleIdentifier))")
            print("📱 提取的应用信息: \(appName) v\(version) (\(bundleIdentifier))")
            
            // 清理临时目录
            try FileManager.default.removeItem(at: tempDir)
            
            return AppInfo(
                name: appName,
                version: version,
                bundleIdentifier: bundleIdentifier,
                path: ipaPath,
                localPath: ipaPath
            )
            
        } catch {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
            throw PackageInstallationError.installationFailed("提取应用信息失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 签名方法
    private func performAdhocSigning(ipaPath: String, appInfo: AppInfo) async throws {
        print("🔐 [DownloadView] 开始签名: \(ipaPath)")
        print("📱 [DownloadView] 应用信息: \(appInfo.name) v\(appInfo.version) (\(appInfo.bundleIdentifier))")
        
        // 检查ZsignSwift库是否可用
        #if canImport(ZsignSwift)
        // 使用Task来等待签名完成，添加超时处理
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 添加签名任务
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    // 先解压IPA文件获取.app包路径
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    defer {
                        // 清理临时目录
                        try? FileManager.default.removeItem(at: tempDir)
                    }
                    
                    do {
                        // 创建临时目录
                        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                        
                        // 解压IPA文件
                        #if canImport(ZipArchive)
                        let unzipSuccess = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: tempDir.path)
                        guard unzipSuccess else {
                            throw PackageInstallationError.installationFailed("IPA文件解压失败")
                        }
                        #else
                        // 如果没有ZipArchive，使用系统方法
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                        process.arguments = ["-q", ipaPath, "-d", tempDir.path]
                        try process.run()
                        process.waitUntilExit()
                        
                        guard process.terminationStatus == 0 else {
                            throw PackageInstallationError.installationFailed("IPA文件解压失败")
                        }
                        #endif
                        
                        // 查找Payload目录中的.app文件
                        let payloadDir = tempDir.appendingPathComponent("Payload")
                        let payloadContents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
                        
                        guard let appBundle = payloadContents.first(where: { $0.pathExtension == "app" }) else {
                            throw PackageInstallationError.installationFailed("未找到.app文件")
                        }
                        
                        let appPath = appBundle.path
                        print("🔐 [DownloadView] 找到.app包路径: \(appPath)")
                        
                        let success = Zsign.sign(
                            appPath: appPath,
                            entitlementsPath: "",
                            customIdentifier: appInfo.bundleIdentifier,
                            customName: appInfo.name,
                            customVersion: appInfo.version,
                            adhoc: true,
                            removeProvision: true, // 签名时应该移除provisioning文件
                            completion: { _, error in
                                if let error = error {
                                    print("❌ [DownloadView] 签名失败: \(error)")
                                    continuation.resume(throwing: PackageInstallationError.installationFailed("签名失败: \(error.localizedDescription)"))
                                } else {
                                    print("✅ [DownloadView] 签名成功")
                                    continuation.resume()
                                }
                            }
                        )
                        
                        if !success {
                            continuation.resume(throwing: PackageInstallationError.installationFailed("签名过程启动失败"))
                        }
                        
                    } catch {
                        print("❌ [DownloadView] 解压或签名失败: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30秒超时
                throw PackageInstallationError.timeoutError
            }
            
            // 等待第一个完成的任务
            try await group.next()
            group.cancelAll()
        }
        #else
        // ZsignSwift库不可用，抛出错误
        print("❌ [DownloadCardView] ZsignSwift库不可用！")
        throw PackageInstallationError.installationFailed("ZsignSwift库不可用")
        #endif
    }
    
    /// 安装进度显示视图
    private var installationProgressView: some SwiftUIView {
        VStack(spacing: 20) {
            // 安装图标
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .scaleEffect(isInstalling ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isInstalling)
            
            // 安装状态文本
            Text(installStatus)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // 进度条
            ProgressView(value: installProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(height: 8)
            
            // 进度百分比
            Text("\(Int(installProgress * 100))%")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // 取消按钮
            Button("取消安装") {
                // TODO: 实现取消安装逻辑
                isInstalling = false
                installProgress = 0.0
                installStatus = ""
            }
            .foregroundColor(.red)
            .padding(.top, 20)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
                .shadow(radius: 10)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - 下载请求视图
    private var downloadRequestsView: some SwiftUIView {
        ForEach(Array(vm.downloadRequests.enumerated()), id: \.element.id) { enumeratedItem in
            let index = enumeratedItem.offset
            let request = enumeratedItem.element
            DownloadCardView(
                request: request
            )
            .scaleEffect(animateCards ? 1 : 0.9)
            .opacity(animateCards ? 1 : 0)
            .animation(Animation.spring().delay(Double(index) * 0.1), value: animateCards)
        }
    }
    
    private var emptyStateView: some SwiftUIView {
        VStack(spacing: 32) {
            // 图标
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(24)
                .scaleEffect(animateCards ? 1.1 : 1)
                .opacity(animateCards ? 1 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: animateCards
                )
            
            // 关于代码作者按钮 - 限制宽度的设计
            Button(action: {
                guard let url = URL(string: "https://github.com/pxx917144686"),
                    UIApplication.shared.canOpenURL(url) else {
                    return
                }
                UIApplication.shared.open(url)
            }) {
                HStack(spacing: 16) {
                    Text("👉 看看源代码")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            // 限制最大宽度并居中
            .frame(maxWidth: 200)  // 设置一个合适的最大宽度
            .padding(.horizontal, 8)
            
            // 空状态文本
            VStack(spacing: 8) {
                Text("暂无下载任务")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 下载卡片视图
struct DownloadCardView: SwiftUIView {
    @ObservedObject var request: DownloadRequest
    @EnvironmentObject var themeManager: ThemeManager
    
    // 添加状态变量
    @State private var showDetailView = false
    @State private var showInstallView = false
    
    // 安装相关状态
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationMessage: String = ""
    @State private var httpServer: SimpleHTTPServer?
    
    // Safari WebView状态
    @State private var showSafariWebView = false
    @State private var safariURL: URL?
    
    var body: some SwiftUIView {
        ModernCard {
            VStack(spacing: 16) {
                // APP信息行
                HStack(spacing: 16) {
                    // APP图标
                    AsyncImage(url: URL(string: request.package.iconURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.accentColor)
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(10)
                    
                    // APP详细信息 - 与图标紧密组合
                    VStack(alignment: .leading, spacing: 4) {
                        // APP名称
                        Text(request.package.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // Bundle ID
                        Text(request.package.bundleIdentifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // 版本信息
                        Text("版本 \(request.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // 文件大小信息（如果可用）
                        if let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            if let fileSize = getFileSize(path: localFilePath) {
                                Text("文件大小: \(fileSize)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 右上角按钮组
                    VStack(spacing: 4) {
                        // 删除按钮
                        Button(action: {
                            deleteDownload()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 分享按钮（仅在下载完成时显示）
                        if request.runtime.status == .completed,
                           let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            Button(action: {
                                shareIPAFile(path: localFilePath)
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 进度条 - 显示所有下载相关状态
                if request.runtime.status == .downloading || 
                   request.runtime.status == .waiting || 
                   request.runtime.status == .paused ||
                   request.runtime.progressValue >= 0 {
                    progressView
                }
                
                // 安装进度条 - 显示安装状态
                if isInstalling {
                    installationProgressView
                }
                
                // 操作按钮
                actionButtons
            }
            .padding(16)
        }
    }
    
    // MARK: - 操作按钮（去掉暂停功能）
    private var actionButtons: some SwiftUIView {
        VStack(spacing: 8) {
            // 主要操作按钮
            HStack(spacing: 8) {
                // 下载失败时显示重试按钮
                if request.runtime.status == .failed {
                    Button(action: {
                        retryDownload()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("重试")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                Spacer()
            }
            
            // 下载完成时显示额外信息和操作按钮
            if request.runtime.status == .completed {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("文件已保存到:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 安装按钮
                        if let localFilePath = request.localFilePath,
                           FileManager.default.fileExists(atPath: localFilePath) {
                            Button(action: {
                                startInstallation(for: request)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("开始安装")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Text(request.localFilePath ?? "未知路径")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 16) // 缩进对齐
                }
                .padding(.horizontal, 4)
            }
        }
        .onTapGesture {
            handleCardTap()
        }
        .sheet(isPresented: $showSafariWebView) {
            if let url = safariURL {
                SafariWebView(url: url)
            }
        }
    }
    
    // MARK: - 卡片点击处理
    private func handleCardTap() {
        switch request.runtime.status {
        case .completed:
            // 下载完成时，显示安装选项
            if let localFilePath = request.localFilePath, FileManager.default.fileExists(atPath: localFilePath) {
                showInstallView = true
            } else {
                // 如果文件不存在，显示详情页面
                showDetailView = true
            }
        case .failed:
            // 下载失败时，显示详情页面
            showDetailView = true
        case .cancelled:
            // 下载取消时，显示详情页面
            showDetailView = true
        default:
            // 其他状态时，显示详情页面
            showDetailView = true
        }
    }
    

    

    
    // MARK: - 分享功能
    private func shareIPAFile(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ 文件不存在: \(path)")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        #if os(iOS)
        // iOS平台使用UIActivityViewController
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // 设置分享标题
        activityViewController.setValue("分享IPA文件", forKey: "subject")
        
        // 获取当前窗口的根视图控制器
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // 在iPad上需要设置popoverPresentationController
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true) {
                print("✅ 分享界面已显示")
            }
        }
        #else
        #endif
    
    print("📤 [分享] 准备分享IPA文件: \(path)")
    }
    
    private var statusIndicator: some SwiftUIView {
        Group {
            switch request.runtime.status {
            case .waiting:
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .cancelled:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            }
        }
        .font(.title2)
    }
    
    private var progressView: some SwiftUIView {
        VStack(spacing: 4) {
            HStack {
                Label(getProgressLabel(), systemImage: getProgressIcon())
                    .font(.headline)
                    .foregroundColor(getProgressColor())
                
                Spacer()
                
                Text("\(Int(request.runtime.progressValue * 100))%")
                    .font(.title2)
                    .foregroundColor(themeManager.accentColor)
            }
            
            ProgressView(value: request.runtime.progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor()))
                .scaleEffect(y: 2.0)
            
            HStack {
                Spacer()
                
                Text(request.createdAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // 获取进度标签
    private func getProgressLabel() -> String {
        switch request.runtime.status {
        case .waiting:
            return "等待下载"
        case .downloading:
            return "正在下载"
        case .paused:
            return "已暂停"
        case .completed:
            return "下载完成"
        case .failed:
            return "下载失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    // 获取进度图标
    private func getProgressIcon() -> String {
        switch request.runtime.status {
        case .waiting:
            return "clock"
        case .downloading:
            return "arrow.down.circle"
        case .paused:
            return "pause.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    // 获取进度颜色
    private func getProgressColor() -> Color {
        switch request.runtime.status {
        case .waiting:
            return .orange
        case .downloading:
            return themeManager.accentColor
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    // 获取状态文本
    private func getStatusText() -> String {
        switch request.runtime.status {
        case .waiting:
            return "等待下载"
        case .downloading:
            return "正在下载"
        case .paused:
            return "已暂停"
        case .completed:
            return "下载完成"
        case .failed:
            return "下载失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    // 获取状态颜色
    private func getStatusColor() -> Color {
        switch request.runtime.status {
        case .waiting:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    // 获取文件大小
    private func getFileSize(path: String) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useGB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return nil
    }
    
    // MARK: - 安装进度视图
    private var installationProgressView: some SwiftUIView {
        VStack(spacing: 4) {
            HStack {
                Label("安装进度", systemImage: "arrow.up.circle")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(Int(installationProgress * 100))%")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: installationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 2.0)
            
            Text(installationMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 4)
    }

    var progressCard: some SwiftUIView {
        ModernCard(style: .elevated, padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("下载进度", systemImage: "arrow.down.circle")
                        .font(.headline)
                        .foregroundColor(themeManager.accentColor)
                    
                    Spacer()
                    
                    Text("\(Int(request.runtime.progressValue * 100))%")
                        .font(.title2)
                        .foregroundColor(themeManager.accentColor)
                }
                
                ProgressView(value: request.runtime.progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.accentColor))
                    .scaleEffect(y: 2.0)
                
                HStack {
                    Spacer()
                    
                    Text(request.createdAt.formatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 下载管理方法
    private func deleteDownload() {
        UnifiedDownloadManager.shared.deleteDownload(request: request)
    }
    
    private func retryDownload() {
        UnifiedDownloadManager.shared.startDownload(for: request)
    }
    
    // MARK: - 安装功能
    private func startInstallation(for request: DownloadRequest) {
        guard !isInstalling else { return }
        
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "准备安装..."
        
        Task {
            do {
                try await performOTAInstallation(for: request)
                
                await MainActor.run {
                    installationProgress = 1.0
                    installationMessage = "安装成功完成"
                    isInstalling = false
                }
            } catch {
                await MainActor.run {
                    installationMessage = "安装失败: \(error.localizedDescription)"
                    isInstalling = false
                }
            }
        }
    }
    
    // MARK: - 签名方法
    private func performAdhocSigning(ipaPath: String, appInfo: AppInfo) async throws {
        print("🔐 [DownloadCardView] 开始签名: \(ipaPath)")
        print("📱 [DownloadCardView] 应用信息: \(appInfo.name) v\(appInfo.version) (\(appInfo.bundleIdentifier))")
        
        // 检查ZsignSwift库是否可用
        print("🔍 [DownloadCardView] 检查ZsignSwift库可用性...")
        
        // 直接测试ZsignSwift是否可用
        #if canImport(ZsignSwift)
        print("🔍 [DownloadCardView] ZsignSwift库已导入，开始测试...")
        
        // 测试Zsign枚举是否可用
        let testResult = Zsign.checkSigned(appExecutable: "/System/Library/CoreServices/SpringBoard.app/SpringBoard")
        print("🔍 [DownloadCardView] Zsign功能测试结果: \(testResult)")
        #else
        print("❌ [DownloadCardView] ZsignSwift库未导入！")
        #endif
        
        #if canImport(ZsignSwift)
        print("🔍 [DownloadCardView] ZsignSwift库可用，开始签名...")
        
        // 先测试ZsignSwift库是否真的可用
        print("🔍 [DownloadCardView] 测试ZsignSwift库可用性...")
        
        // 先解压IPA文件获取.app包路径进行测试
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        do {
            // 创建临时目录
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 解压IPA文件
            #if canImport(ZipArchive)
            let unzipSuccess = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: tempDir.path)
            guard unzipSuccess else {
                throw PackageInstallationError.installationFailed("IPA文件解压失败")
            }
            #else
            // 如果没有ZipArchive，使用系统方法
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", ipaPath, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw PackageInstallationError.installationFailed("IPA文件解压失败")
            }
            #endif
            
            // 查找Payload目录中的.app文件
            let payloadDir = tempDir.appendingPathComponent("Payload")
            let payloadContents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
            
            guard let appBundle = payloadContents.first(where: { $0.pathExtension == "app" }) else {
                throw PackageInstallationError.installationFailed("未找到.app文件")
            }
            
            let appPath = appBundle.path
            print("🔍 [DownloadCardView] 测试用.app包路径: \(appPath)")
            
            let testResult = Zsign.sign(
                appPath: appPath,
                entitlementsPath: "",
                customIdentifier: appInfo.bundleIdentifier,
                customName: appInfo.name,
                customVersion: appInfo.version,
                adhoc: true,
                removeProvision: true,
                completion: { _, error in
                    print("🔍 [DownloadCardView] 测试签名回调被调用: \(error?.localizedDescription ?? "成功")")
                }
            )
            print("🔍 [DownloadCardView] 测试签名返回值: \(testResult)")
            
            if !testResult {
                throw PackageInstallationError.installationFailed("ZsignSwift库测试失败，无法启动签名")
            }
            
        } catch {
            print("❌ [DownloadCardView] 测试解压失败: \(error)")
            throw PackageInstallationError.installationFailed("测试解压失败: \(error.localizedDescription)")
        }
        
        // 使用Task来等待签名完成，添加超时处理
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 添加签名任务
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    print("🔍 [DownloadCardView] 准备调用Zsign.sign...")
                    print("🔍 [DownloadCardView] 参数: appPath=\(ipaPath)")
                    print("🔍 [DownloadCardView] 参数: bundleId=\(appInfo.bundleIdentifier)")
                    print("🔍 [DownloadCardView] 参数: appName=\(appInfo.name)")
                    print("🔍 [DownloadCardView] 参数: version=\(appInfo.version)")
                    
                    // 先解压IPA文件获取.app包路径
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    defer {
                        // 清理临时目录
                        try? FileManager.default.removeItem(at: tempDir)
                    }
                    
                    do {
                        // 创建临时目录
                        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                        
                        // 解压IPA文件
                        #if canImport(ZipArchive)
                        let unzipSuccess = SSZipArchive.unzipFile(atPath: ipaPath, toDestination: tempDir.path)
                        guard unzipSuccess else {
                            throw PackageInstallationError.installationFailed("IPA文件解压失败")
                        }
                        #else
                        // 如果没有ZipArchive，使用系统方法
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                        process.arguments = ["-q", ipaPath, "-d", tempDir.path]
                        try process.run()
                        process.waitUntilExit()
                        
                        guard process.terminationStatus == 0 else {
                            throw PackageInstallationError.installationFailed("IPA文件解压失败")
                        }
                        #endif
                        
                        // 查找Payload目录中的.app文件
                        let payloadDir = tempDir.appendingPathComponent("Payload")
                        let payloadContents = try FileManager.default.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
                        
                        guard let appBundle = payloadContents.first(where: { $0.pathExtension == "app" }) else {
                            throw PackageInstallationError.installationFailed("未找到.app文件")
                        }
                        
                        let appPath = appBundle.path
                        print("🔍 [DownloadCardView] 实际签名用.app包路径: \(appPath)")
                        
                        let success = Zsign.sign(
                            appPath: appPath,
                            entitlementsPath: "",
                            customIdentifier: appInfo.bundleIdentifier,
                            customName: appInfo.name,
                            customVersion: appInfo.version,
                            adhoc: true,
                            removeProvision: true, // 签名时应该移除provisioning文件
                            completion: { _, error in
                                print("🔍 [DownloadCardView] Zsign.sign completion回调被调用")
                                if let error = error {
                                    print("❌ [DownloadCardView] 签名失败: \(error)")
                                    continuation.resume(throwing: PackageInstallationError.installationFailed("签名失败: \(error.localizedDescription)"))
                                } else {
                                    print("✅ [DownloadCardView] 签名成功")
                                    continuation.resume()
                                }
                            }
                        )
                        
                        if !success {
                            continuation.resume(throwing: PackageInstallationError.installationFailed("签名过程启动失败"))
                        }
                        
                    } catch {
                        print("❌ [DownloadCardView] 解压或签名失败: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30秒超时
                throw PackageInstallationError.timeoutError
            }
            
            // 等待第一个完成的任务
            try await group.next()
            group.cancelAll()
        }
        #else
        // ZsignSwift库不可用，抛出错误
        print("❌ [DownloadCardView] ZsignSwift库不可用！")
        throw PackageInstallationError.installationFailed("ZsignSwift库不可用")
        #endif
    }
    
    private func performOTAInstallation(for request: DownloadRequest) async throws {
        NSLog("🔧 [APP] 开始简化安装流程")
        NSLog("⏰ [APP] 安装开始时间: \(Date())")
        NSLog("📋 [APP] 下载请求ID: \(request.id)")
        print("🔧 开始简化安装流程")
        print("⏰ 安装开始时间: \(Date())")
        print("📋 下载请求ID: \(request.id)")
        
        guard let localFilePath = request.localFilePath else {
            NSLog("❌ [APP] 本地文件路径为空")
            throw PackageInstallationError.invalidIPAFile
        }
        
        NSLog("✅ [APP] 本地文件路径验证通过: \(localFilePath)")
        
        // 创建AppInfo
        let appInfo = AppInfo(
            name: request.package.name,
            version: request.version,
            bundleIdentifier: request.package.bundleIdentifier,
            path: localFilePath
        )
        
        NSLog("📱 [APP] AppInfo创建成功:")
        NSLog("   - 名称: \(request.package.name)")
        NSLog("   - 版本: \(request.version)")
        NSLog("   - Bundle ID: \(request.package.bundleIdentifier)")
        NSLog("   - 路径: \(localFilePath)")
        print("📱 AppInfo: \(request.package.name) v\(request.version) (\(request.package.bundleIdentifier))")
        print("📁 IPA路径: \(localFilePath)")
        
        await MainActor.run {
            installationMessage = "正在验证IPA文件..."
            installationProgress = 0.2
        }
        
        NSLog("🔍 [APP] 开始验证IPA文件...")
        // 验证IPA文件是否存在
        guard FileManager.default.fileExists(atPath: localFilePath) else {
            NSLog("❌ [APP] IPA文件不存在: \(localFilePath)")
            throw PackageInstallationError.invalidIPAFile
        }
        
        // 获取文件大小
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localFilePath)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useGB]
                formatter.countStyle = .file
                let fileSizeString = formatter.string(fromByteCount: fileSize)
                NSLog("✅ [APP] IPA文件验证成功 - 大小: \(fileSizeString)")
            }
        } catch {
            NSLog("⚠️ [APP] 无法获取文件大小: \(error)")
        }
        
        await MainActor.run {
            installationMessage = "正在进行签名..."
            installationProgress = 0.4
        }
        
        NSLog("🔐 [APP] 开始执行签名...")
        // 执行签名
        try await self.performAdhocSigning(ipaPath: localFilePath, appInfo: appInfo)
        NSLog("✅ [APP] 签名完成")
        
        await MainActor.run {
            installationMessage = "签名成功，准备安装..."
            installationProgress = 0.6
        }
        
        // 启动HTTP服务器
        NSLog("🚀 [APP] 创建HTTP服务器...")
        let serverPort = SimpleHTTPServer.randomPort()
        NSLog("🔢 [APP] 随机端口: \(serverPort)")
        
        let server = SimpleHTTPServer(
            port: serverPort,
            ipaPath: localFilePath,
            appInfo: appInfo
        )
        
        NSLog("✅ [APP] HTTP服务器创建成功，开始启动...")
        server.start()
        
        // 等待服务器启动
        NSLog("⏳ [APP] 等待服务器启动 (4秒)...")
        try await Task.sleep(nanoseconds: 4_000_000_000) // 等待4秒
        NSLog("✅ [APP] 服务器启动等待完成")
        
        // 测试服务器连接
        NSLog("🔍 [APP] 开始测试服务器连接...")
        await testServerConnection(port: server.port)
        
        await MainActor.run {
            installationMessage = "正在生成安装URL..."
            installationProgress = 0.8
        }
        
        // 获取设备IP地址
        NSLog("🌐 [APP] 开始获取设备IP地址...")
        let deviceIP = await getDeviceIPAddress()
        NSLog("📱 [APP] 设备IP地址获取成功: \(deviceIP)")
        NSLog("🔢 [APP] 服务器端口: \(server.port)")
        print("📱 设备IP地址: \(deviceIP)")
        
        // 生成安装URL - 智能选择IP地址
        NSLog("🔗 [APP] 开始生成安装URL...")
        
        // 优先使用localhost，因为iOS系统对localhost访问更友好
        let manifestURL = "http://127.0.0.1:\(server.port)/plist/\(appInfo.bundleIdentifier)"
        let encodedManifestURL = manifestURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestURL
        let itmsURL = "itms-services://?action=download-manifest&url=\(encodedManifestURL)"
        
        NSLog("💡 [APP] 使用localhost地址，避免iOS网络限制")
        
        NSLog("🔗 [APP] Manifest URL: \(manifestURL)")
        NSLog("🔗 [APP] 编码后的Manifest URL: \(encodedManifestURL)")
        NSLog("🔗 [APP] ITMS URL: \(itmsURL)")
        print("🔗 Manifest URL: \(manifestURL)")
        print("🔗 ITMS URL: \(itmsURL)")
        
        // 测试plist文件访问
        NSLog("🔍 [APP] 开始测试plist文件访问...")
        await testPlistAccess(manifestURL: manifestURL)
        
        await MainActor.run {
            installationMessage = "正在打开iOS安装对话框..."
            installationProgress = 0.9
        }
        
        // 使用Safari WebView打开安装页面
        NSLog("🔍 [APP] 开始创建安装页面URL...")
        let localInstallURL = "http://127.0.0.1:\(server.port)/install"
        
        if let installURL = URL(string: localInstallURL) {
            NSLog("✅ [APP] 安装页面URL创建成功: \(installURL)")
            NSLog("🔍 [APP] 准备在Safari WebView中打开安装页面...")
            print("🔍 准备在Safari WebView中打开安装页面: \(installURL)")
            
            // 先测试本地服务器连接
            NSLog("🌐 [APP] 开始测试本地服务器连接...")
            await testNetworkConnectivity(deviceIP: "127.0.0.1", port: server.port)
            
            NSLog("📱 [APP] 准备在主线程中打开Safari WebView...")
            DispatchQueue.main.async {
                NSLog("🚀 [APP] 开始设置Safari WebView...")
                self.safariURL = installURL
                self.showSafariWebView = true
                NSLog("✅ [APP] 正在Safari WebView中打开安装页面")
                print("✅ 正在Safari WebView中打开安装页面")
                
                // 延迟关闭Safari WebView，给用户足够时间看到安装弹窗
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    self.showSafariWebView = false
                    NSLog("🔒 [APP] 自动关闭Safari WebView")
                    print("🔒 自动关闭Safari WebView")
                    
                    // 延迟停止服务器
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        server.stop()
                        NSLog("🛑 [APP] 停止HTTP服务器")
                        print("🛑 停止HTTP服务器")
                    }
                }
            }
        } else {
            NSLog("❌ [APP] 无法创建安装页面URL: \(localInstallURL)")
            throw PackageInstallationError.installationFailed("无法创建安装页面URL")
        }
        
        await MainActor.run {
            installationMessage = "iOS安装对话框已打开"
            installationProgress = 1.0
        }
    }
    
    // MARK: - 测试服务器连接
    private func testServerConnection(port: Int) async {
        let testURL = "http://127.0.0.1:\(port)/test"
        NSLog("🔍 [APP] 测试服务器连接 - URL: \(testURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: testURL)!)
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("📡 [APP] 服务器连接测试 - 状态码: \(httpResponse.statusCode)")
                NSLog("📡 [APP] 响应数据大小: \(data.count) 字节")
                
                if httpResponse.statusCode == 200 {
                    NSLog("✅ [APP] 服务器连接测试成功")
                    if let responseString = String(data: data, encoding: .utf8) {
                        NSLog("📄 [APP] 服务器响应: \(responseString)")
                    }
                } else {
                    NSLog("❌ [APP] 服务器连接测试失败，状态码: \(httpResponse.statusCode)")
                }
            }
        } catch {
            NSLog("❌ [APP] 服务器连接测试错误: \(error)")
        }
    }
    
    // MARK: - 测试网络连接
    private func testNetworkConnectivity(deviceIP: String, port: Int) async {
        NSLog("🌐 [APP] 开始测试网络连接...")
        NSLog("📱 [APP] 测试设备IP: \(deviceIP)")
        NSLog("🔢 [APP] 测试端口: \(port)")
        
        let testURLs = [
            "http://\(deviceIP):\(port)/test",
            "http://\(deviceIP):\(port)/health"
        ]
        
        var successCount = 0
        for (index, testURL) in testURLs.enumerated() {
            NSLog("🔍 [APP] 测试URL \(index + 1)/\(testURLs.count): \(testURL)")
            guard let url = URL(string: testURL) else { 
                NSLog("❌ [APP] 无法创建URL: \(testURL)")
                continue 
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    NSLog("📡 [APP] 网络连接测试 - \(testURL)")
                    NSLog("   - 状态码: \(httpResponse.statusCode)")
                    NSLog("   - 响应大小: \(data.count) 字节")
                    
                    if httpResponse.statusCode == 200 {
                        NSLog("✅ [APP] 网络连接测试成功: \(testURL)")
                        successCount += 1
                        if let responseString = String(data: data, encoding: .utf8) {
                            NSLog("📄 [APP] 响应内容: \(responseString)")
                        }
                    } else {
                        NSLog("❌ [APP] 网络连接测试失败 - 状态码: \(httpResponse.statusCode)")
                    }
                }
            } catch {
                NSLog("❌ [APP] 网络连接测试失败 - \(testURL)")
                NSLog("   - 错误: \(error)")
            }
        }
        
        if successCount > 0 {
            NSLog("✅ [APP] 网络连接测试完成 - 成功: \(successCount)/\(testURLs.count)")
        } else {
            NSLog("⚠️ [APP] 网络连接测试失败，可能影响安装")
            NSLog("💡 [APP] 建议检查:")
            NSLog("   1. 设备IP地址是否正确: \(deviceIP)")
            NSLog("   2. 服务器是否正在运行")
            NSLog("   3. 防火墙设置")
            NSLog("   4. 本地网络权限")
        }
    }
    
    // MARK: - 测试plist文件访问
    private func testPlistAccess(manifestURL: String) async {
        NSLog("📄 [APP] 开始测试plist文件访问...")
        NSLog("🔗 [APP] Manifest URL: \(manifestURL)")
        
        guard let url = URL(string: manifestURL) else {
            NSLog("❌ [APP] 无法创建plist测试URL: \(manifestURL)")
            return
        }
        
        NSLog("✅ [APP] URL创建成功，开始请求...")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("📡 [APP] Plist文件访问测试结果:")
                NSLog("   - 状态码: \(httpResponse.statusCode)")
                NSLog("   - 文件大小: \(data.count) 字节")
                NSLog("   - Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
                
                if httpResponse.statusCode == 200 {
                    NSLog("✅ [APP] Plist文件访问成功")
                    if let plistString = String(data: data, encoding: .utf8) {
                        let preview = String(plistString.prefix(300))
                        NSLog("📋 [APP] Plist内容预览:")
                        NSLog("\(preview)...")
                        
                        // 验证plist格式
                        if plistString.contains("<?xml") && plistString.contains("plist") {
                            NSLog("✅ [APP] Plist格式验证通过")
                        } else {
                            NSLog("⚠️ [APP] Plist格式可能有问题")
                        }
                    } else {
                        NSLog("⚠️ [APP] 无法解析plist内容为字符串")
                    }
                } else {
                    NSLog("❌ [APP] Plist文件访问失败，状态码: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        NSLog("📄 [APP] 错误响应: \(errorData)")
                    }
                }
            }
        } catch {
            NSLog("❌ [APP] Plist文件访问测试失败: \(error)")
            NSLog("💡 [APP] 可能的原因:")
            NSLog("   1. 网络连接问题")
            NSLog("   2. 服务器未启动")
            NSLog("   3. 路由配置错误")
            NSLog("   4. 文件不存在")
        }
    }
    
    // MARK: - 获取设备IP地址
    private func getDeviceIPAddress() async -> String {
        NSLog("🌐 [APP] 开始获取设备IP地址...")
        var address: String = "127.0.0.1" // 默认值
        var interfaceCount = 0
        var foundInterfaces: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { 
            NSLog("❌ [APP] getifaddrs调用失败")
            return address 
        }
        guard let firstAddr = ifaddr else { 
            NSLog("❌ [APP] 无法获取网络接口列表")
            return address 
        }
        
        NSLog("🔍 [APP] 开始扫描网络接口...")
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            interfaceCount += 1
            
            // 检查接口类型
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                // 检查接口名称
                let name = String(cString: interface.ifa_name)
                foundInterfaces.append(name)
                NSLog("🔍 [APP] 发现IPv4接口: \(name)")
                
                if name == "en0" || name == "pdp_ip0" {
                    NSLog("✅ [APP] 找到目标接口: \(name)")
                    // 获取IP地址
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    NSLog("✅ [APP] 成功获取IP地址: \(address) (接口: \(name))")
                    break
                }
            }
        }
        
        freeifaddrs(ifaddr)
        NSLog("📊 [APP] 网络接口扫描完成:")
        NSLog("   - 总接口数: \(interfaceCount)")
        NSLog("   - 发现的接口: \(foundInterfaces.joined(separator: ", "))")
        NSLog("   - 最终IP地址: \(address)")
        print("📱 设备IP地址: \(address)")
        return address
    }
}

// MARK: - 类型定义
public enum SigningFileHandlerError: Error, LocalizedError {
    case disinjectFailed
    case missingCertifcate
    
    public var errorDescription: String? {
        switch self {
        case .disinjectFailed:
            return "反注入失败"
        case .missingCertifcate:
            return "缺少证书"
        }
    }
}

public struct Options {
    public var disInjectionFiles: [String] = []
    public var appEntitlementsFile: URL?
    public var appIdentifier: String?
    public var appName: String?
    public var appVersion: String?
    public var removeProvisioning: Bool = true
    
    public init() {}
}

public class OptionsManager {
    public static let shared = OptionsManager()
    public var options = Options()
    
    private init() {}
}

public struct CertificatePair {
    public var password: String?
    
    public init(password: String? = nil) {
        self.password = password
    }
}

public enum StorageType {
    case provision
    case certificate
}

public class Storage {
    public static let shared = Storage()
    
    private init() {}
    
    public func getFile(_ type: StorageType, from cert: CertificatePair) -> URL? {
        // 简化实现，返回nil
        return nil
    }
}