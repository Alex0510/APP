//
//  NetworkMonitor.swift
//  APP
//
//  Created by pxx917144686 on 2025/08/20.
//  从iAppStore-SwiftUI-main项目转移
//

import Foundation
import Network
import Combine

class NetworkStateChecker: ObservableObject {
    static let shared = NetworkStateChecker()
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    
    let publisher = PassthroughSubject<NWPath, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                self?.publisher.send(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}
