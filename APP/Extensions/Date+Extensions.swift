import Foundation
import SwiftUI

extension Date {
    func stripTime() -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    struct ExpirationInfo {
        let date: Date
        let formatted: String
        let color: Color
        let icon: String
        
        init(date: Date) {
            self.date = date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            self.formatted = formatter.string(from: date)
            
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            
            if daysUntilExpiration < 0 {
                self.color = .red // 已过期
                self.icon = "exclamationmark.triangle.fill"
            } else if daysUntilExpiration < 7 {
                self.color = .orange // 即将过期
                self.icon = "clock.fill"
            } else if daysUntilExpiration < 30 {
                self.color = .yellow // 一个月内过期
                self.icon = "clock"
            } else {
                self.color = .green // 正常
                self.icon = "checkmark.circle.fill"
            }
        }
    }
    
    func expirationInfo() -> ExpirationInfo {
        return ExpirationInfo(date: self)
    }
}