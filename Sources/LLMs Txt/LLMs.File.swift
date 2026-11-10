public import Buffer_Linear
public import Builder
public import Memory_Allocator
public import Memory_Small
public import Storage

extension LLMs {
    public struct File: Sendable, Hashable {
        public var title: String
        public var summary: String?
        public var details: String?
        public var sections: [LLMs.Section]

        public init(
            title: String,
            summary: String? = nil,
            details: String? = nil,
            sections: [LLMs.Section] = []
        ) {
            self.title = title
            self.summary = summary
            self.details = details
            self.sections = sections
        }
    }
}

extension LLMs.File {
    public init(
        title: String,
        summary: String? = nil,
        details: String? = nil,
        @Builder<LLMs.Section> sections content: () ->
            Buffer<Storage<Memory.Allocator<Memory.Small<0>>>.Contiguous<LLMs.Section>>.Linear
    ) {
        var buffer = content()
        var sections: [LLMs.Section] = []
        while !buffer.isEmpty {
            sections.append(buffer.remove.first())
        }
        self.init(title: title, summary: summary, details: details, sections: sections)
    }
}

extension LLMs.File {
    public var optional: LLMs.Section? {
        sections.first(where: \.isOptional)
    }
}
