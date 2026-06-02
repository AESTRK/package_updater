import SwiftUI

@main
struct PackageUpdaterApp: App {
    @NSApplicationDelegateAdaptor(PackageUpdaterAppDelegate.self) private var appDelegate
    @StateObject private var runner = ScriptRunner()
    @StateObject private var matrix = RequirementsMatrixStore()

    var body: some Scene {
        WindowGroup {
            PackageUpdaterAppRoot(runner: runner, matrix: matrix)
        }
        .defaultSize(width: 900, height: 600)
    }
}

private struct PackageUpdaterAppRoot: View {
    @ObservedObject var runner: ScriptRunner
    @ObservedObject var matrix: RequirementsMatrixStore

    var body: some View {
        PackageUpdaterAppServices.runner = runner
        PackageUpdaterAppServices.matrix = matrix
        return PackageUpdaterView()
            .environmentObject(runner)
            .environmentObject(matrix)
            .frame(minWidth: 720, minHeight: 520)
            .packageUpdaterQuickActionsContextMenu()
    }
}
