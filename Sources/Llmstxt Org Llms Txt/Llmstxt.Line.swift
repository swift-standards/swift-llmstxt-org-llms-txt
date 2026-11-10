import ASCII

extension Llmstxt {
    struct Line {
        let number: Int
        let bytes: ArraySlice<UInt8>
    }
}

extension Llmstxt.Line {
    static func split(_ bytes: [UInt8]) -> [Llmstxt.Line] {
        var lines: [Llmstxt.Line] = []
        var start = bytes.startIndex
        var index = bytes.startIndex
        while index < bytes.endIndex {
            switch bytes[index] {
            case ASCII.Character.Control.lf:
                lines.append(Llmstxt.Line(number: lines.count + 1, bytes: bytes[start..<index]))
                index += 1
                start = index

            case ASCII.Character.Control.cr:
                lines.append(Llmstxt.Line(number: lines.count + 1, bytes: bytes[start..<index]))
                index += 1
                if index < bytes.endIndex, bytes[index] == ASCII.Character.Control.lf {
                    index += 1
                }
                start = index

            default:
                index += 1
            }
        }
        if start < bytes.endIndex {
            lines.append(Llmstxt.Line(number: lines.count + 1, bytes: bytes[start..<bytes.endIndex]))
        }
        return lines
    }
}

extension Llmstxt.Line {
    var isBlank: Bool {
        bytes.allSatisfy(ASCII.Classification.isWhitespace)
    }

    var indented: ArraySlice<UInt8>? {
        var rest = bytes
        var spaces = 0
        while spaces < 3, rest.first == ASCII.SPACE.sp {
            rest = rest.dropFirst()
            spaces += 1
        }
        guard let first = rest.first, !ASCII.Classification.isWhitespace(first) else {
            return nil
        }
        return rest
    }
}

extension Llmstxt.Line {
    var heading: (level: Int, content: ArraySlice<UInt8>)? {
        guard let rest = indented else { return nil }
        let marks = rest.prefix(while: { $0 == ASCII.Character.Graphic.numberSign }).count
        guard (1...6).contains(marks) else { return nil }
        var content = rest.dropFirst(marks)
        if let first = content.first, !ASCII.Classification.isWhitespace(first) { return nil }
        content = content.trimmed
        var closing = 0
        while closing < content.count,
            content[content.endIndex - closing - 1] == ASCII.Character.Graphic.numberSign
        {
            closing += 1
        }
        if closing == content.count {
            content = content.prefix(0)
        } else if closing > 0,
            ASCII.Classification.isWhitespace(content[content.endIndex - closing - 1])
        {
            content = content.dropLast(closing).trimmed
        }
        return (marks, content)
    }

    var isSetextUnderline: Bool {
        guard let rest = indented?.trimmed, let first = rest.first else { return false }
        guard first == ASCII.Character.Graphic.equalsSign || first == ASCII.Character.Graphic.hyphen else {
            return false
        }
        return rest.allSatisfy { $0 == first }
    }

    var fence: Llmstxt.Fence? {
        guard let rest = indented, let first = rest.first else { return nil }
        guard first == ASCII.Character.Graphic.leftSingleQuotationMark || first == ASCII.Character.Graphic.tilde
        else { return nil }
        let count = rest.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        if first == ASCII.Character.Graphic.leftSingleQuotationMark, rest.dropFirst(count).contains(first) {
            return nil
        }
        return Llmstxt.Fence(marker: first, count: count)
    }

    func closes(_ fence: Llmstxt.Fence) -> Bool {
        guard let rest = indented?.trimmed else { return false }
        return rest.count >= fence.count && rest.allSatisfy { $0 == fence.marker }
    }

    var quoted: ArraySlice<UInt8>? {
        guard let rest = indented, rest.first == ASCII.Character.Graphic.greaterThanSign else { return nil }
        let content = rest.dropFirst()
        if let first = content.first, first == ASCII.SPACE.sp || first == ASCII.Character.Control.htab {
            return content.dropFirst()
        }
        return content
    }

    var item: ArraySlice<UInt8>? {
        guard let rest = indented, let first = rest.first else { return nil }
        let marker: Int
        if first == ASCII.Character.Graphic.hyphen || first == ASCII.Character.Graphic.asterisk
            || first == ASCII.Character.Graphic.plusSign
        {
            marker = 1
        } else {
            let digits = rest.prefix(while: ASCII.Classification.isDigit).count
            guard (1...9).contains(digits), rest.count > digits else { return nil }
            let delimiter = rest[rest.startIndex + digits]
            guard delimiter == ASCII.Character.Graphic.period || delimiter == ASCII.Character.Graphic.rightParenthesis
            else { return nil }
            marker = digits + 1
        }
        let content = rest.dropFirst(marker)
        if let next = content.first, !ASCII.Classification.isWhitespace(next) { return nil }
        return content.trimmed
    }

    var interruptsParagraph: Bool {
        heading != nil || item != nil || quoted != nil || fence != nil
    }
}

extension ArraySlice<UInt8> {
    var trimmed: ArraySlice<UInt8> {
        var result = self
        while let first = result.first, ASCII.Classification.isWhitespace(first) {
            result = result.dropFirst()
        }
        while let last = result.last, ASCII.Classification.isWhitespace(last) {
            result = result.dropLast()
        }
        return result
    }
}
