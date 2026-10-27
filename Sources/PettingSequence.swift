import Foundation

/// Short lines sent one at a time as petting continues.
struct PettingSequence {
    static let opening = [
        "Who is a good boy?",
        "Who is a good boy?",
        "You are a good boy!",
        "Yes you are!"
    ]

    private var step = 0

    mutating func next(excluding previous: String?) -> String {
        guard step < Self.opening.count else {
            return Compliments.randomFollowUp(excluding: previous)
        }
        defer { step += 1 }
        return Self.opening[step]
    }

    mutating func reset() {
        step = 0
    }
}
