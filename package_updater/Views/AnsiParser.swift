import AppKit

/// Convertit une chaîne avec séquences ANSI SGR (couleurs bash) en NSAttributedString.
enum AnsiParser {
    static func attributedString(
        from input: String,
        font: NSFont,
        defaultColor: NSColor = NSColor(white: 0.92, alpha: 1),
        boldColor: NSColor? = nil
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var color = defaultColor
        var bold = false
        var i = input.startIndex

        func appendText(_ slice: Substring) {
            guard !slice.isEmpty else { return }
            var f = font
            if bold {
                f = NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: f,
                .foregroundColor: bold && boldColor != nil ? boldColor! : color,
            ]
            result.append(NSAttributedString(string: String(slice), attributes: attrs))
        }

        func applySGR(_ codes: String) {
            for part in codes.split(separator: ";") {
                guard let code = Int(part) else { continue }
                switch code {
                case 0:
                    color = defaultColor
                    bold = false
                case 1:
                    bold = true
                case 31:
                    color = NSColor.systemRed
                case 32:
                    color = NSColor.systemGreen
                case 33:
                    color = NSColor.systemYellow
                case 36:
                    color = NSColor.systemCyan
                default:
                    break
                }
            }
        }

        while i < input.endIndex {
            if input[i] == "\u{1B}" {
                let rest = input[i...]
                guard rest.hasPrefix("\u{1B}["),
                      let end = rest.firstIndex(of: "m")
                else {
                    i = input.index(after: i)
                    continue
                }
                let codeStart = input.index(i, offsetBy: 2)
                let codeStr = String(input[codeStart..<end])
                applySGR(codeStr)
                i = input.index(after: end)
                continue
            }

            let start = i
            while i < input.endIndex, input[i] != "\u{1B}" {
                i = input.index(after: i)
            }
            appendText(input[start..<i])
        }

        return result
    }
}
