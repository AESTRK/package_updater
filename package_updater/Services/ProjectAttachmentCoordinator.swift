import AlphaLagoonPaths
import AppKit
import Foundation

struct ProjectAttachmentProposal: Equatable {
    let project: String
    let packages: [String]
    let referenceProject: String?
}

enum ProjectAttachmentCoordinator {
    static func parseProposals(from url: URL) -> [ProjectAttachmentProposal] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            fputs("[package_updater] Audit TSV illisible (\(url.path)): \(error.localizedDescription)\n", stderr)
            return []
        }
        return parseProposalsTSV(text)
    }

    static func parseProposalsError(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            _ = try String(contentsOf: url, encoding: .utf8)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @MainActor
    static func promptAndAttach(runner: ScriptRunner, matrix: RequirementsMatrixStore) {
        guard PackageUpdaterActions.saveMatrixIfNeeded(matrix) else { return }
        guard !runner.isRunning else { return }

        runner.beginManualOperation(title: "Découverte nouveaux projets…")

        let discoverScript = UpdaterPaths.discoverProjectAttachmentsScript
        var env = ProcessInfo.processInfo.environment
        env["PACKAGE_UPDATER_ROOT"] = UpdaterPaths.repoRoot.path
        env["INSTALLER_ROOT"] = UpdaterPaths.installerRoot.path
        env["REQUIREMENTS_MATRIX"] = matrix.fileURL.path
        env["LOG_BASE_DIR"] = UpdaterPaths.runsLogBase.path
        AlphaLagoonShellEnvironment.applyAlphaLagoonRoots(
            configDataDir: UpdaterPaths.configDataDir,
            suiteRoot: UpdaterPaths.suiteRoot,
            to: &env
        )
        AlphaLagoonShellEnvironment.applyTerminalDefaults(to: &env)
        AlphaLagoonShellEnvironment.ensureHomebrewPath(in: &env)

        let discoverResult = AlphaLagoonShellSyncRunner.run(
            configuration: ShellRunConfiguration(
                script: discoverScript,
                workingDirectory: UpdaterPaths.repoRoot,
                environment: env
            )
        )
        runner.appendToLog(discoverResult.output)
        runner.endManualOperation(
            exitCode: discoverResult.exitCode,
            successMessage: "Découverte terminée",
            failurePrefix: "Découverte échouée"
        )

        guard discoverResult.exitCode == 0 else { return }

        let auditURL = UpdaterPaths.auditMatrixAttachTSV
        if let parseError = parseProposalsError(from: auditURL) {
            presentInfoAlert(
                title: "Audit illisible",
                message: "Le fichier \(auditURL.lastPathComponent) n'a pas pu être lu : \(parseError)"
            )
            return
        }

        let proposals = parseProposals(from: auditURL)
        let venvMissing = parseVenvMissingProjects(from: auditURL)

        if proposals.isEmpty {
            if !venvMissing.isEmpty {
                presentInfoAlert(
                    title: "Venv manquant",
                    message: """
                    Déjà sur la matrice mais sans .venv :
                    \(venvMissing.map { "• \($0)" }.joined(separator: "\n"))

                    Lancez Installateur → Venv install (ou rebuild_all_venvs.sh).
                    « Rattacher » ajoute un projet à la matrice ; il ne crée pas le venv.
                    """
                )
            } else {
                presentInfoAlert(
                    title: "Aucun nouveau projet",
                    message: "Tous les projets Python détectés sont déjà couverts par la matrice."
                )
            }
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

    private static func parseProposalsTSV(_ text: String) -> [ProjectAttachmentProposal] {
        var packagesByProject: [String: [String]] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, parts[0] != "project", !parts[0].isEmpty else { continue }
            if parts.count >= 5, parts[4] == "venv_missing" {
                continue
            }
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

    private static func parseVenvMissingProjects(from url: URL) -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            return []
        }
        var out: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5, parts[4] == "venv_missing", !parts[0].isEmpty, parts[0] != "project" else {
                continue
            }
            if !out.contains(parts[0]) {
                out.append(parts[0])
            }
        }
        return out.sorted()
    }

    private static func referenceProject(for project: String) -> String? {
        guard project.contains("_rsi_") else { return nil }
        return project.replacingOccurrences(of: "_rsi_", with: "_ma_")
    }
}
