import AppKit
import SwiftUI

/// Journal style terminal : couleurs ANSI du script bash.
struct AnsiLogView: NSViewRepresentable {
    let text: String
    var autoScroll = true

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)
        textView.textColor = NSColor(white: 0.92, alpha: 1)
        textView.insertionPointColor = .white
        textView.font = NSFont.monospacedSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .regular
        )
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byCharWrapping

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard context.coordinator.lastText != text else { return }

        context.coordinator.lastText = text
        let font = textView.font ?? NSFont.monospacedSystemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .regular
        )
        let attributed = AnsiParser.attributedString(from: text, font: font)
        textView.textStorage?.setAttributedString(attributed)

        if autoScroll {
            DispatchQueue.main.async {
                textView.scrollToEndOfDocument(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastText = ""
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
    }
}
