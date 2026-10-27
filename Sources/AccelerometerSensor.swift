import Foundation
import IOKit
import IOKit.hid

private let accelerationReportCallback: IOHIDReportCallback = {
    context, result, _, _, _, report, length in
    guard let context, result == kIOReturnSuccess, length == 22 else { return }
    let sensor = Unmanaged<AccelerometerSensor>.fromOpaque(context).takeUnretainedValue()
    let x = Double(accelInt32LE(report, 6)) / 65536
    let y = Double(accelInt32LE(report, 10)) / 65536
    let z = Double(accelInt32LE(report, 14)) / 65536
    // This device is scheduled on the main run loop below.
    MainActor.assumeIsolated { sensor.receive(x: x, y: y, z: z) }
}

private func accelInt32LE(_ bytes: UnsafeMutablePointer<UInt8>, _ offset: Int) -> Int32 {
    let raw = UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
    return Int32(bitPattern: raw)
}

@MainActor
final class AccelerometerSensor {
    private var service: io_service_t = 0
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var firstReadingTimer: Timer?
    private var reportCounter = 0
    private var baselineMagnitude: Double?
    private let onActivity: (Double, TimeInterval) -> Void
    private let onError: (String) -> Void

    private(set) var deviceFound = false
    private(set) var sampleCount = 0
    private(set) var error: String?

    init(onActivity: @escaping (Double, TimeInterval) -> Void,
         onError: @escaping (String) -> Void) {
        self.onActivity = onActivity
        self.onError = onError

        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else {
            error = "Could not search for a motion sensor."
            return
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            error = "Could not search for a motion sensor."
            return
        }
        defer { IOObjectRelease(iterator) }

        while true {
            let candidate = IOIteratorNext(iterator)
            guard candidate != 0 else { break }
            let page = Self.intProperty(candidate, "PrimaryUsagePage")
            let usage = Self.intProperty(candidate, "PrimaryUsage")
            if page == 0xFF00, usage == 3 {
                service = candidate
                break
            }
            IOObjectRelease(candidate)
        }

        guard service != 0 else {
            error = "No built-in accelerometer was found."
            return
        }
        deviceFound = true

        guard let openedDevice = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            error = "The accelerometer could not be opened."
            return
        }
        let result = IOHIDDeviceOpen(openedDevice, 0)
        guard result == kIOReturnSuccess else {
            error = result == kIOReturnNotPermitted
                ? "macOS blocked accelerometer access. This sensor may require elevated access."
                : "The accelerometer could not be opened."
            return
        }

        device = openedDevice
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        buffer.initialize(repeating: 0, count: 64)
        reportBuffer = buffer
        IOHIDDeviceRegisterInputReportCallback(
            openedDevice, buffer, 64, accelerationReportCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDDeviceScheduleWithRunLoop(openedDevice, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue as CFString)

        let newTimer = Timer(timeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.sampleCount == 0 else { return }
                let message = "Accelerometer found, but it is not sending readings. macOS may restrict this sensor."
                self.error = message
                self.onError(message)
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        firstReadingTimer = newTimer
    }

    fileprivate func receive(x: Double, y: Double, z: Double) {
        reportCounter += 1
        guard reportCounter % 8 == 0 else { return }
        let magnitude = (x * x + y * y + z * z).squareRoot()
        guard magnitude.isFinite, magnitude < 8 else { return }

        let baseline = baselineMagnitude ?? magnitude
        let activity = abs(magnitude - baseline)
        baselineMagnitude = baseline + 0.002 * (magnitude - baseline)
        sampleCount += 1
        if error != nil {
            error = nil
            onError("")
        }
        onActivity(activity, ProcessInfo.processInfo.systemUptime)
    }

    private static func intProperty(_ service: io_service_t, _ key: String) -> Int? {
        let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (value as? NSNumber)?.intValue
    }

    isolated deinit {
        firstReadingTimer?.invalidate()
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue as CFString)
            IOHIDDeviceClose(device, 0)
        }
        reportBuffer?.deallocate()
        if service != 0 { IOObjectRelease(service) }
    }
}
