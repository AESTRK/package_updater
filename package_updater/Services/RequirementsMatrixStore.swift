import AppKit
import Combine
import Foundation

@MainActor
final class RequirementsMatrixStore: ObservableObject {
    @Published var text = ""
    @Published private(set) var isDirty = false
    @Published private(set) var statusMessage = ""

    let fileURL: URL

    init() {
        fileURL = UpdaterPaths.requirementsMatrixURL
        load()
    }

    func load() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
            } else {
                text = ""
            }
            isDirty = false
            statusMessage = "Matrice chargée"
        } catch {
            statusMessage = "Lecture impossible : \(error.localizedDescription)"
        }
    }

    @discardableResult
    func save() -> Bool {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            isDirty = false
            statusMessage = "Matrice enregistrée"
            return true
        } catch {
            statusMessage = "Échec enregistrement : \(error.localizedDescription)"
            return false
        }
    }

    func textDidChange() {
        isDirty = true
        statusMessage = "Modifications non enregistrées"
    }

    func openInDefaultEditor() {
        NSWorkspace.shared.open(fileURL)
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
