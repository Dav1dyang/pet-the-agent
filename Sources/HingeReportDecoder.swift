import Foundation

enum HingeReportDecoder {
    static func degrees(from bytes: [UInt8], reportID: Int) -> Double? {
        guard bytes.count >= 3, reportID == 7 || reportID == 1 else { return nil }
        let raw = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
        let angle = reportID == 7 ? Double(raw) / 100 : Double(raw & 0x1FF)
        return (0...180).contains(angle) ? angle : nil
    }
}
