import Foundation

@MainActor
enum PackageUpdaterActions {
    static func runUpdater(mode: String, runner: ScriptRunner, matrix: RequirementsMatrixStore) {
        guard saveMatrixIfNeeded(matrix) else { return }
        runner.run(mode: mode, requirementsMatrix: matrix.fileURL) { [weak matrix] code in
            if (mode == "audit-apply" || mode == "apply-attachments"), code == 0 {
                matrix?.load()
            }
        }
    }

    static func attachNewProjects(runner: ScriptRunner, matrix: RequirementsMatrixStore) {
        ProjectAttachmentCoordinator.promptAndAttach(runner: runner, matrix: matrix)
    }

    @discardableResult
    static func saveMatrixIfNeeded(_ matrix: RequirementsMatrixStore) -> Bool {
        guard matrix.isDirty else { return true }
        return matrix.save()
    }

    @discardableResult
    static func saveMatrix(_ matrix: RequirementsMatrixStore) -> Bool {
        matrix.save()
    }
}
