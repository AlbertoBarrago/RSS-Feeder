//
//  RSSParser.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import Foundation
import SwiftData

class RSSParser: NSObject, ObservableObject {
    @Published var isLoading = false

    func fetchFeed(from feedSource: RSSFeedSource, in context: ModelContext, completion: (() -> Void)? = nil) {
        guard let url = URL(string: feedSource.url) else {
            #if DEBUG
            print("Invalid URL: \(feedSource.url)")
            #endif
            completion?()
            return
        }

        #if DEBUG
        print("Starting request for \(feedSource.name) at \(Date())")
        #endif

        self.isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30.0

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion?()
                    }
                }

                if let error = error {
                    print("Network error for \(feedSource.name): \(error.localizedDescription)")
                    return
                }

                #if DEBUG
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code for \(feedSource.name): \(httpResponse.statusCode)")
                    print("Response headers for \(feedSource.name): \(httpResponse.allHeaderFields)")
                }
                #endif

                guard let data = data else {
                    print("No data received for \(feedSource.name)")
                    return
                }

                let parser = XMLParser(data: data)
                let delegate = RSSParserDelegate(feedSource: feedSource, modelContext: context)
                parser.delegate = delegate
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

        DispatchQueue.main.async {
            self.isLoading = true
        }

        let group = DispatchGroup()

        for source in sources {
            group.enter()
            fetchFeed(from: source, in: context) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
            completion()
        }
    }
}

class RSSParserDelegate: NSObject, XMLParserDelegate {
    private var currentFeedSource: RSSFeedSource
    private var modelContext: ModelContext

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var parsedItems: [RSSFeedItem] = []
    private var isInItem = false

    init(feedSource: RSSFeedSource, modelContext: ModelContext) {
        self.currentFeedSource = feedSource
        self.modelContext = modelContext
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
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
            !currentTitle.isEmpty,
            !currentLink.isEmpty
        {

            let cleanedDate = currentPubDate.replacingOccurrences(of: "+0000", with: "")
                .replacingOccurrences(of: "GMT", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let newItem = RSSFeedItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: cleanedDate.isEmpty ? Date().description : cleanedDate,
                feedSourceName: currentFeedSource.name,
                feedSourceURL: currentFeedSource.url
            )
            parsedItems.append(newItem)
            isInItem = false
        }

        currentElement = ""
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        DispatchQueue.main.async {
            do {
                let allLinks = self.parsedItems.map { $0.link }
                let fetchDescriptor = FetchDescriptor<RSSFeedItem>(
                    predicate: #Predicate { allLinks.contains($0.link) }
                )
                let existingItems = try self.modelContext.fetch(fetchDescriptor)
                let existingLinks = Set(existingItems.map { $0.link })

                let newItems = self.parsedItems.filter { !existingLinks.contains($0.link) }

                for item in newItems {
                    self.modelContext.insert(item)
                }

                self.currentFeedSource.lastUpdated = Date()

                try? self.modelContext.save()
                print("Added \(newItems.count) new items from \(self.currentFeedSource.name)")
            } catch {
                print("Error fetching or saving items: \(error)")
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML parsing error: \(parseError.localizedDescription)")
    }
}
