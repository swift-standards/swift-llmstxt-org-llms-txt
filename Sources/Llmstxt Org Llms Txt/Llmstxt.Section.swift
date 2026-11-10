public import Buffer_Linear
public import Builder
public import Memory_Allocator
public import Memory_Small
public import Storage

extension Llmstxt {
    public struct Section: Sendable, Hashable {
        public var title: String
        public var links: [Llmstxt.Link]

        public init(_ title: String, links: [Llmstxt.Link] = []) {
            self.title = title
            self.links = links
        }
    }
}

extension Llmstxt.Section {
    public init(
        _ title: String,
        @Builder<Llmstxt.Link> links content: () ->
            Buffer<Storage<Memory.Allocator<Memory.Small<0>>>.Contiguous<Llmstxt.Link>>.Linear
    ) {
        var buffer = content()
        var links: [Llmstxt.Link] = []
        while !buffer.isEmpty {
            links.append(buffer.remove.first())
        }
        self.init(title, links: links)
    }
}

extension Llmstxt.Section {
    public var isOptional: Bool { title == "Optional" }
}
