import SwiftUI

enum CachedAsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
}

/// A wrapper around standard image fetching that utilizes URLCache for robust disk and memory caching.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let scale: CGFloat
    let transaction: Transaction
    let content: (CachedAsyncImagePhase) -> Content

    @State private var phase: CachedAsyncImagePhase = .empty

    init(
        url: URL?,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (CachedAsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    private func load() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                phase = .failure(URLError(.badServerResponse))
                return
            }

            guard let uiImage = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeRawData))
                return
            }

            withAnimation(transaction.animation) {
                phase = .success(Image(uiImage: uiImage))
            }
        } catch {
            phase = .failure(error)
        }
    }
}

// Add extension to support the non-phase init if needed
extension CachedAsyncImage {
    init<I: View, P: View>(
        url: URL?,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(url: url, scale: scale) { phase in
            if case .success(let image) = phase {
                content(image)
            } else {
                placeholder()
            }
        }
    }
}
