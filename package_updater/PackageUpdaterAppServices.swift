import Foundation

@MainActor
enum PackageUpdaterAppServices {
    static weak var runner: ScriptRunner?
    static weak var matrix: RequirementsMatrixStore?
}
