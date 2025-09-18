import SwiftUI
import Zsign

struct LibraryInfoView: View {
	var app: AppInfoPresentable
	@Environment(\.dismiss) private var dismiss
	
    var body: some View {
		NavigationView {
			List {
				Section {} header: {
					FRAppIconView(app: app)
						.frame(maxWidth: .infinity, alignment: .center)
				}
				
				_infoSection(for: app)
				_certSection(for: app)
				_bundleSection(for: app)
				_executableSection(for: app)
				
				Section {
					Button("在文件中打开", systemImage: "folder") {
						if let uuidDir = Storage.shared.getUuidDirectory(for: app) {
							let urlString = uuidDir.absoluteString
							if urlString.hasPrefix("file://") {
								let newURLString = "shareddocuments://" + urlString.dropFirst("file://".count)
								if let sharedURL = URL(string: newURLString) {
									UIApplication.shared.open(sharedURL)
								}
							}
						}
					}
				}
			}
			.navigationTitle(app.name ?? "")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("取消") {
						dismiss()
					}
				}
			}
		}
    }
}

extension LibraryInfoView {
	@ViewBuilder
	private func _infoSection(for app: AppInfoPresentable) -> some View {
		Section {
			if let name = app.name {
				_infoCell("名称", desc: name)
			}
			
			if let ver = app.version {
				_infoCell("版本", desc: ver)
			}
			
			if let id = app.identifier {
				_infoCell("标识符", desc: id)
			}
			
			if let date = app.date {
				_infoCell("添加日期", desc: date.formatted())
			}
		} header: {
			Text("信息")
		}
	}
	
	@ViewBuilder
	private func _certSection(for app: AppInfoPresentable) -> some View {
		if let cert = Storage.shared.getCertificate(from: app) {
			Section {
				CertificatesCellView(
					cert: cert
				)
			} header: {
				Text("证书")
			}
		}
	}
	
	@ViewBuilder
	private func _bundleSection(for app: AppInfoPresentable) -> some View {
		Section {
			NavigationLink("替代图标", destination: SigningAlternativeIconView(app: app, appIcon: .constant(nil), isModifing: .constant(false)))
			NavigationLink("框架和插件", destination: SigningFrameworksView(app: app, options: .constant(nil)))
		} header: {
			Text("包")
		}
	}
	
	@ViewBuilder
	private func _executableSection(for app: AppInfoPresentable) -> some View {
		Section {
			NavigationLink("动态库", destination: SigningDylibView(app: app, options: .constant(nil)))
		} header: {
			Text("可执行文件")
		}
	}
	
	@ViewBuilder
	private func _infoCell(_ title: String, desc: String) -> some View {
		HStack {
			Text(title)
			Spacer()
			Text(desc)
				.foregroundColor(.secondary)
		}
		.copyableText(desc)
	}
}
