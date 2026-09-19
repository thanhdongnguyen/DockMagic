import Foundation

enum GrokBuildObservationStatus: String, Sendable {
    case notConfigured, loading, live, stale, unavailable, failed
}

struct GrokBuildObservation<Value: Equatable & Sendable>: Equatable, Sendable {
    var status: GrokBuildObservationStatus = .notConfigured
    var value: Value?
    var error: GrokBuildError?
    var sourceUpdatedAt: Date?
    var collectedAt: Date?
    var lastAttemptAt: Date?
}

enum GrokBuildConnectionState: Equatable, Sendable {
    case notConfigured, checking, signedOut, connected, unsupportedAuthentication
    case signingIn, signingOut, failed(GrokBuildError)
}

/// An in-memory correlation token, not proof of authentication. A terminal
/// callback must return the exact attempt that created it, even for the same
/// executable/home. It is never persisted or logged.
struct GrokBuildSignInAttempt: Equatable, Sendable {
    let id = UUID()
    let configuration: GrokBuildCLIConfiguration
}

struct GrokBuildLocalCollection: Sendable {
    let cache: GrokBuildHistoryCache
    let snapshot: GrokBuildHistorySnapshot
    let readableRootCount: Int
}

protocol GrokBuildLocalCollecting: Sendable {
    func collect(configuration: GrokBuildCLIConfiguration, cache: GrokBuildHistoryCache,
                 now: Date, calendar: Calendar, force: Bool) async throws -> GrokBuildLocalCollection
}
