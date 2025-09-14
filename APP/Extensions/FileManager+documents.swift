import Foundation.NSFileManager

extension FileManager {
	var archives: URL {
		URL.documentsDirectory.appendingPathComponent("Archives")
	}
	
	var signed: URL {
		URL.documentsDirectory.appendingPathComponent("Signed")
	}
	
	func signed(_ uuid: String) -> URL {
		signed.appendingPathComponent(uuid)
	}
	
	var unsigned: URL {
		URL.documentsDirectory.appendingPathComponent("Unsigned")
	}
	
	func unsigned(_ uuid: String) -> URL {
		unsigned.appendingPathComponent(uuid)
	}
	
	var certificates: URL {
		URL.documentsDirectory.appendingPathComponent("Certificates")
	}
	
	func certificates(_ uuid: String) -> URL {
		certificates.appendingPathComponent(uuid)
	}
}