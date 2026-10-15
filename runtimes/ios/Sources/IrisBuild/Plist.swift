/// A value of an old-style (OpenStep) property list, the format Xcode keeps
/// `project.pbxproj` in.
public indirect enum Plist: Equatable, Sendable {
    case string(String)
    case array([Plist])
    case dictionary([String: Plist])

    public var string: String? {
        if case let .string(value) = self { value } else { nil }
    }

    public var array: [Plist]? {
        if case let .array(value) = self { value } else { nil }
    }

    public var dictionary: [String: Plist]? {
        if case let .dictionary(value) = self { value } else { nil }
    }

    /// The strings of an array, skipping anything else.
    public var strings: [String] { array?.compactMap(\.string) ?? [] }

    public subscript(key: String) -> Plist? { dictionary?[key] }
}

public struct PlistError: Error, CustomStringConvertible {
    public let message: String
    /// The line the parser stopped at, from 1.
    public let line: Int

    public var description: String { "line \(line): \(message)" }
}

extension Plist {
    /// Parses `{ key = value; }` dictionaries, `( a, b, )` arrays, quoted and
    /// bare strings, and `/* */` and `//` comments.
    public init(parsing text: String) throws {
        var parser = Parser(bytes: Array(text.utf8))
        self = try parser.value()
        parser.skipSpace()
        guard parser.index == parser.bytes.count else { throw parser.error("text after the end") }
    }
}

private struct Parser {
    let bytes: [UInt8]
    var index = 0

    func error(_ message: String) -> PlistError {
        PlistError(message: message, line: bytes[..<min(index, bytes.count)].count { $0 == UInt8(ascii: "\n") } + 1)
    }

    var current: UInt8? { index < bytes.count ? bytes[index] : nil }

    mutating func skipSpace() {
        while let byte = current {
            if byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r") {
                index += 1
            } else if byte == UInt8(ascii: "/"), index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "*") {
                index += 2
                while index + 1 < bytes.count, !(bytes[index] == UInt8(ascii: "*") && bytes[index + 1] == UInt8(ascii: "/")) {
                    index += 1
                }
                index = min(index + 2, bytes.count)
            } else if byte == UInt8(ascii: "/"), index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "/") {
                while let byte = current, byte != UInt8(ascii: "\n") { index += 1 }
            } else {
                return
            }
        }
    }

    mutating func expect(_ character: Character) throws {
        skipSpace()
        guard current == character.asciiValue else { throw error("expected \(character)") }
        index += 1
    }

    mutating func value() throws -> Plist {
        skipSpace()
        switch current {
        case UInt8(ascii: "{"):
            index += 1
            var dictionary: [String: Plist] = [:]
            while true {
                skipSpace()
                if current == UInt8(ascii: "}") {
                    index += 1
                    return .dictionary(dictionary)
                }
                guard case let .string(key) = try value() else { throw error("a key must be a string") }
                try expect("=")
                dictionary[key] = try value()
                try expect(";")
            }
        case UInt8(ascii: "("):
            index += 1
            var array: [Plist] = []
            while true {
                skipSpace()
                if current == UInt8(ascii: ")") {
                    index += 1
                    return .array(array)
                }
                array.append(try value())
                skipSpace()
                if current == UInt8(ascii: ",") { index += 1 }
            }
        case UInt8(ascii: "\""):
            return .string(try quoted())
        case nil:
            throw error("unexpected end")
        default:
            let start = index
            while let byte = current, isBare(byte) { index += 1 }
            guard index > start else { throw error("unexpected character") }
            return .string(String(decoding: bytes[start ..< index], as: UTF8.self))
        }
    }

    /// Letters, digits and the punctuation Xcode leaves unquoted.
    func isBare(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a") ... UInt8(ascii: "z"), UInt8(ascii: "A") ... UInt8(ascii: "Z"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
            true
        default:
            "_$+/:.-".utf8.contains(byte) || byte >= 0x80
        }
    }

    mutating func quoted() throws -> String {
        index += 1
        var out: [UInt8] = []
        while let byte = current {
            index += 1
            switch byte {
            case UInt8(ascii: "\""):
                return String(decoding: out, as: UTF8.self)
            case UInt8(ascii: "\\"):
                guard let escaped = current else { break }
                index += 1
                switch escaped {
                case UInt8(ascii: "n"): out.append(UInt8(ascii: "\n"))
                case UInt8(ascii: "t"): out.append(UInt8(ascii: "\t"))
                case UInt8(ascii: "r"): out.append(UInt8(ascii: "\r"))
                case UInt8(ascii: "U"):
                    // \U followed by four hex digits, a UTF-16 unit.
                    let end = min(index + 4, bytes.count)
                    let hex = String(decoding: bytes[index ..< end], as: UTF8.self)
                    index = end
                    if let unit = UInt16(hex, radix: 16), let scalar = Unicode.Scalar(unit) {
                        out.append(contentsOf: Array(String(Character(scalar)).utf8))
                    }
                default: out.append(escaped)
                }
            default:
                out.append(byte)
            }
        }
        throw error("unterminated string")
    }
}
