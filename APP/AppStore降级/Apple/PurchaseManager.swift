//
//  PurchaseManager.swift
//  APP
//
//  由 pxx917144686 于 2025/08/20 创建。
//
import Foundation
// MARK: - 缺失类型的类型别名
// 使用来自 Apple.swift 的 Account 类型
/// 处理应用内购买和许可证管理的购买管理器
class PurchaseManager {
    static let shared = PurchaseManager()
    // 使用特定的客户端实现以避免歧义
    private let searchManager = SearchManager.shared
    private init() {}
    /// 从 iTunes 商店购买应用
    /// - 参数:
    ///   - appIdentifier: 应用标识符 (ID 或包 ID)
    ///   - account: 用户账户信息
    ///   - countryCode: 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 包含购买响应或错误的结果
    func purchaseApp(
        appIdentifier: String,
        account: Account,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<PurchaseResult, PurchaseError> {
        do {
            // 首先，如果提供的是包 ID，则获取曲目 ID
            let trackId: String
            if Int(appIdentifier) != nil {
                // 已经是曲目 ID
                trackId = appIdentifier
            } else {
                // 假设是包 ID，进行查找
                let trackIdResult = await searchManager.getTrackId(
                    bundleIdentifier: appIdentifier,
                    countryCode: countryCode,
                    deviceFamily: deviceFamily
                )
                switch trackIdResult {
                case .success(let id):
                    trackId = String(id)
                case .failure(let error):
                    return .failure(.appNotFound(error.localizedDescription))
                }
            }
            // 尝试购买应用
            let _ = try await StoreRequest.shared.purchase(
                appIdentifier: trackId,
                directoryServicesIdentifier: account.directoryServicesIdentifier,
                passwordToken: account.passwordToken,
                storeFront: account.storeResponse.storeFront
            )
            // 如果执行到这里，说明购买成功
            let result = PurchaseResult(
                trackId: trackId,
                success: true,
                message: "应用购买成功",
                licenseInfo: nil
            )
            return .success(result)
        } catch {
            if let se = error as? StoreError, se == .userInteractionRequired {
                return .failure(.unknownError("需要在 App Store 完成一次获取/密码确认后再试"))
            }
            return .failure(.networkError(error))
        }
    }
    /// 检查用户是否已经购买或拥有该应用
    /// - 参数:
    ///   - appIdentifier: 应用标识符 (曲目 ID 或包 ID)
    ///   - account: 用户账户信息
    ///   - countryCode: 商店区域 (默认值: "US")
    /// - 返回值: 指示应用是否已拥有的结果
    func checkAppOwnership(
        appIdentifier: String,
        account: Account,
        countryCode: String = "US"
    ) async -> Result<Bool, PurchaseError> {
        do {
            // 尝试获取应用的下载信息
            // 如果成功，则用户拥有该应用
            let trackId: String
            if Int(appIdentifier) != nil {
                trackId = appIdentifier
            } else {
                let trackIdResult = await searchManager.getTrackId(
                    bundleIdentifier: appIdentifier,
                    countryCode: countryCode,
                    deviceFamily: DeviceFamily.phone
                )
                switch trackIdResult {
                case .success(let id):
                    trackId = String(id)
                case .failure(let error):
                    return .failure(.appNotFound(error.localizedDescription))
                }
            }
            let downloadResponse = try await StoreRequest.shared.download(
                appIdentifier: trackId,
                directoryServicesIdentifier: account.directoryServicesIdentifier,
                appVersion: nil,
                passwordToken: account.passwordToken,
                storeFront: account.storeResponse.storeFront
            )
            // 如果执行到这里且 songList 有项，则说明用户拥有该应用
            return .success(!downloadResponse.songList.isEmpty)
        } catch let storeError as StoreError {
            // 特殊处理StoreError类型的错误
            if case .invalidLicense = storeError {
                print("🔐 [购买验证] 检测到许可证错误，用户未购买此应用")
                // 重要修改：对于许可证错误，不返回失败，而是返回成功但标记为未拥有
                // 这样可以让下载流程继续，而不是直接阻止下载
                return .success(false)
            }
            // 其他StoreError类型
            return .failure(.networkError(storeError))
        } catch {
            // 其他类型的错误
            return .failure(.networkError(error))
        }
    }
    /// 如果用户尚未拥有应用，则进行购买
    /// - 参数:
    ///   - appIdentifier: 应用标识符 (曲目 ID 或包 ID)
    ///   - account: 用户账户信息
    ///   - countryCode: 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 包含购买结果的结果
    func purchaseAppIfNeeded(
        appIdentifier: String,
        account: Account,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<PurchaseResult, PurchaseError> {
        // 首先检查用户是否已经拥有该应用
        let ownershipResult = await checkAppOwnership(
            appIdentifier: appIdentifier,
            account: account,
            countryCode: countryCode
        )
        switch ownershipResult {
        case .success(let isOwned):
            if isOwned {
                let result = PurchaseResult(
                    trackId: appIdentifier,
                    success: true,
                    message: "应用已拥有，无需购买",
                    licenseInfo: nil
                )
                return .success(result)
            } else {
                // 未拥有则尝试执行零元购买（仅对免费应用有效；对付费应用会返回错误）
                do {
                    let _ = try await StoreRequest.shared.purchase(
                        appIdentifier: String(appIdentifier),
                        directoryServicesIdentifier: account.directoryServicesIdentifier,
                        passwordToken: account.passwordToken,
                        storeFront: account.storeResponse.storeFront
                    )
                    let result = PurchaseResult(
                        trackId: appIdentifier,
                        success: true,
                        message: "已完成获取（零元购买）",
                        licenseInfo: nil
                    )
                    return .success(result)
                } catch {
                    return .failure(.networkError(error))
                }
            }
        case .failure(let error):
            // 仅在真正的网络或API错误时返回失败
            // 对于许可证错误，已经在checkAppOwnership中处理
            return .failure(error)
        }
    }
    /// 获取应用价格信息
    /// - 参数:
    ///   - appIdentifier: 应用标识符 (曲目 ID 或包 ID)
    ///   - countryCode: 商店区域 (默认值: "US")
    ///   - deviceFamily: 设备类型 (默认值: .phone)
    /// - 返回值: 包含价格信息的结果
    func getAppPrice(
        appIdentifier: String,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async -> Result<AppPriceInfo, PurchaseError> {
        let lookupResult: Result<iTunesSearchResult, SearchError>
        if Int(appIdentifier) != nil {
            // 是曲目 ID，需要进行搜索
            // 这是一个限制 - 需要不同的 API 端点来通过曲目 ID 查找
            return .failure(.invalidIdentifier("无法通过Track ID获取价格信息，请使用Bundle ID"))
        } else {
            // 是包 ID
            lookupResult = await searchManager.lookupApp(
                bundleIdentifier: appIdentifier,
                countryCode: countryCode,
                deviceFamily: deviceFamily
            )
        }
        switch lookupResult {
        case .success(let appInfo):
            let priceInfo = AppPriceInfo(
                trackId: appInfo.trackId,
                bundleId: appInfo.bundleId,
                price: appInfo.price ?? 0.0,
                formattedPrice: appInfo.formattedPrice ?? "\(appInfo.price ?? 0.0)",
                currency: appInfo.currency ?? "USD",
                isFree: (appInfo.price ?? 0.0) == 0.0
            )
            return .success(priceInfo)
        case .failure(let error):
            return .failure(.appNotFound(error.localizedDescription))
        }
    }
    // MARK: - 私有辅助方法
    /// 将商店 API 购买错误映射为 PurchaseError
    private func mapPurchaseError(_ failureType: String, customerMessage: String?) -> PurchaseError {
        switch failureType.lowercased() {
        case let type where type.contains("price"):
            return .priceMismatch(customerMessage ?? "价格不匹配")
        case let type where type.contains("country"):
            return .invalidCountry(customerMessage ?? "无效的国家/地区")
        case let type where type.contains("password"):
            return .passwordTokenExpired(customerMessage ?? "密码令牌已过期")
        case let type where type.contains("license"):
            return .licenseAlreadyExists(customerMessage ?? "许可证已存在")
        case let type where type.contains("payment"):
            return .paymentRequired(customerMessage ?? "需要付款")
        default:
            return .unknownError(customerMessage ?? "未知购买错误")
        }
    }
    /// 将商店 API 下载错误映射为相应的错误
    private func mapDownloadError(_ failureType: String, customerMessage: String?) -> PurchaseError {
        switch failureType.lowercased() {
        case let type where type.contains("license"):
            return .licenseCheckFailed(customerMessage ?? "许可证检查失败")
        case let type where type.contains("item"):
            return .appNotFound(customerMessage ?? "应用未找到")
        default:
            return .unknownError(customerMessage ?? "未知错误")
        }
    }
}
// MARK: - 购买模型
/// 购买结果信息
struct PurchaseResult {
    let trackId: String
    let success: Bool
    let message: String
    let licenseInfo: LicenseInfo?
}
/// 应用许可证信息
struct LicenseInfo {
    let licenseId: String
    let purchaseDate: Date
    let expirationDate: Date?
    let isValid: Bool
}
/// 应用价格信息
struct AppPriceInfo {
    let trackId: Int
    let bundleId: String
    let price: Double
    let formattedPrice: String
    let currency: String
    let isFree: Bool
    var displayPrice: String {
        return isFree ? "免费" : formattedPrice
    }
}
/// 购买相关的错误
enum PurchaseError: LocalizedError {
    case invalidIdentifier(String)
    case appNotFound(String)
    case priceMismatch(String)
    case invalidCountry(String)
    case passwordTokenExpired(String)
    case licenseAlreadyExists(String)
    case paymentRequired(String)
    case licenseCheckFailed(String)
    case networkError(Error)
    case unknownError(String)
    var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let message):
            return "无效的应用标识符: \(message)"
        case .appNotFound(let message):
            return "应用未找到: \(message)"
        case .priceMismatch(let message):
            return "价格不匹配: \(message)"
        case .invalidCountry(let message):
            return "无效的国家/地区: \(message)"
        case .passwordTokenExpired(let message):
            return "密码令牌已过期: \(message)"
        case .licenseAlreadyExists(let message):
            return "许可证已存在: \(message)"
        case .paymentRequired(let message):
            return "需要付款: \(message)"
        case .licenseCheckFailed(let message):
            return "许可证检查失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}