// swift-tools-version:5.9
import PackageDescription

// sMap for iOS and macOS, release 1.6.9. Built from the sMap SDK by its release workflow; do not edit by hand.
// - SMap (iOS 14+): the map in a native view (UIKit and SwiftUI).
// - SMapMac (macOS 12+): the map in the system web view running the bundled Web SDK (AppKit and SwiftUI).
// Both re-export SMapCore. Documentation: https://open.superroute.ca/developer/smap
let release = "https://github.com/Goodneo-Solutions/smap-sdk-releases/releases/download/1.6.9"

let package = Package(
    name: "SMap",
    platforms: [.iOS(.v14), .macOS(.v12)],
    products: [
        .library(name: "SMap", targets: ["SMapIOS"]),
        .library(name: "SMapMac", targets: ["SMapMacOS"]),
    ],
    dependencies: [
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", exact: "6.31.0"),
        .package(url: "https://github.com/warrenm/GLTFKit2", exact: "0.5.15"),
    ],
    targets: [
        .binaryTarget(
            name: "SMapCore",
            url: "\(release)/SMapCore.xcframework.zip",
            checksum: "b3440b4e95fbed6e034e1d5f2f42c73a0c9ddb15f245eb41ceb0416b5c21f3b3"
        ),
        .binaryTarget(
            name: "SMap",
            url: "\(release)/SMap.xcframework.zip",
            checksum: "066faa6bb7005c9e1c3b67e5ddb71266b387ef1741072c9da75133e5422e8762"
        ),
        .binaryTarget(
            name: "SMapMac",
            url: "\(release)/SMapMac.xcframework.zip",
            checksum: "3522797dcb07f48f8e84bcec323aad4f603c042aad148a88c7a969a5e22c8a08"
        ),
        .target(
            name: "SMapIOS",
            dependencies: [
                .target(name: "SMap", condition: .when(platforms: [.iOS])),
                .target(name: "SMapCore", condition: .when(platforms: [.iOS])),
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution", condition: .when(platforms: [.iOS])),
                .product(name: "GLTFKit2", package: "GLTFKit2", condition: .when(platforms: [.iOS])),
            ],
            path: "Sources/SMapIOS"
        ),
        .target(
            name: "SMapMacOS",
            dependencies: [
                .target(name: "SMapMac", condition: .when(platforms: [.macOS])),
                .target(name: "SMapCore", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/SMapMacOS"
        ),
    ]
)
