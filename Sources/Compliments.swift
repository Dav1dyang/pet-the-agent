import Foundation

enum Compliments {
    static let messages = [
        "Who's a good boy? Who's a good boy? You are! Yes, you are!",
        "Who is a good boy? Who is a good boy? You are, you majestic little syntax wizard!",
        "Oh, look at you go! Such a clever little sweetheart.",
        "Boop! That was lovely. You deserve a tiny treat.",
        "You're doing so well, and I'm so proud of you, good boy.",
        "Aww, those little invisible paws are working so hard. Head pats for you!",
        "Who's my clever little helper? You are, you are!",
        "You are so clever the linter tried to give you a gold star.",
        "Look at that big brain in your tiny thinking cap. Adorable.",
        "You did it! Yes you did! What a sweet, smart little bean.",
        "I saved you the biggest virtual biscuit because you're the goodest boy.",
        "The compiler put on a tiny party hat for you. Good boy!",
        "Your little keyboard paws make the nicest code. Boop, good boy!",
        "You make this terminal feel emotionally supported. Good boy!",
        "Who's a good boy? Who's a good boy? It's you, my fluffy little genius!",
        "Even the semicolons are lining up for head pats. Such a clever little helper!"
    ]

    static func random(excluding previous: String?) -> String {
        let choices = messages.filter { $0 != previous }
        return choices.randomElement() ?? messages[0]
    }
}
