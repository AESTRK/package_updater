import Combine
import Foundation

@MainActor
final class ScriptRunner: ObservableObject {
    @Published private(set) var logText = ""
    @Published private(set) var isRunning = false
    @Published private(set) var lastExitCode: Int32?
    @Published private(set) var statusMessage = "Prêt"

    private var process: Process?
    private var outputPipe: Pipe?
    private var logHandle: FileHandle?
    private var onComplete: ((Int32) -> Void)?

    func run(mode: String, requirementsMatrix: URL? = nil, onComplete: ((Int32) -> Void)? = nil) {
        self.onComplete = onComplete
        let matrixURL = requirementsMatrix ?? UpdaterPaths.requirementsMatrixURL
        runUpdater(mode: mode, requirementsMatrix: matrixURL)
    }

    func cancel() {
        process?.terminate()
        statusMessage = "Annulé"
    }

    func setBootstrapMessage(_ message: String) {
        logText = message
        statusMessage = "Prêt"
    }

    private func runUpdater(mode: String, requirementsMatrix: URL) {
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
        try? Data().write(to: logURL)

        append("=== \(mode) ===\n\n")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path]
        proc.currentDirectoryURL = UpdaterPaths.repoRoot

        var env = ProcessInfo.processInfo.environment
        env["PACKAGE_UPDATER_ROOT"] = UpdaterPaths.repoRoot.path
        env["PACKAGE_UPDATER_LOG_FILE"] = logURL.path
        env["PACKAGE_UPDATER_LOG_STAMP"] = UpdaterPaths.frenchLogStamp(from: runDate)
        env["PACKAGE_UPDATER_LOG_PID"] = String(ProcessInfo.processInfo.processIdentifier)
        env["INSTALLER_ROOT"] = UpdaterPaths.installerRoot.path
        env["REQUIREMENTS_MATRIX"] = requirementsMatrix.path
        env["LOG_BASE_DIR"] = UpdaterPaths.runsLogBase.path
        env["ALPHA_LAGOON_ROOT"] = UpdaterPaths.suiteRoot.path
        env["PYTHONUNBUFFERED"] = "1"
        env["CLICOLOR_FORCE"] = "1"
        env["TERM"] = "xterm-256color"
        if env["PATH"] == nil || env["PATH"]?.contains("/opt/homebrew/bin") == false {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                + (env["PATH"].map { ":\($0)" } ?? "")
        }
        proc.environment = env

        let pipe = Pipe()
        outputPipe = pipe
        proc.standardOutput = pipe
        proc.standardError = pipe

        if let handle = try? FileHandle(forWritingTo: logURL) {
            logHandle = handle
        }

        let outHandle = pipe.fileHandleForReading
        outHandle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.append(chunk)
            }
        }

        proc.terminationHandler = { [weak self] p in
            let code = p.terminationStatus
            DispatchQueue.main.async { [weak self] in
                self?.pipeFinished(exitCode: code, pipe: pipe)
            }
        }

        process = proc
        do {
            try proc.run()
        } catch {
            isRunning = false
            statusMessage = "Échec lancement : \(error.localizedDescription)"
            append("\n\(statusMessage)\n")
            onComplete?(-1)
            onComplete = nil
        }
    }

    private func pipeFinished(exitCode: Int32, pipe: Pipe) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remaining.isEmpty, let chunk = String(data: remaining, encoding: .utf8) {
            append(chunk)
        }

        logHandle?.closeFile()
        logHandle = nil
        process = nil
        isRunning = false
        lastExitCode = exitCode
        statusMessage = exitCode == 0 ? "Terminé (OK)" : "Terminé (code \(exitCode))"
        append("\n--- \(statusMessage) ---\n")
        onComplete?(exitCode)
        onComplete = nil
    }

    private func append(_ chunk: String) {
        logText += chunk
        if logText.count > 500_000 {
            logText = String(logText.suffix(400_000))
        }
        if let logHandle {
            let plain = AnsiParser.strippingANSICodes(from: chunk)
            if let data = plain.data(using: .utf8) {
                try? logHandle.write(contentsOf: data)
            }
        }
    }
}
