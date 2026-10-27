// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PetTheAgent",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PetTheAgent", targets: ["PetTheAgent"])],
    targets: [
        .executableTarget(name: "PetTheAgent", path: "Sources"),
        .testTarget(name: "PetTheAgentTests", dependencies: ["PetTheAgent"], path: "Tests")
    ]
)
