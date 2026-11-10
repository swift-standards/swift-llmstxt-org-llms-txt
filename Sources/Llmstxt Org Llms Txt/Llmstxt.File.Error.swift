extension Llmstxt.File {
    public enum Error: Swift::Error, Sendable, Equatable {
        case invalidUTF8
        case missingTitle
        case emptyTitle(line: Int)
        case emptySummary(line: Int)
        case heading(line: Int)
        case emptySectionTitle(line: Int)
        case content(line: Int)
        case link(Llmstxt.Link.Error, line: Int)
    }
}
