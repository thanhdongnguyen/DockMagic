import Foundation

protocol NowPlayingProviding: Sendable {
    var source: NowPlayingSource { get }
    func observe(requestPermission: Bool) async -> NowPlayingObservation
    func perform(_ command: NowPlayingCommand, target: NowPlayingCommandTarget) async throws
    func artwork(for reference: NowPlayingArtworkReference) async throws -> Data?
}

enum NowPlayingProviderError: LocalizedError {
    case appleEvent(Int, String), targetChanged, unavailable
    var errorDescription: String? {
        switch self {
        case let .appleEvent(code, message): "\(message) (\(code))"
        case .targetChanged: "The song changed. Try the control again."
        case .unavailable: "The music app is not available. Open it and try again."
        }
    }
}
