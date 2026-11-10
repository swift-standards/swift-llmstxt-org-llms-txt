import Llmstxt_Org_Llms_Txt
import RFC_3986
import Testing

enum `Llmstxt.File Tests` {}

extension `Llmstxt.File Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Llmstxt.File Tests` {
    static let canonical = """
        # rule.law

        > Rules and the apps that apply them.

        Every app links to its own documentation.

        - Pages are Markdown.

        ## Apps

        - [All apps](https://rule.law/apps.md): Every app, by jurisdiction
        - [Search](/search.md)

        ## Optional

        - [Changelog](https://rule.law/changes.md): What changed, newest first

        """
}

extension `Llmstxt.File Tests`.Test.Unit {

    @Test
    func `a file reads into its title, summary, details and sections`() throws {
        let file = try Llmstxt.File(parsing: `Llmstxt.File Tests`.canonical)
        #expect(file.title == "rule.law")
        #expect(file.summary == "Rules and the apps that apply them.")
        #expect(file.details == "Every app links to its own documentation.\n\n- Pages are Markdown.")
        #expect(file.sections.map(\.title) == ["Apps", "Optional"])
        #expect(
            file.sections[0].links == [
                Llmstxt.Link("All apps", try RFC_3986.URI("https://rule.law/apps.md"), note: "Every app, by jurisdiction"),
                Llmstxt.Link("Search", try RFC_3986.URI("/search.md")),
            ]
        )
    }

    @Test
    func `a canonical file renders back to the same bytes`() throws {
        let bytes = Array(`Llmstxt.File Tests`.canonical.utf8)
        #expect(try Llmstxt.File(parsing: bytes).bytes == bytes)
    }

    @Test
    func `a built file renders the canonical form`() throws {
        let apps = try RFC_3986.URI("https://rule.law/apps.md")
        let file = Llmstxt.File(title: "rule.law", summary: "Rules and the apps that apply them.") {
            Llmstxt.Section("Apps") {
                Llmstxt.Link("All apps", apps, note: "Every app, by jurisdiction")
            }
            Llmstxt.Section("Empty")
        }
        #expect(
            String(decoding: file.bytes, as: UTF8.self) == """
                # rule.law

                > Rules and the apps that apply them.

                ## Apps

                - [All apps](https://rule.law/apps.md): Every app, by jurisdiction

                ## Empty

                """
        )
        #expect(try Llmstxt.File(parsing: file.bytes) == file)
    }

    @Test
    func `only the title is required`() throws {
        let file = try Llmstxt.File(parsing: "# Title\n")
        #expect(file == Llmstxt.File(title: "Title"))
        #expect(file.bytes == Array("# Title\n".utf8))
    }

    @Test
    func `a file without an H1 is refused`() {
        #expect(throws: Llmstxt.File.Error.missingTitle) { try Llmstxt.File(parsing: "") }
        #expect(throws: Llmstxt.File.Error.missingTitle) { try Llmstxt.File(parsing: "## Docs\n") }
        #expect(throws: Llmstxt.File.Error.missingTitle) { try Llmstxt.File(parsing: "Intro\n# Title\n") }
        #expect(throws: Llmstxt.File.Error.missingTitle) { try Llmstxt.File(parsing: "Title\n=====\n") }
        #expect(throws: Llmstxt.File.Error.missingTitle) { try Llmstxt.File(parsing: "#Title\n") }
    }

    @Test
    func `an empty title is refused`() {
        #expect(throws: Llmstxt.File.Error.emptyTitle(line: 2)) { try Llmstxt.File(parsing: "\n#   \n") }
        #expect(throws: Llmstxt.File.Error.emptyTitle(line: 1)) { try Llmstxt.File(parsing: "# ##\n") }
    }

    @Test
    func `the Optional section is marked but keeps its links`() throws {
        let file = try Llmstxt.File(parsing: `Llmstxt.File Tests`.canonical)
        #expect(file.sections.map(\.isOptional) == [false, true])
        #expect(file.optional?.links.map(\.name) == ["Changelog"])
        #expect(try Llmstxt.File(parsing: "# T\n\n## optional\n").optional == nil)
    }
}

extension `Llmstxt.File Tests`.Test.`Edge Case` {

    @Test
    func `a byte-order mark is skipped and never written`() throws {
        let file = try Llmstxt.File(parsing: [0xEF, 0xBB, 0xBF] + Array("# Title\n".utf8))
        #expect(file.title == "Title")
        #expect(file.bytes == Array("# Title\n".utf8))
    }

