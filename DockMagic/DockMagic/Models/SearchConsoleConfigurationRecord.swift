import Foundation
import SwiftData

@Model
final class SearchConsoleConfigurationRecord {
    @Attribute(.unique) var identifier: String
    var projectID: String
    var privateKeyID: String
    var clientEmail: String
    var tokenURI: String
    var selectedProperty: String
    var primaryMetricRawValue: String
    var timeRangeRawValue: String
    var displayModeRawValue: String
    var credentialReference: String?
    var cachedSnapshotData: Data?
    var updatedAt: Date

    init(
        identifier: String = "search-console",
        projectID: String = "",
        privateKeyID: String = "",
        clientEmail: String = "",
        tokenURI: String = "https://oauth2.googleapis.com/token",
        selectedProperty: String = "",
        primaryMetricRawValue: String = SearchConsoleMetric.clicks.rawValue,
        timeRangeRawValue: String = SearchConsoleTimeRange.last7Days.rawValue,
        displayModeRawValue: String = SearchConsoleDisplayMode.focus.rawValue,
        credentialReference: String? = nil,
        cachedSnapshotData: Data? = nil,
        updatedAt: Date = .now
    ) {
        self.identifier = identifier
        self.projectID = projectID
        self.privateKeyID = privateKeyID
        self.clientEmail = clientEmail
        self.tokenURI = tokenURI
        self.selectedProperty = selectedProperty
        self.primaryMetricRawValue = primaryMetricRawValue
        self.timeRangeRawValue = timeRangeRawValue
        self.displayModeRawValue = displayModeRawValue
        self.credentialReference = credentialReference
        self.cachedSnapshotData = cachedSnapshotData
        self.updatedAt = updatedAt
    }

    var configuration: SearchConsoleConfiguration {
        let metadata: SearchConsoleServiceAccountMetadata? = {
            guard !projectID.isEmpty, !privateKeyID.isEmpty,
                  !clientEmail.isEmpty, let tokenURL = URL(string: tokenURI) else {
                return nil
            }
            return SearchConsoleServiceAccountMetadata(
                projectID: projectID,
                privateKeyID: privateKeyID,
                clientEmail: clientEmail,
                tokenURI: tokenURL
            )
        }()

        return SearchConsoleConfiguration(
            metadata: metadata,
            selectedProperty: selectedProperty,
            primaryMetric: SearchConsoleMetric(rawValue: primaryMetricRawValue) ?? .clicks,
            timeRange: SearchConsoleTimeRange(rawValue: timeRangeRawValue) ?? .last7Days,
            displayMode: SearchConsoleDisplayMode(rawValue: displayModeRawValue) ?? .focus,
            credentialReference: credentialReference
        )
    }

    func update(from configuration: SearchConsoleConfiguration) {
        projectID = configuration.metadata?.projectID ?? ""
        privateKeyID = configuration.metadata?.privateKeyID ?? ""
        clientEmail = configuration.metadata?.clientEmail ?? ""
        tokenURI = configuration.metadata?.tokenURI.absoluteString
            ?? "https://oauth2.googleapis.com/token"
        selectedProperty = configuration.selectedProperty
        primaryMetricRawValue = configuration.primaryMetric.rawValue
        timeRangeRawValue = configuration.timeRange.rawValue
        displayModeRawValue = configuration.displayMode.rawValue
        credentialReference = configuration.credentialReference
        updatedAt = .now
    }
}
