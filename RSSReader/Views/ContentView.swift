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
    @State private var selectedFilter: FilterOption = .all

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

    private var unreadCount: Int {
        allFeedItems.filter { !$0.isRead }.count
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
                VStack(spacing: 8) {
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

                            if case .unread = filter, unreadCount > 0 {
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
                            selectedFilter = .feed(feed)
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
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == .feed(feed) ? Color.blue.opacity(0.8) : Color.clear)
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
            RSSFeedSource(name: "Hacker News", url: "https://hnrss.org/frontpage"),
            RSSFeedSource(name: "TechCrunch", url: "https://techcrunch.com/feed/"),
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
            try modelContext.delete(model: RSSFeedItem.self, where: #Predicate { item in
                item.feedSourceURL == feedURL
            })
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
            try modelContext.delete(model: RSSFeedItem.self, where: #Predicate { $0.isRead })
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
            modelContext.delete(item)
        }

        try? modelContext.save()
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
