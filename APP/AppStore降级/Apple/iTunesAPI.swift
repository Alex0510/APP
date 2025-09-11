//
//  iTunesAPI.swift
//  APP
//
//  由 pxx917144686 于 2025/08/24 创建。
//
import Foundation
/// 搜索错误类型
enum SearchError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case noResults
    case invalidAppIdentifier
    case rateLimited
    case emptyQuery
    case invalidLimit
    case invalidBundleId
    case invalidTrackId
    case missingIdentifier
    case appNotFound
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的API响应"
        case .noResults:
            return "未找到相关应用"
        case .invalidAppIdentifier:
            return "无效的应用标识符"
        case .rateLimited:
            return "请求频率过高，请稍后重试"
        case .emptyQuery:
            return "搜索词不能为空"
        case .invalidLimit:
            return "搜索结果数量限制无效（1-200）"
        case .invalidBundleId:
            return "无效的应用包标识符"
        case .invalidTrackId:
            return "无效的Track ID"
        case .missingIdentifier:
            return "缺少应用标识符或Track ID"
        case .appNotFound:
            return "未找到指定的应用"
        }
    }
}
/// iTunes 应用商店 API 的设备类型
enum DeviceFamily: String, CaseIterable {
    case phone = "iPhone"
    case pad = "iPad"
    /// 默认设备类型
    static let `default` = DeviceFamily.phone
    /// 用于 UI 显示的名称
    var displayName: String {
        switch self {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        }
    }
    /// 用于 iTunes API 的软件类型
    var softwareType: String {
        switch self {
        case .phone: return "software"
        case .pad: return "iPadSoftware"
        }
    }
    

    /// 用于 API 请求的设备标识符
    var identifier: String {
        return self.rawValue
    }
}
/// iTunes API 响应结构
struct iTunesResponse: Codable {
    let resultCount: Int
    let results: [iTunesSearchResult]
}
/// iTunes 搜索结果项
struct iTunesSearchResult: Codable, Identifiable, Hashable {
    let trackId: Int
    let trackName: String
    let artistName: String?
    let bundleId: String
    let version: String
    let formattedPrice: String?
    let price: Double?
    let currency: String?
    let trackViewUrl: String
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl512: String?
    let screenshotUrls: [String]?
    let ipadScreenshotUrls: [String]?
    let description: String?
    let releaseNotes: String?
    let sellerName: String?
    let genres: [String]?
    let primaryGenreName: String?
    let contentAdvisoryRating: String?
    let averageUserRating: Double?
    let userRatingCount: Int?
    let fileSizeBytes: String?
    let minimumOsVersion: String?
    let currentVersionReleaseDate: String?
    let releaseDate: String?
    let isGameCenterEnabled: Bool?
    let supportedDevices: [String]?
    let languageCodesISO2A: [String]?
    let advisories: [String]?
    let features: [String]?
    
    var id: Int { trackId }
    
