import Llmstxt_Org_Llms_Txt
import RFC_3986
import Testing

enum `Llmstxt.Link Tests` {}

extension `Llmstxt.Link Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `Llmstxt.Link Tests` {
    static func link(_ item: String) throws(Llmstxt.File.Error) -> Llmstxt.Link? {
        try Llmstxt.File(parsing: "# T\n## A\n- \(item)\n").sections.first?.links.first
    }

    static func refusal(_ item: String) -> Llmstxt.Link.Error? {
        do throws(Llmstxt.File.Error) {
            _ = try link(item)
            return nil
        } catch {
            guard case .link(let refusal, line: 3) = error else { return nil }
            return refusal
        }
    }
}

extension `Llmstxt.Link Tests`.Test.Unit {

    @Test
    func `a link reads its name, URL and note`() throws {
        let link = try `Llmstxt.Link Tests`.link("[Docs](https://example.com/docs.md): Read first")
        #expect(link == Llmstxt.Link("Docs", try RFC_3986.URI("https://example.com/docs.md"), note: "Read first"))
    }

    @Test
    func `the note is optional, and the colon needs no space`() throws {
        #expect(try `Llmstxt.Link Tests`.link("[Docs](/docs.md)")?.note == nil)
        #expect(try `Llmstxt.Link Tests`.link("[Docs](/docs.md):Read first  ")?.note == "Read first")
    }

    @Test(arguments: [
        ("Plain text", Llmstxt.Link.Error.missingLink),
        ("", Llmstxt.Link.Error.missingLink),
        ("[Docs", Llmstxt.Link.Error.unclosedName),
        ("[ ](/a)", Llmstxt.Link.Error.emptyName),
        ("[Docs]", Llmstxt.Link.Error.missingURL),
        ("[Docs] (/a)", Llmstxt.Link.Error.missingURL),
        ("[Docs]()", Llmstxt.Link.Error.missingURL),
        ("[Docs](<>)", Llmstxt.Link.Error.missingURL),
        ("[Docs](/a", Llmstxt.Link.Error.unclosedURL),
        ("[Docs](/a \"Title\")", Llmstxt.Link.Error.unclosedURL),
        ("[Docs](/a) and more", Llmstxt.Link.Error.textAfterLink),
        ("[Docs](/a):", Llmstxt.Link.Error.emptyNote),
        ("[Docs](/a):   ", Llmstxt.Link.Error.emptyNote),
    ])
    func `a malformed link is refused`(item: String, refusal: Llmstxt.Link.Error) {
        #expect(`Llmstxt.Link Tests`.refusal(item) == refusal)
    }

    @Test
    func `a URL that is not RFC 3986 is refused`() {
        guard case .invalidURL = `Llmstxt.Link Tests`.refusal("[Docs](<https://example.com/a b>)") else {
            Issue.record("expected invalidURL")
            return
        }
    }
}

extension `Llmstxt.Link Tests`.Test.`Edge Case` {

    @Test
    func `names keep their Markdown, including escaped and nested brackets`() throws {
        #expect(try `Llmstxt.Link Tests`.link("[The *rule* \\] [v2]](/a)")?.name == "The *rule* \\] [v2]")
    }

    @Test
    func `an angle-bracketed URL and balanced parentheses are read`() throws {
        #expect(try `Llmstxt.Link Tests`.link("[a](<https://e.com/a)>)")?.url.value == "https://e.com/a)")
        #expect(try `Llmstxt.Link Tests`.link("[a](https://e.com/(x))")?.url.value == "https://e.com/(x)")
    }

    @Test
    func `a URL with unbalanced parentheses renders between angle brackets`() throws {
        let a = try RFC_3986.URI("https://e.com/a)")
        let b = try RFC_3986.URI("https://e.com/(b)")
        let file = Llmstxt.File(title: "T") {
            Llmstxt.Section("A") {
                Llmstxt.Link("a", a)
                Llmstxt.Link("b", b)
            }
        }
        #expect(String(decoding: file.bytes, as: UTF8.self).hasSuffix("- [a](<https://e.com/a)>)\n- [b](https://e.com/(b))\n"))
        #expect(try Llmstxt.File(parsing: file.bytes) == file)
    }
}
