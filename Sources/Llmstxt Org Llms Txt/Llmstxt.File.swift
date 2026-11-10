public import Buffer_Linear
public import Builder
public import Memory_Allocator
public import Memory_Small
public import Storage

extension Llmstxt {
    public struct File: Sendable, Hashable {
        public var title: String
        public var summary: String?
        public var details: String?
        public var sections: [Llmstxt.Section]

        public init(
            title: String,
            summary: String? = nil,
            details: String? = nil,
            sections: [Llmstxt.Section] = []
        ) {
            self.title = title
            self.summary = summary
            self.details = details
            self.sections = sections
        }
    }
}

extension Llmstxt.File {
    public init(
        title: String,
        summary: String? = nil,
        details: String? = nil,
        @Builder<Llmstxt.Section> sections content: () ->
            Buffer<Storage<Memory.Allocator<Memory.Small<0>>>.Contiguous<Llmstxt.Section>>.Linear
    ) {
        var buffer = content()
        var sections: [Llmstxt.Section] = []
        while !buffer.isEmpty {
            sections.append(buffer.remove.first())
        }
        self.init(title: title, summary: summary, details: details, sections: sections)
    }
}

extension Llmstxt.File {
    public var optional: Llmstxt.Section? {
        sections.first(where: \.isOptional)
    }
}
