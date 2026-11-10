import ASCII
import RFC_3986

extension LLMs.File {
    public var bytes: [UInt8] {
        Array(text.utf8)
    }

    private var text: String {
        var text = "# \(title)\n"
        if let summary {
            text += "\n"
            for line in summary.split(separator: "\n", omittingEmptySubsequences: false) {
                text += line.isEmpty ? ">\n" : "> \(line)\n"
            }
        }
        if let details {
            text += "\n\(details)\n"
        }
        for section in sections {
            text += "\n## \(section.title)\n"
            if !section.links.isEmpty {
                text += "\n"
            }
            for link in section.links {
                text += "- \(link.markdown)\n"
            }
        }
        return text
    }
}

extension LLMs.File: CustomStringConvertible {
    public var description: String { text }
}

extension LLMs.Link {
    var markdown: String {
        let url = url.value
        var depth = 0
        var balanced = true
        for character in url.utf8 {
            if character == ASCII.Character.Graphic.leftParenthesis { depth += 1 }
            if character == ASCII.Character.Graphic.rightParenthesis {
                depth -= 1
                if depth < 0 { balanced = false }
            }
        }
        let destination = balanced && depth == 0 ? url : "<\(url)>"
        guard let note else { return "[\(name)](\(destination))" }
        return "[\(name)](\(destination)): \(note)"
    }
}
