import Foundation
import Combine

class InstallerStatusViewModel: ObservableObject {
    @Published var status: InstallerStatus = .none
    @Published var packageProgress: Double = 0.0
    
    enum InstallerStatus {
        case none
        case ready
        case sendingManifest
        case sendingPayload
        case installing
        case completed
        case broken
    }
    
    var isCompleted: Bool {
        status == .completed
    }
    
    init(isIdevice: Bool = false) {
        // 初始化逻辑
    }
}

extension InstallerStatusViewModel {
	var overallProgress: Double {
		return packageProgress
	}
	
	var statusImage: String {
		switch status {
		case .none: "archivebox.fill"
		case .ready: "app.gift"
		case .sendingManifest, .sendingPayload: "paperplane.fill"
		case .installing: "square.and.arrow.down"
		case .completed: "app.badge.checkmark"
		case .broken: "exclamationmark.triangle.fill"
		}
	}
	
	var statusLabel: String {
		switch status {
		case .none: "打包中"
		case .ready: "准备"
		case .sendingManifest: "发送清单"
		case .sendingPayload: "发送文件"
		case .installing: "安装中"
		case .completed: "完成"
		case .broken: "错误"
		}
	}
}
