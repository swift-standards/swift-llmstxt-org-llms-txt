extension LLMs.File {
    public enum Error: Swift::Error, Sendable, Equatable {
        case invalidUTF8
        case missingTitle
        case emptyTitle(line: Int)
        case emptySummary(line: Int)
        case heading(line: Int)
        case emptySectionTitle(line: Int)
        case content(line: Int)
        case link(LLMs.Link.Error, line: Int)
    }
}