    @Test
    func `bytes that are not UTF-8 are refused`() {
        #expect(throws: Llmstxt.File.Error.invalidUTF8) {
            try Llmstxt.File(parsing: Array("# Title ".utf8) + [0xC3, 0x28])
        }
    }

    @Test
    func `CRLF and CR end lines, and rendering writes LF`() throws {
        let file = try Llmstxt.File(parsing: "# T\r\n\r\n> S\r## A\r\n- [a](/a)")
        #expect(file == Llmstxt.File(title: "T", summary: "S", sections: [Llmstxt.Section("A", links: [Llmstxt.Link("a", try RFC_3986.URI("/a"))])]))
        #expect(file.bytes == Array("# T\n\n> S\n\n## A\n\n- [a](/a)\n".utf8))
    }

    @Test
    func `an ATX closing sequence is not part of a title`() throws {
        #expect(try Llmstxt.File(parsing: "  # Title ##  \n").title == "Title")
        #expect(try Llmstxt.File(parsing: "# C#\n").title == "C#")
    }

    @Test
    func `the summary is the blockquote straight after the title, lazy lines included`() throws {
        let file = try Llmstxt.File(parsing: "# T\n\n> One\n>\n>   Two\nthree\n\n> Not the summary\n")
        #expect(file.summary == "One\n\n  Two\nthree")
        #expect(file.details == "> Not the summary")
        #expect(try Llmstxt.File(parsing: "# T\n\nText\n\n> Quote\n").summary == nil)
    }

    @Test
    func `an empty blockquote summary is refused`() {
        #expect(throws: Llmstxt.File.Error.emptySummary(line: 3)) { try Llmstxt.File(parsing: "# T\n\n>\n>  \n") }
    }

    @Test
    func `headings in the details are refused, unless inside a fenced code block`() throws {
        #expect(throws: Llmstxt.File.Error.heading(line: 3)) { try Llmstxt.File(parsing: "# T\n\n### Notes\n") }
        #expect(throws: Llmstxt.File.Error.heading(line: 3)) { try Llmstxt.File(parsing: "# T\n\n# Again\n") }
        #expect(throws: Llmstxt.File.Error.heading(line: 4)) { try Llmstxt.File(parsing: "# T\n\nNotes\n-----\n") }
        let file = try Llmstxt.File(parsing: "# T\n\n```sh\n# comment\n## not a section\n```\n\n- item\n---\n")
        #expect(file.details == "```sh\n# comment\n## not a section\n```\n\n- item\n---")
        #expect(file.sections.isEmpty)
    }

    @Test
    func `a section holds only list items and blank lines`() {
        #expect(throws: Llmstxt.File.Error.content(line: 4)) { try Llmstxt.File(parsing: "# T\n## A\n- [a](/a)\nMore text\n") }
        #expect(throws: Llmstxt.File.Error.heading(line: 3)) { try Llmstxt.File(parsing: "# T\n## A\n### B\n") }
        #expect(throws: Llmstxt.File.Error.heading(line: 3)) { try Llmstxt.File(parsing: "# T\n## A\n# B\n") }
        #expect(throws: Llmstxt.File.Error.emptySectionTitle(line: 2)) { try Llmstxt.File(parsing: "# T\n##\n") }
    }

    @Test
    func `a link refusal names its line`() {
        #expect(throws: Llmstxt.File.Error.link(.missingURL, line: 4)) {
            try Llmstxt.File(parsing: "# T\n## A\n- [a](/a)\n- [b]()\n")
        }
    }

    @Test
    func `every list marker is read, and rendering writes a hyphen`() throws {
        let file = try Llmstxt.File(parsing: "# T\n## A\n* [a](/a)\n+ [b](/b)\n1. [c](/c)\n2) [d](/d)\n")
        #expect(file.sections[0].links.map(\.name) == ["a", "b", "c", "d"])
        #expect(file.bytes == Array("# T\n\n## A\n\n- [a](/a)\n- [b](/b)\n- [c](/c)\n- [d](/d)\n".utf8))
    }

    @Test
    func `full page content under a section, as in an llms-full.txt, is refused`() {
        #expect(throws: Llmstxt.File.Error.content(line: 5)) {
            try Llmstxt.File(parsing: "# rule.law\n\n## Apps\n\nEvery app applies one rule.\n")
        }
    }
}

extension `Llmstxt.File Tests`.Test.Integration {

    @Test
    func `the llmstxt.org mock example reads`() throws {
        let file = try Llmstxt.File(
            parsing: """
                # Title

                > Optional description goes here

                Optional details go here

                ## Section name

                - [Link title](https://link_url): Optional link details

                ## Optional

                - [Link title](https://link_url)
                """
        )
        #expect(file.title == "Title")
        #expect(file.summary == "Optional description goes here")
        #expect(file.details == "Optional details go here")
        #expect(file.sections.map(\.title) == ["Section name", "Optional"])
        #expect(file.sections[0].links.first?.note == "Optional link details")
        #expect(file.optional?.links.first?.note == nil)
    }
}
