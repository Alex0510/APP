
import SwiftUI

struct SigningFrameworksView: View {
	@State private var _frameworks: [String] = []
	@State private var _plugins: [String] = []
	
	private let _frameworksPath: String = "框架"
	private let _pluginsPath: String = "插件"
	
	var app: AppInfoPresentable
	@Binding var options: Options?
	
	var body: some View {
		List {
			Group {
				if !_frameworks.isEmpty {
					Section(_frameworksPath) {
						ForEach(_frameworks, id: \.self) { framework in
							SigningToggleCellView(
								title: "\(self._frameworksPath)/\(framework)",
								options: $options,
								arrayKeyPath: \.removeFiles
							)
						}
					}
				}
				
				if !_plugins.isEmpty {
					Section(_pluginsPath) {
						ForEach(_plugins, id: \.self) { plugin in
							SigningToggleCellView(
								title: "\(self._pluginsPath)/\(plugin)",
								options: $options,
								arrayKeyPath: \.removeFiles
							)
						}
					}
				}
				
				if
					_frameworks.isEmpty,
					_plugins.isEmpty
				{
					Text("未找到框架或插件。")
						.font(.footnote)
						.foregroundColor(.secondary)
				}
			}
			.disabled(options == nil)
		}
		.navigationTitle("框架和插件")
		.onAppear(perform: _listFrameworksAndPlugins)
	}
}

extension SigningFrameworksView {
	private func _listFrameworksAndPlugins() {
		guard let path = Storage.shared.getAppDirectory(for: app) else { return }
		
		_frameworks = _listFiles(at: path.appendingPathComponent(_frameworksPath))
		_plugins = _listFiles(at: path.appendingPathComponent(_pluginsPath))
	}
	
	private func _listFiles(at path: URL) -> [String] {
		(try? FileManager.default.contentsOfDirectory(atPath: path.path)) ?? []
	}
}
