//
//  TSMGConstants.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation

struct TSMGConstants {
    
    
    // MARK: - 分类类型
    static let categoryTypeListIds: [String: String] = [
        "所有 App": "0",
        "商业": "6000",
        "开发者工具": "6024",
        "教育": "6017",
        "娱乐": "6016",
        "财务": "6015",
        "美食佳饮": "6023",
        "游戏": "6014",
        "健康健美": "6013",
        "生活": "6012",
        "医疗": "6020",
        "音乐": "6011",
        "导航": "6010",
        "新闻": "6009",
        "摄影与录像": "6008",
        "效率": "6007",
        "参考": "6006",
        "社交": "6005",
        "体育": "6004",
        "旅行": "6003",
        "工具": "6002",
        "购物": "6024",
        "天气": "6001",
        "图书": "6018",
        "报刊杂志": "6021",
        "商品指南": "6022"
    ]
    
    // MARK: - 地区类型
    static let regionTypeListIds: [String: String] = [
        "中国": "cn",
        "美国": "us",
        "日本": "jp",
        "英国": "gb",
        "德国": "de",
        "法国": "fr",
        "澳大利亚": "au",
        "加拿大": "ca",
        "意大利": "it",
        "西班牙": "es",
        "韩国": "kr",
        "巴西": "br",
        "墨西哥": "mx",
        "印度": "in",
        "俄罗斯": "ru",
        "荷兰": "nl",
        "瑞典": "se",
        "挪威": "no",
        "丹麦": "dk",
        "芬兰": "fi"
    ]
    
    
    // MARK: - 默认值
    static let defaultCategory = "所有 App"
    static let defaultRegion = "中国"
}
