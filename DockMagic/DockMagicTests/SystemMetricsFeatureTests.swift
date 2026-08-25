import AppKit
import SwiftUI
import XCTest
@testable import DockMagic

final class SystemMetricsFeatureTests: XCTestCase {
    func testProcessListCalculationTreatsLibprocResultAsPIDCount() {
        let ids = ProcessListCalculation.processIDs(
            in: [11, 22, 33, 44, 0, 0],
            returnedCount: 4
        )

        XCTAssertEqual(ids, [11, 22, 33, 44])
    }

    func testProcessCalculationRanksAndNormalizesAcrossActiveProcessors() {
        let previous = Dictionary(uniqueKeysWithValues: [
            counters(pid: 1, start: 100, name: "Alpha", cpu: 1_000_000_000, memory: 100),
            counters(pid: 2, start: 200, name: "Beta", cpu: 2_000_000_000, memory: 400),
            counters(pid: 3, start: 300, name: "Gamma", cpu: 4_000_000_000, memory: 250)
        ].map { ($0.id, $0) })
        let current = Dictionary(uniqueKeysWithValues: [
            counters(pid: 1, start: 100, name: "Alpha", cpu: 3_000_000_000, memory: 120),
            counters(pid: 2, start: 200, name: "Beta", cpu: 2_800_000_000, memory: 450),
            counters(pid: 3, start: 300, name: "Gamma", cpu: 4_400_000_000, memory: 300)
        ].map { ($0.id, $0) })

        let snapshot = ProcessMetricsCalculation.snapshot(
            previous: previous,
            current: current,
            elapsed: 1,
            activeProcessorCount: 4
        )

        XCTAssertTrue(snapshot.isCPUReady)
        XCTAssertEqual(snapshot.topCPU.map(\.name), ["Alpha", "Beta", "Gamma"])
        XCTAssertEqual(snapshot.topCPU[0].cpuUsage, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.topCPU[1].cpuUsage, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.topMemory.map(\.name), ["Beta", "Gamma", "Alpha"])
        XCTAssertEqual(snapshot.readableProcessCount, 3)
    }

    func testProcessCalculationTreatsPIDReuseAndCounterResetAsNewProcesses() {
        let oldIdentity = counters(
            pid: 42,
            start: 100,
            name: "Old process",
            cpu: 5_000_000_000,
            memory: 500
        )
        let resetIdentity = counters(
            pid: 51,
            start: 200,
            name: "Reset process",
            cpu: 5_000_000_000,
            memory: 300
        )
        let previous = [
            oldIdentity.id: oldIdentity,
            resetIdentity.id: resetIdentity
        ]
        let reusedPID = counters(
            pid: 42,
            start: 999,
            name: "New process",
            cpu: 250_000_000,
            memory: 700
        )
        let resetCounters = counters(
            pid: 51,
            start: 200,
            name: "Reset process",
            cpu: 1_000_000_000,
            memory: 350
        )
        let current = [
            reusedPID.id: reusedPID,
            resetCounters.id: resetCounters
        ]

        let snapshot = ProcessMetricsCalculation.snapshot(
            previous: previous,
            current: current,
            elapsed: 1,
            activeProcessorCount: 8
        )

        XCTAssertTrue(snapshot.isCPUReady)
        XCTAssertTrue(snapshot.topCPU.isEmpty)
        XCTAssertEqual(snapshot.topMemory.map(\.name), ["New process", "Reset process"])
    }

    func testFirstProcessSampleShowsRAMWhileCPUEstablishesBaseline() {
        let process = counters(
            pid: 7,
            start: 700,
            name: "Baseline",
            cpu: 1_000_000,
            memory: 900
        )
        let snapshot = ProcessMetricsCalculation.snapshot(
            previous: nil,
            current: [process.id: process],
            elapsed: 0,
            activeProcessorCount: 4
        )

        XCTAssertFalse(snapshot.isCPUReady)
        XCTAssertTrue(snapshot.topCPU.isEmpty)
        XCTAssertEqual(snapshot.topMemory.first?.name, "Baseline")
    }

