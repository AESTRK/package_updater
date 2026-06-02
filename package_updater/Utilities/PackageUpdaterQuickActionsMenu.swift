import AppKit
import SwiftUI

enum PackageUpdaterQuickActionsMenu {
    static let centerOnPrimaryScreenTitle = "Centrer sur l'écran principal"

    @ViewBuilder
    static func contextMenuContent(runner: ScriptRunner, matrix: RequirementsMatrixStore) -> some View {
        Section {
            scriptButton("Venv audit", mode: "audit", runner: runner, matrix: matrix)
            scriptButton("Mettre à jour matrice (auto)", mode: "audit-apply", runner: runner, matrix: matrix)
            scriptButton("Sync installateur", mode: "sync-installer", runner: runner, matrix: matrix)

            if runner.isRunning {
                Button("Annuler") {
                    runner.cancel()
                }
            }
        }

        Divider()

        Button(centerOnPrimaryScreenTitle) {
            MainWindowCentering.centerMainWindowOnPrimaryScreen()
        }
    }

    @ViewBuilder
    private static func scriptButton(
        _ label: String,
        mode: String,
        runner: ScriptRunner,
        matrix: RequirementsMatrixStore
    ) -> some View {
        Button(label) {
            PackageUpdaterActions.runUpdater(mode: mode, runner: runner, matrix: matrix)
        }
        .disabled(runner.isRunning)
    }

    @MainActor
    static func makeDockMenu(delegate: PackageUpdaterAppDelegate) -> NSMenu {
        let menu = NSMenu()
        let running = PackageUpdaterAppServices.runner?.isRunning ?? false

        menu.addItem(item("Venv audit", action: #selector(PackageUpdaterAppDelegate.dockRunAudit), target: delegate, enabled: !running))
        menu.addItem(item("Mettre à jour matrice (auto)", action: #selector(PackageUpdaterAppDelegate.dockRunAuditApply), target: delegate, enabled: !running))
        menu.addItem(item("Sync installateur", action: #selector(PackageUpdaterAppDelegate.dockRunSyncInstaller), target: delegate, enabled: !running))
        if running {
            menu.addItem(item("Annuler", action: #selector(PackageUpdaterAppDelegate.dockCancelRun), target: delegate))
        }

        menu.addItem(.separator())
        menu.addItem(
            item(
                centerOnPrimaryScreenTitle,
                action: #selector(PackageUpdaterAppDelegate.centerMainWindowOnPrimaryScreen),
                target: delegate
            )
        )

        return menu
    }

    private static func item(
        _ title: String,
        action: Selector,
        target: AnyObject,
        enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.isEnabled = enabled
        return item
    }
}

extension View {
    func packageUpdaterQuickActionsContextMenu() -> some View {
        modifier(PackageUpdaterQuickActionsContextMenuModifier())
    }
}

private struct PackageUpdaterQuickActionsContextMenuModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.contextMenu {
            if let runner = PackageUpdaterAppServices.runner,
               let matrix = PackageUpdaterAppServices.matrix {
                PackageUpdaterQuickActionsMenu.contextMenuContent(runner: runner, matrix: matrix)
            } else {
                Button(PackageUpdaterQuickActionsMenu.centerOnPrimaryScreenTitle) {
                    MainWindowCentering.centerMainWindowOnPrimaryScreen()
                }
            }
        }
    }
}
