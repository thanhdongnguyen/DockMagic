import AppKit
import Foundation

let duration = Double(CommandLine.arguments.dropFirst().first ?? "30") ?? 30
let end = ProcessInfo.processInfo.systemUptime + duration
var samples: [String] = ["time,x,y"]
while ProcessInfo.processInfo.systemUptime < end {
    let point = NSEvent.mouseLocation
    let time = ProcessInfo.processInfo.systemUptime
    samples.append("\(time),\(point.x),\(point.y)")
    Thread.sleep(forTimeInterval: 0.005)
}
let path = "/private/tmp/dockmagic-shelf-probe/pointer-trace.csv"
try samples.joined(separator: "\n").appending("\n").write(toFile: path, atomically: true, encoding: .utf8)
print("samples=\(samples.count - 1)")
