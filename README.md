<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/smap-logo-dark.svg">
  <img src="assets/smap-logo.svg" alt="sMap" height="56">
</picture>

# sMap SDK releases

Published builds of the sMap SDKs for iOS, macOS and Android, and example apps for every platform. Maps from
Superroute's sMap service: five colour schemes, labels in any language, points (clustered or not), lines and areas,
3D buildings, map keys or short-lived tokens.

Documentation: https://open.superroute.ca/developer/smap

Latest release: **1.5.9**

## iOS and macOS (Swift Package Manager)

In Xcode, *File › Add Package Dependencies…* with `https://github.com/Goodneo-Solutions/smap-sdk-releases`, or in
`Package.swift`:

```swift
.package(url: "https://github.com/Goodneo-Solutions/smap-sdk-releases", from: "1.5.9")
// target dependency, iOS 14+:
.product(name: "SMap", package: "smap-sdk-releases")
// target dependency, macOS 12+:
.product(name: "SMapMac", package: "smap-sdk-releases")
```

The SDKs are XCFrameworks with library evolution, attached to each GitHub Release. The package brings the rendering
engine and the glTF reader on iOS as its own dependencies; on macOS the bundled Web SDK is inside `SMapMac.framework`.

## Android (Gradle)

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://goodneo-solutions.github.io/smap-sdk-releases/maven") }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("ca.superroute:smap:1.5.9")
}
```

Android 6.0 (API 23) and later.

## Other platforms

| Platform | Install |
|---|---|
| Web (JavaScript) | `npm install @superrouteca/smap` |
| React | `npm install @superrouteca/smap-react @superrouteca/smap` |
| React Native | `npm install @superrouteca/smap-react-native` |
| Flutter | `smap_flutter: ^1.5.9` in `pubspec.yaml` |
| Windows | `dotnet add package Superroute.SMap.Wpf` or `dotnet add package Superroute.SMap.WinForms` |
| Leaflet, OpenLayers, Mapbox GL JS, deck.gl, ArcGIS, CesiumJS | `npm install @superrouteca/smap-leaflet` (`-openlayers`, `-mapbox`, `-deckgl`, `-arcgis`, `-cesium`) |

## Examples

Each folder under [`examples/`](examples/) is a complete app on the published packages of the latest release:

| Folder | Platform |
|---|---|
| [`examples/android`](examples/android) | Android (`./gradlew :app:assembleDebug -PsmapToken=…`) |
| [`examples/ios`](examples/ios) | iOS (open `SMapExample.xcodeproj`) |
| [`examples/macos`](examples/macos) | macOS (open `SMapMacExample.xcodeproj`) |
| [`examples/flutter`](examples/flutter) | Flutter |
| [`examples/react-native`](examples/react-native) | React Native |
| [`examples/react`](examples/react) | React (Vite) |
| [`examples/windows`](examples/windows) | Windows (WPF and WinForms) |
| [`examples/web`](examples/web) | Web SDK plan editor and the Leaflet, OpenLayers, Mapbox GL JS, deck.gl, ArcGIS and CesiumJS adapters (serve the folder, e.g. `npx serve examples/web/leaflet`) |

## Repository layout

- `Package.swift`, `Sources/`: the Swift package (binary targets on the release assets, and two wrapper targets that
  only re-export them).
- `maven/`: the Maven repository, served by GitHub Pages at https://goodneo-solutions.github.io/smap-sdk-releases/maven.
- `examples/`: the example apps.
- `assets/`: the sMap logos.

This repository is written by the sMap SDK's release workflow; changes made here by hand are replaced at the next
release.

## Licence

Superroute SDK License — see [LICENSE](LICENSE) and [open.superroute.ca/developer/license](https://open.superroute.ca/developer/license). Versions published before the Superroute SDK License keep the licence they were published with.
