
import SwiftUI
import ZIPFoundation

// 创建与ZIPFoundation兼容的压缩级别枚举
enum ZIPCompressionLevel: Int, CaseIterable, Identifiable {
    case none = 0
    case speed = 1
    case `default` = 2
    case best = 3
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .none: "无"
        case .speed: "快速"
        case .default: "默认"
        case .best: "最佳"
        }
    }
    
    // 转换为ZIPFoundation的CompressionMethod
    var compressionMethod: CompressionMethod {
        switch self {
        case .none: .deflate // ZIPFoundation没有store方法，使用deflate作为默认
        default: .deflate // 对于速度、默认和最佳压缩，都使用deflate方法
        }
    }
}

struct ArchiveView: View {
    @AppStorage("Feather.compressionLevel") private var _compressionLevel: Int = ZIPCompressionLevel.default.rawValue
    @AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
    
    var body: some View {
        List {
            Section("归档与压缩") {
                Picker("压缩选择", systemImage: "archivebox", selection: $_compressionLevel) {
                    ForEach(ZIPCompressionLevel.allCases) { level in
                        Text(level.label).tag(level.rawValue)
                    }
                }
            }
            
            Section {
                Toggle("导出时显示分享表", systemImage: "square.and.arrow.up", isOn: $_useShareSheet)
            } footer: {
                Text("切换显示分享表将在导出到您的文件后显示分享表。")
            }
        }
    }
}
