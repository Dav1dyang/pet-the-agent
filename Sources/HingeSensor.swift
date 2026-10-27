import Foundation
import IOKit.hid

@MainActor
final class HingeSensor {
    private let manager: IOHIDManager
    private var device: IOHIDDevice?
    private var timer: Timer?
    private let onAngle: (Double) -> Void
    private let onError: (String) -> Void
    private var failedReports = 0
    private(set) var error: String?
    private(set) var resolutionDegrees = 1.0
    private var reportID: CFIndex = 1

    init(onAngle: @escaping (Double) -> Void, onError: @escaping (String) -> Void) {
        self.onAngle = onAngle
        self.onError = onError
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            kIOHIDPrimaryUsagePageKey as String: 0x0020,
            kIOHIDPrimaryUsageKey as String: 0x008A
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let candidate = devices.first(where: {
                  IOHIDDeviceGetProperty($0, kIOHIDProductKey as CFString) as? String == "las"
              }) else {
            error = "This Mac does not expose a readable lid-angle sensor."
            return
        }
        let deviceResult = IOHIDDeviceOpen(candidate, 0)
        guard deviceResult == kIOReturnSuccess else {
            error = deviceResult == kIOReturnNotPermitted
                ? "Sensor access was denied. Allow Input Monitoring in System Settings, then reopen the app."
                : "The lid-angle sensor could not be opened."
            return
        }
        if Self.readAngle(from: candidate, reportID: 7) != nil {
            reportID = 7
            resolutionDegrees = 0.01
        } else if Self.readAngle(from: candidate, reportID: 1) == nil {
            IOHIDDeviceClose(candidate, 0)
            error = "The hinge sensor is present but is not returning angles."
            return
        }
        device = candidate
    }

    func start() {
        guard device != nil, timer == nil else { return }
        let newTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func poll() {
        guard let device else { return }
        guard let angle = Self.readAngle(from: device, reportID: reportID) else {
            failedReports += 1
            if failedReports >= 180 {
                timer?.invalidate()
                timer = nil
                let message = "The MacBook sensor stopped returning angles. Reopen the app after checking Input Monitoring."
                error = message
                onError(message)
            }
            return
        }
        failedReports = 0
        onAngle(angle)
    }

    private static func readAngle(from device: IOHIDDevice, reportID: CFIndex) -> Double? {
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(bytes.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, reportID, &bytes, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        return HingeReportDecoder.degrees(from: Array(bytes.prefix(length)), reportID: Int(reportID))
    }

    isolated deinit {
        timer?.invalidate()
        if let device { IOHIDDeviceClose(device, 0) }
    }
}
