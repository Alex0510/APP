import SwiftUI

// TechnicalDetailsView.swift
// of pxx917144686
// 技术详情视图，显示动态库注入的技术信息

struct TechnicalDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 说明
                    technicalSection(
                        title: "LiveContainer 非越狱注入流程",
                        icon: "gearshape.2",
                        content: [
                            "LCMachOUtils核心引擎：基于非越狱的Mach-O文件处理",
                            "应用Bundle分析：自动定位可执行文件和Frameworks目录",
                            "动态库预处理：标准化加载命令和依赖关系",
                            "ElleKit集成：使用ellekit.deb替代CydiaSubstrate框架",
                            "正常代码签名：不使用CoreTrust绕过，在iOS 17+上必须使用正常签名"
                        ]
                    )
                    
                    // Mach-O 文件修改
                    technicalSection(
                        title: "Mach-O 文件修改",
                        icon: "doc.binary",
                        content: [
                            "insert_dylib工具：插入LC_LOAD_DYLIB和LC_LOAD_WEAK_DYLIB命令",
                            "install_name_tool工具：添加RPATH和修改动态库路径",
                            "optool工具：移除不需要的加载命令",
                            "正常代码签名：在iOS 17+上必须使用正常签名流程",
                            "LCMachOUtils集成：完整的Mach-O文件解析和修改"
                        ]
                    )
                    
                    // Dyld 钩子机制
                    technicalSection(
                        title: "Dyld 钩子机制",
                        icon: "link",
                        content: [
                            "钩子dyld API函数：dlsym, _dyld_image_count等",
                            "隐藏LiveContainer自身镜像",
                            "SDK版本欺骗：dyld_program_sdk_at_least",
                            "符号缓存机制：getCachedSymbol/saveCachedSymbol",
                            "绕过锁机制：dlopenBypassingLock"
                        ]
                    )
                    
                    // 文件格式支持
                    technicalSection(
                        title: "支持的文件格式",
                        icon: "folder",
                        content: [
                            ".dylib - 动态库文件",
                            ".framework - 框架包",
                            "自动解析Info.plist获取可执行文件",
                            "支持RTLD_LAZY和RTLD_GLOBAL标志",
                            "错误处理和用户友好提示"
                        ]
                    )
                    
                    // 安全机制
                    technicalSection(
                        title: "安全机制",
                        icon: "shield",
                        content: [
                            "自动备份原始文件",
                            "验证Mach-O文件格式",
                            "检查文件权限和完整性",
                            "失败时自动恢复备份",
                            "详细的错误日志记录"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("技术实现详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func technicalSection(title: String, icon: String, content: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(content, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                        
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    TechnicalDetailsView()
}
