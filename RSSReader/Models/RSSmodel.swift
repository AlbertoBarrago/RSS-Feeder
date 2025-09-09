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
    @Attribute(.externalStorage) var content: String?

    init(title: String, link: String, pubDate: String, feedSourceName: String, feedSourceURL: String, content: String? = nil) {
        self.title = title
        self.link = link
        self.pubDate = pubDate
        self.feedSourceName = feedSourceName
        self.feedSourceURL = feedSourceURL
        self.isRead = false
        self.content = content
    }
}

@Model
final class RSSFeedSource: Identifiable {
    var id: UUID = UUID()
    var name: String
    var url: String
    var lastUpdated: Date?

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

enum FilterOption: Hashable {
    case all
    case unread
    case read
    case feed(RSSFeedSource)

    var rawValue: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .read: return "Read"
        case .feed(let feed): return feed.name
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .unread: return "envelope.badge"
        case .read: return "envelope.open"
        case .feed: return "newspaper"
        }
    }

    static var allCases: [FilterOption] {
        return [.all, .unread, .read]
    }
    
    static func == (lhs: FilterOption, rhs: FilterOption) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.unread, .unread), (.read, .read):
            return true
        case (.feed(let lhsFeed), .feed(let rhsFeed)):
            return lhsFeed.id == rhsFeed.id
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
         switch self {
         case .all:
             hasher.combine(0)
         case .unread:
             hasher.combine(1)
         case .read:
             hasher.combine(2)
         case .feed(let feed):
             hasher.combine(3)
             hasher.combine(feed.id)
         }
     }
}

@Model
final class DeletedArticle {
    @Attribute(.unique) var link: String

    init(link: String) {
        self.link = link
    }
}