    func testProcessSnapshotClampsRowsAndLimitsBothRankings() {
        var rows: [ProcessMetricRow] = []
        for index in 0..<14 {
            let identity = ProcessMetricID(
                processID: Int32(index),
                startTime: UInt64(index)
            )
            let name = index == 0 ? "   " : "Process \(index)"
            let cpuUsage = index == 1 ? Double.infinity : 1.5
            rows.append(ProcessMetricRow(
                id: identity,
                name: name,
                cpuUsage: cpuUsage,
                memoryBytes: UInt64(index)
            ))
        }
        let snapshot = ProcessMetricsSnapshot(
            topCPU: rows,
            topMemory: rows,
            isCPUReady: true,
            readableProcessCount: -1
        )

        XCTAssertEqual(snapshot.topCPU.count, 10)
        XCTAssertEqual(snapshot.topMemory.count, 10)
        XCTAssertEqual(snapshot.topCPU[0].name, "Process 0")
        XCTAssertEqual(snapshot.topCPU[0].cpuUsage, 1)
        XCTAssertEqual(snapshot.topCPU[1].cpuUsage, 0)
        XCTAssertEqual(snapshot.readableProcessCount, 0)
    }

    func testLiveProcessSamplerReadsCurrentHost() async throws {
        let sampler = SystemProcessMetricsSampler()

        let first = try await sampler.sample()
        try await Task.sleep(for: .milliseconds(80))
        let second = try await sampler.sample()

        XCTAssertFalse(first.topMemory.isEmpty)
        XCTAssertFalse(first.isCPUReady)
        XCTAssertTrue(second.isCPUReady)
        XCTAssertFalse(second.topCPU.isEmpty)
        XCTAssertLessThanOrEqual(
            second.topCPU.count,
            ProcessMetricsSnapshot.maximumVisibleProcesses
        )
        XCTAssertGreaterThan(second.readableProcessCount, 0)
    }

    @MainActor
    func testStoreRecordsProcessSnapshotsAndResetsSampler() async throws {
        let processSampler = CountingProcessSampler()
        let store = SystemMetricsStore(
            sampler: SystemMetricsSequenceSampler(),
            processSampler: processSampler,
            samplingInterval: .milliseconds(10),
            historyLimit: 3
        )

        store.start()
        try await waitUntil {
            store.history.count == 3 && store.currentProcesses.isCPUReady
        }

        XCTAssertEqual(store.currentProcesses.topCPU.count, 10)
        XCTAssertTrue(store.isMonitoring)

        store.stop()
        let processCallsAfterStop = await processSampler.callCount
        try await Task.sleep(for: .milliseconds(40))
        let finalProcessCalls = await processSampler.callCount
        let resetCallCount = await processSampler.resetCallCount
        XCTAssertEqual(finalProcessCalls, processCallsAfterStop)
        XCTAssertEqual(resetCallCount, 1)
    }

