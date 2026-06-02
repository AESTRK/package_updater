import AppKit

/// Convertit une chaîne avec séquences ANSI SGR (couleurs bash) en NSAttributedString.
enum AnsiParser {
    /// Retire les séquences ANSI pour fichiers log / éditeur texte.
    static func strippingANSICodes(from input: String) -> String {
        guard input.contains("\u{1B}") else { return input }
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "\u{1B}" {
                let afterEsc = input.index(after: i)
                guard afterEsc < input.endIndex, input[afterEsc] == "[" else {
                    result.append(input[i])
                    i = input.index(after: i)
                    continue
                }
                var j = input.index(after: afterEsc)
                while j < input.endIndex, input[j] != "m" {
                    j = input.index(after: j)
                }
                if j < input.endIndex {
                    i = input.index(after: j)
                    continue
                }
            }
            result.append(input[i])
            i = input.index(after: i)
        }
        return result
    }

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

    /// Colorise les lignes du rapport audit (sans codes ANSI dans le flux).
    static func attributedStringColoredLogLine(
        _ line: String,
        font: NSFont,
        defaultColor: NSColor = NSColor(white: 0.92, alpha: 1)
    ) -> NSAttributedString {
        var color = defaultColor
        if line.contains("MATRICE_SUPERIEURE") || line.contains(" ABSENT") || line.contains("VENV_ABSENT") {
            color = .systemRed
        } else if line.contains("MATRICE_A_RAFRAICHIR") || line.contains("A_CHECKER") || line.contains("A_VERIFIER") {
            color = .systemYellow
        } else if line.contains(" SANS_MATRICE") || line.contains(" LIBRE") {
            color = .systemCyan
        } else if line.contains("A_JOUR") && line.contains(" OK") {
            color = .systemGreen
        } else if line.hasPrefix("[") && line.hasSuffix("]") {
            color = NSColor(white: 0.75, alpha: 1)
        }
        return NSAttributedString(
            string: line + "\n",
            attributes: [.font: font, .foregroundColor: color]
        )
    }

    static func attributedStringForLog(
        _ input: String,
        font: NSFont,
        defaultColor: NSColor = NSColor(white: 0.92, alpha: 1)
    ) -> NSAttributedString {
        if input.contains("\u{1B}[") {
            return attributedString(from: input, font: font, defaultColor: defaultColor)
        }
        let result = NSMutableAttributedString()
        for line in input.split(separator: "\n", omittingEmptySubsequences: false) {
            result.append(attributedStringColoredLogLine(String(line), font: font, defaultColor: defaultColor))
        }
        return result
    }
}
