import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
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
        let isSelected = viewModel.selectedFilterIndex == index && viewModel.selectedFeedFilter == nil
        
        return Button(action: {
            viewModel.selectedFilterIndex = index
            viewModel.selectedFeedFilter = nil
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
        if let count = viewModel.getFilterCount(for: filter), count > 0 {
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
                    viewModel.showingAddFeed = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add Feed")
            }
            .padding(.horizontal)

            LazyVStack(spacing: 4) {
                ForEach(viewModel.feedSources, id: \.id) { feed in
                    Button(action: {
                        withAnimation {
                            viewModel.selectedFilterIndex = -1
                            viewModel.selectedFeedFilter = feed
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

                            let count = viewModel.unreadCount(for: feed)
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
                        .background(viewModel.selectedFeedFilter?.id == feed.id ? Color.gray.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            viewModel.feedToEdit = feed
                        }

                        Button("Refresh", systemImage: "arrow.clockwise") {
                            viewModel.refreshCurrentFilter()
                        }

                        Divider()

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.deleteFeed(feed)
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
                        viewModel.cleanReadItems()
                    }

                    Button("Clean Old Articles (30+ days)", systemImage: "calendar") {
                        viewModel.cleanOldItems()
                    }

                    Divider()

                    Button("Clean All Articles", systemImage: "trash", role: .destructive) {
                        viewModel.clearAllFeedItems()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Cleanup Options")

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(action: {
                    viewModel.refreshCurrentFilter()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Refresh All Feeds")
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
