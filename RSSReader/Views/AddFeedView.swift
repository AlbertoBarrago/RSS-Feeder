//
//  AddFeedView.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftUI

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
                            feedName = feedURL.extractDomainName()
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
        guard feedURL.isValidURL() else {
            errorMessage = "Please enter a valid URL"
            return
        }

        onAdd(feedURL, feedName)
        dismiss()
    }
}
