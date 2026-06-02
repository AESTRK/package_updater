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

    func run(mode: String, requirementsMatrix: URL? = nil) {
        let matrixURL = requirementsMatrix ?? UpdaterPaths.requirementsMatrixURL
        runUpdater(mode: mode, requirementsMatrix: matrixURL)
    }

    func cancel() {
        process?.terminate()
        statusMessage = "Annulé"
    }

    private func runUpdater(mode: String, requirementsMatrix: URL) {
        let script = UpdaterPaths.packageUpdaterScript
        guard !isRunning else { return }
        guard FileManager.default.isExecutableFile(atPath: script.path) else {
            statusMessage = "Script introuvable : \(script.path)"
            append("ERREUR: \(statusMessage)\n")
            return
        }

        isRunning = true
        lastExitCode = nil
        statusMessage = "En cours : \(mode)…"
        logText = ""

        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let runDir = UpdaterPaths.logRoot.appendingPathComponent("run_\(ts)", isDirectory: true)
        try? FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        let logURL = runDir.appendingPathComponent("\(mode).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        append("=== \(mode) ===\n")
        append("Script: \(script.path)\n")
        append("Matrice: \(requirementsMatrix.path)\n")
        append("Installateur: \(UpdaterPaths.installerRoot.path)\n")
        append("Log fichier: \(logURL.path)\n\n")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path, mode]
        proc.currentDirectoryURL = UpdaterPaths.repoRoot

        var env = ProcessInfo.processInfo.environment
        env["PACKAGE_UPDATER_ROOT"] = UpdaterPaths.repoRoot.path
        env["ALPHA_LAGOON_INSTALLER_ROOT"] = UpdaterPaths.installerRoot.path
        env["REQUIREMENTS_MATRIX"] = requirementsMatrix.path
        proc.environment = env

        let pipe = Pipe()
        outputPipe = pipe
        proc.standardOutput = pipe
        proc.standardError = pipe

        if let handle = try? FileHandle(forWritingTo: logURL) {
            logHandle = handle
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.append(chunk)
            }
        }

        proc.terminationHandler = { [weak self] p in
            let code = p.terminationStatus
            DispatchQueue.main.async { [weak self] in
                self?.pipeFinished(exitCode: code)
            }
        }

        process = proc
        do {
            try proc.run()
        } catch {
            isRunning = false
            statusMessage = "Échec lancement : \(error.localizedDescription)"
            append("\n\(statusMessage)\n")
        }
    }

    private func pipeFinished(exitCode: Int32) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        logHandle?.closeFile()
        logHandle = nil
        process = nil
        isRunning = false
        lastExitCode = exitCode
        statusMessage = exitCode == 0 ? "Terminé (OK)" : "Terminé (code \(exitCode))"
        append("\n--- \(statusMessage) ---\n")
    }

    private func append(_ chunk: String) {
        logText += chunk
        if logText.count > 500_000 {
            logText = String(logText.suffix(400_000))
        }
        if let data = chunk.data(using: .utf8), let logHandle {
            try? logHandle.write(contentsOf: data)
        }
    }
}
