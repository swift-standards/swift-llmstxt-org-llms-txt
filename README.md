# swift-llmstxt-org-llms-txt

Use this package when you publish or read an `/llms.txt` file, the Markdown overview of a site for language models proposed at llmstxt.org (v2). Build one with `Llmstxt.File(title:summary:)`, whose block lists `Llmstxt.Section`s of `Llmstxt.Link`s, and write it with `bytes`; read one with `Llmstxt.File(parsing:)`, which refuses a file that breaks the format with an `Llmstxt.File.Error` naming the line. Link URLs are `RFC_3986.URI`. The package reads the format's subset of Markdown itself: the Institute's only Markdown package, swift-markdown-html-render, renders Markdown to HTML through swiftlang/swift-markdown, which needs Foundation and does not keep the source text of names, notes and details.

## Laws

- Input is UTF-8; anything else is refused as `invalidUTF8`. A leading byte-order mark is skipped and never written. CRLF, CR and LF all end a line; `bytes` writes LF, one at the end of the file.
- The first line that is not blank must be an ATX H1, `#` and a space, or the file is refused as `missingTitle`. A setext H1 is not read as one. A closing run of `#` is not part of the title, and an empty title is refused as `emptyTitle`.
- The summary is the blockquote straight after the title, blank lines between allowed. Each line loses its `>` and one space after it; lines that continue its paragraph without a `>` belong to it. A blockquote with no text is refused as `emptySummary`. A later blockquote is part of the details.
- The details are everything after the summary up to the first H2, kept as written without trailing blank lines. Any other heading there, ATX or setext, is refused as `heading`; a `#` line inside a fenced code block is not a heading.
- Each H2 starts a section, and an empty H2 is refused as `emptySectionTitle`. A section holds list items and blank lines only and may hold none. Any other line is refused as `content`, and a heading other than an H2 as `heading`.
- Each list item is `[name](url)`, optionally followed by `:` and a note. Items marked `-`, `*`, `+`, `1.` or `1)` are read; `bytes` writes `- `. The name and note are kept as written, Markdown included. A malformed item is refused as `link` with an `Llmstxt.Link.Error`: `missingLink`, `unclosedName`, `emptyName`, `missingURL` (also for `[name]` or `[name]()`), `unclosedURL` (also for a link title), `invalidURL` when RFC 3986 refuses the URL, `textAfterLink` and `emptyNote`.
- A URL may be written between angle brackets. `bytes` writes one there only when its parentheses do not balance.
- A section whose title is exactly `Optional` is the Optional section: `isOptional` is true and `Llmstxt.File.optional` returns it. v2 gives it no mechanical meaning, so its links are never dropped.
- A file read from canonical bytes, as `bytes` writes them, renders back to the same bytes, and a built file whose titles, names and notes are single lines reads back to the same file.
- llmstxt.org v2 does not describe `llms-full.txt`, so this package has no type for it. Such a file, with page content under its H2s, is refused as an llms.txt file as `content`.
