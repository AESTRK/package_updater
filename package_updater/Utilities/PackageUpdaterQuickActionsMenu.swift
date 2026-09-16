import AlphaLagoonAppKit
import AppKit
import SwiftUI

enum PackageUpdaterQuickActionsMenu {
    static let centerOnPrimaryScreenTitle = QuickActionsDockMenuBuilder.centerOnPrimaryScreenTitle

    @ViewBuilder
    static func contextMenuContent(runner: ScriptRunner, matrix: RequirementsMatrixStore) -> some View {
        Section {
            scriptButton("Venv audit", mode: "audit", runner: runner, matrix: matrix)
            scriptButton("Mettre à jour matrice (auto)", mode: "audit-apply", runner: runner, matrix: matrix)
            Button("Rattacher nouveaux projets…") {
                PackageUpdaterActions.attachNewProjects(runner: runner, matrix: matrix)
            }
            .disabled(runner.isRunning)
            scriptButton("Archiver matrice", mode: "archive-matrix", runner: runner, matrix: matrix)

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

        menu.addItem(QuickActionsDockMenuBuilder.item("Venv audit", action: #selector(PackageUpdaterAppDelegate.dockRunAudit), target: delegate, enabled: !running))
        menu.addItem(QuickActionsDockMenuBuilder.item("Mettre à jour matrice (auto)", action: #selector(PackageUpdaterAppDelegate.dockRunAuditApply), target: delegate, enabled: !running))
        menu.addItem(QuickActionsDockMenuBuilder.item("Rattacher nouveaux projets…", action: #selector(PackageUpdaterAppDelegate.dockAttachNewProjects), target: delegate, enabled: !running))
        menu.addItem(QuickActionsDockMenuBuilder.item("Archiver matrice", action: #selector(PackageUpdaterAppDelegate.dockRunArchiveMatrix), target: delegate, enabled: !running))
        if running {
            menu.addItem(QuickActionsDockMenuBuilder.item("Annuler", action: #selector(PackageUpdaterAppDelegate.dockCancelRun), target: delegate))
        }

        menu.addItem(.separator())
        menu.addItem(
            QuickActionsDockMenuBuilder.centerWindowItem(
                target: delegate,
                action: #selector(PackageUpdaterAppDelegate.centerMainWindowOnPrimaryScreen),
                title: centerOnPrimaryScreenTitle
            )
        )

        return menu
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
