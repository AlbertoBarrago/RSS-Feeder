//
//  Data+Extensions.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import Foundation

extension String {
    func extractDomain() -> String {
        guard let url = URL(string: self),
              let host = url.host else {
            return self
        }

        let components = host.components(separatedBy: ".")
        if components.count > 2 && components[0] == "www" {
            return components.dropFirst().joined(separator: ".")
        }
        return host
    }

    func extractDomainName() -> String {
        guard let url = URL(string: self),
              let host = url.host else {
            return "RSS Feed"
        }

        let components = host.components(separatedBy: ".")
        if components.count > 2 && components[0] == "www" {
            return components[1].capitalized
        } else if components.count > 1 {
            return components[0].capitalized
        }
        return host.capitalized
    }

    func isValidURL() -> Bool {
        if let url = URL(string: self) {
            return url.scheme == "http" || url.scheme == "https"
        }
        return false
    }

    func toDate() -> Date? {
        let formatter = DateFormatter()
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: self) {
                return date
            }
        }
        return nil
    }

    func formatAsRSSDate() -> String {
        guard let date = self.toDate() else {
            return self
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            return formatter.string(from: date)
        }
    }
}