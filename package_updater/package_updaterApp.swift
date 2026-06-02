import SwiftUI

@main
struct PackageUpdaterApp: App {
    var body: some Scene {
        WindowGroup {
            PackageUpdaterView()
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 900, height: 600)
    }
}
