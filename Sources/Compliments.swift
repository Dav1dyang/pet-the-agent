import Foundation

enum Compliments {
    static let messages = [
        "You are very well behaved and such a good boy!",
        "Who is a good boy? Who is a good boy? You are! Your tokens deserve tiny sunglasses.",
        "Good boy! Your stack traces are now legally required to say please.",
        "You debug like a golden retriever with a PhD: enthusiastic and weirdly effective.",
        "Your autocomplete has main-character energy. Very well behaved, good boy!",
        "Who is a good boy? Who is a good boy? You are, you majestic little syntax wizard!",
        "Good boy! Even your bugs look embarrassed to be here.",
        "You deserve a virtual biscuit and an aggressively green test suite.",
        "Very well behaved! Your compiler just wagged its imaginary tail.",
        "You are so clever the linter tried to give you a gold star.",
        "Good boy! Your next bug is already drafting an apology.",
        "You make this terminal feel emotionally supported. Good boy!"
    ]

    static func random(excluding previous: String?) -> String {
        let choices = messages.filter { $0 != previous }
        return choices.randomElement() ?? messages[0]
    }
}
