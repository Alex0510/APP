//
//  AppFavorite.swift
//  APP
//
//  Created by pxx917144686 on 2025/09/18.
//

import Foundation

struct AppFavorite: Codable, Identifiable {
    let appId: String
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let bundleId: String
    let version: String
    let price: Double?
    let formattedPrice: String?
    let currency: String?
    let addTimeStamp: TimeInterval
    let regionName: String
    
    var id: String { "\(appId)_\(regionName)" }
    
    var addTime: String {
        let date = Date.init(timeIntervalSince1970: addTimeStamp)
        let dateformat = DateFormatter()
        dateformat.dateFormat = "yyyy-MM-dd HH:mm"
        return dateformat.string(from: date)
    }
    
    var displayPrice: String {
        if let price = price, price > 0 {
            return formattedPrice ?? "\(price)"
        } else {
            return "免费"
        }
    }
    
    static func createFromAppDetail(_ appDetail: AppDetail, regionName: String) -> AppFavorite {
        return AppFavorite(
            appId: String(appDetail.trackId),
            trackName: appDetail.trackName,
            artistName: appDetail.artistName,
            artworkUrl100: appDetail.artworkUrl100,
            bundleId: appDetail.bundleId,
            version: appDetail.version,
            price: appDetail.price,
            formattedPrice: appDetail.formattedPrice,
            currency: appDetail.currency,
            addTimeStamp: Date().timeIntervalSince1970,
            regionName: regionName
        )
    }
}
