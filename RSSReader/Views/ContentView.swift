//
//  ContentView.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var feedSources: [RSSFeedSource]
    @Query(sort: \RSSFeedItem.pubDate, order: .reverse) private var allFeedItems: [RSSFeedItem]

    @StateObject private var parser = RSSParser()
    @State private var showingAddFeed = false
    @State private var showingManageFeeds = false
    @State private var selectedFilterIndex: Int = 0
    @State private var selectedFeedFilter: RSSFeedSource? = nil

    private var filteredFeedItems: [RSSFeedItem] {
        switch selectedFilter {
        case .all:
            return allFeedItems
        case .unread:
            return allFeedItems.filter { !$0.isRead }
        case .read:
            return allFeedItems.filter { $0.isRead }
        case .feed(let feedSource):
            return allFeedItems.filter { $0.feedSourceURL == feedSource.url }
        }
    }
    
    private func getFilterCount(for filter: FilterOption) -> Int? {
        switch filter {
        case .all:
            return allCount > 0 ? allCount : nil
        case .unread:
            return unreadCount > 0 ? unreadCount : nil
        case .read:
            return readCount > 0 ? readCount : nil
        case .feed:
            return nil
        }
    }
    
    private var selectedFilter: FilterOption {
        if let feedFilter = selectedFeedFilter {
            return .feed(feedFilter)
        }
        return FilterOption.allCases[selectedFilterIndex]
    }
    
    private func isFilterSelected(_ filter: FilterOption) -> Bool {
        switch (selectedFilter, filter) {
        case (.all, .all), (.unread, .unread), (.read, .read):
            return true
        case (.feed(let selectedFeed), .feed(let filterFeed)):
            return selectedFeed.id == filterFeed.id
        default:
            return false
        }
    }

    private var unreadCount: Int {
        allFeedItems.filter { !$0.isRead }.count
    }

    private var readCount: Int {
        allFeedItems.filter { $0.isRead }.count
    }

    private var allCount: Int {
        allFeedItems.count
    }

    private func unreadCount(for feedSource: RSSFeedSource) -> Int {
        allFeedItems.filter { $0.feedSourceURL == feedSource.url && !$0.isRead }.count
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            mainContentView
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

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    filterSection
                    Divider().padding(.vertical)
                    feedsSection
                }
            }

            Spacer()
            bottomControls
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 300)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Main Content View
    private var mainContentView: some View {
        VStack(spacing: 0) {
            contentHeader
            Divider()
            articlesList
        }
    }

    private var contentHeader: some View {
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

            if case .all = selectedFilter {
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
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    private var articlesList: some View {
        Group {
            if parser.isLoading && allFeedItems.isEmpty {
                VStack(spacing: 0) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading articles...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !filteredFeedItems.isEmpty {
                List {
                    ForEach(filteredFeedItems, id: \.id) { item in
                        ArticleRow(
                            item: item,
                            onMarkAsRead: {
                                markAsRead(item)
                            },
                            onToggleReadStatus: {
                                toggleReadStatus(item)
                            })
                    }
                    .onDelete(perform: deleteItems)
                }
                .id(selectedFilter)
                .listStyle(PlainListStyle())
                .refreshable {
                    await refreshCurrentFilter()
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
                        Task {
                            await refreshCurrentFilter()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Sidebar Components
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FILTERS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 5) {
                filterButton(for: .all, index: 0)
                filterButton(for: .unread, index: 1)
                filterButton(for: .read, index: 2)
            }
            .padding(.horizontal, 8)
        }
        .padding(.top)
    }
    
    private func filterButton(for filter: FilterOption, index: Int) -> some View {
        let isSelected = selectedFilterIndex == index && selectedFeedFilter == nil
        
        return Button(action: {
            selectedFilterIndex = index
            selectedFeedFilter = nil
        }) {
            filterButtonContent(filter: filter, isSelected: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func filterButtonContent(filter: FilterOption, isSelected: Bool) -> some View {
        HStack {
            filterButtonIcon(filter: filter, isSelected: isSelected)
            filterButtonText(filter: filter, isSelected: isSelected)
            Spacer()
            filterButtonCounter(filter: filter, isSelected: isSelected)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isSelected ? Color.gray.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func filterButtonIcon(filter: FilterOption, isSelected: Bool) -> some View {
        Image(systemName: filter.icon)
            .frame(width: 16)
            .foregroundColor(.primary)
    }

    private func filterButtonText(filter: FilterOption, isSelected: Bool) -> some View {
        Text(filter.rawValue)
            .foregroundColor(.primary)
    }

    @ViewBuilder
    private func filterButtonCounter(filter: FilterOption, isSelected: Bool) -> some View {
        if let count = getFilterCount(for: filter), count > 0 {
            let shouldShowBlue = (filter == .unread && count > 0)
            
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(shouldShowBlue ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }

    private var feedsSection: some View {
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
                    Button(action: {
                        withAnimation {
                            selectedFilterIndex = -1
                            selectedFeedFilter = feed
                        }
                    }) {
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

                                Text(feed.url.extractDomain())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            let count = unreadCount(for: feed)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFeedFilter?.id == feed.id ? Color.gray.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            parser.isLoading = true
                            parser.fetchFeed(from: feed, in: modelContext) {
                                parser.isLoading = false
                            }
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

    private var bottomControls: some View {
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
                        .controlSize(.small)
                }

                Button(action: {
                    refreshCurrentFilter()
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

    // MARK: - Data Management Functions
    private func addDefaultFeeds() {
        let defaultFeeds = [
            RSSFeedSource(name: "joshwcomeau", url: "https://www.joshwcomeau.com/rss.xml"),
            RSSFeedSource(name: "nytimes-tecnology", url: "https://rss.nytimes.com/services/xml/rss/nyt/Technology.xml"),
            RSSFeedSource(name: "rsshub-science", url: "https://rsshub.app/science/blogs/pipeline"),
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

        parser.fetchFeed(from: newFeed, in: modelContext) {}
    }

    private func deleteFeed(_ feed: RSSFeedSource) {
        let feedURL = feed.url
        do {
            let itemsToDelete = try modelContext.fetch(FetchDescriptor<RSSFeedItem>(predicate: #Predicate { $0.feedSourceURL == feedURL }))
            for item in itemsToDelete {
                let deletedArticle = DeletedArticle(link: item.link)
                modelContext.insert(deletedArticle)
                modelContext.delete(item)
            }
            
            modelContext.delete(feed)
            try modelContext.save()
        } catch {
            print("Error deleting feed and its items: \(error)")
        }
    }

    private func refreshCurrentFilter() {
        switch selectedFilter {
        case .feed(let feedSource):
            parser.isLoading = true
            parser.fetchFeed(from: feedSource, in: modelContext) {
                parser.isLoading = false
            }
        default:
            refreshAllFeeds()
        }
    }

    private func refreshAllFeeds() {
        parser.isLoading = true
        parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
            parser.isLoading = false
        }
    }

    private func refreshAllFeedsAsync() async {
        return await withCheckedContinuation { continuation in
            parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
                continuation.resume()
            }
        }
    }

    private func refreshCurrentFilter() async {
        switch selectedFilter {
        case .feed(let feedSource):
            return await withCheckedContinuation { continuation in
                parser.fetchFeed(from: feedSource, in: modelContext) {
                    continuation.resume()
                }
            }
        default:
            return await refreshAllFeedsAsync()
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
            let readItems = try modelContext.fetch(FetchDescriptor<RSSFeedItem>(predicate: #Predicate { $0.isRead }))
            for item in readItems {
                let deletedArticle = DeletedArticle(link: item.link)
                modelContext.insert(deletedArticle)
                modelContext.delete(item)
            }
            try modelContext.save()
        } catch {
            print("Error cleaning read items: \(error)")
        }
    }

    private func cleanOldItems() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldItems = allFeedItems.filter {
            guard let itemDate = $0.pubDate.toDate() else { return false }
            return itemDate < thirtyDaysAgo
        }

        for item in oldItems {
            let deletedArticle = DeletedArticle(link: item.link)
            modelContext.insert(deletedArticle)
            modelContext.delete(item)
        }

        try? modelContext.save()
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let item = filteredFeedItems[index]
                let deletedArticle = DeletedArticle(link: item.link)
                modelContext.insert(deletedArticle)
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    private func clearAllFeedItems() {
        do {
            let allItems = try modelContext.fetch(FetchDescriptor<RSSFeedItem>())
            for item in allItems {
                let deletedArticle = DeletedArticle(link: item.link)
                modelContext.insert(deletedArticle)
                modelContext.delete(item)
            }
            try modelContext.save()
        } catch {
            print("Error clearing all feed items: \(error)")
        }
    }
}
