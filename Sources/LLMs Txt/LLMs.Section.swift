public import Buffer_Linear
public import Builder
public import Memory_Allocator
public import Memory_Small
public import Storage

extension LLMs {
    public struct Section: Sendable, Hashable {
        public var title: String
        public var links: [LLMs.Link]

        public init(_ title: String, links: [LLMs.Link] = []) {
            self.title = title
            self.links = links
        }
    }
}

extension LLMs.Section {
    public init(
        _ title: String,
        @Builder<LLMs.Link> links content: () ->
            Buffer<Storage<Memory.Allocator<Memory.Small<0>>>.Contiguous<LLMs.Link>>.Linear
    ) {
        var buffer = content()
        var links: [LLMs.Link] = []
        while !buffer.isEmpty {
            links.append(buffer.remove.first())
        }
        self.init(title, links: links)
    }
}

extension LLMs.Section {
    public var isOptional: Bool { title == "Optional" }
}
