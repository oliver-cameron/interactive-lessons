// swift-tools-version: 6.2

import PackageDescription

// Three layers, each allowed to import less than the one after it:
//   LessonModel   Foundation only. The saved lesson format; plain Codable data.
//   LessonEngine  Observation, no SwiftUI. Builds the variable store and resolves names.
//   LessonUI      SwiftUI. Renders a resolved lesson.
let package = Package(
    name: "LessonKit",
    platforms: [.iOS(.v26), .macOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "LessonKit", targets: ["LessonModel", "LessonEngine", "LessonUI"]),
    ],
    targets: [
        .target(name: "LessonModel"),
        .target(name: "LessonEngine", dependencies: ["LessonModel"]),
        .target(name: "LessonUI", dependencies: ["LessonModel", "LessonEngine"]),
        .testTarget(name: "LessonModelTests", dependencies: ["LessonModel"]),
        .testTarget(name: "LessonEngineTests", dependencies: ["LessonModel", "LessonEngine"]),
    ],
    // Matches the app target. Move to Swift 6 once the store settles (design.md section 11).
    swiftLanguageModes: [.v5]
)
