import AppKit

final class PackageUpdaterAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        PackageUpdaterQuickActionsMenu.makeDockMenu(delegate: self)
    }

    @objc func centerMainWindowOnPrimaryScreen() {
        MainWindowCentering.centerMainWindowOnPrimaryScreen()
    }

    @objc func dockRunAudit() {
        guard let runner = PackageUpdaterAppServices.runner,
              let matrix = PackageUpdaterAppServices.matrix else { return }
        PackageUpdaterActions.runUpdater(mode: "audit", runner: runner, matrix: matrix)
    }

    @objc func dockRunAuditApply() {
        guard let runner = PackageUpdaterAppServices.runner,
              let matrix = PackageUpdaterAppServices.matrix else { return }
        PackageUpdaterActions.runUpdater(mode: "audit-apply", runner: runner, matrix: matrix)
    }

    @objc func dockRunSyncInstaller() {
        guard let runner = PackageUpdaterAppServices.runner,
              let matrix = PackageUpdaterAppServices.matrix else { return }
        PackageUpdaterActions.runUpdater(mode: "sync-installer", runner: runner, matrix: matrix)
    }

    @objc func dockCancelRun() {
        PackageUpdaterAppServices.runner?.cancel()
    }
}
