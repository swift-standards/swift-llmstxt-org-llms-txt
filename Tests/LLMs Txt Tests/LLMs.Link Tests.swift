import LLMs_Txt
import RFC_3986
import Testing

enum `LLMs.Link Tests` {}

extension `LLMs.Link Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `LLMs.Link Tests` {
    static func link(_ item: String) throws(LLMs.File.Error) -> LLMs.Link? {
        try LLMs.File(parsing: "# T\n## A\n- \(item)\n").sections.first?.links.first
    }

    static func refusal(_ item: String) -> LLMs.Link.Error? {
        do throws(LLMs.File.Error) {
            _ = try link(item)
            return nil
        } catch {
            guard case .link(let refusal, line: 3) = error else { return nil }
            return refusal
        }
    }
}

extension `LLMs.Link Tests`.Test.Unit {

    @Test
    func `a link reads its name, URL and note`() throws {
        let link = try `LLMs.Link Tests`.link("[Docs](https://example.com/docs.md): Read first")
        #expect(link == LLMs.Link("Docs", try RFC_3986.URI("https://example.com/docs.md"), note: "Read first"))
    }

    @Test
    func `the note is optional, and the colon needs no space`() throws {
        #expect(try `LLMs.Link Tests`.link("[Docs](/docs.md)")?.note == nil)
        #expect(try `LLMs.Link Tests`.link("[Docs](/docs.md):Read first  ")?.note == "Read first")
    }

    @Test(arguments: [
        ("Plain text", LLMs.Link.Error.missingLink),
        ("", LLMs.Link.Error.missingLink),
        ("[Docs", LLMs.Link.Error.unclosedName),
        ("[ ](/a)", LLMs.Link.Error.emptyName),
        ("[Docs]", LLMs.Link.Error.missingURL),
        ("[Docs] (/a)", LLMs.Link.Error.missingURL),
        ("[Docs]()", LLMs.Link.Error.missingURL),
        ("[Docs](<>)", LLMs.Link.Error.missingURL),
        ("[Docs](/a", LLMs.Link.Error.unclosedURL),
        ("[Docs](/a \"Title\")", LLMs.Link.Error.unclosedURL),
        ("[Docs](/a) and more", LLMs.Link.Error.textAfterLink),
        ("[Docs](/a):", LLMs.Link.Error.emptyNote),
        ("[Docs](/a):   ", LLMs.Link.Error.emptyNote),
    ])
    func `a malformed link is refused`(item: String, refusal: LLMs.Link.Error) {
        #expect(`LLMs.Link Tests`.refusal(item) == refusal)
    }

    @Test
    func `a URL that is not RFC 3986 is refused`() {
        guard case .invalidURL = `LLMs.Link Tests`.refusal("[Docs](<https://example.com/a b>)") else {
            Issue.record("expected invalidURL")
            return
        }
    }
}

extension `LLMs.Link Tests`.Test.`Edge Case` {

    @Test
    func `names keep their Markdown, including escaped and nested brackets`() throws {
        #expect(try `LLMs.Link Tests`.link("[The *rule* \\] [v2]](/a)")?.name == "The *rule* \\] [v2]")
    }

    @Test
    func `an angle-bracketed URL and balanced parentheses are read`() throws {
        #expect(try `LLMs.Link Tests`.link("[a](<https://e.com/a)>)")?.url.value == "https://e.com/a)")
        #expect(try `LLMs.Link Tests`.link("[a](https://e.com/(x))")?.url.value == "https://e.com/(x)")
    }

    @Test
    func `a URL with unbalanced parentheses renders between angle brackets`() throws {
        let a = try RFC_3986.URI("https://e.com/a)")
        let b = try RFC_3986.URI("https://e.com/(b)")
        let file = LLMs.File(title: "T") {
            LLMs.Section("A") {
                LLMs.Link("a", a)
                LLMs.Link("b", b)
            }
        }
        #expect(String(decoding: file.bytes, as: UTF8.self).hasSuffix("- [a](<https://e.com/a)>)\n- [b](https://e.com/(b))\n"))
        #expect(try LLMs.File(parsing: file.bytes) == file)
    }
}
