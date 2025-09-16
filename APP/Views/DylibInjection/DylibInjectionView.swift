// DylibInjectionView.swift
// 极简两卡片 + 底部操作条，实现与当前UI操作一致

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct DylibInjectionView: View {
    @StateObject private var injectionManager = DylibInjectionManager()

    // 选择状态
    @State private var selectedLibraryApp: AppInfoPresentable?
    @State private var selectedDylib: DylibFile?

    // 弹层
    @State private var showIpaImporter = false
    @State private var showDylibImporter = false
    @State private var showLogsSheet = false
    @State private var showSigning = false
    @State private var pushSigning = false

    // 错误与提示
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showLibraryEmptyAlert = false

    // 目标
    @State private var signingTarget: AppInfoPresentable?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 卡片：目标应用
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("目标应用").font(.headline); Spacer() }
                        if let app = selectedLibraryApp, let dir = Storage.shared.getAppDirectory(for: app) {
                            HStack {
                                FRAppIconView(app: app, size: 48)
                                VStack(alignment: .leading) {
                                    Text(app.name ?? "?")
                                    Text(app.identifier ?? "?").font(.caption).foregroundColor(.secondary)
                                    Text(app.version ?? "?").font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(dir.lastPathComponent).font(.caption2).foregroundColor(.secondary)
                            }
                        } else {
                            Text("未选择应用").font(.subheadline).foregroundColor(.secondary)
                        }
                        Button {
                            showIpaImporter = true
                        } label: {
                            Label("导入 IPA", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 卡片：动态库
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("动态库").font(.headline); Spacer() }
                        if let dylib = selectedDylib {
                            HStack {
                                Image(systemName: dylib.isFramework ? "folder.fill" : "doc.fill").foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(dylib.name)
                                    Text(dylib.size).font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        } else {
                            Text("未选择动态库").font(.subheadline).foregroundColor(.secondary)
                        }
                        Button {
                            showDylibImporter = true
                        } label: {
                            Label("导入动态库", systemImage: "shippingbox").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 120)
            }
            .navigationTitle("动态库注入")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("日志") { showLogsSheet = true }
                }
            }
            .onAppear {
                injectionManager.loadAvailableDylibs()
                injectionManager.loadInstalledApps()
            }
            // 隐式导航，避免使用服务式弹层
            .background(
                Group {
                    if let target = signingTarget {
                        NavigationLink(isActive: $pushSigning) {
                            SigningBridgeView(app: target, dylib: selectedDylib)
                                .environment(\.managedObjectContext, Storage.shared.context)
                        } label: { EmptyView() }
                        .hidden()
                    } else {
                        EmptyView()
                    }
                }
            )
            // 导入 IPA（使用系统文件选择器）
            .sheet(isPresented: $showIpaImporter) {
                GenericDocumentPicker(contentTypes: [.data]) { url in
                    handleIpaPick(url)
                }
            }
            // 导入 Dylib/Framework
            .fileImporter(isPresented: $showDylibImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
                handleDylibPick(result)
            }
            // 签名页
            .fullScreenCover(isPresented: $showSigning) {
                if let target = signingTarget {
                    SigningBridgeView(app: target, dylib: selectedDylib)
                        .environment(\.managedObjectContext, Storage.shared.context)
                } else {
                    Color.clear.ignoresSafeArea()
                }
            }
            // 底部操作条
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        // 确保已选择目标应用
                        if selectedLibraryApp == nil {
                            if let first = firstLibraryApp() {
                                selectedLibraryApp = first
                            } else {
                                showLibraryEmptyAlert = true
                                return
                            }
                        }
                        // 确保已选择动态库（允许为空，但按你的交互是需要选择的）
                        guard let target = selectedLibraryApp else { return }
                        signingTarget = target
                        // 收起其它弹层，延时打开
                        showIpaImporter = false
                        showDylibImporter = false
                        showLogsSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // 改为导航推入，避免服务视图白屏
                            pushSigning = true
                        }
                    } label: {
                        Text("注入并进入签名").fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                    }.buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial)
            }
            // 提示与日志
            .alert("库为空，请先导入IPA", isPresented: $showLibraryEmptyAlert) { Button("知道了", role: .cancel) {} }
            .alert("导入失败", isPresented: $showImportError) { Button("知道了", role: .cancel) {} } message: { Text(importErrorMessage) }
            .sheet(isPresented: $showLogsSheet) { InjectionLogsSheet(manager: injectionManager) }
        }
    }
}

