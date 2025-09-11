//
//  PlistEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct PlistEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = PlistEditorViewModel()
    
    @State private var _showingEditAlert = false
    @State private var _editingItem: PlistItem?
    @State private var _editValue: String = ""
    
    @State private var _expandedItems: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
        }
        .onAppear {
            viewModel.loadPlist(from: fileURL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("编辑值", isPresented: $_showingEditAlert, presenting: _editingItem) { item in
            TextField("值", text: $_editValue)
            Button("取消", role: .cancel) {
                _resetEditState()
            }
            Button("完成") {
                _saveEditedValue()
            }
        } message: { item in
            Text("编辑键的值: \(item.key)")
        }
    }
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("关闭")
            }
            
            Spacer()
            
            Text(fileURL.lastPathComponent)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                viewModel.savePlist()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("加载 plist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("错误")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.plistItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("空属性列表")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("此属性列表不包含任何项目")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                plistContentView
            }
        }
    }
    
    private var plistContentView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("根字典")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(viewModel.plistItems.count) item\(viewModel.plistItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            List {
                ForEach(_flattenedItems()) { item in
                    PlistItemRow(
                        item: item,
                        isExpanded: _expandedItems.contains(item.id.uuidString),
                        onExpandToggle: {
                            _toggleExpansion(for: item)
                        },
                        onEditTap: {
                            _startEditing(item: item)
                        }
                    )
                }
            }
            .listStyle(.plain)
        }
    }
    
    private func _flattenedItems() -> [PlistItem] {
        return _flattenItems(viewModel.plistItems)
    }
    
    private func _flattenItems(_ items: [PlistItem]) -> [PlistItem] {
        var result: [PlistItem] = []
        
        for item in items {
            result.append(item)
            
            if item.isExpandable && _expandedItems.contains(item.id.uuidString) {
                result.append(contentsOf: _flattenItems(item.children))
            }
        }
        
        return result
    }
    
    private func _toggleExpansion(for item: PlistItem) {
        let itemId = item.id.uuidString
        
        if _expandedItems.contains(itemId) {
            _expandedItems.remove(itemId)
        } else {
            _expandedItems.insert(itemId)
        }
    }
    
    private func _startEditing(item: PlistItem) {
        _editingItem = item
        _editValue = _getEditableValue(for: item)
        _showingEditAlert = true
    }
    
    private func _getEditableValue(for item: PlistItem) -> String {
        switch item.type {
        case "布尔值":
            return item.displayValue == "YES" ? "true" : "false"
        default:
            return item.value
        }
    }
    
    private func _saveEditedValue() {
        guard let item = _editingItem else { return }
        
        if item.keyPath.count == 1 {
            viewModel.updateValue(for: item.key, newValue: _editValue, type: item.type)
        } else {
            viewModel.updateNestedValue(at: item.keyPath, newValue: _editValue, type: item.type)
        }
        
        _resetEditState()
    }
    
    private func _resetEditState() {
        _editingItem = nil
        _editValue = ""
        _showingEditAlert = false
    }
}

struct PlistItemRow: View {
    let item: PlistItem
    let isExpanded: Bool
    let onExpandToggle: () -> Void
    let onEditTap: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // indentation
            HStack(spacing: 0) {
                ForEach(0..<item.depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                }
            }
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.key)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text(item.type)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                        
                        Text(item.displayValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                }
                Spacer()
                if item.isExpandable {
                    Button(action: onExpandToggle) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 4, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isExpandable {
                onExpandToggle()
            } else {
                onEditTap()
            }
        }
    }
}

@MainActor
class PlistEditorViewModel: ObservableObject {
    
