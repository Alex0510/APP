import Foundation
import OSLog

class HeartbeatManager: ObservableObject {
	static let shared = HeartbeatManager()

	private init() {
	}

	func start(_ force: Bool) {
		Logger.misc.info("HeartbeatManager.start 调用")
	}

	func checkSocketConnection() -> (isConnected: Bool, error: Error?) {
		Logger.misc.info("HeartbeatManager.checkSocketConnection 调用")
		return (true, nil)
	}

	static func pairingFile() -> String {
		Logger.misc.info("HeartbeatManager.pairingFile 调用")
		return URL.documentsDirectory.appendingPathComponent("pairingFile.plist").path
	}
}