// MARK: - 事件处理与工具函数
extension DylibInjectionView {
    fileprivate func handleIpaPick(_ pickedURL: URL) {
        guard pickedURL.pathExtension.lowercased() == "ipa" else {
            importErrorMessage = "请选择 .ipa 文件"
            showImportError = true
            return
        }
        let access = pickedURL.startAccessingSecurityScopedResource()
        let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ipa")
        do {
            if FileManager.default.fileExists(atPath: tempDest.path) {
                try FileManager.default.removeItem(at: tempDest)
            }
            try FileManager.default.copyItem(at: pickedURL, to: tempDest)
        } catch {
            if access { pickedURL.stopAccessingSecurityScopedResource() }
            importErrorMessage = "复制 IPA 到临时目录失败：\(error.localizedDescription)"
            showImportError = true
            return
        }
        if access { pickedURL.stopAccessingSecurityScopedResource() }
        Task {
            await injectionManager.importIPA(from: tempDest)
            _ = await waitUntilLatestImportedReady(timeoutMs: 2500, intervalMs: 150)
            await MainActor.run {
                selectedLibraryApp = latestImportedApp() ?? firstLibraryApp()
            }
        }
    }

    fileprivate func handleDylibPick(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let pickedURL = urls.first else { return }
        let valid = ["dylib", "framework"].contains(pickedURL.pathExtension.lowercased())
        guard valid else {
            importErrorMessage = "请选择 .dylib 或 .framework 文件"
            showImportError = true
            return
        }
        let access = pickedURL.startAccessingSecurityScopedResource()
        defer { if access { pickedURL.stopAccessingSecurityScopedResource() } }
        injectionManager.importDylib(from: pickedURL)
        injectionManager.loadAvailableDylibs()
        if let matched = injectionManager.availableDylibs.first(where: { $0.name == pickedURL.lastPathComponent }) {
            selectedDylib = matched
        }
    }

    fileprivate func waitUntilLatestImportedReady(timeoutMs: Int, intervalMs: Int) async -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline {
            if let app = latestImportedApp(), Storage.shared.getAppDirectory(for: app) != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
        }
        return false
    }

    fileprivate func firstLibraryApp() -> AppInfoPresentable? {
        let ctx = Storage.shared.context
        if let req = Imported.fetchRequest() as? NSFetchRequest<Imported>, let imported = try? ctx.fetch(req), let first = imported.first { return first }
        if let req = Signed.fetchRequest() as? NSFetchRequest<Signed>, let signed = try? ctx.fetch(req), let first = signed.first { return first }
        return nil
    }

    fileprivate func latestImportedApp() -> AppInfoPresentable? {
        let ctx = Storage.shared.context
        if let r1 = Imported.fetchRequest() as? NSFetchRequest<Imported> {
            r1.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
            if let fetched = try? ctx.fetch(r1), let first = fetched.first { return first }
        }
        if let r2 = Signed.fetchRequest() as? NSFetchRequest<Signed> {
            r2.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
            if let fetched = try? ctx.fetch(r2), let first = fetched.first { return first }
        }
        return nil
    }
}

// MARK: - 日志
struct InjectionLogsSheet: View {
    @ObservedObject var manager: DylibInjectionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(manager.injectionLogs) { log in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: log.type.icon).foregroundColor(Color(log.type.color))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.message).font(.subheadline)
                        Text(log.timestamp, style: .time).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }.padding(.vertical, 2)
            }
            .navigationTitle("日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }
}

#Preview {
    DylibInjectionView()
}

