//  ContentView.swift
//  RSSReader
//
//  Created by Alberto Barrago on 2025.
//

import SwiftUI
import AppKit
import SwiftData
import Foundation

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var feedSources: [RSSFeedSource]
    
    @StateObject private var parser = RSSParser()
    @State private var showingAddFeed = false
    @State private var showingManageFeeds = false
    @State private var selectedFilter = FilterOption.all
    @State private var showingCleanupMenu = false
    
    // Simplified query - no pagination
    @Query(sort: \RSSFeedItem.pubDate, order: .reverse) private var allFeedItems: [RSSFeedItem]
    
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
    
    // Filtered items based on current filter
    private var filteredFeedItems: [RSSFeedItem] {
        switch selectedFilter {
        case .all:
            return allFeedItems
        case .unread:
            return allFeedItems.filter { !$0.isRead }
        case .read:
            return allFeedItems.filter { $0.isRead }
        }
    }
    
    var unreadCount: Int {
        allFeedItems.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Filter Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("FILTERS")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top)
                            
                            VStack(spacing: 5) {
                                ForEach(FilterOption.allCases, id: \.self) { filter in
                                    Button(action: {
                                        selectedFilter = filter
                                    }) {
                                        HStack {
                                            Image(systemName: filter.icon)
                                                .frame(width: 16)
                                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                            
                                            Text(filter.rawValue)
                                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                            
                                            Spacer()
                                            
                                            if filter == .unread && unreadCount > 0 {
                                                Text("\(unreadCount)")
                                                    .font(.caption)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(selectedFilter == filter ? .white.opacity(0.3) : .blue)
                                                    .foregroundColor(selectedFilter == filter ? .white : .white)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(selectedFilter == filter ? .blue : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.top)
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Feeds Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("FEEDS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingAddFeed = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Add Feed")
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 4) {
                                ForEach(feedSources, id: \.id) { feed in
                                    HStack {
                                        Circle()
                                            .fill(.blue.opacity(0.2))
                                            .frame(width: 12, height: 12)
                                            .overlay(
                                                Circle()
                                                    .stroke(.blue, lineWidth: 1)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(feed.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            
                                            Text(extractDomain(from: feed.url))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .contextMenu {
                                        Button("Refresh", systemImage: "arrow.clockwise") {
                                            parser.fetchFeed(from: feed, in: modelContext) { }
                                        }
                                        
                                        Divider()
                                        
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            deleteFeed(feed)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack {
                        Menu {
                            Button("Clean Read Articles", systemImage: "envelope.open") {
                                cleanReadItems()
                            }
                            
                            Button("Clean Old Articles (30+ days)", systemImage: "calendar") {
                                cleanOldItems()
                            }
                            
                            Divider()
                            
                            Button("Clean All Articles", systemImage: "trash", role: .destructive) {
                                clearAllFeedItems()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Cleanup Options")
                        
                        Spacer()
                        
                        if parser.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Button(action: {
                            refreshAllFeeds()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .rotationEffect(.degrees(parser.isLoading ? 360 : 0))
                                .animation(parser.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: parser.isLoading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh All Feeds")
                        .disabled(parser.isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .frame(minWidth: 220, idealWidth: 280, maxWidth: 300)
            .background(Color(.controlBackgroundColor))
            
        } detail: {
            // MARK: - Main Content Area
            VStack(spacing: 0) {
                // Content Header
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(selectedFilter.rawValue)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !filteredFeedItems.isEmpty {
                            Text("\(filteredFeedItems.count) articles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        if selectedFilter == .all || selectedFilter == .unread {
                            Button(action: {
                                markAllAsRead()
                            }) {
                                Label("Mark All Read", systemImage: "envelope.open")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(filteredFeedItems.allSatisfy { $0.isRead })
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Articles List
                if parser.isLoading && allFeedItems.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading articles...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if !filteredFeedItems.isEmpty {
                    List {
                        ForEach(filteredFeedItems, id: \.id) { item in
                            ArticleRow(item: item, onMarkAsRead: {
                                markAsRead(item)
                            }, onToggleReadStatus: {
                                toggleReadStatus(item)
                            })
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshAllFeedsAsync()
                    }
                    
                } else if feedSources.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No RSS Feeds",
                        subtitle: "Add your first RSS feed to get started",
                        actionTitle: "Add Feed",
                        action: {
                            showingAddFeed = true
                        }
                    )
                    
                } else {
                    EmptyStateView(
                        icon: "newspaper",
                        title: "No Articles",
                        subtitle: "Your feeds don't have any articles yet",
                        actionTitle: "Refresh Feeds",
                        action: {
                            refreshAllFeeds()
                        }
                    )
                }
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView { url, name in
                addFeedSource(url: url, name: name)
            }
        }
        .sheet(isPresented: $showingManageFeeds) {
            ManageFeedsView()
        }
        .onAppear {
            if feedSources.isEmpty {
                addDefaultFeeds()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        let components = host.components(separatedBy: ".")
        if components.count > 2 && components[0] == "www" {
            return components.dropFirst().joined(separator: ".")
        }
        return host
    }
    
    private func deleteFeed(_ feed: RSSFeedSource) {
        modelContext.delete(feed)
        try? modelContext.save()
    }
    
    // MARK: - Data Management Functions
    private func addDefaultFeeds() {
        let defaultFeeds = [
            RSSFeedSource(name: "BBC News", url: "http://feeds.bbci.co.uk/news/rss.xml"),
            RSSFeedSource(name: "Hacker News", url: "https://hnrss.org/frontpage"),
            RSSFeedSource(name: "TechCrunch", url: "https://techcrunch.com/feed/")
        ]
        
        for feed in defaultFeeds {
            modelContext.insert(feed)
        }
        try? modelContext.save()
    }
    
    private func addFeedSource(url: String, name: String) {
        let newFeed = RSSFeedSource(name: name, url: url)
        modelContext.insert(newFeed)
        try? modelContext.save()
        
        parser.fetchFeed(from: newFeed, in: modelContext) { }
    }
    
    private func refreshAllFeeds() {
        parser.refreshAllFeeds(sources: feedSources, in: modelContext) { }
    }
    
    private func refreshAllFeedsAsync() async {
        return await withCheckedContinuation { continuation in
            parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
                continuation.resume()
            }
        }
    }
    
    private func markAsRead(_ item: RSSFeedItem) {
        item.isRead = true
        try? modelContext.save()
    }
    
    private func toggleReadStatus(_ item: RSSFeedItem) {
        item.isRead.toggle()
        try? modelContext.save()
    }
    
    private func markAllAsRead() {
        for item in filteredFeedItems where !item.isRead {
            item.isRead = true
        }
        try? modelContext.save()
    }
    
    private func cleanReadItems() {
        do {
            try modelContext.delete(model: RSSFeedItem.self, where: #Predicate { $0.isRead })
            try modelContext.save()
        } catch {
            print("Error cleaning read items: \(error)")
        }
    }
    
    private func cleanOldItems() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let formatter = DateFormatter()
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        do {
            let fetchDescriptor = FetchDescriptor<RSSFeedItem>()
            let allItems = try modelContext.fetch(fetchDescriptor)
            
            var deletedCount = 0
           
            for item in allItems {
                var itemDate: Date?
                
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: item.pubDate) {
                        itemDate = date
                        break
                    }
                }

                if let date = itemDate, date < thirtyDaysAgo {
                    modelContext.delete(item)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                try modelContext.save()
                print("Cleaned \(deletedCount) old items")
            } else {
                print("No old items to clean.")
            }
            
        } catch {
            print("Error cleaning old items: \(error)")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = filteredFeedItems[index]
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
    
    private func clearAllFeedItems() {
        do {
            try modelContext.delete(model: RSSFeedItem.self)
            try modelContext.save()
        } catch {
            print("Error clearing all feed items: \(error)")
        }
    }
}

// MARK: - Supporting Views
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
                        
                        Text(formatDate(item.pubDate))
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
    
    private func formatDate(_ dateString: String) -> String {
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
            if let date = formatter.date(from: dateString) {
                let calendar = Calendar.current
                if calendar.isDateInToday(date) {
                    formatter.dateFormat = "HH:mm"
                    return "Today \(formatter.string(from: date))"
                } else if calendar.isDateInYesterday(date) {
                    formatter.dateFormat = "HH:mm"
                    return "Yesterday \(formatter.string(from: date))"
                } else {
                    formatter.dateFormat = "MMM dd"
                    return formatter.string(from: date)
                }
            }
        }
        
        return dateString
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(actionTitle) {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - RSS Parser and other components (keeping the same logic)

class RSSParser: NSObject, ObservableObject, XMLParserDelegate {
    @Published var isLoading = false
    
    private var modelContext: ModelContext?
    private var currentFeedSource: RSSFeedSource?
    private var completionHandler: (() -> Void)?
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var parsedItems: [RSSFeedItem] = []
    private var isInItem = false

    func fetchFeed(from feedSource: RSSFeedSource, in context: ModelContext, completion: (() -> Void)? = nil) {
        guard let url = URL(string: feedSource.url) else {
            print("Invalid URL: \(feedSource.url)")
            completion?()
            return
        }
        
        self.modelContext = context
        self.currentFeedSource = feedSource
        self.completionHandler = completion
        self.parsedItems = []
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30.0
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.completionHandler?()
                    }
                }
                
                if let error = error {
                    print("Network error for \(feedSource.name): \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received for \(feedSource.name)")
                    return
                }
                
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
            }
            
            task.resume()
        }
    }
    
    func refreshAllFeeds(sources: [RSSFeedSource], in context: ModelContext, completion: @escaping () -> Void) {
        guard !sources.isEmpty else {
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for source in sources {
            group.enter()
            fetchFeed(from: source, in: context) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }

    // XML Parser delegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        
        if currentElement == "item" || currentElement == "entry" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedString.isEmpty { return }

        if isInItem {
            switch currentElement {
            case "title":
                currentTitle += trimmedString
            case "link":
                currentLink += trimmedString
            case "pubdate", "published", "dc:date":
                currentPubDate += trimmedString
            default:
                break
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if (elementName.lowercased() == "item" || elementName.lowercased() == "entry") && isInItem,
           let feedSource = currentFeedSource,
           !currentTitle.isEmpty,
           !currentLink.isEmpty {
            
            let cleanedDate = currentPubDate.replacingOccurrences(of: "+0000", with: "")
                .replacingOccurrences(of: "GMT", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let newItem = RSSFeedItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: cleanedDate.isEmpty ? Date().description : cleanedDate,
                feedSourceName: feedSource.name,
                feedSourceURL: feedSource.url
            )
            parsedItems.append(newItem)
            isInItem = false
        }
        
        currentElement = ""
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        guard let context = modelContext else { return }
        
        DispatchQueue.main.async {
            do {
                let allLinks = self.parsedItems.map { $0.link }
                let fetchDescriptor = FetchDescriptor<RSSFeedItem>(
                    predicate: #Predicate { allLinks.contains($0.link) }
                )
                let existingItems = try context.fetch(fetchDescriptor)
                let existingLinks = Set(existingItems.map { $0.link })
                
                let newItems = self.parsedItems.filter { !existingLinks.contains($0.link) }
                
                for item in newItems {
                    context.insert(item)
                }
                
                try? context.save()
                print("Added \(newItems.count) new items from \(self.currentFeedSource?.name ?? "unknown")")
            } catch {
                print("Error fetching or saving items: \(error)")
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML parsing error: \(parseError.localizedDescription)")
    }
}

// MARK: - Add Feed View
struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedURL = ""
    @State private var feedName = ""
    @State private var errorMessage = ""
    
    let onAdd: (String, String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add RSS Feed")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Feed Name")
                    .font(.headline)
                TextField("e.g., Tech News", text: $feedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Feed URL")
                    .font(.headline)
                TextField("https://example.com/rss", text: $feedURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if feedName.isEmpty {
                            feedName = extractDomainName(from: feedURL)
                        }
                    }
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Feed") {
                    addFeed()
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedURL.isEmpty || feedName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
    
    private func addFeed() {
        guard isValidURL(feedURL) else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        onAdd(feedURL, feedName)
        dismiss()
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme == "http" || url.scheme == "https"
        }
        return false
    }
    
    private func extractDomainName(from urlString: String) -> String {
        guard let url = URL(string: urlString),
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
}

// MARK: - Manage Feeds View
struct ManageFeedsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var feedSources: [RSSFeedSource]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage RSS Feeds")
                .font(.title2)
                .fontWeight(.semibold)
            
            if feedSources.isEmpty {
                Text("No feeds added yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(feedSources, id: \.id) { feedSource in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feedSource.name)
                                    .font(.headline)
                                Text(feedSource.url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button("Delete") {
                                modelContext.delete(feedSource)
                                try? modelContext.save()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Data Models
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
