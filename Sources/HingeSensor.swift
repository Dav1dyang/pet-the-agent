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

    init(onAngle: @escaping (Double) -> Void, onError: @escaping (String) -> Void) {
        self.onAngle = onAngle
        self.onError = onError
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            "UsagePage": 0x0020,
            "Usage": 0x008A
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let managerResult = IOHIDManagerOpen(manager, 0)
        guard managerResult == kIOReturnSuccess else {
            error = managerResult == kIOReturnNotPermitted
                ? "Sensor access was denied. Allow Input Monitoring in System Settings, then reopen the app."
                : "Could not open the MacBook sensor manager."
            return
        }
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
        device = candidate
    }

    func start() {
        guard device != nil, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    private func poll() {
        guard let device else { return }
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(bytes.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length)
        guard result == kIOReturnSuccess, length >= 3 else {
            failedReports += 1
            if failedReports >= 90 {
                timer?.invalidate()
                timer = nil
                let message = "The MacBook sensor stopped returning angles. Reopen the app after checking Input Monitoring."
                error = message
                onError(message)
            }
            return
        }
        failedReports = 0
        let angle = Double(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        guard (0...180).contains(angle) else { return }
        onAngle(angle)
    }

    isolated deinit {
        timer?.invalidate()
        if let device { IOHIDDeviceClose(device, 0) }
        IOHIDManagerClose(manager, 0)
    }
}
