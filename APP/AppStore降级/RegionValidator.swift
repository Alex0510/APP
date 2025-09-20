//
//  RegionValidator.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation

/// 地区验证器 - 确保所有API调用使用正确的地区信息
@MainActor
class RegionValidator: ObservableObject {
    static let shared = RegionValidator()
    
    @Published var lastValidationResult: ValidationResult?
    @Published var validationHistory: [ValidationResult] = []
    
    private init() {}
    
    /// 验证结果
    struct ValidationResult {
        let timestamp: Date
        let accountEmail: String
        let accountRegion: String
        let searchRegion: String
        let effectiveRegion: String
        let isValid: Bool
        let errorMessage: String?
        
        var description: String {
            if isValid {
                return "✅ 地区验证通过: \(accountRegion) -> \(effectiveRegion)"
            } else {
                return "❌ 地区验证失败: \(errorMessage ?? "未知错误")"
            }
        }
    }
    
    /// 验证地区设置是否正确（不发布状态变化）
    func validateRegionSettings(
        account: Account?,
        searchRegion: String,
        effectiveRegion: String
    ) -> ValidationResult {
        let timestamp = Date()
        let accountEmail = account?.email ?? "未登录"
        let accountRegion = account?.countryCode ?? "未知"
        
        var isValid = true
        var errorMessage: String?
        
        // 检查账户是否存在
        guard let account = account else {
            isValid = false
            errorMessage = "未登录账户"
            let result = ValidationResult(
                timestamp: timestamp,
                accountEmail: accountEmail,
                accountRegion: accountRegion,
                searchRegion: searchRegion,
                effectiveRegion: effectiveRegion,
                isValid: isValid,
                errorMessage: errorMessage
            )
            // 异步保存验证结果
            Task { @MainActor in
                lastValidationResult = result
                validationHistory.append(result)
            }
            return result
        }
        
        // 检查账户地区是否有效
        if account.countryCode.isEmpty {
            isValid = false
            errorMessage = "账户地区信息为空"
        }
        
        // 检查有效地区是否与账户地区匹配
        if effectiveRegion != account.countryCode {
            isValid = false
            errorMessage = "有效地区(\(effectiveRegion))与账户地区(\(account.countryCode))不匹配"
        }
        
        // 检查storeFront是否有效
        if account.storeResponse.storeFront.isEmpty {
            isValid = false
            errorMessage = "账户StoreFront信息为空"
        }
        
        let result = ValidationResult(
            timestamp: timestamp,
            accountEmail: accountEmail,
            accountRegion: accountRegion,
            searchRegion: searchRegion,
            effectiveRegion: effectiveRegion,
            isValid: isValid,
            errorMessage: errorMessage
        )
        
        // 异步保存验证结果，避免在视图更新中触发状态变化
        Task { @MainActor in
            lastValidationResult = result
            validationHistory.append(result)
            
            // 限制历史记录数量
            if validationHistory.count > 50 {
                validationHistory.removeFirst()
            }
        }
        
        print("🔍 [RegionValidator] \(result.description)")
        
        return result
    }
    
    /// 获取地区验证建议
    func getRegionValidationAdvice(for result: ValidationResult) -> [String] {
        var advice: [String] = []
        
        if !result.isValid {
            if result.accountEmail == "未登录" {
                advice.append("请先登录Apple ID账户")
            } else if result.accountRegion == "未知" {
                advice.append("账户地区信息异常，请重新登录")
            } else if result.effectiveRegion != result.accountRegion {
                advice.append("建议将搜索地区设置为账户地区: \(result.accountRegion)")
            } else if result.errorMessage?.contains("StoreFront") == true {
                advice.append("账户StoreFront信息异常，请重新登录")
            }
        } else {
            advice.append("地区设置正确，可以正常下载")
        }
        
        return advice
    }
    
    /// 清除验证历史
    func clearValidationHistory() {
        validationHistory.removeAll()
        lastValidationResult = nil
    }
    
    /// 获取验证统计
    func getValidationStats() -> (total: Int, success: Int, failure: Int) {
        let total = validationHistory.count
        let success = validationHistory.filter { $0.isValid }.count
        let failure = total - success
        return (total, success, failure)
    }
}

// MARK: - 扩展方法
extension RegionValidator {
    
    /// 快速验证当前设置（不触发状态变化）
    func quickValidate(
        account: Account?,
        searchRegion: String,
        effectiveRegion: String
    ) -> Bool {
        // 简单的布尔验证，不调用会触发状态变化的方法
        guard let account = account else { return false }
        return account.countryCode == effectiveRegion
    }
    
    /// 安全的地区验证（不触发状态变化）
    func safeValidate(
        account: Account?,
        searchRegion: String,
        effectiveRegion: String
    ) -> Bool {
        guard let account = account else { return false }
        guard !account.countryCode.isEmpty else { return false }
        guard !effectiveRegion.isEmpty else { return false }
        return account.countryCode == effectiveRegion
    }
    
    /// 获取地区兼容性检查
    func checkRegionCompatibility(
        accountRegion: String,
        targetRegion: String
    ) -> (compatible: Bool, message: String) {
        if accountRegion == targetRegion {
            return (true, "地区完全匹配")
        }
        
        // 检查是否是常见的不兼容组合
        let incompatiblePairs = [
            ("CN", "US"), ("US", "CN"),
            ("HK", "CN"), ("CN", "HK"),
            ("TW", "CN"), ("CN", "TW")
        ]
        
        for (region1, region2) in incompatiblePairs {
            if (accountRegion == region1 && targetRegion == region2) ||
               (accountRegion == region2 && targetRegion == region1) {
                return (false, "\(accountRegion) 和 \(targetRegion) 地区不兼容")
            }
        }
        
        return (true, "地区可能兼容，但建议使用账户地区")
    }
}
