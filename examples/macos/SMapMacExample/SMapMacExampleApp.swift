import SwiftUI

@main
struct SMapMacExampleApp: App {
    var body: some Scene {
        WindowGroup("sMap") {
            DemoScreen()
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}
