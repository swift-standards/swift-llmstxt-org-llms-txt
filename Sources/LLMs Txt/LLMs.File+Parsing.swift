extension LLMs.File {
    public init(parsing text: some StringProtocol) throws(LLMs.File.Error) {
        try self.init(parsing: Array(text.utf8))
    }

    public init(parsing bytes: some Collection<UInt8>) throws(LLMs.File.Error) {
        var bytes = Array(bytes)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        guard String(validating: bytes, as: UTF8.self) != nil else { throw .invalidUTF8 }
        var parser = LLMs.Parser(lines: LLMs.Line.split(bytes))
        self = try parser.file()
    }
}
