
import SwiftUI

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
					Text("已经获得了配对文件！")
				} else {
					Text("未找到配对文件，请导入。")
				}
			}
			
			Section {
				Button("导入配对文件", systemImage: "square.and.arrow.down") {
					_isImportingPairingPresenting = true
				}
			}
			
			Section("说明") {
				Button("配对文件说明", systemImage: "questionmark.circle") {
					if let url = URL(string: "https://github.com/StephenDev0/StikDebug-Guide/blob/main/pairing_file.md") {
						UIApplication.shared.open(url)
					}
				}
				Button("下载StosVPN", systemImage: "arrow.down.app") {
					if let url = URL(string: "https://apps.apple.com/us/app/stosvpn/id6744003051") {
						UIApplication.shared.open(url)
					}
				}
			}
		}
		.sheet(isPresented: $_isImportingPairingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes:  [.xmlPropertyList],
				onResult: { result in
					switch result {
					case .success(let selectedFileURL):
						FR.movePairing(selectedFileURL)
						doesHavePairingFile = true
					case .failure(let error):
						print("Failed to import pairing file: \(error)")
					}
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
				Text("状态指示器")
					.font(.headline)
				Text("状态在后台激活，当应用重新打开或提示时会重启。如果下面的状态在脉动，说明它是正常的。")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
	}
}
