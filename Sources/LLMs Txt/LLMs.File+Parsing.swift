extension LLMs.File {
    public init(parsing text: some Swift.StringProtocol) throws(LLMs.File.Error) {
        self = try Self.parse(Array(text.utf8))
    }

    public init(parsing bytes: some Swift.Collection<UInt8>) throws(LLMs.File.Error) {
        self = try Self.parse(Array(bytes))
    }

    private static func parse(_ bytes: [UInt8]) throws(LLMs.File.Error) -> LLMs.File {
        var bytes = bytes
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        guard String(validating: bytes, as: UTF8.self) != nil else { throw .invalidUTF8 }
        var parser = LLMs.Parser(lines: LLMs.Line.split(bytes))
        return try parser.file()
    }
}
