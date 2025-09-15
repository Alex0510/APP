import SwiftUI
// DylibInjectionView.swift
// of pxx917144686
// 动态库注入界面

import NimbleViews

struct DylibInjectionView: View {
    @StateObject private var injectionManager = DylibInjectionManager()
    @StateObject private var ipaPackager = DylibInjectionIPAPackager.shared
    @State private var selectedApp: InstalledApp?
    @State private var selectedDylib: DylibFile?
    @State private var showFilePicker: Bool = false
    @State private var showAppPicker: Bool = false
    @State private var showTechnicalDetails: Bool = false
    @State private var showIPAPackaging: Bool = false
    @State private var appleId: String = ""
    @State private var generatedIPAPath: String?
    
    var body: some View {
        NBNavigationView("动态库注入") {
            VStack(spacing: 20) {
                // 主要操作区域 - 非越狱设计
                mainOperationSection
                
                // 状态显示区域
                statusSection
                
                // 应用选择区域
                appSelectionSection
                
                // 动态库选择区域
                dylibSelectionSection
                
                // 操作按钮区域
                actionButtonsSection
                
                // IPA打包区域
                if showIPAPackaging {
                    ipaPackagingSection
                }
                
                // 日志显示区域
                logSection
                
                Spacer()
            }
            .padding()
            .onAppear {
                injectionManager.loadAvailableDylibs()
                injectionManager.loadInstalledApps()
            }
            .sheet(isPresented: $showAppPicker) {
                AppPickerSheet(selectedApp: $selectedApp, apps: injectionManager.installedApps)
            }
            .sheet(isPresented: $showFilePicker) {
                FilePickerSheet(selectedDylib: $selectedDylib, dylibs: injectionManager.availableDylibs)
            }
            .sheet(isPresented: $showTechnicalDetails) {
                TechnicalDetailsView()
            }
        }
    }
    
