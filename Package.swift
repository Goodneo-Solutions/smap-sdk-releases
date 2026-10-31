// swift-tools-version:5.9
import PackageDescription

// sMap for iOS and macOS, release 1.5.8. Built from the sMap SDK by its release workflow; do not edit by hand.
// - SMap (iOS 14+): the map in a native view (UIKit and SwiftUI).
// - SMapMac (macOS 12+): the map in the system web view running the bundled Web SDK (AppKit and SwiftUI).
// Both re-export SMapCore. Documentation: https://open.superroute.ca/developer/smap
let release = "https://github.com/Goodneo-Solutions/smap-sdk-releases/releases/download/1.5.8"

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
            checksum: "d06d9517a27b3230c6f1fcbb8d2487ea3e4df8a10fedabbe648c89f49ace4d8f"
        ),
        .binaryTarget(
            name: "SMap",
            url: "\(release)/SMap.xcframework.zip",
            checksum: "11e491601d01fb7817cdf7d388f465460af3ac832b8123d0bf94c039d5831503"
        ),
        .binaryTarget(
            name: "SMapMac",
            url: "\(release)/SMapMac.xcframework.zip",
            checksum: "3e55e7ce925e5cf4a9a8af8aebb1e8bbd851aba217b88044fb28e6473e1df3be"
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
