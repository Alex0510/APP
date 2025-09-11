//
//  CertificateMemoryHandler.swift
//  Ksign
//
//  Created by Nagata Asami on 6/14/25.
//

import Foundation

final class CertificateMemoryHandler: NSObject {
	private let _uuid = UUID().uuidString
	
	private let _p12Data: Data
	private let _provisionData: Data
	private let _keyPassword: String?
	private let _certNickname: String?
	
	private var _certPair: Certificate?
	
	init(
		p12Data: Data,
		provisionData: Data,
		password: String? = nil,
		nickname: String? = nil
	) {
		self._p12Data = p12Data
		self._provisionData = provisionData
		self._keyPassword = password
		self._certNickname = nickname
		
		// Parse the provision data to get certificate info
		_certPair = CertificateReader.parseData(provisionData)
		
		super.init()
	}
	
	func validate() -> Bool {
		return _certPair != nil
	}
	
	func addToDatabase() async throws {
		guard _certPair != nil else {
			throw CertificateMemoryHandlerError.certNotValid
		}
		
		Storage.shared.addCertificateWithData(
			uuid: _uuid,
			p12Data: _p12Data,
			provisionData: _provisionData,
			password: _keyPassword,
			nickname: _certNickname,
			ppq: _certPair?.PPQCheck ?? false,
			expiration: _certPair?.ExpirationDate ?? Date()
		) { _ in
			print("[\(self._uuid)] Added certificate to database with in-memory data")
		}
	}
}

private enum CertificateMemoryHandlerError: Error {
	case certNotValid
} 