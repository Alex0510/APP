//
//  ZipCompression+cases.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import ZipArchive

// 定义压缩级别枚举
enum ZipCompression: Int, CaseIterable, Hashable {
	case NoCompression = 0
	case BestSpeed = 1
	case DefaultCompression = 2
	case BestCompression = 3
	
	static var allCases: [ZipCompression] {
		return [.NoCompression, .BestSpeed, .DefaultCompression, .BestCompression]
	}
	
	var label: String {
		switch self {
		case .NoCompression: return "None"
		case .BestSpeed: return "Speed"
		case .DefaultCompression: return "Default"
		case .BestCompression: return "Best"
		}
	}
}
