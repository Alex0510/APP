//
//  NetworkingManager.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//  简化的网络管理器
//

import Foundation
import Combine
import UIKit

class NetworkingManager {
    
    static func download(url: URL) -> AnyPublisher<Data, Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    static func handleCompletion(completion: Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            break
        case .failure(let error):
            print("Download error: \(error)")
        }
    }
}
