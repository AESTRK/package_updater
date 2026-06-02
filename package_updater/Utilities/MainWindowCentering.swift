import AppKit
import CoreGraphics

/// Centre la fenêtre principale sur l'écran avec la barre de menus (Dock / menu bar exclus).
enum MainWindowCentering {
    @MainActor
    static func centerMainWindowOnPrimaryScreen() {
        if let window = resolveTargetWindow() {
            center(window: window)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            if let window = resolveTargetWindow() {
                center(window: window)
            }
        }
    }

    @MainActor
    private static func resolveTargetWindow() -> NSWindow? {
        if let main = NSApp.mainWindow, main.isVisible { return main }
        if let key = NSApp.keyWindow, key.isVisible { return key }
        return NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
    }

    @MainActor
    private static func center(window: NSWindow) {
        guard let screen = primaryScreen() else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visible.origin.x + (visible.width - frame.width) / 2
        frame.origin.y = visible.origin.y + (visible.height - frame.height) / 2
        window.setFrame(frame, display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func primaryScreen() -> NSScreen? {
        let mainID = CGMainDisplayID()
        for screen in NSScreen.screens {
            guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            if CGDirectDisplayID(num.uint32Value) == mainID {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}
