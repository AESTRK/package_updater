import Foundation

enum UpdaterPaths {
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

    static var scriptsDirectory: URL {
        repoRoot.appendingPathComponent("scripts", isDirectory: true)
    }

    static var packageUpdaterScript: URL {
        scriptsDirectory.appendingPathComponent("package-updater.sh")
    }

    static var requirementsMatrixURL: URL {
        scriptsDirectory.appendingPathComponent("requirements_matrix.txt")
    }

    static var installerRoot: URL = {
        let env = ProcessInfo.processInfo.environment["INSTALLER_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("XcodeProjects/installer", isDirectory: true)
    }()

    static var logRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/AlphaLagoon/_logs/package_updater", isDirectory: true)
    }
}
