//
//  String.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//  字符串扩展
//

import Foundation
import CryptoKit

extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
}
