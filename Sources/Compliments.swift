import Foundation

enum Compliments {
    static let messages = [
        "You are very well behaved and such a good boy!",
        "You are doing a wonderful job. Good boy!",
        "That was thoughtful work. You are a very good boy!",
        "You are clever, patient, and very well behaved. Good boy!",
        "Excellent work, coding buddy. You are a good boy!",
        "Who is a good boy? Who is a good boy? You are a good boy!"
    ]

    static func random(excluding previous: String?) -> String {
        let choices = messages.filter { $0 != previous }
        return choices.randomElement() ?? messages[0]
    }
}
