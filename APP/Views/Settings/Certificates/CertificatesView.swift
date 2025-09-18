
import SwiftUI

struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@State private var _isAddingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	var body: some View {
		List {
			ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
				_cellButton(for: cert, at: index)
			}
		}
		.navigationTitle("证书")
		.overlay {
			if _certificates.isEmpty {
				if #available(iOS 17, *) {
						VStack(spacing: 16) {
							Image(systemName: "questionmark.folder.fill")
								.font(.system(size: 48))
								.foregroundColor(.secondary)
							Text("无证书")
								.font(.title2)
								.fontWeight(.medium)
							Text("通过导入一个证书开始签名。")
								.font(.body)
								.foregroundColor(.secondary)
							Button {
								_isAddingPresenting = true
							} label: {
								Label("导入", systemImage: "plus")
							}
							.buttonStyle(.bordered)
							
							if _bindingSelectedCert == nil {
								Button {
									_isAddingPresenting = true
								} label: {
									Label("添加证书", systemImage: "plus")
								}
								.buttonStyle(.bordered)
							}
						}
				}
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationBarBackButtonHidden(false)
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
		}
	}
}

extension CertificatesView {
	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		Button {
			_selectedCertBinding.wrappedValue = index
		} label: {
			CertificatesCellView(
				cert: cert
			)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.vertical, 8)
		}
		.buttonStyle(.plain)
		.listRowBackground(
			_selectedCertBinding.wrappedValue == index ? 
			Color.accentColor.opacity(0.1) : 
			Color.clear
		)
		.listRowSeparator(.hidden)
		.contextMenu {
			_contextActions(for: cert)
			Divider()
			_actions(for: cert)
		}
		.transaction {
			$0.animation = nil
		}
	}
	
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
			Button("删除", systemImage: "trash", role: .destructive) {
			Storage.shared.deleteCertificate(for: cert)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
			Button("获取信息", systemImage: "info.circle") {
			_isSelectedInfoPresenting = cert
		}
		Divider()
			Button("证书时效状态", systemImage: "person.text.rectangle") {
			Storage.shared.revokagedCertificate(for: cert)
		}
	}
}
