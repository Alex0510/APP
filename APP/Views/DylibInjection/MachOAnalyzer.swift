import Foundation
// MachOAnalyzer.swift
// of pxx917144686
// Mach-O文件分析器，提供Mach-O文件的详细分析功能

import MachO

/// Mach-O文件分析器，提供Mach-O文件的详细分析功能
class MachOAnalyzer {
    
    // MARK: - 数据结构
    struct MachOInfo {
        let path: String
        let magic: UInt32
        let cpuType: cpu_type_t
        let cpuSubtype: cpu_subtype_t
        let fileType: UInt32
        let ncmds: UInt32
        let sizeofcmds: UInt32
        let flags: UInt32
        let is64Bit: Bool
        let isExecutable: Bool
        let isDylib: Bool
        let isFramework: Bool
        let hasCodeSignature: Bool
        let loadCommands: [LoadCommandInfo]
    }
    
    struct LoadCommandInfo {
        let cmd: UInt32
        let cmdsize: UInt32
        let description: String
    }
    
    // MARK: - 分析Mach-O文件
    static func analyzeMachO(at path: String) -> (info: MachOInfo?, error: String?) {
        let fileManager = FileManager.default
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: path) else {
            return (nil, "文件不存在: \(path)")
        }
        
        // 打开文件
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return (nil, "无法打开文件: \(path)")
        }
        defer { fileHandle.closeFile() }
        
        // 读取Mach-O头部
        let headerData = fileHandle.readData(ofLength: MemoryLayout<mach_header_64>.size)
        guard headerData.count == MemoryLayout<mach_header_64>.size else {
            return (nil, "文件太小，无法读取Mach-O头部")
        }
        
        let header = headerData.withUnsafeBytes { $0.load(as: mach_header_64.self) }
        
        // 检查魔数
        let magic = header.magic
        let is64Bit = (magic == MH_MAGIC_64 || magic == MH_CIGAM_64)
        
        if !isValidMachOMagic(magic) {
            return (nil, "无效的Mach-O魔数: 0x\(String(magic, radix: 16))")
        }
        
        // 分析文件类型
        let fileType = header.filetype
        let isExecutable = (fileType == MH_EXECUTE)
        let isDylib = (fileType == MH_DYLIB)
        let isFramework = (fileType == MH_DYLIB && path.hasSuffix(".framework"))
        
        // 读取加载命令
        var loadCommands: [LoadCommandInfo] = []
        var hasCodeSignature = false
        
        let headerSize = is64Bit ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
        fileHandle.seek(toFileOffset: UInt64(headerSize))
        
        for _ in 0..<header.ncmds {
            // 读取命令头部
            let cmdData = fileHandle.readData(ofLength: MemoryLayout<load_command>.size)
            guard cmdData.count == MemoryLayout<load_command>.size else {
                break
            }
            
            let cmd = cmdData.withUnsafeBytes { $0.load(as: load_command.self) }
            
            // 检查代码签名
            if cmd.cmd == LC_CODE_SIGNATURE {
                hasCodeSignature = true
            }
            
            let description = getLoadCommandDescription(cmd.cmd)
            loadCommands.append(LoadCommandInfo(
                cmd: cmd.cmd,
                cmdsize: cmd.cmdsize,
                description: description
            ))
            
            // 跳过命令数据
            let remainingSize = Int(cmd.cmdsize) - MemoryLayout<load_command>.size
            if remainingSize > 0 {
                fileHandle.seek(toFileOffset: fileHandle.offsetInFile + UInt64(remainingSize))
            }
        }
        
        let info = MachOInfo(
            path: path,
            magic: magic,
            cpuType: header.cputype,
            cpuSubtype: header.cpusubtype,
            fileType: fileType,
            ncmds: header.ncmds,
            sizeofcmds: header.sizeofcmds,
            flags: header.flags,
            is64Bit: is64Bit,
            isExecutable: isExecutable,
            isDylib: isDylib,
            isFramework: isFramework,
            hasCodeSignature: hasCodeSignature,
            loadCommands: loadCommands
        )
        
        return (info, nil)
    }
    
    // MARK: - 验证Mach-O魔数
    private static func isValidMachOMagic(_ magic: UInt32) -> Bool {
        switch magic {
        case MH_MAGIC, MH_CIGAM, MH_MAGIC_64, MH_CIGAM_64:
            return true
        default:
            return false
        }
    }
    
    // MARK: - 获取加载命令描述
    private static func getLoadCommandDescription(_ cmd: UInt32) -> String {
        switch cmd {
        case UInt32(LC_SEGMENT):
            return "LC_SEGMENT - 段命令"
        case UInt32(LC_SEGMENT_64):
            return "LC_SEGMENT_64 - 64位段命令"
        case UInt32(LC_SYMTAB):
            return "LC_SYMTAB - 符号表"
        case UInt32(LC_DYSYMTAB):
            return "LC_DYSYMTAB - 动态符号表"
        case UInt32(LC_LOAD_DYLIB):
            return "LC_LOAD_DYLIB - 加载动态库"
        case UInt32(LC_LOAD_WEAK_DYLIB):
            return "LC_LOAD_WEAK_DYLIB - 弱加载动态库"
        case UInt32(LC_ID_DYLIB):
            return "LC_ID_DYLIB - 动态库标识"
        case UInt32(LC_UUID):
            return "LC_UUID - UUID"
        case UInt32(LC_CODE_SIGNATURE):
            return "LC_CODE_SIGNATURE - 代码签名"
        case LC_RPATH:
            return "LC_RPATH - 运行时路径"
        case LC_MAIN:
            return "LC_MAIN - 主入口点"
        case UInt32(LC_VERSION_MIN_IPHONEOS):
            return "LC_VERSION_MIN_IPHONEOS - 最低iOS版本"
        case UInt32(LC_VERSION_MIN_MACOSX):
            return "LC_VERSION_MIN_MACOSX - 最低macOS版本"
        default:
            return "未知命令: 0x\(String(cmd, radix: 16))"
        }
    }
    
    // MARK: - 检查是否可以注入
    static func canInjectIntoMachO(at path: String) -> (canInject: Bool, reason: String?) {
        let result = analyzeMachO(at: path)
        
        guard let info = result.info else {
            return (false, result.error)
        }
        
        // 检查是否为可执行文件
        if !info.isExecutable {
            return (false, "目标文件不是可执行文件")
        }
        
        // 检查架构
        if info.cpuType != CPU_TYPE_ARM64 {
            return (false, "仅支持ARM64架构")
        }
        
        // 检查是否有足够的空间添加加载命令
        let availableSpace = calculateAvailableSpace(for: info)
        let requiredSpace = MemoryLayout<dylib_command>.size + 256 // 估算所需空间
        
        if availableSpace < requiredSpace {
            return (false, "没有足够的空间添加加载命令")
        }
        
        return (true, nil)
    }
    
    // MARK: - 计算可用空间
    private static func calculateAvailableSpace(for info: MachOInfo) -> Int {
        // 这是一个简化的计算，实际实现需要更复杂的逻辑
        let headerSize = info.is64Bit ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size
        let totalSize = headerSize + Int(info.sizeofcmds)
        
        // 假设文本段开始位置为可用空间的结束位置
        // 实际实现需要解析段信息
        return 4096 - totalSize // 简化的计算
    }
    
    // MARK: - 获取文件信息摘要
    static func getFileSummary(at path: String) -> String {
        let result = analyzeMachO(at: path)
        
        guard let info = result.info else {
            return "分析失败: \(result.error ?? "未知错误")"
        }
        
        var summary = "Mach-O文件信息:\n"
        summary += "路径: \(info.path)\n"
        summary += "架构: \(getArchitectureDescription(info.cpuType, info.cpuSubtype))\n"
        summary += "文件类型: \(getFileTypeDescription(info.fileType))\n"
        summary += "加载命令数量: \(info.ncmds)\n"
        summary += "代码签名: \(info.hasCodeSignature ? "是" : "否")\n"
        summary += "可注入: \(canInjectIntoMachO(at: path).canInject ? "是" : "否")\n"
        
        return summary
    }
    
    // MARK: - 获取架构描述
    private static func getArchitectureDescription(_ cpuType: cpu_type_t, _ cpuSubtype: cpu_subtype_t) -> String {
        switch cpuType {
        case CPU_TYPE_ARM64:
            return "ARM64"
        case CPU_TYPE_ARM:
            return "ARM"
        case CPU_TYPE_X86_64:
            return "x86_64"
        case CPU_TYPE_X86:
            return "x86"
        default:
            return "未知架构"
        }
    }
    
    // MARK: - 获取文件类型描述
    private static func getFileTypeDescription(_ fileType: UInt32) -> String {
        switch fileType {
        case UInt32(MH_EXECUTE):
            return "可执行文件"
        case UInt32(MH_DYLIB):
            return "动态库"
        case UInt32(MH_BUNDLE):
            return "Bundle"
        case UInt32(MH_OBJECT):
            return "目标文件"
        default:
            return "未知类型"
        }
    }
}
