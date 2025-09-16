import Foundation
import Vapor
import NIOSSL
import NIOTLS
import SwiftUI
import IDeviceSwift
class ServerInstaller: Identifiable, ObservableObject {
	let id = UUID()
	let port = Int.random(in: 4000...8000)
	private var _needsShutdown = false
	
	var packageUrl: URL?
	var app: AppInfoPresentable
	@ObservedObject var viewModel: InstallerStatusViewModel
	private var _server: Application?

	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.app = app
		self.viewModel = viewModel
		// 延迟初始化服务器
		Task {
			do {
				try await _setup()
				try _configureRoutes()
				try _server?.server.start()
				_needsShutdown = true
			} catch {
				print("ServerInstaller 初始化失败: \(error)")
			}
		}
	}
	
	deinit {
		_shutdownServer()
	}
	
	private func _setup() async throws {
		self._server = try? await setupApp(port: port)
	}
		
	private func _configureRoutes() throws {
		_server?.get("*") { [weak self] req in
			guard let self else { return Response(status: .badGateway) }
			switch req.url.path {
			case plistEndpoint.path:
				self._updateStatus(.sendingManifest)
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "text/xml",
				], body: .init(data: installManifestData))
			case displayImageSmallEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageSmallData))
			case displayImageLargeEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageLargeData))
			case payloadEndpoint.path:
				guard let packageUrl = packageUrl else {
					return Response(status: .notFound)
				}
				
				self._updateStatus(.sendingPayload)
				
				return req.fileio.streamFile(
					at: packageUrl.path
				) { result in
					self._updateStatus(.completed(result))
				}
			case "/install":
				var headers = HTTPHeaders()
				headers.add(name: .contentType, value: "text/html")
				return Response(status: .ok, headers: headers, body: .init(string: self.html))
			default:
				return Response(status: .notFound)
			}
		}
	}
	
	private func _shutdownServer() {
		guard _needsShutdown else { return }
		
		_needsShutdown = false
		_server?.server.shutdown()
		_server?.shutdown()
	}
	
	private func _updateStatus(_ newStatus: InstallerStatusViewModel.InstallerStatus) {
		DispatchQueue.main.async {
			self.viewModel.status = newStatus
		}
	}
		
	func getServerMethod() -> Int {
		UserDefaults.standard.integer(forKey: "Feather.serverMethod")
	}
	
	func getIPFix() -> Bool {
		UserDefaults.standard.bool(forKey: "Feather.ipFix")
	}
}