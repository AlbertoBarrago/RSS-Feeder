
import SwiftUI

struct CustomAsyncImage: View {
    let url: URL?

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color(NSColor.controlBackgroundColor)
                        ProgressView()
                    }
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color(NSColor.controlBackgroundColor)
                        Image(systemName: "photo.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Image(systemName: "photo.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
    }
}