    @MainActor
    func testSystemMetricsHoverDashboardRendersAppearanceVariants() async throws {
        let suiteName = "DockMagicTests.SystemMetricsHover.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(DockFeature.systemMetrics.rawValue, forKey: DockFeature.storageKey)

        let metricsStore = SystemMetricsStore(
            sampler: SystemMetricsSequenceSampler(),
            processSampler: PreviewProcessSampler()
        )
        for _ in 0..<8 {
            await metricsStore.refresh()
        }
        let appModel = DockAppModel(
            preferences: DockPreferencesStore(defaults: defaults),
            metricsStore: metricsStore
        )

        XCTAssertEqual(
            DockHoverPanelPlacement.panelSize(for: .systemMetrics),
            DockHoverPanelPlacement.systemMetricsPanelSize
        )

        let variants: [(
            String,
            DSAppearanceMode,
            NSAppearance.Name,
            DSAccessibilityOverrides,
            Bool
        )] = [
            ("Dark", .dark, .darkAqua, .init(), false),
            ("Light", .light, .aqua, .init(), false),
            (
                "Increased Contrast",
                .dark,
                .accessibilityHighContrastDarkAqua,
                .init(increaseContrast: true),
                false
            ),
            (
                "Reduced Transparency",
                .dark,
                .darkAqua,
                .init(reduceTransparency: true),
                false
            ),
            ("Grayscale", .dark, .darkAqua, .init(), true)
        ]

        var renderings: [Data] = []
        for (label, mode, appearanceName, overrides, grayscale) in variants {
            var view = AnyView(
                DockHoverDashboardRoot(
                    appModel: appModel,
                    pointerEdge: .bottom,
                    appearanceMode: mode
                )
                .environment(\.dsAccessibilityOverrides, overrides)
            )
            if grayscale {
                view = AnyView(view.grayscale(1))
            }
            let data = try renderPNG(
                view,
                size: DockHoverPanelPlacement.systemMetricsPanelSize,
                appearanceName: appearanceName,
                name: "CPU & RAM Hover — \(label)"
            )
            XCTAssertGreaterThan(data.count, 20_000)
            attachPNG(data, name: "CPU & RAM Hover — \(label)")
            renderings.append(data)
        }

        XCTAssertNotEqual(renderings[0], renderings[1])
        XCTAssertGreaterThanOrEqual(Set(renderings).count, 3)
    }

    private func counters(
        pid: Int32,
        start: UInt64,
        name: String,
        cpu: UInt64,
        memory: UInt64
    ) -> ProcessResourceCounters {
        ProcessResourceCounters(
            id: ProcessMetricID(processID: pid, startTime: start),
            name: name,
            totalCPUTimeNanoseconds: cpu,
            physicalFootprintBytes: memory
        )
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for a system metrics condition.")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    private func renderPNG<Content: View>(
        _ content: Content,
        size: NSSize,
        appearanceName: NSAppearance.Name,
        name: String
    ) throws -> Data {
        try autoreleasepool {
            let hostingView = NSHostingView(rootView: content)
            hostingView.appearance = NSAppearance(named: appearanceName)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: appearanceName)
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.contentView = hostingView
            defer {
                window.contentView = nil
                window.close()
            }

            hostingView.wantsLayer = true
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            guard let representation = hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            ) else {
                throw SystemMetricsRenderingError.bitmapAllocationFailed
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
            guard let data = representation.representation(
                using: .png,
                properties: [:]
            ) else {
                throw SystemMetricsRenderingError.pngEncodingFailed
            }
            return data
        }
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
}

private enum SystemMetricsRenderingError: Error {
    case bitmapAllocationFailed
    case pngEncodingFailed
}

private actor SystemMetricsSequenceSampler: SystemMetricsSampling {
    private var index = 0

    func sample() -> SystemMetricsSnapshot {
        defer { index += 1 }
        let cpu = 0.24 + Double(index % 5) * 0.08
        let memory = 0.52 + Double(index % 3) * 0.025
        return SystemMetricsSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_800_000_000 + Double(index)),
            cpuUsage: cpu,
            memoryUsage: memory,
            memoryUsedBytes: UInt64(memory * 32_000_000_000),
            memoryTotalBytes: 32_000_000_000
        )
    }
}

private actor PreviewProcessSampler: ProcessMetricsSampling {
    func sample() -> ProcessMetricsSnapshot {
        .designPreview
    }
}

actor CountingProcessSampler: ProcessMetricsSampling {
    private(set) var callCount = 0
    private(set) var resetCallCount = 0

    func reset() {
        resetCallCount += 1
    }

    func sample() -> ProcessMetricsSnapshot {
        callCount += 1
        return .designPreview
    }
}
