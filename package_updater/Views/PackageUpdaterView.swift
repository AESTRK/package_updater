import AppKit
import SwiftUI

struct PackageUpdaterView: View {
    @EnvironmentObject private var runner: ScriptRunner
    @EnvironmentObject private var matrix: RequirementsMatrixStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AlphaLagoon — Package Updater")
                .font(.title2.bold())

            HStack(spacing: 8) {
                actionButton("Venv audit", mode: "audit")
                actionButton("Mettre à jour matrice (auto)", mode: "audit-apply")
                attachProjectsButton
                actionButton("Sync installateur", mode: "sync-installer", prominent: true)
            }

            matrixToolbar

            HStack(alignment: .top, spacing: 10) {
                matrixEditor
                logPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear {
            runner.setBootstrapMessage("Prêt.\n")
        }
    }

    private var matrixToolbar: some View {
        HStack(spacing: 8) {
            Text("Matrice")
                .font(.headline)
            Spacer()
            Text(matrix.statusMessage)
                .font(.caption)
                .foregroundStyle(matrix.isDirty ? .orange : .secondary)
            Button("Enregistrer") { saveMatrix() }
                .disabled(!matrix.isDirty || runner.isRunning)
            Button("Recharger") { matrix.load() }
                .disabled(runner.isRunning)
            Button("Ouvrir…") { matrix.openInDefaultEditor() }
        }
    }

    private var matrixEditor: some View {
        TextEditor(text: Binding(
            get: { matrix.text },
            set: { newValue in
                matrix.text = newValue
                matrix.textDidChange()
            }
        ))
        .font(.system(.caption, design: .monospaced))
        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(matrix.isDirty ? Color.orange.opacity(0.6) : Color.secondary.opacity(0.3)))
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Journal")
                    .font(.headline)
                Spacer()
                Text(runner.statusMessage)
                    .font(.caption)
                    .foregroundStyle(runner.lastExitCode == 0 ? .green : .primary)
                if runner.isRunning {
                    Button("Annuler") { runner.cancel() }
                }
            }

            AnsiLogView(text: runner.logText, autoScroll: runner.isRunning)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15)))
        }
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var attachProjectsButton: some View {
        Button("Rattacher nouveaux projets…") {
            PackageUpdaterActions.attachNewProjects(runner: runner, matrix: matrix)
        }
        .buttonStyle(.bordered)
        .disabled(runner.isRunning)
    }

    @ViewBuilder
    private func actionButton(_ title: String, mode: String, prominent: Bool = false) -> some View {
        let button = Button(title) {
            runUpdater(mode: mode)
        }
        .disabled(runner.isRunning)

        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func runUpdater(mode: String) {
        PackageUpdaterActions.runUpdater(mode: mode, runner: runner, matrix: matrix)
    }

    @discardableResult
    private func saveMatrix() -> Bool {
        PackageUpdaterActions.saveMatrix(matrix)
    }
}

#Preview {
    PackageUpdaterView()
        .environmentObject(ScriptRunner())
        .environmentObject(RequirementsMatrixStore())
        .frame(width: 1100, height: 640)
}
