//
//  iTunesAPI.swift
//  APP
//
//  由 pxx917144686 于 2025/08/24 创建。
//
import Foundation
import SwiftUI
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
enum DeviceFamily: String, CaseIterable, Codable {
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
    // MARK: - 公共辅助
    private func storefrontCode(for countryCode: String) -> String {
        let cc = countryCode.uppercased()
        return Apple.storeFrontCodeMap[cc] ?? "143441"
    }
    private func appsPageURL(country: String, appId: Int) -> URL {
        return URL(string: "https://apps.apple.com/\(country)/app/id\(appId)")!
    }
    private func fetchAMPTargetToken(country: String, appId: Int) async throws -> String {
        let url = appsPageURL(country: country, appId: appId)
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw SearchError.invalidResponse
        }
        let pattern = #"token%22%3A%22([^%]+)%22%7D"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: html.utf16.count)
        guard let match = regex.firstMatch(in: html, options: [], range: range), match.numberOfRanges >= 2,
              let tokenRange = Range(match.range(at: 1), in: html) else {
            throw SearchError.invalidResponse
        }
        return String(html[tokenRange])
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

    // MARK: - Reviews (RSS JSON)
    enum ReviewSort: String { case mostRecent = "mostRecent", mostHelpful = "mostHelpful" }
    struct AppReview: Codable, Identifiable, Hashable {
        let id: String
        let userName: String
        let userUrl: String
        let version: String
        let score: Int
        let title: String
        let text: String
        let url: String
        let updated: String
    }
    func reviews(
        id: Int,
        country: String = "us",
        page: Int = 1,
        sort: ReviewSort = .mostRecent
    ) async throws -> [AppReview] {
        let url = URL(string: "https://itunes.apple.com/\(country)/rss/customerreviews/page=\(page)/id=\(id)/sortby=\(sort.rawValue)/json")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SearchError.invalidResponse }
        // 结构松散，使用字典解析
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let feed = json?["feed"] as? [String: Any]
        let entries = (feed?["entry"] as? [[String: Any]]) ?? []
        let map: ( [String: Any] ) -> AppReview? = { entry in
            guard let id = (entry["id"] as? [String: Any])?["label"] as? String,
                  let author = entry["author"] as? [String: Any],
                  let name = (author["name"] as? [String: Any])?["label"] as? String,
                  let uri = (author["uri"] as? [String: Any])?["label"] as? String,
                  let version = ((entry["im:version"] as? [String: Any])?["label"]) as? String,
                  let ratingStr = ((entry["im:rating"] as? [String: Any])?["label"]) as? String,
                  let rating = Int(ratingStr),
                  let title = (entry["title"] as? [String: Any])?["label"] as? String,
                  let text = (entry["content"] as? [String: Any])?["label"] as? String,
                  let link = (entry["link"] as? [String: Any])?["attributes"] as? [String: Any],
                  let href = link["href"] as? String,
                  let updated = (entry["updated"] as? [String: Any])?["label"] as? String
            else { return nil }
            return AppReview(id: id, userName: name, userUrl: uri, version: version, score: rating, title: title, text: text, url: href, updated: updated)
        }
        return entries.compactMap(map)
    }

    // MARK: - Privacy (AMP API)
    struct AppPrivacy: Codable {
        let managePrivacyChoicesUrl: String?
        let privacyTypes: [PrivacyType]
        struct PrivacyType: Codable { let privacyType: String; let identifier: String; let description: String; let dataCategories: [DataCategory]? }
        struct DataCategory: Codable { let dataCategory: String; let identifier: String; let dataTypes: [String]? }
    }
    func privacy(id: Int, country: String = "US") async throws -> AppPrivacy {
        let token = try await fetchAMPTargetToken(country: country, appId: id)
        let url = URL(string: "https://amp-api-edge.apps.apple.com/v1/catalog/\(country)/apps/\(id)?platform=web&fields=privacyDetails")!
        var request = URLRequest(url: url)
        request.setValue("https://apps.apple.com", forHTTPHeaderField: "Origin")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SearchError.invalidResponse }
        let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let dataArr = root?["data"] as? [[String: Any]], let first = dataArr.first,
           let attributes = first["attributes"] as? [String: Any], let privacy = attributes["privacyDetails"] {
            let pdata = try JSONSerialization.data(withJSONObject: privacy, options: [])
            return try JSONDecoder().decode(AppPrivacy.self, from: pdata)
        }
        throw SearchError.invalidResponse
    }

    // MARK: - Version History (AMP API)
    struct AppVersionInfo: Codable, Identifiable, Hashable { let versionDisplay: String; let releaseNotes: String?; let releaseDate: String; let releaseTimestamp: String; var id: String { versionDisplay + releaseTimestamp } }
    func versionHistory(id: Int, country: String = "US") async throws -> [AppVersionInfo] {
        let token = try await fetchAMPTargetToken(country: country, appId: id)
        let url = URL(string: "https://amp-api-edge.apps.apple.com/v1/catalog/\(country)/apps/\(id)?platform=web&extend=versionHistory&additionalPlatforms=appletv,ipad,iphone,mac,realityDevice")!
        var request = URLRequest(url: url)
        request.setValue("https://apps.apple.com", forHTTPHeaderField: "Origin")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SearchError.invalidResponse }
        let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let dataArr = root?["data"] as? [[String: Any]], let first = dataArr.first,
           let attributes = first["attributes"] as? [String: Any],
           let platform = attributes["platformAttributes"] as? [String: Any],
           let ios = platform["ios"] as? [String: Any],
           let versions = ios["versionHistory"] {
            let vdata = try JSONSerialization.data(withJSONObject: versions, options: [])
            return try JSONDecoder().decode([AppVersionInfo].self, from: vdata)
        }
        return []
    }

    // MARK: - Suggest (XML Plist)
    struct SuggestTerm: Codable, Identifiable, Hashable { let term: String; var id: String { term } }
    
    // MARK: - Search History
    struct SearchHistoryItem: Codable, Identifiable, Hashable {
        let id: UUID
        let query: String
        let timestamp: Date
        let resultCount: Int
        
        init(query: String, resultCount: Int = 0) {
            self.id = UUID()
            self.query = query
            self.timestamp = Date()
            self.resultCount = resultCount
        }
    }
    
    // MARK: - Search Filter
    struct SearchFilter: Codable {
        var category: String = "0" // 所有分类
        var price: PriceFilter = .all
        var rating: RatingFilter = .all
        var deviceType: DeviceFamily = .phone
        var sortBy: SortOption = .relevance
        
        enum PriceFilter: String, CaseIterable, Codable {
            case all = "all"
            case free = "free"
            case paid = "paid"
            
            var displayName: String {
                switch self {
                case .all: return "所有价格"
                case .free: return "免费"
                case .paid: return "付费"
                }
            }
        }
        
        enum RatingFilter: String, CaseIterable, Codable {
            case all = "all"
            case fourPlus = "4+"
            case threePlus = "3+"
            case twoPlus = "2+"
            case onePlus = "1+"
            
            var displayName: String {
                switch self {
                case .all: return "所有评分"
                case .fourPlus: return "4星以上"
                case .threePlus: return "3星以上"
                case .twoPlus: return "2星以上"
                case .onePlus: return "1星以上"
                }
            }
        }
        
        enum SortOption: String, CaseIterable, Codable {
            case relevance = "relevance"
            case popularity = "popularity"
            case rating = "rating"
            case releaseDate = "releaseDate"
            case price = "price"
            
            var displayName: String {
                switch self {
                case .relevance: return "相关性"
                case .popularity: return "热门度"
                case .rating: return "评分"
                case .releaseDate: return "发布日期"
                case .price: return "价格"
                }
            }
        }
    }
    func suggest(term: String) async throws -> [SuggestTerm] {
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let url = URL(string: "https://search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints?clientApplication=Software&term=\(encoded)")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SearchError.invalidResponse }
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = plist as? [String: Any],
              let arr = ((dict["plist"] as? [String: Any])?["dict"] as? [String: Any])?["array"] as? [[String: Any]] ?? (dict["array"] as? [[String: Any]]),
              let list = arr.first? ["dict"] as? [[String: Any]] else { return [] }
        var terms: [SuggestTerm] = []
        for entry in list {
            if let s = entry["string"] as? [String], let t = s.first { terms.append(SuggestTerm(term: t)) }
        }
        return terms
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
    
    /// 增强搜索方法 - 支持过滤器和排序
    func enhancedSearch(
        query: String,
        filter: SearchFilter = SearchFilter(),
        limit: Int = 50,
        country: String = "US"
    ) async -> Result<[iTunesSearchResult], Error> {
        do {
            var searchResults = try await search(
                term: query,
                limit: limit,
                countryCode: country,
                deviceFamily: filter.deviceType
            ) ?? []
            
            // 应用过滤器
            searchResults = applyFilters(searchResults, filter: filter)
            
            // 应用排序
            searchResults = applySorting(searchResults, sortBy: filter.sortBy)
            
            return .success(searchResults)
        } catch {
            return .failure(error)
        }
    }
    
    /// 应用搜索过滤器
    private func applyFilters(_ results: [iTunesSearchResult], filter: SearchFilter) -> [iTunesSearchResult] {
        var filtered = results
        
        // 价格过滤
        switch filter.price {
        case .free:
            filtered = filtered.filter { $0.price == 0.0 }
        case .paid:
            filtered = filtered.filter { ($0.price ?? 0.0) > 0.0 }
        case .all:
            break
        }
        
        // 评分过滤
        switch filter.rating {
        case .fourPlus:
            filtered = filtered.filter { ($0.averageUserRating ?? 0.0) >= 4.0 }
        case .threePlus:
            filtered = filtered.filter { ($0.averageUserRating ?? 0.0) >= 3.0 }
        case .twoPlus:
            filtered = filtered.filter { ($0.averageUserRating ?? 0.0) >= 2.0 }
        case .onePlus:
            filtered = filtered.filter { ($0.averageUserRating ?? 0.0) >= 1.0 }
        case .all:
            break
        }
        
        // 分类过滤 - 暂时禁用，因为iTunesSearchResult没有primaryGenreId属性
        // if filter.category != "0" {
        //     filtered = filtered.filter { $0.primaryGenreId == Int(filter.category) }
        // }
        
        return filtered
    }
    
    /// 应用排序
    private func applySorting(_ results: [iTunesSearchResult], sortBy: SearchFilter.SortOption) -> [iTunesSearchResult] {
        switch sortBy {
        case .relevance:
            return results // 保持原始顺序
        case .popularity:
            return results.sorted { ($0.userRatingCount ?? 0) > ($1.userRatingCount ?? 0) }
        case .rating:
            return results.sorted { ($0.averageUserRating ?? 0.0) > ($1.averageUserRating ?? 0.0) }
        case .releaseDate:
            return results.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
        case .price:
            return results.sorted { ($0.price ?? 0.0) < ($1.price ?? 0.0) }
        }
    }
    
    /// 获取搜索建议
    func getSearchSuggestions(for query: String) async -> Result<[SuggestTerm], Error> {
        do {
            let suggestions = try await suggest(term: query)
            return .success(suggestions)
        } catch {
            return .failure(error)
        }
    }
}