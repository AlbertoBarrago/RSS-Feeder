import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack(spacing: 0) {
            contentHeader
            searchBar
            Divider()
            articlesList
        }
    }

    private var contentHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.selectedFilter.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                if !viewModel.filteredFeedItems.isEmpty {
                    Text("\(viewModel.filteredFeedItems.count) articles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if case .all = viewModel.selectedFilter {
                Button(action: {
                    viewModel.markAllAsRead()
                }) {
                    Label("Mark All Read", systemImage: "envelope.open")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.filteredFeedItems.allSatisfy { $0.isRead })
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search by title", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }

    private var articlesList: some View {
        Group {
            if viewModel.isLoading && viewModel.allFeedItems.isEmpty {
                VStack(spacing: 0) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading articles...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.filteredFeedItems.isEmpty {
                List {
                    ForEach(viewModel.filteredFeedItems, id: \.id) { item in
                        ArticleRow(
                            item: item,
                            onMarkAsRead: {
                                viewModel.markAsRead(item)
                            },
                            onToggleReadStatus: {
                                viewModel.toggleReadStatus(item)
                            })
                    }
                    .onDelete(perform: viewModel.deleteItems)
                }
                .id(viewModel.selectedFilter)
                .listStyle(PlainListStyle())
                .refreshable {
                    viewModel.refreshCurrentFilter()
                }
            } else if viewModel.feedSources.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No RSS Feeds",
                    subtitle: "Add your first RSS feed to get started",
                    actionTitle: "Add Feed",
                    action: {
                        viewModel.showingAddFeed = true
                    }
                )
            } else {
                EmptyStateView(
                    icon: "newspaper",
                    title: "No Articles",
                    subtitle: "Your feeds don't have any articles yet",
                    actionTitle: "Refresh Feeds",
                    action: {
                        viewModel.refreshCurrentFilter()
                    }
                )
            }
        }
    }
}
