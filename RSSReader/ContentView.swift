//
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
    @Query(sort: \RSSFeedItem.pubDate, order: .reverse) private var feedItems: [RSSFeedItem]
    @Query private var feedSources: [RSSFeedSource]
    
    @StateObject private var parser = RSSParser()
    @State private var showingAddFeed = false
    @State private var showingManageFeeds = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Feed Reader")
                    .font(.headline)
                Spacer()
                
                // Manage feeds button
                Button(action: {
                    showingManageFeeds = true
                }) {
                    Image(systemName: "list.bullet")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Add feed button
                Button(action: {
                    showingAddFeed = true
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Refresh button
                Button(action: {
                    refreshAllFeeds()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Content
            if parser.isLoading {
                ProgressView("Loading feeds...")
                    .padding()
            } else if !feedItems.isEmpty {
                List {
                    ForEach(feedItems, id: \.id) { item in
                        Button(action: {
                            if let url = URL(string: item.link) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                HStack {
                                    Text(item.feedSourceName)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text(item.pubDate)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 8)
                    }
                    .onDelete(perform: deleteItems)
                }
            } else if feedSources.isEmpty {
                VStack(spacing: 16) {
                    Text("No RSS feeds added yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add Your First Feed") {
                        showingAddFeed = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                Text("No feed items to display.\nTry refreshing your feeds.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView { url, name in
                addFeedSource(url: url, name: name)
            }
        }
        .sheet(isPresented: $showingManageFeeds) {
            ManageFeedsView()
        }
        .onAppear {
            // Add default feed if no feeds exist
            if feedSources.isEmpty {
                addDefaultFeed()
            }
            refreshAllFeeds()
        }
    }
    
    private func addDefaultFeed() {
        let defaultFeed = RSSFeedSource(
            name: "Apple Newsroom",
            url: "https://www.apple.com/newsroom/rss-feed.rss"
        )
        modelContext.insert(defaultFeed)
        try? modelContext.save()
    }
    
    private func addFeedSource(url: String, name: String) {
        let newFeed = RSSFeedSource(name: name, url: url)
        modelContext.insert(newFeed)
        try? modelContext.save()
        
        // Immediately fetch from the new feed
        parser.fetchFeed(from: newFeed, in: modelContext)
    }
    
    private func refreshAllFeeds() {
        removeDuplicateFeedItems()
        limitFeedItems()
        for feedSource in feedSources {
            parser.fetchFeed(from: feedSource, in: modelContext)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(feedItems[index])
            }
        }
    }

    private func removeDuplicateFeedItems() {
        let fetchDescriptor = FetchDescriptor<RSSFeedItem>()
        do {
            let allItems = try modelContext.fetch(fetchDescriptor)
            let groupedByLink = Dictionary(grouping: allItems, by: { $0.link })
            
            for (_, items) in groupedByLink {
                if items.count > 1 {
                    let sortedItems = items.sorted { $0.pubDate > $1.pubDate }
                    for (index, item) in sortedItems.enumerated() {
                        if index > 0 {
                            modelContext.delete(item)
                        }
                    }
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Error removing duplicate items: \(error)")
        }
    }

    private func limitFeedItems() {
        let fetchDescriptor = FetchDescriptor<RSSFeedSource>()
        do {
            let allFeedSources = try modelContext.fetch(fetchDescriptor)
            for feedSource in allFeedSources {
                let url = feedSource.url
                let fetchDescriptor = FetchDescriptor<RSSFeedItem>(
                    predicate: #Predicate { $0.feedSourceURL == url },
                    sortBy: [SortDescriptor(\.pubDate, order: .reverse)]
                )
                let items = try modelContext.fetch(fetchDescriptor)
                if items.count > 50 {
                    for (index, item) in items.enumerated() {
                        if index >= 50 {
                            modelContext.delete(item)
                        }
                    }
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Error limiting feed items: \(error)")
        }
    }
}

// MARK: - Add Feed View
struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedURL = ""
    @State private var feedName = ""
    @State private var isValidating = false
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
                .disabled(feedURL.isEmpty || feedName.isEmpty || isValidating)
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

// MARK: - RSS Feed Parser
import SwiftData
class RSSParser: NSObject, ObservableObject, XMLParserDelegate {
    @Published var isLoading = false
    
    private var modelContext: ModelContext?
    private var currentFeedSource: RSSFeedSource?
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var parsedItems: [RSSFeedItem] = []

    func fetchFeed(from feedSource: RSSFeedSource, in context: ModelContext) {
        guard let url = URL(string: feedSource.url) else {
            print("Invalid URL: \(feedSource.url)")
            return
        }
        
        self.modelContext = context
        self.currentFeedSource = feedSource
        self.parsedItems = [] // Clear parsed items for new feed
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let parser = XMLParser(contentsOf: url) else {
                print("Failed to create XMLParser from URL: \(url)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            parser.delegate = self
            parser.parse()
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "item" {
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedString.isEmpty { return }

        switch currentElement {
        case "title":
            currentTitle += trimmedString
        case "link":
            currentLink += trimmedString
        case "pubDate":
            currentPubDate += trimmedString
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item",
           let feedSource = currentFeedSource {
            
            let newItem = RSSFeedItem(
                title: currentTitle,
                link: currentLink,
                pubDate: currentPubDate,
                feedSourceName: feedSource.name,
                feedSourceURL: feedSource.url
            )
            parsedItems.append(newItem)
        }
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
            } catch {
                print("Error fetching or saving items: \(error)")
            }
        }
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
    
    init(title: String, link: String, pubDate: String, feedSourceName: String, feedSourceURL: String) {
        self.title = title
        self.link = link
        self.pubDate = pubDate
        self.feedSourceName = feedSourceName
        self.feedSourceURL = feedSourceURL
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
