
import SwiftUI

struct RichArticleRow: View {
    let item: RSSFeedItem
    let onMarkAsRead: () -> Void
    let onToggleReadStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Title and Read/Unread buttons
            HStack(alignment: .top) {
                Circle()
                    .fill(item.isRead ? Color.clear : Color.blue)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: item.isRead ? 1 : 0)
                    )
                    .padding(.top, 5)

                Text(item.title)
                    .font(.headline)
                    .fontWeight(item.isRead ? .regular : .bold)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(item.isRead ? .secondary : .primary)
                
                Spacer()

                Button(action: onToggleReadStatus) {
                    Image(systemName: item.isRead ? "envelope.open" : "envelope.badge")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(item.isRead ? "Mark as Unread" : "Mark as Read")
            }

            // Main Content with Image and Description
            HStack(alignment: .top, spacing: 12) {
                if let imageURL = item.previewImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color(NSColor.controlBackgroundColor)
                            ProgressView()
                        }
                    }
                    .frame(width: 120, height: 80)
                    .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let description = item.itemDescription {
                        Text(description.strippingHTML())
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(4)
                    }
                    
                    Spacer()

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
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            onMarkAsRead()
            if let url = URL(string: item.link) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
