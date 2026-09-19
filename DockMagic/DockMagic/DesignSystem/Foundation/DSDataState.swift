import Foundation

/// Presentation only: acquisition, capability and freshness belong to features.
enum DSDataState<Value> {
    case loading
    case available(Value)
    case empty(String)
    case unavailable(String)
    case stale(Value, detail: String)
    case partial(Value, detail: String)
    case failed(String, lastValue: Value?)

    var value: Value? {
        switch self {
        case .available(let value), .stale(let value, _), .partial(let value, _): return value
        case .failed(_, let value): return value
        default: return nil
        }
    }

    var detail: String? {
        switch self {
        case .loading: return "Loading"
        case .available: return nil
        case .empty(let text), .unavailable(let text), .failed(let text, _): return text
        case .stale(_, let text): return "Stale · \(text)"
        case .partial(_, let text): return "Partial · \(text)"
        }
    }

    var isLoading: Bool { if case .loading = self { return true }; return false }
}

struct DSMetricValue: Equatable {
    let formatted: String
    var unit: String? = nil
    var fraction: Double? = nil

    static func percent(_ value: Double?) -> DSDataState<Self> {
        guard let value, value.isFinite else { return .unavailable("Not reported") }
        let normalized = min(max(value, 0), 1)
        return .available(Self(formatted: normalized.formatted(.percent.precision(.fractionLength(0))), fraction: normalized))
    }
}

enum DSProgressValue {
    static func normalized(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }
}