    // MARK: - 主要操作区域
    private var mainOperationSection: some View {
        VStack(spacing: 40) {
            // 主要操作按钮
            HStack(spacing: 40) {
                // 注入选项
                Button {
                    showAppPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("注入动态库")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(injectionManager.installedApps.isEmpty)
                .accessibilityLabel("注入动态库")
                
                // 移除选项
                Button {
                    showAppPicker = true
                } label: {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                        Text("移除动态库")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(!injectionManager.installedApps.contains { $0.isInjected })
                .accessibilityLabel("移除注入")
            }
            
            // 高级设置按钮
            Button {
                showTechnicalDetails = true
            } label: {
                Label("技术详情", systemImage: "gear")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 状态显示区域
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("注入状态")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(injectionManager.injectionStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 应用选择区域
    private var appSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择目标应用")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("请选择要注入的应用", text: .constant(selectedApp?.name ?? ""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
                
                Button("选择") {
                    showAppPicker = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 动态库选择区域
    private var dylibSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择动态库文件")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("请选择要注入的.dylib文件", text: .constant(selectedDylib?.name ?? ""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
                
                Button("选择") {
                    showFilePicker = true
                }
                .buttonStyle(.bordered)
            }
            
            if !injectionManager.availableDylibs.isEmpty {
                Text("可用的动态库文件:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(injectionManager.availableDylibs) { dylib in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dylib.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(dylib.size)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedDylib?.id == dylib.id ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2))
                            .cornerRadius(6)
                            .onTapGesture {
                                selectedDylib = dylib
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                if let app = selectedApp, let dylib = selectedDylib {
                    injectionManager.performInjection(app: app, dylib: dylib)
                }
            }) {
                HStack {
                    if injectionManager.isInjecting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(injectionManager.isInjecting ? "注入中..." : "开始注入")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canInject ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canInject || injectionManager.isInjecting)
            
            // 新增：IPA打包按钮
            Button(action: {
                showIPAPackaging.toggle()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("创建可安装IPA包")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canInject ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canInject)
            
            HStack(spacing: 12) {
                Button("移除注入") {
                    if let selectedApp = selectedApp {
                        injectionManager.removeInjection(from: selectedApp)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(selectedApp == nil || injectionManager.isInjecting)
                
                Button("清除选择") {
                    clearSelection()
                }
                .buttonStyle(.bordered)
                
                Button("技术详情") {
                    showTechnicalDetails = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - 日志显示区域
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作日志")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if injectionManager.injectionLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• LiveContainer非越狱技术")
                            Text("• 使用LCMachOUtils修改Mach-O文件")
                            Text("• 插入LC_LOAD_DYLIB命令")
                            Text("• 支持ElleKit框架加载（替代CydiaSubstrate）")
                            Text("• 自动备份和恢复机制")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else {
                        ForEach(injectionManager.injectionLogs) { log in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: log.type.icon)
                                    .foregroundColor(Color(log.type.color))
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.message)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    
                                    Text(log.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 计算属性
    private var canInject: Bool {
        selectedApp != nil && selectedDylib != nil
    }
    
    private var statusColor: Color {
        switch injectionManager.injectionStatus {
        case "准备就绪":
            return .green
        case "初始化LiveContainer...", "验证目标应用...", "修改Mach-O文件...", "移除注入中...":
            return .orange
        case "注入完成", "移除完成":
            return .green
        case "注入失败", "移除失败":
            return .red
        default:
            return .gray
        }
    }
    
    // MARK: - 方法
    private func clearSelection() {
        selectedApp = nil
        selectedDylib = nil
    }
}

// MARK: - 简化的选择器组件
struct AppPickerSheet: View {
    @Binding var selectedApp: InstalledApp?
    let apps: [InstalledApp]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(apps) { app in
                HStack {
                    Image(systemName: "app.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.headline)
                        Text(app.bundleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedApp?.id == app.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .onTapGesture {
                    selectedApp = app
                    dismiss()
                }
            }
            .navigationTitle("选择应用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct FilePickerSheet: View {
    @Binding var selectedDylib: DylibFile?
    let dylibs: [DylibFile]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(dylibs) { dylib in
                HStack {
                    Image(systemName: dylib.isFramework ? "folder.fill" : "doc.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text(dylib.name)
                            .font(.headline)
                        Text(dylib.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedDylib?.id == dylib.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .onTapGesture {
                    selectedDylib = dylib
                    dismiss()
                }
            }
            .navigationTitle("选择动态库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - IPA打包区域
extension DylibInjectionView {
    private var ipaPackagingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("IPA打包设置")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("关闭") {
                    showIPAPackaging = false
                }
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Apple ID (可选)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("输入Apple ID获取真实签名数据", text: $appleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("提示：提供Apple ID可以获取真实的签名数据，提高安装成功率")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 进度显示
            if ipaPackager.isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: ipaPackager.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text(ipaPackager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 错误信息显示
            if let errorMessage = ipaPackager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    createInstallableIPA()
                }) {
                    HStack {
                        if ipaPackager.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(ipaPackager.isProcessing ? "创建中..." : "创建IPA包")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canInject && !ipaPackager.isProcessing ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canInject || ipaPackager.isProcessing)
                
                if let ipaPath = generatedIPAPath {
                    Button(action: {
                        triggerSystemInstallation()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("安装到设备")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - IPA打包功能
    private func createInstallableIPA() {
        guard let app = selectedApp, let dylib = selectedDylib else { return }
        
        LiveContainerIntegration.shared.injectDylibAndCreateIPA(
            dylibPath: dylib.path,
            targetAppPath: app.path,
            appleId: appleId.isEmpty ? nil : appleId
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ipaPath):
                    self.generatedIPAPath = ipaPath
                    self.ipaPackager.statusMessage = "IPA包创建成功！"
                case .failure(let error):
                    self.ipaPackager.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func triggerSystemInstallation() {
        guard let ipaPath = generatedIPAPath else { return }
        DylibInjectionIPAPackager.shared.triggerSystemInstallation(for: ipaPath)
    }
}

#Preview {
    DylibInjectionView()
}
