//
//  RSSmodel.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftData
import Foundation

@Model
final class RSSFeedItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var link: String
    var pubDate: String
    var feedSourceName: String
    var feedSourceURL: String
    var isRead: Bool = false
    
    init(title: String, link: String, pubDate: String, feedSourceName: String, feedSourceURL: String) {
        self.title = title
        self.link = link
        self.pubDate = pubDate
        self.feedSourceName = feedSourceName
        self.feedSourceURL = feedSourceURL
        self.isRead = false
    }
}

@Model
final class RSSFeedSource: Identifiable {
    var id: UUID = UUID()
    var name: String
    var url: String
    
    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

enum FilterOption: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case read = "Read"
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .unread: return "envelope.badge"
        case .read: return "envelope.open"
        }
    }
}
