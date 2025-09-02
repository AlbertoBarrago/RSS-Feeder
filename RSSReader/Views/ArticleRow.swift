//
//  ArticleRow.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftUI
import AppKit

struct ArticleRow: View {
    let item: RSSFeedItem
    let onMarkAsRead: () -> Void
    let onToggleReadStatus: () -> Void

    var body: some View {
        Button(action: {
            onMarkAsRead()
            if let url = URL(string: item.link) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.isRead ? Color.clear : Color.blue)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: item.isRead ? 1 : 0)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(item.isRead ? .regular : .semibold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(item.isRead ? .secondary : .primary)
                        .lineLimit(3)

                    HStack {
                        Label(item.feedSourceName, systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.blue)

                        Spacer()

                        Text(item.pubDate.formatAsRSSDate())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: onToggleReadStatus) {
                    Image(systemName: item.isRead ? "envelope.open" : "envelope.badge")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(item.isRead ? "Mark as Unread" : "Mark as Read")
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
