//
//  FilesView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import NimbleViews

extension URL: @retroactive Identifiable {
    public var id: String { self.absoluteString }
}

struct FilesView: View {
    let directoryURL: URL?
    let isRootView: Bool
    
    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var searchText = ""
    @Namespace private var animation
    @AppStorage("Feather.useLastExportLocation") private var _useLastExportLocation: Bool = false

    @State private var extractionProgress: Double = 0
    @State private var isExtracting = false
    @State private var plistFileURL: URL?
    @State private var hexEditorFileURL: URL?
    @State private var moveSingleFile: FileItem?
    @State private var showFilePreview = false
    @State private var previewFile: FileItem?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var navigateToDirectoryURL: URL?
    
    // MARK: - 初始化器
    
    init() {
        self.directoryURL = nil
        self.isRootView = true
        self._viewModel = StateObject(wrappedValue: FilesViewModel())
    }
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.isRootView = false
        self._viewModel = StateObject(wrappedValue: FilesViewModel(directory: directoryURL))
    }
    
    private var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return viewModel.files
        } else {
            return viewModel.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        Group {
            if isRootView {
                NavigationStack {
                    filesBrowserContent
                }
                .accentColor(.accentColor)
            } else {
                filesBrowserContent
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            if !isRootView {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    // MARK: - 主要内容    
    private var filesBrowserContent: some View {
        ZStack {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                .refreshable {
                    if isRootView {
                        await withCheckedContinuation { continuation in
                            viewModel.loadFiles()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                continuation.resume()
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        addButton
                        editButton
                    }
                    if viewModel.isEditMode == .active {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 12) {
                                selectAllButton
                                moveButton
                                shareButton
                                deleteButton
                            }
                        }
                    }
                }
            
            if isExtracting {
                extractionProgressView
            }
        }
        .sheet(isPresented: $viewModel.showingImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType.item],
                allowsMultipleSelection: true,
                onDocumentsPicked: { urls in
                    viewModel.importFiles(urls: urls)
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(item: $moveSingleFile) { item in
            FileExporterRepresentableView(
                urlsToExport: [item.url],
                asCopy: false,
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    moveSingleFile = nil
                    viewModel.loadFiles()
                }
            )
        }
        .sheet(isPresented: $viewModel.showDirectoryPicker) {
            FileExporterRepresentableView(
                urlsToExport: Array(viewModel.selectedItems.map { $0.url }),
                asCopy: false,
                useLastLocation: _useLastExportLocation,
                onCompletion: { _ in
                    viewModel.selectedItems.removeAll()
                    if viewModel.isEditMode == .active { viewModel.isEditMode = .inactive }
                
                    viewModel.loadFiles()
                }
            )
        }

        .fullScreenCover(item: $plistFileURL) { fileURL in
            PlistEditorView(fileURL: fileURL)
        }
        .fullScreenCover(item: $hexEditorFileURL) { fileURL in
            HexEditorView(fileURL: fileURL)
        }
        .alert(String(localized: "新建文件夹"), isPresented: $viewModel.showingNewFolderDialog) {
            TextField(String(localized: "文件夹名称"), text: $viewModel.newFolderName)
                .autocapitalization(.words)
                .disableAutocorrection(true)
            Button(String(localized: "取消"), role: .cancel) { viewModel.newFolderName = "" }
            Button(String(localized: "创建")) { viewModel.createNewFolder() }
        } message: {
            Text(String(localized: "请输入新文件夹的名称"))
        }
        .alert(String(localized: "重命名文件"), isPresented: $viewModel.showRenameDialog) {
            TextField(String(localized: "文件名"), text: $viewModel.newFileName)
                .disableAutocorrection(true)
            Button(String(localized: "取消"), role: .cancel) { 
                viewModel.itemToRename = nil
                viewModel.newFileName = "" 
            }
            Button(String(localized: "重命名")) { viewModel.renameFile() }
        } message: {
            Text(String(localized: "请输入新名称"))
        }
        .alert(isPresented: $viewModel.showingError) {
            Alert(
                title: Text(String(localized: "警告")),
                message: Text(viewModel.error ?? String(localized: "发生未知错误")),
                dismissButton: .default(Text(String(localized: "确定")))
            )
        }
        .alert(String(localized: "输入证书密码"), isPresented: $viewModel.showPasswordAlert) {
            TextField(String(localized: "密码（如无密码请留空）"), text: $viewModel.certificatePassword)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button(String(localized: "取消"), role: .cancel) { 
                viewModel.selectedP12File = nil
                viewModel.selectedProvisionFile = nil
                viewModel.certificatePassword = ""
            }
            Button(String(localized: "导入")) { viewModel.completeCertificateImport() }
        } message: {
            Text(String(localized: "请输入证书密码。如果不需要密码，请留空。"))
        }
        .onAppear {
            if !isRootView {
                setupNotifications()
            }
        }
    }
    
    // MARK: - 内容视图
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else {
                fileListView
            }
        }
        .overlay {
            if filteredFiles.isEmpty && !viewModel.isLoading {
                if #available(iOS 17, *) {
                    ContentUnavailableView {
                        Label(.localized("无文件"), systemImage: "folder.fill.badge.questionmark")
                    } description: {
                        Text(.localized("请导入一个文件以开始使用。"))
                    } actions: {
                        Button {
                            viewModel.showingImporter = true
                        } label: {
                            Text("导入文件").bg()
                        }
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fileListView: some View {
        List {
            ForEach(filteredFiles) { file in
                FileRow(
                    file: file,
                    isSelected: viewModel.selectedItems.contains(file),
                    viewModel: viewModel,
                    plistFileURL: $plistFileURL,
                    hexEditorFileURL: $hexEditorFileURL,
                    shareItems: $shareItems,
                    showingShareSheet: $showingShareSheet,
                    moveFileItem: $moveSingleFile,
                    onExtractArchive: extractArchive,
                    onPackageApp: packageAppAsIPA,
                    onImportIpa: importIpaToLibrary,
                    onPresentQuickLook: presentQuickLook,
                    onNavigateToDirectory: navigateToDirectory
                )
                .swipeActions(edge: .trailing) {
                    swipeActions(for: file)
                }
                .listRowBackground(selectionBackground(for: file))
                
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $viewModel.isEditMode)
        .navigationDestination(isPresented: Binding(
            get: { navigateToDirectoryURL != nil },
            set: { if !$0 { navigateToDirectoryURL = nil } }
        )) {
            if let url = navigateToDirectoryURL {
                FilesView(directoryURL: url)
            }
        }
    }
    
    // MARK: - 辅助属性
    
    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        } else {
            // 隐藏根目录的"Documents"标题
            return ""
        }
    }
    
    private var extractionProgressView: some View {
        FileUIHelpers.extractionProgressView(progress: extractionProgress)
    }
    
    // MARK: - 设置方法
    
    private func setupView() {
        viewModel.loadFiles()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionStarted"), object: nil, queue: .main) { _ in
            self.isExtracting = true
            self.extractionProgress = 0.1
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionCompleted"), object: nil, queue: .main) { _ in
            self.extractionProgress = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    self.isExtracting = false
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionFailed"), object: nil, queue: .main) { _ in
            self.isExtracting = false
        }
        
   
    }
    
    // MARK: - 工具栏项目
    
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label(String(localized: "导入文件"), systemImage: "doc.badge.plus")
            }
            .tint(.primary)
            Button {
                viewModel.showingNewFolderDialog = true
            } label: {
                Label(String(localized: "新建文件夹"), systemImage: "folder.badge.plus")
            }
            .tint(.primary)
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
    
    private var editButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                viewModel.isEditMode = viewModel.isEditMode == .active ? .inactive : .active
                if viewModel.isEditMode == .inactive {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Text(viewModel.isEditMode == .active ? String(localized: "完成") : String(localized: "编辑"))
        }
    }
    
    private var selectAllButton: some View {
        Button {
            if viewModel.selectedItems.isEmpty {
                for file in viewModel.files {
                    viewModel.selectedItems.insert(file)
                }
            } else {
                viewModel.selectedItems.removeAll()
            }
        } label: {
            Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
        }
    }
    
    private var moveButton: some View {
        Button {
            viewModel.showDirectoryPicker = true
        } label: {
            Label(String(localized: "移动"), systemImage: "folder")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map { $0.url }
                shareItems = urls
                showingShareSheet = true
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.deleteSelectedItems()
        } label: {
            Image(systemName: "trash")
                .tint(.red)
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    // MARK: - 操作    
    private func navigateToDirectory(_ url: URL) {
        navigateToDirectoryURL = url
    }
    

    
    // MARK: - 文件操作    
    private func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success:
                    withAnimation {
                        self.viewModel.loadFiles()
                    }
                    
                case .failure:
                    self.viewModel.error = String(localized: "解压文件时出现问题。\n也许可以尝试在设置中切换解压依赖库!")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success(let ipaFileName):
                    self.viewModel.loadFiles()
                    self.viewModel.error = String(localized: "成功将 \(file.name) 打包为 \(ipaFileName)")
                    self.viewModel.showingError = true
                    
                case .failure(let error):
                    self.viewModel.error = String(localized: "打包IPA失败：\(error.localizedDescription)")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func importIpaToLibrary(_ file: FileItem) {
        let id = "FeatherManualDownload_\(UUID().uuidString)"
        let download = self.downloadManager.startArchive(from: file.url, id: id)
        self.downloadManager.handlePachageFile(url: file.url, dl: download) { err in
            DispatchQueue.main.async {
                if let _ = err {
                    self.viewModel.error = String(localized: "哎呀！解压文件时出现问题。\n也许可以尝试在设置中切换解压库？")
                    self.viewModel.showingError = true
                } else {
                }
                if let index = DownloadManager.shared.getDownloadIndex(by: download.id) {
                    DownloadManager.shared.downloads.remove(at: index)
                }
            }
        }
    }
    
    private func presentQuickLook(for file: FileItem) {
        let previewController = QuickLookController.shared
        previewController.previewFile(file.url)
    }
    
    // MARK: - UI辅助方法
    
    private func selectionBackground(for file: FileItem) -> some View {
        FileUIHelpers.selectionBackground(for: file, selectedItems: viewModel.selectedItems)
    }
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        FileUIHelpers.swipeActions(for: file, viewModel: viewModel)
    }
}
