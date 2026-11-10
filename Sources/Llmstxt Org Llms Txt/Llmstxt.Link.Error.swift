public import RFC_3986

extension Llmstxt.Link {
    public enum Error: Swift::Error, Sendable, Equatable {
        case missingLink
        case unclosedName
        case emptyName
        case missingURL
        case unclosedURL
        case invalidURL(RFC_3986.Error)
        case textAfterLink
        case emptyNote
    }
}
