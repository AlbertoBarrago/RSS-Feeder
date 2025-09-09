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
    @StateObject private var viewModel: ContentViewModel

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            MainContentView(viewModel: viewModel)
        }
        .frame(minWidth: 300, minHeight: 200)
        .sheet(isPresented: $viewModel.showingAddFeed) {
            AddFeedView { url, name in
                viewModel.addFeedSource(url: url, name: name)
            }
        }
        .sheet(isPresented: $viewModel.showingManageFeeds) {
            ManageFeedsView()
        }
        .sheet(item: $viewModel.feedToEdit) { feed in
            EditFeedView(feed: feed) { updatedFeed in
                viewModel.updateFeedSource(updatedFeed)
            }
        }
        .onAppear {
            if viewModel.feedSources.isEmpty {
                viewModel.addDefaultFeeds()
            }
        }
    }
}
