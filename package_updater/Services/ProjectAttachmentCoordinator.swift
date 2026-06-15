import AppKit
import Foundation

struct ProjectAttachmentProposal: Equatable {
    let project: String
    let packages: [String]
    let referenceProject: String?
}

enum ProjectAttachmentCoordinator {
    static func parseProposals(from url: URL) -> [ProjectAttachmentProposal] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var packagesByProject: [String: [String]] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, parts[0] != "project", !parts[0].isEmpty else { continue }
            let project = parts[0]
            let package = parts[1]
            var list = packagesByProject[project, default: []]
            if !list.contains(package) {
                list.append(package)
            }
            packagesByProject[project] = list
        }

        return packagesByProject.keys.sorted().map { project in
            ProjectAttachmentProposal(
                project: project,
                packages: packagesByProject[project, default: []].sorted(),
                referenceProject: referenceProject(for: project)
            )
        }
    }

    @MainActor
    static func promptAndAttach(runner: ScriptRunner, matrix: RequirementsMatrixStore) {
        guard PackageUpdaterActions.saveMatrixIfNeeded(matrix) else { return }
        guard !runner.isRunning else { return }

        runner.beginManualOperation(title: "Découverte nouveaux projets…")

        let discoverScript = UpdaterPaths.discoverProjectAttachmentsScript
        let discoverResult = ScriptProcessRunner.run(
            script: discoverScript,
            matrixURL: matrix.fileURL
        )
        runner.appendToLog(discoverResult.output)
        runner.endManualOperation(
            exitCode: discoverResult.exitCode,
            successMessage: "Découverte terminée",
            failurePrefix: "Découverte échouée"
        )

        guard discoverResult.exitCode == 0 else { return }

        let proposals = parseProposals(from: UpdaterPaths.auditMatrixAttachTSV)
        guard !proposals.isEmpty else {
            presentInfoAlert(
                title: "Aucun nouveau projet",
                message: "Tous les projets Python détectés sont déjà couverts par la matrice."
            )
            return
        }

        var approved: [String] = []
        for proposal in proposals {
            if confirmAttach(proposal) {
                approved.append(proposal.project)
            }
        }

        guard !approved.isEmpty else {
            runner.appendToLog("\nAucun rattachement confirmé.\n")
            return
        }

        runner.run(
            mode: "apply-attachments",
            requirementsMatrix: matrix.fileURL,
            extraEnvironment: ["APPROVED_PROJECTS": approved.joined(separator: ",")]
        ) { [weak matrix] code in
            if code == 0 {
                matrix?.load()
            }
        }
    }

    @MainActor
    private static func confirmAttach(_ proposal: ProjectAttachmentProposal) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Rattacher \(proposal.project) ?"
        let packageList = proposal.packages.joined(separator: ", ")
        if let reference = proposal.referenceProject {
            alert.informativeText =
                "Référence : \(reference)\n\(proposal.packages.count) ligne(s) matrice : \(packageList)"
        } else {
            alert.informativeText =
                "\(proposal.packages.count) ligne(s) matrice : \(packageList)"
        }
        alert.addButton(withTitle: "Oui")
        alert.addButton(withTitle: "Non")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    private static func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func referenceProject(for project: String) -> String? {
        guard project.contains("_rsi_") else { return nil }
        return project.replacingOccurrences(of: "_rsi_", with: "_ma_")
    }
}

enum ScriptProcessRunner {
    static func run(script: URL, matrixURL: URL, extraEnvironment: [String: String] = [:]) -> (exitCode: Int32, output: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [script.path]
        proc.currentDirectoryURL = UpdaterPaths.repoRoot

        var env = ProcessInfo.processInfo.environment
        env["PACKAGE_UPDATER_ROOT"] = UpdaterPaths.repoRoot.path
        env["INSTALLER_ROOT"] = UpdaterPaths.installerRoot.path
        env["REQUIREMENTS_MATRIX"] = matrixURL.path
        env["LOG_BASE_DIR"] = UpdaterPaths.runsLogBase.path
        env["ALPHA_LAGOON_ROOT"] = UpdaterPaths.suiteRoot.path
        env["PYTHONUNBUFFERED"] = "1"
        if env["PATH"] == nil || env["PATH"]?.contains("/opt/homebrew/bin") == false {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                + (env["PATH"].map { ":\($0)" } ?? "")
        }
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do {
            try proc.run()
        } catch {
            return (-1, "ERREUR lancement script: \(error.localizedDescription)\n")
        }

        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (proc.terminationStatus, output)
    }
}
