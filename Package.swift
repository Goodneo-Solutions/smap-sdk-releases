// swift-tools-version:5.9
import PackageDescription

// sMap for iOS and macOS, release 1.5.9. Built from the sMap SDK by its release workflow; do not edit by hand.
// - SMap (iOS 14+): the map in a native view (UIKit and SwiftUI).
// - SMapMac (macOS 12+): the map in the system web view running the bundled Web SDK (AppKit and SwiftUI).
// Both re-export SMapCore. Documentation: https://open.superroute.ca/developer/smap
let release = "https://github.com/Goodneo-Solutions/smap-sdk-releases/releases/download/1.5.9"

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
            checksum: "e2fbfd64836044cc4eca4e98db87cfa4b18c90b4d563761916756232bce80d3e"
        ),
        .binaryTarget(
            name: "SMap",
            url: "\(release)/SMap.xcframework.zip",
            checksum: "9a3b14a4cbd8b6f180db70bcaa4cbcc6a4f1b8c1cb2ff764888cdfd05290354d"
        ),
        .binaryTarget(
            name: "SMapMac",
            url: "\(release)/SMapMac.xcframework.zip",
            checksum: "ca468ef7f1b2da189d965ae20b64b7943327d83444d61bb2c444b4aace3158eb"
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
