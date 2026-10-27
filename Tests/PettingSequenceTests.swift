import XCTest
@testable import PetTheAgent

final class PettingSequenceTests: XCTestCase {
    func testOpeningPlaysOneLinePerPetInOrder() {
        var sequence = PettingSequence()
        let lines = (0..<4).map { _ in sequence.next(excluding: nil) }
        XCTAssertEqual(lines, [
            "Who is a good boy?",
            "Who is a good boy?",
            "You are a good boy!",
            "Yes you are!"
        ])
    }

    func testRestartsAfterAQuietBreak() {
        var sequence = PettingSequence()
        _ = sequence.next(excluding: nil)
        _ = sequence.next(excluding: nil)
        sequence.reset()
        XCTAssertEqual(sequence.next(excluding: nil), "Who is a good boy?")
    }

    func testLongPetContinuesWithSweetCompliments() {
        var sequence = PettingSequence()
        for _ in 0..<4 { _ = sequence.next(excluding: nil) }
        let followUp = sequence.next(excluding: nil)
        XCTAssertTrue(Compliments.messages.contains(followUp))
        XCTAssertFalse(followUp.hasPrefix("Who's a good boy?"))
        XCTAssertFalse(followUp.hasPrefix("Who is a good boy?"))
    }
}
