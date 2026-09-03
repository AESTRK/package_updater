import AlphaLagoonPaths
import Foundation

enum UpdaterPaths {
    static let projectName = "package_updater"
    static let matrixFileName = "pip_matrix.txt"

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

    static let suiteRoot: URL = AlphaLagoonPaths.suiteRoot()

    static var xcodeProjectsLogRoot: URL {
        suiteRoot.appendingPathComponent("_logs_XcodeProjects", isDirectory: true)
    }

    static var configDataDir: URL {
        AlphaLagoonPaths.configDataDir()
    }

    static var requirementsMatrixURL: URL {
        if let env = ProcessInfo.processInfo.environment["REQUIREMENTS_MATRIX"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return AlphaLagoonPaths.pipMatrixURL(configDataDir: configDataDir)
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

    static var archiveMatrixScript: URL {
        scriptsDirectory.appendingPathComponent("archive-matrix.sh")
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
        case "archive-matrix":
            return archiveMatrixScript
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
        AlphaLagoonPaths.frenchLogStamp(from: date)
    }

    static func logBaseName(forMode mode: String) -> String {
        switch mode {
        case "audit":
            return "venv_audit"
        case "audit-apply":
            return "maj_matrice"
        case "archive-matrix":
            return "archive_matrix"
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

        try? fm.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        fm.createFile(atPath: target.path, contents: nil)
        return target
    }
}
