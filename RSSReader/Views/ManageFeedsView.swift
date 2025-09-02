//
//  ManageFeedsView.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftUI
import SwiftData

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
