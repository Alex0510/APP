
import SwiftUI
import NimbleViews
import IDeviceSwift

struct TunnelView: View {
	@State private var _isImportingPairingPresenting = false
	
	@State var doesHavePairingFile = false
	
    var body: some View {
		Group {
			Section {
				_tunnelInfo()
				TunnelHeaderView()
			} footer: {
				if doesHavePairingFile {
					Text(.localized("已经获得了配对文件！"))
				} else {
					Text(.localized("未找到配对文件，请导入。"))
				}
			}
			
			Section {
				Button(.localized("导入配对文件"), systemImage: "square.and.arrow.down") {
					_isImportingPairingPresenting = true
				}
			}
			
			NBSection(.localized("说明")) {
				Button(.localized("配对文件说明"), systemImage: "questionmark.circle") {
					UIApplication.open("https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md")
				}
				Button(.localized("下载StosVPN"), systemImage: "arrow.down.app") {
					UIApplication.open("https://apps.apple.com/us/app/stosvpn/id6744003051")
				}
			}
		}
		.sheet(isPresented: $_isImportingPairingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList, .plist, .mobiledevicepairing],
				onDocumentsPicked: { urls in
					guard let selectedFileURL = urls.first else { return }
					FR.movePairing(selectedFileURL)
					doesHavePairingFile = true
				}
			)
			.ignoresSafeArea()
		}
		.onAppear {
			doesHavePairingFile = FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile())
			? true
			: false
		}
    }
	
	@ViewBuilder
	private func _tunnelInfo() -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 6) {
				Text(.localized("状态指示器"))
					.font(.headline)
				Text(.localized("状态在后台激活，当应用重新打开或提示时会重启。如果下面的状态在脉动，说明它是正常的。"))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
	}
}
