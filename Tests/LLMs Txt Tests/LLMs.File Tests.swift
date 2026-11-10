import LLMs_Txt
import RFC_3986
import Testing

enum `LLMs.File Tests` {}

extension `LLMs.File Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `LLMs.File Tests` {
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

extension `LLMs.File Tests`.Test.Unit {

    @Test
    func `a file reads into its title, summary, details and sections`() throws {
        let file = try LLMs.File(parsing: `LLMs.File Tests`.canonical)
        #expect(file.title == "rule.law")
        #expect(file.summary == "Rules and the apps that apply them.")
        #expect(file.details == "Every app links to its own documentation.\n\n- Pages are Markdown.")
        #expect(file.sections.map(\.title) == ["Apps", "Optional"])
        #expect(
            file.sections[0].links == [
                LLMs.Link("All apps", try RFC_3986.URI("https://rule.law/apps.md"), note: "Every app, by jurisdiction"),
                LLMs.Link("Search", try RFC_3986.URI("/search.md")),
            ]
        )
    }

    @Test
    func `a canonical file renders back to the same bytes`() throws {
        let bytes = Array(`LLMs.File Tests`.canonical.utf8)
        #expect(try LLMs.File(parsing: bytes).bytes == bytes)
    }

    @Test
    func `a built file renders the canonical form`() throws {
        let apps = try RFC_3986.URI("https://rule.law/apps.md")
        let file = LLMs.File(title: "rule.law", summary: "Rules and the apps that apply them.") {
            LLMs.Section("Apps") {
                LLMs.Link("All apps", apps, note: "Every app, by jurisdiction")
            }
            LLMs.Section("Empty")
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
        #expect(try LLMs.File(parsing: file.bytes) == file)
    }

    @Test
    func `only the title is required`() throws {
        let file = try LLMs.File(parsing: "# Title\n")
        #expect(file == LLMs.File(title: "Title"))
        #expect(file.bytes == Array("# Title\n".utf8))
    }

    @Test
    func `a file without an H1 is refused`() {
        #expect(throws: LLMs.File.Error.missingTitle) { try LLMs.File(parsing: "") }
        #expect(throws: LLMs.File.Error.missingTitle) { try LLMs.File(parsing: "## Docs\n") }
        #expect(throws: LLMs.File.Error.missingTitle) { try LLMs.File(parsing: "Intro\n# Title\n") }
        #expect(throws: LLMs.File.Error.missingTitle) { try LLMs.File(parsing: "Title\n=====\n") }
        #expect(throws: LLMs.File.Error.missingTitle) { try LLMs.File(parsing: "#Title\n") }
    }

    @Test
    func `an empty title is refused`() {
        #expect(throws: LLMs.File.Error.emptyTitle(line: 2)) { try LLMs.File(parsing: "\n#   \n") }
        #expect(throws: LLMs.File.Error.emptyTitle(line: 1)) { try LLMs.File(parsing: "# ##\n") }
    }

    @Test
    func `the Optional section is marked but keeps its links`() throws {
        let file = try LLMs.File(parsing: `LLMs.File Tests`.canonical)
        #expect(file.sections.map(\.isOptional) == [false, true])
        #expect(file.optional?.links.map(\.name) == ["Changelog"])
        #expect(try LLMs.File(parsing: "# T\n\n## optional\n").optional == nil)
    }
}

extension `LLMs.File Tests`.Test.`Edge Case` {

    @Test
    func `a byte-order mark is skipped and never written`() throws {
        let file = try LLMs.File(parsing: [0xEF, 0xBB, 0xBF] + Array("# Title\n".utf8))
        #expect(file.title == "Title")
        #expect(file.bytes == Array("# Title\n".utf8))
    }

    @Test
    func `bytes that are not UTF-8 are refused`() {
        #expect(throws: LLMs.File.Error.invalidUTF8) {
            try LLMs.File(parsing: Array("# Title ".utf8) + [0xC3, 0x28])
        }
    }

    @Test
    func `CRLF and CR end lines, and rendering writes LF`() throws {
        let file = try LLMs.File(parsing: "# T\r\n\r\n> S\r## A\r\n- [a](/a)")
        #expect(file == LLMs.File(title: "T", summary: "S", sections: [LLMs.Section("A", links: [LLMs.Link("a", try RFC_3986.URI("/a"))])]))
        #expect(file.bytes == Array("# T\n\n> S\n\n## A\n\n- [a](/a)\n".utf8))
    }

    @Test
    func `an ATX closing sequence is not part of a title`() throws {
        #expect(try LLMs.File(parsing: "  # Title ##  \n").title == "Title")
        #expect(try LLMs.File(parsing: "# C#\n").title == "C#")
    }

    @Test
    func `the summary is the blockquote straight after the title, lazy lines included`() throws {
        let file = try LLMs.File(parsing: "# T\n\n> One\n>\n>   Two\nthree\n\n> Not the summary\n")
        #expect(file.summary == "One\n\n  Two\nthree")
        #expect(file.details == "> Not the summary")
        #expect(try LLMs.File(parsing: "# T\n\nText\n\n> Quote\n").summary == nil)
    }

    @Test
    func `an empty blockquote summary is refused`() {
        #expect(throws: LLMs.File.Error.emptySummary(line: 3)) { try LLMs.File(parsing: "# T\n\n>\n>  \n") }
    }

    @Test
    func `headings in the details are refused, unless inside a fenced code block`() throws {
        #expect(throws: LLMs.File.Error.heading(line: 3)) { try LLMs.File(parsing: "# T\n\n### Notes\n") }
        #expect(throws: LLMs.File.Error.heading(line: 3)) { try LLMs.File(parsing: "# T\n\n# Again\n") }
        #expect(throws: LLMs.File.Error.heading(line: 4)) { try LLMs.File(parsing: "# T\n\nNotes\n-----\n") }
        let file = try LLMs.File(parsing: "# T\n\n```sh\n# comment\n## not a section\n```\n\n- item\n---\n")
        #expect(file.details == "```sh\n# comment\n## not a section\n```\n\n- item\n---")
        #expect(file.sections.isEmpty)
    }

    @Test
    func `a section holds only list items and blank lines`() {
        #expect(throws: LLMs.File.Error.content(line: 4)) { try LLMs.File(parsing: "# T\n## A\n- [a](/a)\nMore text\n") }
        #expect(throws: LLMs.File.Error.heading(line: 3)) { try LLMs.File(parsing: "# T\n## A\n### B\n") }
        #expect(throws: LLMs.File.Error.heading(line: 3)) { try LLMs.File(parsing: "# T\n## A\n# B\n") }
        #expect(throws: LLMs.File.Error.emptySectionTitle(line: 2)) { try LLMs.File(parsing: "# T\n##\n") }
    }

    @Test
    func `a link refusal names its line`() {
        #expect(throws: LLMs.File.Error.link(.missingURL, line: 4)) {
            try LLMs.File(parsing: "# T\n## A\n- [a](/a)\n- [b]()\n")
        }
    }

    @Test
    func `every list marker is read, and rendering writes a hyphen`() throws {
        let file = try LLMs.File(parsing: "# T\n## A\n* [a](/a)\n+ [b](/b)\n1. [c](/c)\n2) [d](/d)\n")
        #expect(file.sections[0].links.map(\.name) == ["a", "b", "c", "d"])
        #expect(file.bytes == Array("# T\n\n## A\n\n- [a](/a)\n- [b](/b)\n- [c](/c)\n- [d](/d)\n".utf8))
    }

    @Test
    func `full page content under a section, as in an llms-full.txt, is refused`() {
        #expect(throws: LLMs.File.Error.content(line: 5)) {
            try LLMs.File(parsing: "# rule.law\n\n## Apps\n\nEvery app applies one rule.\n")
        }
    }
}

extension `LLMs.File Tests`.Test.Integration {

    @Test
    func `the llmstxt.org mock example reads`() throws {
        let file = try LLMs.File(
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
