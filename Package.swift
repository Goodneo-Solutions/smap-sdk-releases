// swift-tools-version:5.9
import PackageDescription

// sMap for iOS and macOS, release 1.2.12. Built from the sMap SDK by its release workflow; do not edit by hand.
// - SMap (iOS 14+): the map in a native view (UIKit and SwiftUI).
// - SMapMac (macOS 12+): the map in the system web view running the bundled Web SDK (AppKit and SwiftUI).
// Both re-export SMapCore. Documentation: https://open.superroute.ca/developer/smap
let release = "https://github.com/Goodneo-Solutions/smap-sdk-releases/releases/download/1.2.12"

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
            checksum: "471e8584108903d179704eb573a61e933242781a40579cb3bcc6849a5842029c"
        ),
        .binaryTarget(
            name: "SMap",
            url: "\(release)/SMap.xcframework.zip",
            checksum: "7b9c33db2262b681b6e2419c75a497f3f9101111070d242c50d90c241feff43d"
        ),
        .binaryTarget(
            name: "SMapMac",
            url: "\(release)/SMapMac.xcframework.zip",
            checksum: "4aca97266fe75fb027b000877e725b6602d72662e4f7e0cd48bdd08ae732fc28"
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
