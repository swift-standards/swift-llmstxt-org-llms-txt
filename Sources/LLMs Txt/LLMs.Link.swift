public import RFC_3986

extension LLMs {
    public struct Link: Sendable, Hashable {
        public var name: String
        public var url: RFC_3986.URI
        public var note: String?

        public init(_ name: String, _ url: RFC_3986.URI, note: String? = nil) {
            self.name = name
            self.url = url
            self.note = note
        }
    }
}
