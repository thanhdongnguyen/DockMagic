import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

final class BatteryFeatureTests: XCTestCase {
    func testSnapshotNormalizesSortsAndLimitsDockDevices() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = BatteryMetricsSnapshot(
            devices: [
                device("keyboard", "Magic Keyboard", .magicKeyboard, 1.4, now),
                device("mouse", "Magic Mouse", .magicMouse, 0.39, now),
                device("case", "Charging Case", .chargingCase, 0.62, now),
                device("pods", "AirPods Pro", .airPods, 0.81, now),
                device("mac", "MacBook Pro", .macBook, -0.2, now)
            ],
            sampledAt: now
        )

        XCTAssertEqual(
            snapshot.devices.map(\.kind),
            [.macBook, .airPods, .chargingCase, .magicMouse, .magicKeyboard]
        )
        XCTAssertEqual(snapshot.devices.first?.level, 0)
        XCTAssertEqual(snapshot.devices.last?.level, 1)
        XCTAssertEqual(snapshot.dockDevices.count, 4)
        XCTAssertEqual(snapshot.dockDevices.last?.kind, .magicMouse)
    }

    func testAccessoryParserReadsAirPodsAndTransientCase() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let devices = BatteryAccessoryParser().devices(
            from: [
                record(
                    1,
                    [
                        "Product": .string("AirPods Pro"),
                        "DeviceAddress": .string("AA-BB-CC"),
                        "Transport": .string("Bluetooth"),
                        "BatteryPercentLeft": .number(81),
                        "BatteryPercentRight": .number(86),
                        "BatteryPercentCase": .number(62),
                        "IsCharging": .boolean(true)
                    ]
                )
            ],
            observedAt: now
        )

        XCTAssertEqual(devices.count, 2)
        let airPods = try XCTUnwrap(devices.first { $0.kind == .airPods })
        XCTAssertEqual(airPods.name, "AirPods Pro")
        XCTAssertEqual(airPods.level, 0.81, accuracy: 0.0001)
        XCTAssertTrue(airPods.isCharging)

        let chargingCase = try XCTUnwrap(
            devices.first { $0.kind == .chargingCase }
        )
        XCTAssertEqual(chargingCase.level, 0.62, accuracy: 0.0001)
        XCTAssertEqual(chargingCase.detail, "Updated just now")
        XCTAssertEqual(chargingCase.observedAt, now)
    }

    func testAccessoryParserMergesDuplicateRegistryServices() {
        let records = [
            record(
                10,
                [
                    "Product": .string("Magic Mouse"),
                    "DeviceAddress": .string("11:22"),
                    "Transport": .string("Bluetooth"),
                    "BatteryPercent": .number(39)
                ]
            ),
            record(
                11,
                [
                    "Product": .string("Magic Mouse"),
                    "DeviceAddress": .string("11:22"),
                    "Transport": .string("Bluetooth"),
                    "BatteryCharging": .number(0)
                ]
            )
        ]

        let devices = BatteryAccessoryParser().devices(
            from: records,
            observedAt: .now
        )

        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices[0].kind, .magicMouse)
        XCTAssertEqual(devices[0].percentage, 39)
        XCTAssertFalse(devices[0].isCharging)
    }

    func testRegistryRecordToleratesDuplicateNormalizedPropertyNames() {
        let record = BatteryRegistryRecord(
            registryID: 12,
            properties: [
                "Battery Percent": .number(40),
                "BatteryPercent": .number(41),
                "Product": .string("Magic Mouse")
            ]
        )

        XCTAssertTrue(
            [40, 41].contains(
                record.properties["batterypercent"]?.number ?? -1
            )
        )
    }

    func testAccessoryParserRejectsBuiltInAndNonBatteryServices() {
        let devices = BatteryAccessoryParser().devices(
            from: [
                record(
                    20,
                    [
                        "Product": .string("Apple Internal Keyboard / Trackpad"),
                        "Built-In": .boolean(true),
                        "BatteryPercent": .number(100)
                    ]
                ),
                record(
                    21,
                    [
                        "Product": .string("Bluetooth Sensor"),
                        "Transport": .string("Bluetooth")
                    ]
                )
            ],
            observedAt: .now
        )

        XCTAssertTrue(devices.isEmpty)
    }

    func testAccessoryParserClassifiesSupportedConnectedDevices() {
        let fixtures: [(String, BatteryDeviceKind)] = [
            ("Magic Mouse", .magicMouse),
            ("Magic Trackpad", .magicTrackpad),
            ("Magic Keyboard", .magicKeyboard),
            ("Studio Headphones", .headphones),
            ("Game Controller", .accessory)
        ]

        for (index, fixture) in fixtures.enumerated() {
            let devices = BatteryAccessoryParser().devices(
                from: [
                    record(
                        UInt64(100 + index),
                        [
                            "Product": .string(fixture.0),
                            "Transport": .string("Bluetooth"),
                            "BatteryPercent": .number(75)
                        ]
                    )
                ],
                observedAt: .now
            )
            XCTAssertEqual(devices.first?.kind, fixture.1, fixture.0)
        }
    }

    @MainActor
    func testStoreReplacesDevicesAcrossConnectDisconnectReconnect() async {
        let now = Date(timeIntervalSince1970: 3_000)
        let connected = BatteryMetricsSnapshot(
            devices: [device("mouse", "Magic Mouse", .magicMouse, 0.4, now)],
            sampledAt: now
        )
        let disconnected = BatteryMetricsSnapshot(
            devices: [],
            sampledAt: now.addingTimeInterval(1)
        )
        let reconnected = BatteryMetricsSnapshot(
            devices: [
                device(
                    "mouse",
                    "Magic Mouse",
                    .magicMouse,
                    0.38,
                    now.addingTimeInterval(2)
                )
            ],
            sampledAt: now.addingTimeInterval(2)
        )
        let sampler = ScriptedBatterySampler([
            connected,
            disconnected,
            reconnected
        ])
        let store = BatteryMetricsStore(
            sampler: sampler,
            samplingInterval: .seconds(60)
        )

        await store.refresh()
        XCTAssertEqual(store.current.devices.map(\.id), ["mouse"])

        await store.refresh()
        XCTAssertTrue(store.current.devices.isEmpty)

        await store.refresh()
        XCTAssertEqual(store.current.devices.map(\.id), ["mouse"])
        XCTAssertEqual(store.current.devices.first?.percentage, 38)
    }

    @MainActor
    func testMonitoringAutomaticallyRemovesAndRestoresReconnectedDevice() async throws {
        let now = Date(timeIntervalSince1970: 3_500)
        let sampler = ScriptedBatterySampler([
            BatteryMetricsSnapshot(
                devices: [
                    device(
                        "headphones",
                        "Studio Headphones",
                        .headphones,
                        0.72,
                        now
                    )
                ],
                sampledAt: now
            ),
            BatteryMetricsSnapshot(
                devices: [],
                sampledAt: now.addingTimeInterval(1)
            ),
            BatteryMetricsSnapshot(
                devices: [
                    device(
                        "headphones",
                        "Studio Headphones",
                        .headphones,
                        0.70,
                        now.addingTimeInterval(2)
                    )
                ],
                sampledAt: now.addingTimeInterval(2)
            )
        ])
        let store = BatteryMetricsStore(
            sampler: sampler,
            samplingInterval: .milliseconds(120)
        )
        defer { store.stop() }

        store.start()
        try await waitUntil {
            store.current.devices.map(\.id) == ["headphones"]
                && store.current.devices.first?.percentage == 72
        }
        try await waitUntil { store.current.devices.isEmpty }
        try await waitUntil {
            store.current.devices.map(\.id) == ["headphones"]
                && store.current.devices.first?.percentage == 70
        }
        XCTAssertTrue(store.isMonitoring)
    }

    @MainActor
    func testAppModelRunsOnlySelectedBatteryFeature() async throws {
        let suite = "DockMagicTests.Batteries.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let preferences = DockPreferencesStore(defaults: defaults)
        preferences.activeFeature = .batteries
        let store = BatteryMetricsStore(
            sampler: ScriptedBatterySampler([.empty]),
            samplingInterval: .seconds(60)
        )
        let model = DockAppModel(
            preferences: preferences,
            batteryStore: store
        )

        model.start()
        XCTAssertTrue(store.isMonitoring)
        guard case .batteries = model.dockPresentation else {
            XCTFail("Batteries must own the Dock presentation when selected.")
            return
        }

        preferences.activeFeature = .dockMagic
        try await waitUntil { !store.isMonitoring }
        model.stop()
    }

    func testLiveSamplerReturnsUniqueNormalizedDevices() async throws {
        let snapshot = try await BatteryMetricsSampler().sample()
        XCTAssertEqual(Set(snapshot.devices.map(\.id)).count, snapshot.devices.count)
        XCTAssertTrue(snapshot.devices.allSatisfy { (0...1).contains($0.level) })
    }

    @MainActor
    func testDockBatteryTileRendersDynamicOneThroughFourDeviceLayouts() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let fixtures = [
            BatteryDeviceSnapshot(
                id: "mac",
                name: "MacBook Pro",
                kind: .macBook,
                level: 0.74,
                isCharging: true,
                observedAt: now
            ),
            BatteryDeviceSnapshot(
                id: "pods",
                name: "AirPods Pro",
                kind: .airPods,
                level: 0.81,
                observedAt: now
            ),
            BatteryDeviceSnapshot(
                id: "case",
                name: "Charging Case",
                kind: .chargingCase,
                level: 0.62,
                observedAt: now
            ),
            BatteryDeviceSnapshot(
                id: "mouse",
                name: "Magic Mouse",
                kind: .magicMouse,
                level: 0.39,
                observedAt: now
            )
        ]

        var renderedData = Set<Data>()
        for count in 1...4 {
            let data = try renderDockPNG(
                snapshot: BatteryMetricsSnapshot(
                    devices: Array(fixtures.prefix(count)),
                    sampledAt: now
                ),
                side: 64
            )
            XCTAssertGreaterThan(try coloredPixelCount(in: data), 80)
            renderedData.insert(data)
            attachPNG(data, name: "Dock — Batteries — \(count) Devices — 64 pt")
        }

        XCTAssertEqual(
            renderedData.count,
            4,
            "Every device count should produce a distinct Dock layout."
        )
    }

    private func device(
        _ id: String,
        _ name: String,
        _ kind: BatteryDeviceKind,
        _ level: Double,
        _ date: Date
    ) -> BatteryDeviceSnapshot {
        BatteryDeviceSnapshot(
            id: id,
            name: name,
            kind: kind,
            level: level,
            observedAt: date
        )
    }

    private func record(
        _ registryID: UInt64,
        _ properties: [String: BatteryRegistryProperty]
    ) -> BatteryRegistryRecord {
        BatteryRegistryRecord(
            registryID: registryID,
            properties: properties
        )
    }

    @MainActor
    private func renderDockPNG(
        snapshot: BatteryMetricsSnapshot,
        side: CGFloat
    ) throws -> Data {
        try autoreleasepool {
            let content = DockMagicThemeRoot(
                content: DockBatteryView(
                    snapshot: snapshot,
                    errorDescription: nil,
                    animatesChanges: false
                ),
                appearanceMode: .dark
            )
            let hostingView = NSHostingView(rootView: content)
            let size = NSSize(width: side, height: side)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            hostingView.appearance = NSAppearance(named: .darkAqua)
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.contentView = hostingView
            defer {
                window.contentView = nil
                window.close()
            }

            hostingView.wantsLayer = true
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            guard
                let representation = hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            else {
                throw BatteryRenderingError.bitmapAllocationFailed
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
            guard let data = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                throw BatteryRenderingError.pngEncodingFailed
            }
            return data
        }
    }

    private func coloredPixelCount(in data: Data) throws -> Int {
        guard let representation = NSBitmapImageRep(data: data) else {
            throw BatteryRenderingError.bitmapAllocationFailed
        }
        var count = 0
        for x in 0..<representation.pixelsWide {
            for y in 0..<representation.pixelsHigh {
                guard
                    let color = representation.colorAt(x: x, y: y)?
                        .usingColorSpace(.sRGB)
                else {
                    continue
                }
                if color.greenComponent > color.redComponent * 1.25,
                   color.greenComponent > color.blueComponent * 1.15 {
                    count += 1
                }
            }
        }
        return count
    }

    private func attachPNG(_ data: Data, name: String) {
        let attachment = XCTAttachment(
            data: data,
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }
}

private enum BatteryRenderingError: Error {
    case bitmapAllocationFailed
    case pngEncodingFailed
}

private actor ScriptedBatterySampler: BatteryMetricsSampling {
    private var snapshots: [BatteryMetricsSnapshot]
    private var index = 0

    init(_ snapshots: [BatteryMetricsSnapshot]) {
        self.snapshots = snapshots
    }

    func sample() async throws -> BatteryMetricsSnapshot {
        guard !snapshots.isEmpty else {
            return .empty
        }
        let snapshot = snapshots[min(index, snapshots.count - 1)]
        index += 1
        return snapshot
    }
}
