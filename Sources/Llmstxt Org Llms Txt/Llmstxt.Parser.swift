extension Llmstxt {
    struct Parser {
        let lines: [Llmstxt.Line]
        var index = 0
    }
}

extension Llmstxt.Parser {
    private var current: Llmstxt.Line? {
        index < lines.count ? lines[index] : nil
    }

    private mutating func skipBlankLines() {
        while let line = current, line.isBlank { index += 1 }
    }

    private static func text(_ lines: some Swift.Collection<ArraySlice<UInt8>>) -> String {
        lines.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
    }
}

extension Llmstxt.Parser {
    mutating func file() throws(Llmstxt.File.Error) -> Llmstxt.File {
        skipBlankLines()
        guard let line = current, let heading = line.heading, heading.level == 1 else {
            throw .missingTitle
        }
        guard !heading.content.isEmpty else { throw .emptyTitle(line: line.number) }
        index += 1
        skipBlankLines()
        let summary = try self.summary()
        skipBlankLines()
        let details = try self.details()
        var sections: [Llmstxt.Section] = []
        while current != nil {
            sections.append(try section())
        }
        return Llmstxt.File(
            title: String(decoding: heading.content, as: UTF8.self),
            summary: summary,
            details: details,
            sections: sections
        )
    }
}

extension Llmstxt.Parser {
    private mutating func summary() throws(Llmstxt.File.Error) -> String? {
        guard let first = current, first.quoted != nil else { return nil }
        var content: [ArraySlice<UInt8>] = []
        while let line = current, !line.isBlank {
            if let quoted = line.quoted {
                content.append(quoted)
            } else if line.interruptsParagraph || line.isSetextUnderline {
                break
            } else {
                content.append(line.bytes)
            }
            index += 1
        }
        guard content.contains(where: { !$0.trimmed.isEmpty }) else {
            throw .emptySummary(line: first.number)
        }
        return Self.text(content)
    }
}

extension Llmstxt.Parser {
    private mutating func details() throws(Llmstxt.File.Error) -> String? {
        let start = index
        var fence: Llmstxt.Fence?
        var paragraph = false
        var container = false
        while let line = current {
            if let open = fence {
                if line.closes(open) { fence = nil }
                index += 1
                continue
            }
            if let heading = line.heading {
                guard heading.level == 2 else { throw .heading(line: line.number) }
                break
            }
            if line.isSetextUnderline, paragraph {
                throw .heading(line: line.number)
            }
            if let opened = line.fence {
                fence = opened
                paragraph = false
            } else if line.isBlank {
                paragraph = false
                container = false
            } else if line.item != nil || line.quoted != nil {
                container = true
                paragraph = false
            } else {
                paragraph = paragraph || !container
            }
            index += 1
        }
        var content = lines[start..<index].map(\.bytes)
        while let last = content.last, last.trimmed.isEmpty { content.removeLast() }
        return content.isEmpty ? nil : Self.text(content)
    }
}

extension Llmstxt.Parser {
    private mutating func section() throws(Llmstxt.File.Error) -> Llmstxt.Section {
        guard let line = current, let heading = line.heading, heading.level == 2 else {
            throw .heading(line: lines[index].number)
        }
        guard !heading.content.isEmpty else { throw .emptySectionTitle(line: line.number) }
        index += 1
        var links: [Llmstxt.Link] = []
        while let line = current {
            if let heading = line.heading {
                guard heading.level == 2 else { throw .heading(line: line.number) }
                break
            }
            if !line.isBlank {
                guard let item = line.item else { throw .content(line: line.number) }
                do throws(Llmstxt.Link.Error) {
                    links.append(try Llmstxt.Link(item: item))
                } catch {
                    throw .link(error, line: line.number)
                }
            }
            index += 1
        }
        return Llmstxt.Section(String(decoding: heading.content, as: UTF8.self), links: links)
    }
}
