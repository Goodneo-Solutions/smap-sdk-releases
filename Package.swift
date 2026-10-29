// swift-tools-version:5.9
import PackageDescription

// sMap for iOS and macOS, release 1.2.11. Built from the sMap SDK by its release workflow; do not edit by hand.
// - SMap (iOS 14+): the map in a native view (UIKit and SwiftUI).
// - SMapMac (macOS 12+): the map in the system web view running the bundled Web SDK (AppKit and SwiftUI).
// Both re-export SMapCore. Documentation: https://open.superroute.ca/developer/smap
let release = "https://github.com/Goodneo-Solutions/smap-sdk-releases/releases/download/1.2.11"

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
            checksum: "51d0b262a7f490473d256e2df84c40890093335f2830e4e928b617b1cbf19540"
        ),
        .binaryTarget(
            name: "SMap",
            url: "\(release)/SMap.xcframework.zip",
            checksum: "24e1fc61535c443b052f33c1a247bd2fa304de6d6253c1740b6a745d1973d403"
        ),
        .binaryTarget(
            name: "SMapMac",
            url: "\(release)/SMapMac.xcframework.zip",
            checksum: "b42e326f3b6c4c76e065546a2c94f9fe7c783dd650b29b1b6c58ccb632a5bae9"
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
