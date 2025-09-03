//
//  DownloadView.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/29.
//

import SwiftUI
import UIKit
import Combine
#if canImport(UIKit)
import SafariServices
#endif
import Vapor
import Foundation

// 明确指定使用SwiftUI的View类型
typealias SwiftUIView = SwiftUI.View

// MARK: - Safari WebView
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

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
    
    public init(name: String, version: String, bundleIdentifier: String, path: String) {
        self.name = name
        self.version = version
        self.bundleIdentifier = bundleIdentifier
        self.path = path
    }
}

// MARK: - 简化HTTP服务器（基于MuffinStoreJailed方法）
class SimpleHTTPServer: NSObject {
    public let port: Int  // 改为public以便外部访问
    private let ipaPath: String
    private let appInfo: AppInfo
    private var app: Application?
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "simple.server.queue", qos: .userInitiated)
    private var plistData: Data?
    private var plistFileName: String?
    
    init(port: Int, ipaPath: String, appInfo: AppInfo) {
        self.port = port
        self.ipaPath = ipaPath
        self.appInfo = appInfo
        super.init()
    }
    
    func start() {
        NSLog("🚀 [Simple HTTP服务器] 启动服务器，端口: \(port)")
        print("🚀 [Simple HTTP服务器] 启动服务器，端口: \(port)")
        
        serverQueue.async { [weak self] in
            self?.startSimpleServer()
        }
    }
    
    private func startSimpleServer() {
        do {
            // 创建Vapor应用
            let config = Environment(name: "development", arguments: ["serve"])
            app = Application(config)
            
            // 配置服务器 - 监听所有接口
            app?.http.server.configuration.port = port
            app?.http.server.configuration.address = .hostname("0.0.0.0", port: port)
            app?.http.server.configuration.tcpNoDelay = true
            app?.threadPool = .init(numberOfThreads: 1)
            
            // 不设置TLS配置，强制HTTP
            app?.http.server.configuration.tlsConfiguration = nil
            
            // 设置路由
            setupSimpleRoutes()
            
            // 启动服务器
            try app?.run()
            
            isRunning = true
            NSLog("✅ [Simple HTTP服务器] 服务器已启动，端口: \(port)")
            print("✅ [Simple HTTP服务器] 服务器已启动，端口: \(port)")
            
        } catch {
            NSLog("❌ [Simple HTTP服务器] 启动失败: \(error)")
            print("❌ [Simple HTTP服务器] 启动失败: \(error)")
            isRunning = false
        }
    }
    
    private func setupSimpleRoutes() {
        guard let app = app else { return }
        
        // 提供IPA文件服务
        app.get("ipa", ":filename") { [weak self] req -> Response in
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                return Response(status: .notFound)
            }
            
            guard let ipaData = try? Data(contentsOf: URL(fileURLWithPath: self.ipaPath)) else {
                return Response(status: .notFound)
            }
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/octet-stream")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: ipaData)
            
            return response
        }
        
        // 提供Plist文件服务
        app.get("plist", ":filename") { [weak self] req -> Response in
            guard let self = self,
                  let filename = req.parameters.get("filename"),
                  filename == self.appInfo.bundleIdentifier else {
                return Response(status: .notFound)
            }
            
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "application/xml")
            response.headers.add(name: "Access-Control-Allow-Origin", value: "*")
            response.headers.add(name: "Cache-Control", value: "no-cache")
            response.body = .init(data: self.generatePlistData())
            
            return response
        }
        
        // 提供Plist文件服务（通过base64编码的路径）
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
                        
                        console.log('尝试打开URL:', itmsURL);
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
        
        // 测试路由
        app.get("test") { req -> Response in
            let response = Response(status: .ok)
            response.headers.add(name: "Content-Type", value: "text/plain")
            response.body = .init(string: "Simple HTTP Server is running!")
            return response
        }
    }
    
    func stop() {
        NSLog("🛑 [Simple HTTP服务器] 停止服务器")
        print("🛑 [Simple HTTP服务器] 停止服务器")
        
        serverQueue.async { [weak self] in
            self?.app?.shutdown()
            self?.isRunning = false
        }
    }
    
    func setPlistData(_ data: Data, fileName: String) {
        self.plistData = data
        self.plistFileName = fileName
        NSLog("✅ [Simple HTTP服务器] 已设置Plist数据: \(fileName)")
        print("✅ [Simple HTTP服务器] 已设置Plist数据: \(fileName)")
    }
    
    // MARK: - 生成类似MuffinStoreJailed的URL
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
        // 创建本地IPA URL
        let localIP = "127.0.0.1"
        let ipaURL = "http://\(localIP):\(port)/\(appInfo.bundleIdentifier).ipa"
        
        // 创建完整的IPA下载URL（包含签名参数）
        let fullIPAURL = "\(ipaURL)?sign=1"
        
        // 使用公共代理服务转发本地URL
        let proxyURL = "https://api.palera.in/genPlist?bundleid=\(appInfo.bundleIdentifier)&name=\(appInfo.bundleIdentifier)&version=\(appInfo.version)&fetchurl=\(fullIPAURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullIPAURL)"
        
        // 生成plist内容
        let plistContent: [String: Any] = [
            "items": [[
                "assets": [
                    [
                        "kind": "software-package",
                        "url": proxyURL
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
            NSLog("❌ [Simple HTTP服务器] 生成Plist数据失败")
            print("❌ 生成Plist数据失败")
            return Data()
        }
        
        NSLog("📄 [Simple HTTP服务器] 生成Plist文件成功，大小: \(plistData.count) 字节")
        print("📄 生成Plist文件成功，大小: \(plistData.count) 字节")
        NSLog("🔗 [Simple HTTP服务器] 代理URL: \(proxyURL)")
        print("🔗 代理URL: \(proxyURL)")
        
        return plistData
    }
}

// MARK: - 可复用安装组件
struct IPAAutoInstaller: SwiftUIView {
    let ipaPath: String
    let appName: String
    let appVersion: String
    let bundleIdentifier: String
    
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationMessage: String = ""
    @State private var showInstallationSheet = false
    @State private var httpServer: SimpleHTTPServer?
    
    var body: some SwiftUIView {
        Button(action: {
            showInstallationSheet = true
        }) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                Text("安装APP")
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showInstallationSheet) {
            InstallationSheetView(
                ipaPath: ipaPath,
                appName: appName,
                appVersion: appVersion,
                bundleIdentifier: bundleIdentifier,
                isPresented: $showInstallationSheet
            )
        }
    }
}

// MARK: - 安装弹窗视图
struct InstallationSheetView: SwiftUIView {
    let ipaPath: String
    let appName: String
    let appVersion: String
    let bundleIdentifier: String
    @Binding var isPresented: Bool
    
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationMessage: String = ""
    @State private var httpServer: SimpleHTTPServer?
    @State private var showSafariWebView = false
    @State private var safariURL: URL?
    
    var body: some SwiftUIView {
        NavigationView {
            VStack(spacing: 20) {
                // APP信息卡片
                appInfoCard
                
                // 安装进度
                if isInstalling {
                    installationProgressCard
                }
                
                // 安装按钮
                installButton
                
                Spacer()
            }
            .padding()
            .navigationTitle("APP安装")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    isPresented = false
                }
            )
        }
        .sheet(isPresented: $showSafariWebView) {
            if let url = safariURL {
                SafariWebView(url: url)
            }
        }
    }
    
    // MARK: - 视图组件
    private var appInfoCard: some SwiftUIView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("版本 \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var installationProgressCard: some SwiftUIView {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.green)
                
                Text("安装进度")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: installationProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text(installationMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var installButton: some SwiftUIView {
        Button(action: startInstallation) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("开始安装")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isInstalling ? Color.gray : Color.blue)
            .cornerRadius(12)
        }
        .disabled(isInstalling)
    }
    
    // MARK: - 安装逻辑
    private func startInstallation() {
        guard !isInstalling else { return }
        
        isInstalling = true
        installationProgress = 0.0
        installationMessage = "准备安装..."
        
        Task {
            do {
                try await performOTAInstallation()
                
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
    
    private func performOTAInstallation() async throws {
        NSLog("🔧 [APP] 开始OTA安装流程")
        print("🔧 开始OTA安装流程")
                
        // 创建AppInfo
        let appInfo = AppInfo(
            name: appName,
            version: appVersion,
            bundleIdentifier: bundleIdentifier,
            path: ipaPath
        )
        
        NSLog("📱 [APP] AppInfo: \(appName) v\(appVersion) (\(bundleIdentifier))")
        print("📱 AppInfo: \(appName) v\(appVersion) (\(bundleIdentifier))")
        NSLog("📁 [APP] IPA路径: \(ipaPath)")
        print("📁 IPA路径: \(ipaPath)")
        
        await MainActor.run {
            installationMessage = "正在验证IPA文件..."
            installationProgress = 0.2
        }
        
        // 验证IPA文件是否存在
        guard FileManager.default.fileExists(atPath: ipaPath) else {
            throw PackageInstallationError.invalidIPAFile
        }
        
        await MainActor.run {
            installationMessage = "正在启动HTTP服务器..."
            installationProgress = 0.4
        }
        
        // 启动简化HTTP服务器
        let serverPort = Int.random(in: 8000...9000)
        self.httpServer = SimpleHTTPServer(port: serverPort, ipaPath: ipaPath, appInfo: appInfo)
        self.httpServer?.start()
        
        // 等待服务器启动
        try await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
        
        // 测试服务器是否正常工作
        await testServerConnection(port: serverPort)
        
        await MainActor.run {
            installationMessage = "正在生成安装页面..."
            installationProgress = 0.6
        }
        
        // 生成本地安装页面URL
        let localInstallURL = "http://127.0.0.1:\(serverPort)/install"
        
        NSLog("🔗 [APP] 本地安装页面URL: \(localInstallURL)")
        print("🔗 本地安装页面URL: \(localInstallURL)")
        
        await MainActor.run {
            installationMessage = "正在打开安装页面..."
            installationProgress = 0.9
        }
        
        // 使用Safari WebView打开安装页面
        await MainActor.run {
            if let installURL = URL(string: localInstallURL) {
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
                        self.httpServer?.stop()
                        NSLog("🛑 [APP] 停止HTTP服务器")
                        print("🛑 停止HTTP服务器")
                    }
                }
            } else {
                NSLog("❌ [APP] 无法创建安装页面URL")
                print("❌ 无法创建安装页面URL")
                self.httpServer?.stop()
            }
        }
        
        NSLog("🎯 [APP] OTA安装流程完成")
        print("🎯 OTA安装流程完成")
        NSLog("📱 [APP] 请在Safari中完成安装")
        print("📱 请在Safari中完成安装")
    }
    
    // MARK: - 服务器测试
    private func testServerConnection(port: Int) async {
        let testURL = "http://127.0.0.1:\(port)/test"
        
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: testURL)!)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                NSLog("✅ [APP] 服务器连接测试成功")
                print("✅ 服务器连接测试成功")
            } else {
                NSLog("⚠️ [APP] 服务器连接测试失败")
                print("⚠️ 服务器连接测试失败")
            }
        } catch {
            NSLog("⚠️ [APP] 服务器连接测试错误: \(error)")
            print("⚠️ 服务器连接测试错误: \(error)")
        }
    }
}



