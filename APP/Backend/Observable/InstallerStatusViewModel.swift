import Foundation
import Combine
import IDeviceSwift

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
		case .none: .localized("打包中")
		case .ready: .localized("准备")
		case .sendingManifest: .localized("发送清单")
		case .sendingPayload: .localized("发送文件")
		case .installing: .localized("安装中")
		case .completed: .localized("完成")
		case .broken: .localized("错误")
		}
	}
}
