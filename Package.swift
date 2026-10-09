// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoViet",
    platforms: [.macOS(.v13)],
    targets: [
        // Engine Telex thuần, không phụ thuộc AppKit
        .target(name: "VietEngine"),
        // Ứng dụng menu bar
        .executableTarget(name: "GoViet", dependencies: ["VietEngine"]),
        // Bộ kiểm thử engine (chạy bằng `swift run VietEngineChecks`, không cần XCTest/Xcode)
        .executableTarget(name: "VietEngineChecks", dependencies: ["VietEngine"]),
    ]
)
