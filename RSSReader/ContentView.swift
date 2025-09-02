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
    @State private var currentPage = 0
    @State private var itemsPerPage = 20
    @State private var isLoadingMore = false
    @State private var showingCleanupMenu = false
    
    // Dynamic query based on filter and pagination
    @State private var feedItems: [RSSFeedItem] = []
    @State private var hasMoreItems = true
    
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
    
    var unreadCount: Int {
        // This could be optimized by performing a count query on modelContext
        // instead of filtering the already loaded feedItems array.
        // For now, this works with the current logic.
        getTotalItemsCount(filter: .unread)
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
                                        resetPagination()
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
                                            parser.fetchFeed(from: feed, in: modelContext) {
                                                DispatchQueue.main.async {
                                                    self.resetPagination()
                                                }
                                            }
                                        }
                                        
                                        Button("Edit", systemImage: "pencil") {
                                            // Future edit functionality
                                        }
                                        .disabled(true)
                                        
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
                        Button(action: {
                            showingCleanupMenu = true
                        }) {
                            Image(systemName: "trash")
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Cleanup Options")
                        .popover(isPresented: $showingCleanupMenu) {
                            CleanupMenuView(onCleanRead: {
                                cleanReadItems()
                            }, onCleanOld: {
                                cleanOldItems()
                            }, onCleanAll: {
                                clearAllFeedItems()
                            })
                        }
                        
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
                        
                        if !feedItems.isEmpty {
                            Text("\(getTotalItemsCount()) articles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        if selectedFilter == .all || selectedFilter == .unread {
                            Button(action: {
                                markAllCurrentPageAsRead()
                            }) {
                                Label("Mark All Read", systemImage: "envelope.open")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(feedItems.allSatisfy { $0.isRead })
                        }
                        
                        Menu {
                            Picker("Items per page", selection: $itemsPerPage) {
                                Text("10 items").tag(10)
                                Text("20 items").tag(20)
                                Text("50 items").tag(50)
                                Text("100 items").tag(100)
                            }
                            .onChange(of: itemsPerPage) { _, _ in
                                resetPagination()
                            }
                        } label: {
                            Label("\(itemsPerPage)", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Articles List
                if parser.isLoading && feedItems.isEmpty {
                    VStack(spacing: 0) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading articles...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else if !feedItems.isEmpty {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(feedItems, id: \.id) { item in
                                ArticleRow(item: item, onMarkAsRead: {
                                    markAsRead(item)
                                }, onToggleReadStatus: {
                                    toggleReadStatus(item)
                                })
                                .onAppear {
                                    if item.id == feedItems.last?.id {
                                        loadMoreItems()
                                    }
                                }
                            }
                            .onDelete(perform: deleteItems)
                            
                            // Load More Section
                            if hasMoreItems {
                                LoadMoreView(isLoading: isLoadingMore, onLoadMore: {
                                    loadMoreItems()
                                })
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshAllFeedsAsync()
                        }
                        .onChange(of: selectedFilter) { _, _ in
                            withAnimation {
                                proxy.scrollTo(feedItems.first?.id, anchor: .top)
                            }
                        }
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
                
                // Bottom Status Bar
                if !feedItems.isEmpty {
                    HStack {
                        Text("Showing \(feedItems.count) of \(getTotalItemsCount()) articles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if currentPage > 0 {
                            Button("Back to Top") {
                                resetPagination()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                        
                        if hasMoreItems && !isLoadingMore {
                            Button("Load More") {
                                loadMoreItems()
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor).opacity(0.3))
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
            loadInitialItems()
        }
    }
    
    // MARK: - Helper Functions
    private func getTotalItemsCount(filter: FilterOption? = nil) -> Int {
        let currentFilter = filter ?? selectedFilter
        do {
            var predicate: Predicate<RSSFeedItem>?
            
            switch currentFilter {
            case .all:
                predicate = nil
            case .unread:
                predicate = #Predicate<RSSFeedItem> { !$0.isRead }
            case .read:
                predicate = #Predicate<RSSFeedItem> { $0.isRead }
            }
            
            let fetchDescriptor = FetchDescriptor<RSSFeedItem>(predicate: predicate)
            return try modelContext.fetchCount(fetchDescriptor)
        } catch {
            return 0
        }
    }
    
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
        resetPagination()
    }
    
    // MARK: - Data Management Functions
    private func loadInitialItems() {
        currentPage = 0
        hasMoreItems = true
        feedItems = []
        loadMoreItems()
    }
    
    private func resetPagination() {
        currentPage = 0
        hasMoreItems = true
        feedItems = []
        loadMoreItems()
    }
    
    private func loadMoreItems() {
        guard !isLoadingMore && hasMoreItems else { return }
        
        isLoadingMore = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let offset = currentPage * itemsPerPage
            
            do {
                var predicate: Predicate<RSSFeedItem>?
                
                switch selectedFilter {
                case .all:
                    predicate = nil
                case .unread:
                    predicate = #Predicate<RSSFeedItem> { !$0.isRead }
                case .read:
                    predicate = #Predicate<RSSFeedItem> { $0.isRead }
                }
                
                var fetchDescriptor = FetchDescriptor<RSSFeedItem>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.pubDate, order: .reverse)]
                )
                fetchDescriptor.fetchLimit = itemsPerPage
                fetchDescriptor.fetchOffset = offset
                
                let newItems = try modelContext.fetch(fetchDescriptor)
                
                if !newItems.isEmpty {
                    feedItems.append(contentsOf: newItems)
                    currentPage += 1
                    hasMoreItems = newItems.count == itemsPerPage
                } else {
                    hasMoreItems = false
                }
                
            } catch {
                print("Error loading items: \(error)")
                hasMoreItems = false
            }
            
            isLoadingMore = false
        }
    }
    
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
        
        parser.fetchFeed(from: newFeed, in: modelContext) {
            DispatchQueue.main.async {
                self.resetPagination()
            }
        }
    }
    
    private func refreshAllFeeds() {
        parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
            DispatchQueue.main.async {
                self.resetPagination()
            }
        }
    }
    
    private func refreshAllFeedsAsync() async {
        return await withCheckedContinuation { continuation in
            parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
                DispatchQueue.main.async {
                    self.resetPagination()
                    continuation.resume()
                }
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
    
    private func markAllCurrentPageAsRead() {
        for item in feedItems where !item.isRead {
            item.isRead = true
        }
        try? modelContext.save()
    }
    
    private func cleanReadItems() {
        do {
            try modelContext.delete(model: RSSFeedItem.self, where: #Predicate { $0.isRead })
            try modelContext.save()
            resetPagination()
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
                resetPagination()
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
                modelContext.delete(feedItems[index])
            }
            try? modelContext.save()
            feedItems.remove(atOffsets: offsets)
        }
    }
    
    private func clearAllFeedItems() {
        do {
            try modelContext.delete(model: RSSFeedItem.self)
            try modelContext.save()
            resetPagination()
        } catch {
            print("Error clearing all feed items: \(error)")
        }
    }
}


// MARK: - Nuova Vista per l'Header della Sidebar
struct SidebarHeaderView: View {
    @ObservedObject var parser: RSSParser
    var onAddFeed: () -> Void
    var onManageFeeds: () -> Void
    var onRefreshAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RSS Reader")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                Menu {
                    Button("Add Feed", systemImage: "plus") { onAddFeed() }
                    Button("Manage Feeds", systemImage: "list.bullet") { onManageFeeds() }
                    Divider()
                    Button("Refresh All", systemImage: "arrow.clockwise") { onRefreshAll() }
                        .disabled(parser.isLoading)
                    Divider()
                    Button("Settings", systemImage: "gear") { }
                        .disabled(true)
                    Button("Quit", systemImage: "xmark") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
            .padding([.horizontal, .bottom])
            .padding(.top)
            
            Divider()
        }
        .background(Color(.controlBackgroundColor))
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

struct LoadMoreView: View {
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more articles...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Load More Articles") {
                    onLoadMore()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
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

struct CleanupMenuView: View {
    let onCleanRead: () -> Void
    let onCleanOld: () -> Void
    let onCleanAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cleanup Options")
                .font(.headline)
                .padding(.bottom, 4)
            
            Button("Clean Read Articles", systemImage: "envelope.open") {
                onCleanRead()
            }
            
            Button("Clean Old Articles (30+ days)", systemImage: "calendar") {
                onCleanOld()
            }
            
            Divider()
            
            Button("Clean All Articles", systemImage: "trash", role: .destructive) {
                onCleanAll()
            }
        }
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
