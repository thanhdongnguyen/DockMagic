import AppKit
import AVFoundation
import CoreImage
import Darwin
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

// Records only a narrow strip around the native Dock. The frames are diagnostic
// evidence for visible overlap; no capture code is linked into DockMagic.
final class FrameSink: NSObject, SCStreamOutput {
    private let context = CIContext()
    private let directory: URL
    private var metadata = ["frame,presentationUptime,displayUptime,callbackUptime,callbackLagMs,status"]
    private var eventMetadata = ["event,presentationUptime,displayUptime,callbackUptime,status"]
    private(set) var frames = 0
    private(set) var idle = 0
    private(set) var blank = 0
    private(set) var otherNoImage = 0
    private(set) var failures = 0
    private(set) var maxCallbackLagMs = 0.0
    private var timebase = mach_timebase_info_data_t()

    init(directory: URL) {
        self.directory = directory
        mach_timebase_info(&timebase)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen else { return }
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                   createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]]
        let status = (attachments?.first?[.status] as? Int).flatMap(SCFrameStatus.init(rawValue:))
        let callbackUptime = ProcessInfo.processInfo.systemUptime
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let presentationUptime = sampleTime.isValid ? CMTimeGetSeconds(sampleTime) : -1
        let displayTicks = attachments?.first?[.displayTime] as? UInt64 ?? 0
        let displayUptime = displayTicks > 0
            ? Double(displayTicks) * Double(timebase.numer) /
                Double(timebase.denom) / 1_000_000_000 : -1
        let lagMs = displayUptime >= 0 ? (callbackUptime - displayUptime) * 1000 : -1
        if lagMs >= 0 { maxCallbackLagMs = max(maxCallbackLagMs, lagMs) }
        let statusText = status == .complete ? "complete"
            : status == .idle ? "idle"
            : status == .blank ? "blank" : "other"
        eventMetadata.append(String(format: "%d,%.6f,%.6f,%.6f,%@",
                                    eventMetadata.count - 1, presentationUptime,
                                    displayUptime, callbackUptime, statusText))
        if status == .idle { idle += 1; return }
        if status == .blank { blank += 1; return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            otherNoImage += 1
            return
        }
        guard let image = context.createCGImage(CIImage(cvPixelBuffer: pixelBuffer),
                                                from: CGRect(x: 0, y: 0,
                                                             width: CVPixelBufferGetWidth(pixelBuffer),
                                                             height: CVPixelBufferGetHeight(pixelBuffer))) else {
            failures += 1
            return
        }
        let file = directory.appendingPathComponent(
            String(format: "%05d-%.6f.png", frames, callbackUptime))
        guard let destination = CGImageDestinationCreateWithURL(file as CFURL,
                                                               UTType.png.identifier as CFString,
                                                               1, nil) else {
            failures += 1
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) { failures += 1 }
        metadata.append(String(format: "%d,%.6f,%.6f,%.6f,%.3f,complete",
                               frames, presentationUptime, displayUptime,
                               callbackUptime, lagMs))
        frames += 1
    }

    func writeManifest() throws {
        let url = directory.appendingPathComponent("frame-index.csv")
        try metadata.joined(separator: "\n").appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
        let eventURL = directory.appendingPathComponent("event-index.csv")
        try eventMetadata.joined(separator: "\n").appending("\n")
            .write(to: eventURL, atomically: true, encoding: .utf8)
    }
}

@main
struct DockFrameCapture {
    static func main() async throws {
        let edge = CommandLine.arguments.dropFirst().first ?? "right"
        let duration = Double(CommandLine.arguments.dropFirst(2).first ?? "8") ?? 8
        guard ["left", "right", "bottom"].contains(edge), duration > 0, duration <= 75 else {
            fatalError("Usage: DockFrameCapture <left|right|bottom> <seconds up to 75>")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false,
                                                                           onScreenWindowsOnly: true)
        let targetScreen: NSScreen? = switch edge {
        case "left": NSScreen.screens.min(by: { $0.frame.minX < $1.frame.minX })
        case "right": NSScreen.screens.max(by: { $0.frame.maxX < $1.frame.maxX })
        default: NSScreen.main
        }
        guard let screenID = targetScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let display = content.displays.first(where: { $0.displayID == CGDirectDisplayID(screenID.uint32Value) }) else {
            fatalError("Target display unavailable")
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let width = CGFloat(display.width)
        let height = CGFloat(display.height)
        let source: CGRect
        switch edge {
        case "left":
            source = CGRect(x: 0, y: max(0, height / 2 - 260), width: min(160, width), height: min(520, height))
        case "right":
            source = CGRect(x: max(0, width - 160), y: max(0, height / 2 - 260),
                            width: min(160, width), height: min(520, height))
        default:
            source = CGRect(x: max(0, width / 2 - 360), y: max(0, height - 130),
                            width: min(720, width), height: min(130, height))
        }
        let config = SCStreamConfiguration()
        config.sourceRect = source
        config.width = Int(source.width * CGFloat(filter.pointPixelScale))
        config.height = Int(source.height * CGFloat(filter.pointPixelScale))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 4
        config.showsCursor = false
        config.capturesAudio = false

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let directory = URL(fileURLWithPath: "/private/tmp/dockmagic-shelf-probe/frames-\(edge)-\(stamp)")
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        let sink = FrameSink(directory: directory)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let sampleQueue = DispatchQueue(label: "dockmagic.frame.capture")
        try stream.addStreamOutput(sink, type: .screen,
                                   sampleHandlerQueue: sampleQueue)
        print("ready directory=\(directory.path) display=\(display.displayID) source=\(source) scale=\(filter.pointPixelScale)")
        fflush(stdout)
        try await stream.startCapture()
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        try await stream.stopCapture()
        try sampleQueue.sync { try sink.writeManifest() }
        print("complete frames=\(sink.frames) idle=\(sink.idle) blank=\(sink.blank) otherNoImage=\(sink.otherNoImage) failures=\(sink.failures) maxCallbackLagMs=\(sink.maxCallbackLagMs) directory=\(directory.path)")
    }
}