struct DownloadView: SwiftUIView {
    @StateObject private var vm: UnifiedDownloadManager = UnifiedDownloadManager.shared
    // 使用独立的安装器，不再依赖 InstallerCoordinator
    // @StateObject private var installerCoordinator: InstallerCoordinator = InstallerCoordinator.shared
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
            LazyVStack(spacing: Spacing.md) {
                // 内容区域间距
                Spacer(minLength: Spacing.md)
                
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
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
    }
    
    
    // MARK: - 安装方法
    
    /// 使用InstallerCoordinator安装IPA文件
    private func installIPAFile(at path: String) {
        guard !isInstalling else { return }
        
        isInstalling = true
        installProgress = 0.0
        installStatus = "准备安装..."
        
        // 创建安装选项
        // TODO: 使用新的安装选项结构
        
        // TODO: 集成新的安装逻辑
        // 暂时使用模拟安装过程
        DispatchQueue.main.async {
            isInstalling = true
            installProgress = 0.0
            installStatus = "准备安装..."
        }
        
        // 模拟安装进度
        Task {
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                await MainActor.run {
                    installProgress = progress
                    installStatus = "安装中... \(Int(progress * 100))%"
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            await MainActor.run {
                isInstalling = false
                installProgress = 1.0
                installStatus = "安装完成"
            }
        }
    }
    

    
    // MARK: - 子视图
    
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
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
        .padding(.horizontal, 20)
            }
        
