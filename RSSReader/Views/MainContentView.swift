import SwiftUI

struct MainContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    var style: ArticleListStyle = .simple

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
                Text(style == .rich ? "Desktop View" : viewModel.selectedFilter.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                if !viewModel.filteredFeedItems.isEmpty {
                    Text("\(viewModel.filteredFeedItems.count) articles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            
            if style == .simple { // Only show this button in the popover
                Button(action: openNewWindow) {
                    Image(systemName: "macwindow")
                }
                .help("Open in New Window")
            }

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

    private func openNewWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Main App Window")
        window.contentView = NSHostingView(
            rootView: ContentView(modelContext: viewModel.modelContext, style: .rich)
        )
        window.makeKeyAndOrderFront(nil)
        
        // We also need to make sure the app becomes a standard windowed app
        // when the user does this.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search by title", text: $viewModel.searchText)
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

    @ViewBuilder
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
                if style == .rich {
                    richLayout
                } else {
                    simpleLayout
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
    
    private var simpleLayout: some View {
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
        .listStyle(.inset)
        .refreshable {
            viewModel.refreshCurrentFilter()
        }
    }
    
    private var richLayout: some View {
        let columns = [
            GridItem(.adaptive(minimum: 350, maximum: 500), spacing: 16)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.filteredFeedItems, id: \.id) { item in
                    RichArticleRow(
                        item: item,
                        onMarkAsRead: {
                            viewModel.markAsRead(item)
                        },
                        onToggleReadStatus: {
                            viewModel.toggleReadStatus(item)
                        }
                    )
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 2, x: 0, y: 1)
                }
            }
            .padding()
        }
        .refreshable {
            viewModel.refreshCurrentFilter()
        }
    }
}
