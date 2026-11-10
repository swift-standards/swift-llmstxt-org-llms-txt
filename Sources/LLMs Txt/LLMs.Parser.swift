extension LLMs {
    struct Parser {
        let lines: [LLMs.Line]
        var index = 0
    }
}

extension LLMs.Parser {
    private var current: LLMs.Line? {
        index < lines.count ? lines[index] : nil
    }

    private mutating func skipBlankLines() {
        while let line = current, line.isBlank { index += 1 }
    }

    private static func text(_ lines: some Collection<ArraySlice<UInt8>>) -> String {
        lines.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
    }
}

extension LLMs.Parser {
    mutating func file() throws(LLMs.File.Error) -> LLMs.File {
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
        var sections: [LLMs.Section] = []
        while current != nil {
            sections.append(try section())
        }
        return LLMs.File(
            title: String(decoding: heading.content, as: UTF8.self),
            summary: summary,
            details: details,
            sections: sections
        )
    }
}

extension LLMs.Parser {
    private mutating func summary() throws(LLMs.File.Error) -> String? {
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

extension LLMs.Parser {
    private mutating func details() throws(LLMs.File.Error) -> String? {
        let start = index
        var fence: LLMs.Fence?
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

extension LLMs.Parser {
    private mutating func section() throws(LLMs.File.Error) -> LLMs.Section {
        guard let line = current, let heading = line.heading, heading.level == 2 else {
            throw .heading(line: lines[index].number)
        }
        guard !heading.content.isEmpty else { throw .emptySectionTitle(line: line.number) }
        index += 1
        var links: [LLMs.Link] = []
        while let line = current {
            if let heading = line.heading {
                guard heading.level == 2 else { throw .heading(line: line.number) }
                break
            }
            if !line.isBlank {
                guard let item = line.item else { throw .content(line: line.number) }
                do throws(LLMs.Link.Error) {
                    links.append(try LLMs.Link(item: item))
                } catch {
                    throw .link(error, line: line.number)
                }
            }
            index += 1
        }
        return LLMs.Section(String(decoding: heading.content, as: UTF8.self), links: links)
    }
}