    // MARK: - 下载请求视图
    private var downloadRequestsView: some SwiftUIView {
        ForEach(Array(vm.downloadRequests.enumerated()), id: \.element.id) { index, request in
            DownloadCardView(
                request: request
            )
            .scaleEffect(animateCards ? 1 : 0.9)
            .opacity(animateCards ? 1 : 0)
            .animation(.spring().delay(Double(index) * 0.1), value: animateCards)
        }
    }
        
    private var emptyStateView: some SwiftUIView {
        VStack(spacing: Spacing.xl) {
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
                HStack(spacing: Spacing.md) {
                    Text("👉 看看源代码")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
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
            .padding(.horizontal, Spacing.sm)
            
            // 空状态文本
            VStack(spacing: Spacing.sm) {
                Text("暂无下载任务")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Spacing.xl)
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
            VStack(spacing: Spacing.md) {
                // APP信息行
                HStack(spacing: Spacing.md) {
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
                    VStack(alignment: .leading, spacing: Spacing.xs) {
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
                    VStack(spacing: Spacing.xs) {
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
            .padding(Spacing.md)
        }
    }
    
    // MARK: - 操作按钮（去掉暂停功能）
    private var actionButtons: some SwiftUIView {
        VStack(spacing: Spacing.sm) {
            // 主要操作按钮
            HStack(spacing: Spacing.sm) {
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
                VStack(alignment: .leading, spacing: Spacing.xs) {
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
    

    
    private func retryDownload() {
        UnifiedDownloadManager.shared.startDownload(for: request)
    }
    
    private func deleteDownload() {
        UnifiedDownloadManager.shared.deleteDownload(request: request)
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
    
    private func performOTAInstallation(for request: DownloadRequest) async throws {
        NSLog("🔧 [APP] 开始OTA安装流程")
        print("🔧 开始OTA安装流程")
        
        // 检查是否在模拟器中运行
        #if targetEnvironment(simulator)
        NSLog("⚠️ [APP] 检测到模拟器环境 - 安装可能无法正常工作")
        print("⚠️ 检测到模拟器环境 - 安装可能无法正常工作")
        #else
        NSLog("📱 [APP] 检测到真机环境 - 将使用OTA安装方法")
        print("📱 检测到真机环境 - 将使用OTA安装方法")
        #endif
        
        guard let localFilePath = request.localFilePath else {
            throw PackageInstallationError.invalidIPAFile
        }
        
        // 创建AppInfo
        let appInfo = AppInfo(
            name: request.package.name,
            version: request.version,
            bundleIdentifier: request.package.bundleIdentifier,
            path: localFilePath
        )
        
        NSLog("📱 [APP] AppInfo: \(request.package.name) v\(request.version) (\(request.package.bundleIdentifier))")
        print("📱 AppInfo: \(request.package.name) v\(request.version) (\(request.package.bundleIdentifier))")
        NSLog("📁 [APP] IPA路径: \(localFilePath)")
        print("📁 IPA路径: \(localFilePath)")
        
        await MainActor.run {
            installationMessage = "正在验证IPA文件..."
            installationProgress = 0.2
        }
        
        // 验证IPA文件是否存在
        guard FileManager.default.fileExists(atPath: localFilePath) else {
            throw PackageInstallationError.invalidIPAFile
        }
        
        await MainActor.run {
            installationMessage = "正在启动HTTP服务器..."
            installationProgress = 0.4
        }
        
        // 启动简化HTTP服务器
        let serverPort = Int.random(in: 8000...9000)
        self.httpServer = SimpleHTTPServer(port: serverPort, ipaPath: localFilePath, appInfo: appInfo)
        self.httpServer?.start()
        
        // 等待服务器启动
        try await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
        
        // 测试服务器是否正常工作
        await testServerConnection(port: serverPort)
        
        await MainActor.run {
            installationMessage = "正在生成安装页面..."
            installationProgress = 0.6
        }
        
        // 生成本地安装页面URL
        let localInstallURL = "http://127.0.0.1:\(serverPort)/install"
        
        NSLog("🔗 [APP] 本地安装页面URL: \(localInstallURL)")
        print("🔗 本地安装页面URL: \(localInstallURL)")
        
        await MainActor.run {
            installationMessage = "正在打开安装页面..."
            installationProgress = 0.9
        }
        
        // 使用Safari WebView打开安装页面
        await MainActor.run {
            if let installURL = URL(string: localInstallURL) {
                // 使用Safari WebView打开安装页面，而不是直接跳转
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
                        self.httpServer?.stop()
                        NSLog("🛑 [APP] 停止HTTP服务器")
                        print("🛑 停止HTTP服务器")
                    }
                }
            } else {
                NSLog("❌ [APP] 无法创建安装页面URL")
                print("❌ 无法创建安装页面URL")
                self.httpServer?.stop()
            }
        }
        
        NSLog("🎯 [APP] OTA安装流程完成")
        print("🎯 OTA安装流程完成")
        NSLog("📱 [APP] 请在Safari中完成安装")
        print("📱 请在Safari中完成安装")
    }
    
    // MARK: - 服务器测试
    private func testServerConnection(port: Int) async {
        let testURL = "http://127.0.0.1:\(port)/test"
        
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: testURL)!)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                NSLog("✅ [APP] 服务器连接测试成功")
                print("✅ 服务器连接测试成功")
            } else {
                NSLog("⚠️ [APP] 服务器连接测试失败")
                print("⚠️ 服务器连接测试失败")
            }
        } catch {
            NSLog("⚠️ [APP] 服务器连接测试错误: \(error)")
            print("⚠️ 服务器连接测试错误: \(error)")
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
        // macOS平台使用NSSharingService
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: [fileURL])
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
        VStack(spacing: Spacing.xs) {
            HStack {
                Label(getProgressLabel(), systemImage: getProgressIcon())
                    .font(.headlineSmall)
                    .foregroundColor(getProgressColor())
                
                Spacer()
                
                Text("\(Int(request.runtime.progressValue * 100))%")
                    .font(.titleMedium)
                    .foregroundColor(themeManager.accentColor)
            }
            
            ProgressView(value: request.runtime.progressValue)
                .progressViewStyle(LinearProgressViewStyle(tint: getProgressColor()))
                .scaleEffect(y: 2.0)
            
            HStack {
                Spacer()
                
                Text(request.createdAt.formatted())
                    .font(.bodySmall)
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
        VStack(spacing: Spacing.xs) {
            HStack {
                Label("安装进度", systemImage: "arrow.up.circle")
                    .font(.headlineSmall)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(Int(installationProgress * 100))%")
                    .font(.titleMedium)
                    .foregroundColor(.green)
            }
            
            ProgressView(value: installationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 2.0)
            
            Text(installationMessage)
                .font(.bodySmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 4)
    }

    var progressCard: some SwiftUIView {
        ModernCard(style: .elevated, padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label("下载进度", systemImage: "arrow.down.circle")
                        .font(.headlineSmall)
                        .foregroundColor(themeManager.accentColor)
                    
                    Spacer()
                    
                    Text("\(Int(request.runtime.progressValue * 100))%")
                        .font(.titleMedium)
                        .foregroundColor(themeManager.accentColor)
                }
                
                ProgressView(value: request.runtime.progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.accentColor))
                    .scaleEffect(y: 2.0)
                
                HStack {
                    Spacer()
                    
                    Text(request.createdAt.formatted())
                        .font(.bodySmall)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - 开发者链接按钮
struct DeveloperLinkButton: SwiftUIView {
    var body: some SwiftUIView {
        Button(action: {
            if let url = URL(string: "https://github.com/pxx917144686") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: "link")
                Text("开发者链接")
            }
            .foregroundColor(.blue)
        }
    }
}