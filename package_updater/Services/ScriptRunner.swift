import AlphaLagoonPaths
import Combine
import Foundation
import SwiftUI

@MainActor
final class ScriptRunner: ObservableObject {
    @Published private(set) var logText = ""
    @Published private(set) var isRunning = false
    @Published private(set) var lastExitCode: Int32?
    @Published private(set) var statusMessage = "Prêt"

    var statusColor: Color {
        if isRunning { return .primary }
        guard let lastExitCode else { return .secondary }
        return lastExitCode == 0 ? .green : .red
    }

    private let shellRunner = AlphaLagoonShellRunner()
    private var onComplete: ((Int32) -> Void)?

    func run(
        mode: String,
        requirementsMatrix: URL? = nil,
        extraEnvironment: [String: String] = [:],
        onComplete: ((Int32) -> Void)? = nil
    ) {
        self.onComplete = onComplete
        let matrixURL = requirementsMatrix ?? UpdaterPaths.requirementsMatrixURL
        runUpdater(mode: mode, requirementsMatrix: matrixURL, extraEnvironment: extraEnvironment)
    }

    func cancel() {
        shellRunner.cancel()
        statusMessage = "Annulé"
    }

    func setBootstrapMessage(_ message: String) {
        logText = message
        statusMessage = "Prêt"
    }

    func beginManualOperation(title: String) {
        logText = "=== \(title) ===\n\n"
        statusMessage = title
        lastExitCode = nil
    }

    func appendToLog(_ chunk: String) {
        append(chunk)
    }

    func endManualOperation(exitCode: Int32, successMessage: String, failurePrefix: String) {
        lastExitCode = exitCode
        statusMessage = exitCode == 0 ? successMessage : "\(failurePrefix) (code \(exitCode))"
        append("\n--- \(statusMessage) ---\n")
    }

    private func runUpdater(mode: String, requirementsMatrix: URL, extraEnvironment: [String: String] = [:]) {
        let script = UpdaterPaths.script(forMode: mode)
        guard !isRunning else { return }

        guard FileManager.default.fileExists(atPath: script.path) else {
            statusMessage = "Script introuvable"
            append(
                """
                ERREUR: script absent
                Chemin attendu: \(script.path)
                Repo: \(UpdaterPaths.repoRoot.path)

                """
            )
            return
        }

        isRunning = true
        lastExitCode = nil
        statusMessage = "En cours : \(mode)…"
        logText = ""

        let runDate = Date()
        let logURL = UpdaterPaths.logFile(forMode: mode, at: runDate)
        UpdaterPaths.ensureLogsLayout()
        append("=== \(mode) ===\n\n")

        var env = ProcessInfo.processInfo.environment
        env["PACKAGE_UPDATER_ROOT"] = UpdaterPaths.repoRoot.path
        env["PACKAGE_UPDATER_LOG_FILE"] = logURL.path
        env["PACKAGE_UPDATER_LOG_STAMP"] = AlphaLagoonPaths.frenchLogStamp(from: runDate)
        env["PACKAGE_UPDATER_LOG_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        env["INSTALLER_ROOT"] = UpdaterPaths.installerRoot.path
        env["REQUIREMENTS_MATRIX"] = requirementsMatrix.path
        env["LOG_BASE_DIR"] = UpdaterPaths.runsLogBase.path
        AlphaLagoonShellEnvironment.applyAlphaLagoonRoots(
            configDataDir: UpdaterPaths.configDataDir,
            suiteRoot: UpdaterPaths.suiteRoot,
            to: &env
        )
        AlphaLagoonShellEnvironment.applyTerminalDefaults(to: &env)
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        AlphaLagoonShellEnvironment.ensureHomebrewPath(in: &env)

        let config = ShellRunConfiguration(
            script: script,
            workingDirectory: UpdaterPaths.repoRoot,
            environment: env,
            logFile: logURL
        )

        shellRunner.run(
            configuration: config,
            onOutput: { [weak self] chunk in
                self?.append(chunk)
            },
            onComplete: { [weak self] code in
                guard let self else { return }
                self.isRunning = false
                self.lastExitCode = code
                self.statusMessage = code == 0 ? "Terminé (OK)" : "Terminé (code \(code))"
                self.append("\n--- \(self.statusMessage) ---\n")
                self.onComplete?(code)
                self.onComplete = nil
            }
        )
    }

    private func append(_ chunk: String) {
        logText += chunk
        if logText.count > 500_000 {
            logText = String(logText.suffix(400_000))
        }
    }
}
