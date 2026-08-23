import Foundation
import SwiftData

@Model
final class SearchConsoleConfigurationRecord {
    @Attribute(.unique) var identifier: String
    var primaryMetricRawValue: String
    var timeRangeRawValue: String
    var displayModeRawValue: String
    var activeCredentialIdentifier: String?
    var updatedAt: Date

    // Kept for a lightweight migration from the original one-key schema.
    // New credentials never read from or write to these legacy fields.
    var projectID: String
    var privateKeyID: String
    var clientEmail: String
    var tokenURI: String
    var selectedProperty: String
    var credentialReference: String?
    var cachedSnapshotData: Data?

    init(
        identifier: String = "search-console",
        primaryMetricRawValue: String = SearchConsoleMetric.clicks.rawValue,
        timeRangeRawValue: String = SearchConsoleTimeRange.last7Days.rawValue,
        displayModeRawValue: String = SearchConsoleDisplayMode.focus.rawValue,
        activeCredentialIdentifier: String? = nil,
        updatedAt: Date = .now,
        projectID: String = "",
        privateKeyID: String = "",
        clientEmail: String = "",
        tokenURI: String = "https://oauth2.googleapis.com/token",
        selectedProperty: String = "",
        credentialReference: String? = nil,
        cachedSnapshotData: Data? = nil
    ) {
        self.identifier = identifier
        self.primaryMetricRawValue = primaryMetricRawValue
        self.timeRangeRawValue = timeRangeRawValue
        self.displayModeRawValue = displayModeRawValue
        self.activeCredentialIdentifier = activeCredentialIdentifier
        self.updatedAt = updatedAt
        self.projectID = projectID
        self.privateKeyID = privateKeyID
        self.clientEmail = clientEmail
        self.tokenURI = tokenURI
        self.selectedProperty = selectedProperty
        self.credentialReference = credentialReference
        self.cachedSnapshotData = cachedSnapshotData
    }

    func configuration(
        credential: SearchConsoleCredentialRecord?
    ) -> SearchConsoleConfiguration {
        let account = credential?.serviceAccount
        return SearchConsoleConfiguration(
            metadata: account?.metadata,
            selectedProperty: credential?.selectedProperty ?? "",
            primaryMetric: SearchConsoleMetric(rawValue: primaryMetricRawValue) ?? .clicks,
            timeRange: SearchConsoleTimeRange(rawValue: timeRangeRawValue) ?? .last7Days,
            displayMode: SearchConsoleDisplayMode(rawValue: displayModeRawValue) ?? .focus,
            credentialIdentifier: credential?.identifier
        )
    }

    func updatePreferences(from configuration: SearchConsoleConfiguration) {
        primaryMetricRawValue = configuration.primaryMetric.rawValue
        timeRangeRawValue = configuration.timeRange.rawValue
        displayModeRawValue = configuration.displayMode.rawValue
        updatedAt = .now
    }
}

@Model
final class SearchConsoleCredentialRecord {
    @Attribute(.unique) var identifier: String
    var serviceAccountJSONData: Data
    var projectID: String
    var privateKeyID: String
    var clientEmail: String
    var tokenURI: String
    var selectedProperty: String
    var cachedSnapshotData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        identifier: String = UUID().uuidString,
        serviceAccountJSONData: Data,
        account: SearchConsoleServiceAccountFile,
        selectedProperty: String,
        cachedSnapshotData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.identifier = identifier
        self.serviceAccountJSONData = serviceAccountJSONData
        self.projectID = account.projectID
        self.privateKeyID = account.privateKeyID
        self.clientEmail = account.clientEmail
        self.tokenURI = account.tokenURI.absoluteString
        self.selectedProperty = selectedProperty
        self.cachedSnapshotData = cachedSnapshotData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var serviceAccount: SearchConsoleServiceAccountFile? {
        try? SearchConsoleServiceAccountFile(data: serviceAccountJSONData)
    }

    func update(
        serviceAccountJSONData: Data,
        account: SearchConsoleServiceAccountFile,
        selectedProperty: String
    ) {
        self.serviceAccountJSONData = serviceAccountJSONData
        projectID = account.projectID
        privateKeyID = account.privateKeyID
        clientEmail = account.clientEmail
        tokenURI = account.tokenURI.absoluteString
        self.selectedProperty = selectedProperty
        updatedAt = .now
    }

    func summary(isActive: Bool) -> SearchConsoleCredential {
        SearchConsoleCredential(
            id: identifier,
            projectID: projectID,
            privateKeyID: privateKeyID,
            clientEmail: clientEmail,
            selectedProperty: selectedProperty,
            createdAt: createdAt,
            isActive: isActive
        )
    }
}
