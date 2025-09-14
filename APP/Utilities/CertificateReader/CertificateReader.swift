import UIKit
import OSLog

class CertificateReader: NSObject {
	let file: URL?
	var decoded: Certificate?
	
	init(_ file: URL?) {
		self.file = file
		super.init()
		self.decoded = self._readAndDecode()
	}
	
	private func _readAndDecode() -> Certificate? {
		guard let file = file else { return nil }
		
		do {
			let fileData = try Data(contentsOf: file)
			
			guard let xmlRange = fileData.range(of: Data("<?xml".utf8)) else {
				Logger.misc.error("未找到XML开始标记")
				return nil
			}
			
			let xmlData = fileData.subdata(in: xmlRange.lowerBound..<fileData.endIndex)
			
			let decoder = PropertyListDecoder()
			let data = try decoder.decode(Certificate.self, from: xmlData)
			return data
		} catch {
			Logger.misc.error("提取证书时出错: \(error.localizedDescription)")
			return nil
		}
	}
}
