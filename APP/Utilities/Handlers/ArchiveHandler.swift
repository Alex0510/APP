import Foundation
import UIKit.UIApplication
import ZIPFoundation
import SwiftUI

final class ArchiveHandler: NSObject {
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _payloadUrl: URL?
	
	private var _app: AppInfoPresentable
	private let _uniqueWorkDir: URL
	
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = app
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func move() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let payloadUrl = _uniqueWorkDir.appendingPathComponent("Payload")
		let movedAppURL = payloadUrl.appendingPathComponent(appUrl.lastPathComponent)

		try _fileManager.createDirectoryIfNeeded(at: payloadUrl)
		
		try _fileManager.copyItem(at: appUrl, to: movedAppURL)
		_payloadUrl = payloadUrl
	}
	
	func archive() async throws -> URL {
		guard let payloadUrl = _payloadUrl else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let zipUrl = _uniqueWorkDir.appendingPathComponent("Archive.zip")
		let ipaUrl = _uniqueWorkDir.appendingPathComponent("Archive.ipa")
		
		let progress = Progress(totalUnitCount: 100)
		try _fileManager.zipItem(
			at: payloadUrl,
			to: zipUrl,
			compressionMethod: .deflate,
			progress: progress
		)
		
		Task { @MainActor in
			self.viewModel.packageProgress = progress.fractionCompleted
		}
		
		try FileManager.default.moveItem(at: zipUrl, to: ipaUrl)
		return ipaUrl
	}
	
	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		let appendingString = "\(_app.name!)_\(_app.version!)_\(Int(Date().timeIntervalSince1970)).ipa"
		let dest = _fileManager.archives.appendingPathComponent(appendingString)
		
		try? _fileManager.moveItem(
			at: package,
			to: dest
		)
		
		if shouldOpen {
			await MainActor.run {
				let archivesURL = FileManager.default.archives
				let urlString = archivesURL.absoluteString
				if urlString.hasPrefix("file://") {
					let newURLString = "shareddocuments://" + urlString.dropFirst("file://".count)
					if let sharedURL = URL(string: newURLString) {
						UIApplication.shared.open(sharedURL)
					}
				}
			}
		}
		
		return dest
	}
	
	static func getCompressionLevel() -> Int {
		UserDefaults.standard.integer(forKey: "Feather.compressionLevel")
	}
}