import ASCII
import RFC_3986

extension LLMs.Link {
    init(item content: ArraySlice<UInt8>) throws(LLMs.Link.Error) {
        guard content.first == ASCII.Character.Graphic.leftBracket else { throw .missingLink }
        var index = content.startIndex + 1
        var depth = 1
        while index < content.endIndex {
            let byte = content[index]
            if byte == ASCII.Character.Graphic.reverseSolidus {
                index += 2
                continue
            }
            if byte == ASCII.Character.Graphic.leftBracket { depth += 1 }
            if byte == ASCII.Character.Graphic.rightBracket {
                depth -= 1
                if depth == 0 { break }
            }
            index += 1
        }
        guard depth == 0, index < content.endIndex else { throw .unclosedName }
        let name = content[(content.startIndex + 1)..<index]
        guard !name.trimmed.isEmpty else { throw .emptyName }
        index += 1
        guard index < content.endIndex, content[index] == ASCII.Character.Graphic.leftParenthesis else {
            throw .missingURL
        }
        index += 1
        let destination: ArraySlice<UInt8>
        (destination, index) = try Self.destination(in: content, from: index)
        guard !destination.isEmpty else { throw .missingURL }
        let url: RFC_3986.URI
        do throws(RFC_3986.Error) {
            url = try RFC_3986.URI(String(decoding: destination, as: UTF8.self))
        } catch {
            throw .invalidURL(error)
        }
        let rest = content[index...].trimmed
        var note: String?
        if let first = rest.first {
            guard first == ASCII.Character.Graphic.colon else { throw .textAfterLink }
            let text = rest.dropFirst().trimmed
            guard !text.isEmpty else { throw .emptyNote }
            note = String(decoding: text, as: UTF8.self)
        }
        self.init(String(decoding: name, as: UTF8.self), url, note: note)
    }
}

extension LLMs.Link {
    private static func destination(
        in content: ArraySlice<UInt8>,
        from start: Int
    ) throws(LLMs.Link.Error) -> (ArraySlice<UInt8>, Int) {
        var index = start
        while index < content.endIndex, ASCII.Classification.isWhitespace(content[index]) { index += 1 }
        let begin: Int
        let end: Int
        if index < content.endIndex, content[index] == ASCII.Character.Graphic.lessThanSign {
            begin = index + 1
            index = begin
            while index < content.endIndex, content[index] != ASCII.Character.Graphic.greaterThanSign {
                if content[index] == ASCII.Character.Graphic.lessThanSign { throw .unclosedURL }
                index += content[index] == ASCII.Character.Graphic.reverseSolidus ? 2 : 1
            }
            guard index < content.endIndex else { throw .unclosedURL }
            end = index
            index += 1
        } else {
            begin = index
            var depth = 0
            while index < content.endIndex {
                let byte = content[index]
                if ASCII.Classification.isWhitespace(byte) { break }
                if byte == ASCII.Character.Graphic.reverseSolidus {
                    index += 2
                    continue
                }
                if byte == ASCII.Character.Graphic.leftParenthesis { depth += 1 }
                if byte == ASCII.Character.Graphic.rightParenthesis {
                    if depth == 0 { break }
                    depth -= 1
                }
                index += 1
            }
            end = min(index, content.endIndex)
            index = end
        }
        while index < content.endIndex, ASCII.Classification.isWhitespace(content[index]) { index += 1 }
        guard index < content.endIndex, content[index] == ASCII.Character.Graphic.rightParenthesis else {
            throw .unclosedURL
        }
        return (content[begin..<end], index + 1)
    }
}
