
import SwiftUI
import NimbleViews

struct InstallationView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	
	private let _installationMethods: [String] = [
		.localized("服务器"),
		.localized("本机设备")
	]
	
    var body: some View {
		NBList(.localized("安装")) {
			Section {
				Picker(.localized("安装类型"), systemImage: "arrow.down.app", selection: $_installationMethod) {
					ForEach(_installationMethods.indices, id: \.description) { index in
						Text(_installationMethods[index]).tag(index)
					}
				}
				.labelsHidden()
				.pickerStyle(.segmented)
			} footer: {
				Text(.localized("服务器（推荐）：\n使用本地托管服务器和itms-services://来安装应用程序。\n\n设备（高级）：\n使用VPN和配对文件。写入AFC并手动调用installd，同时通过回调监控安装进度\n优势：非常可靠，不需要SSL证书或外部托管服务器。相反，它的工作方式类似于计算机。"))
			}
			
			if _installationMethod == 0 {
				ServerView()
			} else if _installationMethod == 1 {
				TunnelView()
			}
		}
		.animation(.default, value: _installationMethod)
    }
}
