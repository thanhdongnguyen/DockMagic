import Foundation
import ImageIO
import UniformTypeIdentifiers

actor NowPlayingArtworkCache {
    private struct Entry { let data: Data?; let date: Date }
    private var entries: [NowPlayingArtworkReference: Entry] = [:]
    private var order: [NowPlayingArtworkReference] = []
    private let fixtureData: Data?
    private let session: URLSession

    init(fixtureData: Data? = nil) {
        self.fixtureData = fixtureData
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func data(for reference: NowPlayingArtworkReference, provider: any NowPlayingProviding) async -> Data? {
        if let entry = entries[reference], entry.data != nil || Date().timeIntervalSince(entry.date) < 60 {
            touch(reference)
            return entry.data
        }
        var raw: Data?
        do {
            switch reference {
            case let .remote(url):
                guard url.scheme == "https" else { throw URLError(.unsupportedURL) }
                let (bytes, response) = try await session.bytes(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      response.url?.scheme == "https", response.expectedContentLength <= 12_000_000 else { throw URLError(.badServerResponse) }
                var collected = Data()
                for try await byte in bytes {
                    if collected.count >= 12_000_000 { throw URLError(.dataLengthExceedsMaximum) }
                    try Task.checkCancellation()
                    collected.append(byte)
                }
                raw = collected
            case .fixture: raw = fixtureData
            case .musicTrack: raw = try await provider.artwork(for: reference)
            }
            try Task.checkCancellation()
        } catch {
            // Failed artwork must not be fetched again on every playback poll.
            // Cancellation belongs to the old selection and must remain retryable.
            guard !Task.isCancelled else { return nil }
            raw = nil
        }
        let data = raw.flatMap(Self.thumbnail)
        entries[reference] = Entry(data: data, date: Date())
        touch(reference)
        while order.count > 8 || entries.values.compactMap(\.data).reduce(0, { $0 + $1.count }) > 16_000_000 {
            entries.removeValue(forKey: order.removeFirst())
        }
        return data
    }

    private func touch(_ reference: NowPlayingArtworkReference) {
        order.removeAll { $0 == reference }
        order.append(reference)
    }

    static func thumbnail(_ data: Data) -> Data? {
        guard data.count <= 12_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 768,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