    enum CodingKeys: String, CodingKey {
        case trackId, trackName, artistName, bundleId, version, formattedPrice, price, currency, trackViewUrl
        case artworkUrl60, artworkUrl100, artworkUrl512
        case screenshotUrls, ipadScreenshotUrls, description, releaseNotes
        case sellerName, genres, primaryGenreName, contentAdvisoryRating
        case averageUserRating, userRatingCount, fileSizeBytes
        case minimumOsVersion, currentVersionReleaseDate, releaseDate
        case isGameCenterEnabled, supportedDevices, languageCodesISO2A
        case advisories, features
    }
}
/// 用于在 iTunes 应用商店搜索和查找应用的 API 客户端
class iTunesClient {
    static let shared = iTunesClient()
    private let session: URLSession
    private let baseURL = "https://itunes.apple.com"
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    /// 在 iTunes 应用商店中搜索应用
    /// - 参数:
    ///   - term: 搜索词
    ///   - limit: 返回的最大结果数量
    ///   - countryCode: 要搜索的 iTunes 应用商店区域
    ///   - deviceFamily: 设备类型 (iPhone/iPad)
    /// - 返回值: 搜索结果，如果未找到结果则返回 nil
    func search(
        term: String,
        limit: Int = 50,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async throws -> [iTunesSearchResult]? {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: countryCode.lowercased()),
            URLQueryItem(name: "media", value: "software"),
            URLQueryItem(name: "entity", value: deviceFamily.softwareType),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iTunes/12.12.0 (Macintosh; OS X 10.15.7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        let iTunesResponse = try decoder.decode(iTunesResponse.self, from: data)
        return iTunesResponse.results.isEmpty ? nil : iTunesResponse.results
    }
    /// 通过应用包 ID 查找应用
    /// - 参数:
    ///   - bundleIdentifier: 要查找的应用包 ID
    ///   - countryCode: 要搜索的 iTunes 应用商店区域
    ///   - deviceFamily: 设备类型 (iPhone/iPad)
    /// - 返回值: 如果找到应用则返回应用信息，否则返回 nil
    func lookup(
        bundleIdentifier: String,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async throws -> iTunesSearchResult? {
        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: countryCode.lowercased()),
            URLQueryItem(name: "media", value: "software"),
            URLQueryItem(name: "entity", value: deviceFamily.softwareType),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iTunes/12.12.0 (Macintosh; OS X 10.15.7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        let iTunesResponse = try decoder.decode(iTunesResponse.self, from: data)
        return iTunesResponse.resultCount > 0 ? iTunesResponse.results.first : nil
    }
    /// 从应用包 ID 获取 Track ID
    /// - 参数:
    ///   - bundleIdentifier: 应用包 ID
    ///   - countryCode: 要搜索的 iTunes 应用商店区域
    ///   - deviceFamily: 设备类型 (iPhone/iPad)
    /// - 返回值: 如果找到则返回 Track ID，否则返回 nil
    func getTrackId(
        bundleIdentifier: String,
        countryCode: String = "US",
        deviceFamily: DeviceFamily = .phone
    ) async throws -> Int? {
        let result = try await lookup(
            bundleIdentifier: bundleIdentifier,
            countryCode: countryCode,
            deviceFamily: deviceFamily
        )
        return result?.trackId
    }
}
// MARK: - 扩展
extension iTunesSearchResult {
    /// 将文件大小格式化为人类可读的格式
    var byteCountDescription: String {
        guard let fileSizeBytes = fileSizeBytes,
              let bytes = Int64(fileSizeBytes) else {
            return "Unknown Size"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    /// 获取设备支持的图标名称
    var displaySupportedDevicesIcon: String {
        var supports_iPhone = false
        var supports_iPad = false
        for device in supportedDevices ?? [] {
            if device.lowercased().contains("iphone") {
                supports_iPhone = true
            }
            if device.lowercased().contains("ipad") {
                supports_iPad = true
            }
        }
        if supports_iPhone, supports_iPad {
            return "ipad.and.iphone"
        } else if supports_iPhone {
            return "iphone"
        } else if supports_iPad {
            return "ipad"
        } else {
            return "questionmark"
        }
    }
    // 为 UI 兼容性提供的便捷计算属性
    var name: String { trackName }
    var bundleIdentifier: String { bundleId }
    var identifier: Int { trackId }
}
extension iTunesClient {
    /// 使用 Result 类型搜索应用的便捷方法
    func searchApps(
        query: String,
        limit: Int = 50,
        country: String = "US",
        deviceType: DeviceFamily = .phone
    ) async -> Result<[iTunesSearchResult], Error> {
        do {
            let results = try await search(
                term: query,
                limit: limit,
                countryCode: country,
                deviceFamily: deviceType
            )
            return .success(results ?? [])
        } catch {
            return .failure(error)
        }
    }
    /// 使用 Result 类型查找应用的便捷方法
    func lookupApp(
        bundleId: String,
        country: String = "US",
        deviceType: DeviceFamily = .phone
    ) async -> Result<iTunesSearchResult?, Error> {
        do {
            let result = try await lookup(
                bundleIdentifier: bundleId,
                countryCode: country,
                deviceFamily: deviceType
            )
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
}