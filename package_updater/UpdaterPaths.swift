import Foundation

enum UpdaterPaths {
    static let projectName = "package_updater"
    static let matrixFileName = "package_updater_latest_matrix.txt"

    static let repoRoot: URL = {
        let env = ProcessInfo.processInfo.environment["PACKAGE_UPDATER_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        let dev = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("XcodeProjects/package_updater", isDirectory: true)
        if FileManager.default.fileExists(atPath: dev.path) {
            return dev
        }
        return Bundle.main.bundleURL.deletingLastPathComponent()
    }()

    static let suiteRoot: URL = {
        let env = ProcessInfo.processInfo.environment["ALPHA_LAGOON_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/AlphaLagoon", isDirectory: true)
    }()

    static var xcodeProjectsLogRoot: URL {
        suiteRoot.appendingPathComponent("_logs_XcodeProjects", isDirectory: true)
    }

    static var requirementsMatrixURL: URL {
        if let env = ProcessInfo.processInfo.environment["REQUIREMENTS_MATRIX"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return repoRoot.appendingPathComponent(matrixFileName)
    }

    static var matrixHistoryDirectory: URL {
        repoRoot.appendingPathComponent("history", isDirectory: true)
    }

    static var scriptsDirectory: URL {
        repoRoot.appendingPathComponent("scripts", isDirectory: true)
    }

    static var venvAuditScript: URL {
        scriptsDirectory.appendingPathComponent("venv-audit.sh")
    }

    static var updateMatrixAutoScript: URL {
        scriptsDirectory.appendingPathComponent("update-matrix-auto.sh")
    }

    static var syncInstallerScript: URL {
        scriptsDirectory.appendingPathComponent("sync-installer.sh")
    }

    static var discoverProjectAttachmentsScript: URL {
        scriptsDirectory.appendingPathComponent("discover-project-attachments.sh")
    }

    static var applyProjectAttachmentsScript: URL {
        scriptsDirectory.appendingPathComponent("apply-project-attachments.sh")
    }

    static func script(forMode mode: String) -> URL {
        switch mode {
        case "audit":
            return venvAuditScript
        case "audit-apply":
            return updateMatrixAutoScript
        case "sync-installer":
            return syncInstallerScript
        case "apply-attachments":
            return applyProjectAttachmentsScript
        default:
            return venvAuditScript
        }
    }

    static var installerRoot: URL = {
        let env = ProcessInfo.processInfo.environment["INSTALLER_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("XcodeProjects/installer", isDirectory: true)
    }()

    static var installerMatrixURL: URL {
        installerRoot.appendingPathComponent(matrixFileName)
    }

    static var runsLogBase: URL {
        xcodeProjectsLogRoot.appendingPathComponent(projectName, isDirectory: true)
    }

    static var auditLogBase: URL { runsLogBase }
    static var logRoot: URL { runsLogBase }

    static var auditMatrixRefreshTSV: URL {
        runsLogBase.appendingPathComponent("audit_matrix_refresh.tsv")
    }

    static var auditMatrixAttachTSV: URL {
        runsLogBase.appendingPathComponent("audit_matrix_attach.tsv")
    }

    /// Horodatage pour noms de fichiers : `02-06-2026_16-49-30` (fuseau local, format FR).
    static func frenchLogStamp(from date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = .current
        formatter.dateFormat = "dd-MM-yyyy_HH-mm-ss"
        return formatter.string(from: date)
    }

    static func logBaseName(forMode mode: String) -> String {
        switch mode {
        case "audit":
            return "venv_audit"
        case "audit-apply":
            return "maj_matrice"
        case "sync-installer":
            return "sync_installer"
        case "apply-attachments":
            return "rattache_projets"
        default:
            return mode.replacingOccurrences(of: "-", with: "_")
        }
    }

    static func logFile(forMode mode: String, at date: Date = Date(), pid: Int32? = nil) -> URL {
        let stamp = frenchLogStamp(from: date)
        let base = logBaseName(forMode: mode)
        let processId = pid ?? ProcessInfo.processInfo.processIdentifier
        return runsLogBase.appendingPathComponent("\(base)_\(stamp)_pid\(processId).log")
    }

    static func ensureLogsLayout() {
        try? FileManager.default.createDirectory(
            at: runsLogBase,
            withIntermediateDirectories: true
        )
    }

    static func ensureHistoryLayout() {
        try? FileManager.default.createDirectory(
            at: matrixHistoryDirectory,
            withIntermediateDirectories: true
        )
    }

    static func archiveMatrixSnapshot(from source: URL? = nil) {
        let src = source ?? requirementsMatrixURL
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())

        ensureHistoryLayout()

        let historyFile = matrixHistoryDirectory.appendingPathComponent("\(stamp)_\(matrixFileName)")
        try? fm.copyItem(at: src, to: historyFile)
    }

    @discardableResult
    static func ensureMatrixLayout() -> URL {
        let fm = FileManager.default
        let target = requirementsMatrixURL
        ensureLogsLayout()
        ensureHistoryLayout()

        if fm.fileExists(atPath: target.path) {
            return target
        }

        let candidates: [URL] = [
            repoRoot.appendingPathComponent("package_updater_latest_output"),
            repoRoot.appendingPathComponent("requirements_matrix.txt"),
            installerRoot.appendingPathComponent("requirements_matrix.txt"),
        ]

        for source in candidates where fm.fileExists(atPath: source.path) {
            try? fm.copyItem(at: source, to: target)
            if fm.fileExists(atPath: target.path) {
                return target
            }
        }

        fm.createFile(atPath: target.path, contents: nil)
        return target
    }
}