    @Published var plistItems: [PlistItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var fileURL: URL?
    private var plistDict: [String: Any] = [:]
    
    func loadPlist(from url: URL) {
        print("PlistEditorViewModel.loadPlist 调用，文件路径: \(url.path)")
        fileURL = url
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try Data(contentsOf: url)
                
                var format = PropertyListSerialization.PropertyListFormat.xml
                if let dict = try PropertyListSerialization.propertyList(
                    from: data,
                    options: .mutableContainersAndLeaves,
                    format: &format
                ) as? [String: Any] {
                    
                    await MainActor.run {
                        plistDict = dict
                        _processPlistData()
                        isLoading = false
                        print("PlistEditorViewModel: 成功加载 \(plistItems.count) 项")
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "The file is not a valid property list."
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载属性列表失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func savePlist() {
        guard let fileURL = fileURL else { return }
        
        Task {
            do {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: plistDict,
                    format: .xml,
                    options: 0
                )
                try data.write(to: fileURL)
                print("Plist 保存成功")
            } catch {
                await MainActor.run {
                    errorMessage = "保存属性列表失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateValue(for key: String, newValue: String, type: String) {
        guard !newValue.isEmpty else { return }
        
        let convertedValue = _convertStringToAppropriateType(newValue, expectedType: type)
        plistDict[key] = convertedValue
        _updateItemDisplayValue(keyPath: [key], newValue: convertedValue)
    }
    
    func updateNestedValue(at keyPath: [String], newValue: String, type: String) {
        guard !newValue.isEmpty, !keyPath.isEmpty else { return }
        
        let convertedValue = _convertStringToAppropriateType(newValue, expectedType: type)
        _updateNestedDictionary(&plistDict, keyPath: keyPath, value: convertedValue)
        _updateItemDisplayValue(keyPath: keyPath, newValue: convertedValue)
    }
    
    private func _processPlistData() {
        plistItems = plistDict.map { key, value in
            _createPlistItem(key: key, value: value, keyPath: [key], depth: 0)
        }.sorted { $0.key < $1.key }
    }
    
    private func _createPlistItem(key: String, value: Any, keyPath: [String], depth: Int) -> PlistItem {
        let type = _getTypeString(for: value)
        let displayValue = _getDisplayValue(for: value)
        let isExpandable = type == "数组" || type == "字典"
        
        var children: [PlistItem] = []
        
        if isExpandable {
            if let arrayValue = value as? [Any] {
                children = arrayValue.enumerated().map { index, item in
                    _createPlistItem(
                        key: "[\(index)]",
                        value: item,
                        keyPath: keyPath + [String(index)],
                        depth: depth + 1
                    )
                }
            } else if let dictValue = value as? [String: Any] {
                children = dictValue.map { childKey, childValue in
                    _createPlistItem(
                        key: childKey,
                        value: childValue,
                        keyPath: keyPath + [childKey],
                        depth: depth + 1
                    )
                }.sorted { $0.key < $1.key }
            }
        }
        
        return PlistItem(
            key: key,
            value: String(describing: value),
            type: type,
            displayValue: displayValue,
            keyPath: keyPath,
            depth: depth,
            children: children,
            isExpandable: isExpandable
        )
    }
    
    private func _getTypeString(for value: Any) -> String {
        switch value {
        case is String:
            return "字符串"
        case is Int:
            return "整数"
        case is Double, is Float:
            return "数字"
        case is Bool:
            return "布尔值"
        case is Date:
            return "日期"
        case is Data:
            return "数据"
        case is [Any]:
            return "数组"
        case is [String: Any]:
            return "字典"
        default:
            return "未知"
        }
    }
    
    private func _getDisplayValue(for value: Any) -> String {
        switch value {
        case let boolValue as Bool:
            return boolValue ? "YES" : "NO"
        case let dataValue as Data:
            return "(\(dataValue.count) bytes)"
        case let arrayValue as [Any]:
            return "(\(arrayValue.count) items)"
        case let dictValue as [String: Any]:
            return "(\(dictValue.count) keys)"
        default:
            let stringValue = String(describing: value)
            return stringValue.count > 50 ? String(stringValue.prefix(50)) + "..." : stringValue
        }
    }
    
    private func _convertStringToAppropriateType(_ stringValue: String, expectedType: String) -> Any {
        switch expectedType {
        case "字符串":
            return stringValue
        case "整数":
            return Int(stringValue) ?? 0
        case "数字":
            return Double(stringValue) ?? 0.0
        case "布尔值":
            return stringValue.lowercased() == "true" || stringValue.lowercased() == "yes" || stringValue == "1"
        case "日期":
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: stringValue) ?? Date()
        case "数据":
            return stringValue.data(using: .utf8) ?? Data()
        default:
            return stringValue
        }
    }
    
    private func _updateNestedDictionary(_ dict: inout [String: Any], keyPath: [String], value: Any) {
        guard !keyPath.isEmpty else { return }
        
        if keyPath.count == 1 {
            dict[keyPath[0]] = value
        } else {
            let firstKey = keyPath[0]
            let remainingPath = Array(keyPath.dropFirst())
            
            if var nestedDict = dict[firstKey] as? [String: Any] {
                _updateNestedDictionary(&nestedDict, keyPath: remainingPath, value: value)
                dict[firstKey] = nestedDict
            } else if var nestedArray = dict[firstKey] as? [Any], let arrayIndex = Int(remainingPath[0]) {
                _updateNestedArray(&nestedArray, keyPath: remainingPath, value: value)
                dict[firstKey] = nestedArray
            }
        }
    }
    
    private func _updateNestedArray(_ array: inout [Any], keyPath: [String], value: Any) {
        guard !keyPath.isEmpty, let index = Int(keyPath[0]) else { return }
        
        if keyPath.count == 1 {
            if index < array.count {
                array[index] = value
            }
        } else {
            let remainingPath = Array(keyPath.dropFirst())
            
            if var nestedDict = array[index] as? [String: Any] {
                _updateNestedDictionary(&nestedDict, keyPath: remainingPath, value: value)
                array[index] = nestedDict
            } else if var nestedArray = array[index] as? [Any] {
                _updateNestedArray(&nestedArray, keyPath: remainingPath, value: value)
                array[index] = nestedArray
            }
        }
    }
    
    private func _updateItemDisplayValue(keyPath: [String], newValue: Any) {
        _updatePlistItemsDisplayValue(&plistItems, keyPath: keyPath, newValue: newValue)
    }
    
    private func _updatePlistItemsDisplayValue(_ items: inout [PlistItem], keyPath: [String], newValue: Any) {
        guard !keyPath.isEmpty else { return }
        
        for i in 0..<items.count {
            if items[i].keyPath == keyPath {
                items[i].value = String(describing: newValue)
                items[i].displayValue = _getDisplayValue(for: newValue)
                return
            } else if !items[i].children.isEmpty {
                _updatePlistItemsDisplayValue(&items[i].children, keyPath: keyPath, newValue: newValue)
            }
        }
    }
}

struct PlistItem: Identifiable {
    let id = UUID()
    let key: String
    var value: String
    let type: String
    var displayValue: String
    let keyPath: [String]
    let depth: Int
    var children: [PlistItem] = []
    let isExpandable: Bool
    
    init(
        key: String,
        value: String,
        type: String,
        displayValue: String,
        keyPath: [String] = [],
        depth: Int = 0,
        children: [PlistItem] = [],
        isExpandable: Bool = false
    ) {
        self.key = key
        self.value = value
        self.type = type
        self.displayValue = displayValue
        self.keyPath = keyPath
        self.depth = depth
        self.children = children
        self.isExpandable = isExpandable
    }
}
