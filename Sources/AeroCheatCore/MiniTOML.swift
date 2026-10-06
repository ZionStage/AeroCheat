import Foundation

/// A TOML value, reduced to what the cheatsheet needs: strings and arrays.
/// Anything else (numbers, booleans, inline tables, dates) is kept as raw text.
public indirect enum TOMLValue: Equatable {
    case string(String)
    case array([TOMLValue])
    case other(String)
}

/// One `key = value` pair with its fully qualified path (table header + dotted key).
public struct TOMLEntry: Equatable {
    public let path: [String]
    public let value: TOMLValue
}

public struct TOMLError: Error, Equatable, CustomStringConvertible {
    public let line: Int
    public let message: String

    public var description: String { "line \(line): \(message)" }
}

/// Minimal TOML reader: ordered key/value entries, `[table]` and `[[array]]` headers,
/// comments, basic/literal/multi-line strings and multi-line arrays.
/// It does not validate the whole TOML grammar; it only has to survive real AeroSpace configs.
public enum MiniTOML {
    public static func parse(_ text: String) throws -> [TOMLEntry] {
        var parser = Parser(Array(text.unicodeScalars))
        return try parser.parseDocument()
    }

    private struct Parser {
        let chars: [Unicode.Scalar]
        var pos = 0
        var line = 1

        init(_ chars: [Unicode.Scalar]) { self.chars = chars }

        var atEnd: Bool { pos >= chars.count }
        var current: Unicode.Scalar? { atEnd ? nil : chars[pos] }

        func peek(_ offset: Int = 0) -> Unicode.Scalar? {
            pos + offset < chars.count ? chars[pos + offset] : nil
        }

        func fail(_ message: String) -> TOMLError { TOMLError(line: line, message: message) }

        mutating func advance() {
            if current == "\n" { line += 1 }
            pos += 1
        }

        mutating func skipInlineSpace() {
            while let c = current, c == " " || c == "\t" { advance() }
        }

        mutating func skipComment() {
            if current == "#" {
                while let c = current, c != "\n" { advance() }
            }
        }

        /// Skips whitespace, newlines and comments.
        mutating func skipBlank() {
            while let c = current {
                if c == " " || c == "\t" || c == "\n" || c == "\r" {
                    advance()
                } else if c == "#" {
                    skipComment()
                } else {
                    break
                }
            }
        }

        mutating func parseDocument() throws -> [TOMLEntry] {
            var entries: [TOMLEntry] = []
            var tablePath: [String] = []
            while true {
                skipBlank()
                guard let c = current else { break }
                if c == "[" {
                    let isArrayOfTables = peek(1) == "["
                    pos += isArrayOfTables ? 2 : 1
                    tablePath = try parseKeyPath(until: "]")
                    guard current == "]" else { throw fail("unterminated table header") }
                    advance()
                    if isArrayOfTables {
                        guard current == "]" else { throw fail("unterminated array-of-tables header") }
                        advance()
                    }
                } else {
                    let key = try parseKeyPath(until: "=")
                    guard current == "=" else { throw fail("expected '=' after key") }
                    advance()
                    skipInlineSpace()
                    let value = try parseValue()
                    entries.append(TOMLEntry(path: tablePath + key, value: value))
                }
                skipInlineSpace()
                skipComment()
                if let c = current, c != "\n", c != "\r" {
                    throw fail("unexpected content after value")
                }
            }
            return entries
        }

        /// Parses `a.b."c d"` up to (not including) the terminator.
        mutating func parseKeyPath(until terminator: Unicode.Scalar) throws -> [String] {
            var parts: [String] = []
            while true {
                skipInlineSpace()
                guard let c = current else { throw fail("unexpected end of file in key") }
                if c == "\"" || c == "'" {
                    parts.append(try parseString())
                } else {
                    var bare = ""
                    while let b = current, isBareKeyScalar(b) {
                        bare.unicodeScalars.append(b)
                        advance()
                    }
                    if bare.isEmpty { throw fail("invalid key") }
                    parts.append(bare)
                }
                skipInlineSpace()
                if current == "." {
                    advance()
                } else if current == terminator {
                    return parts
                } else {
                    throw fail("invalid key")
                }
            }
        }

        func isBareKeyScalar(_ c: Unicode.Scalar) -> Bool {
            (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") || c == "_" || c == "-"
        }

        mutating func parseValue() throws -> TOMLValue {
            guard let c = current else { throw fail("missing value") }
            switch c {
            case "\"", "'":
                return .string(try parseString())
            case "[":
                return try parseArray()
            case "{":
                return .other(try parseInlineTable())
            default:
                var raw = ""
                while let b = current, b != "\n", b != "#", b != ",", b != "]", b != "}" {
                    raw.unicodeScalars.append(b)
                    advance()
                }
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { throw fail("missing value") }
                return .other(trimmed)
            }
        }

        mutating func parseArray() throws -> TOMLValue {
            advance() // [
            var items: [TOMLValue] = []
            while true {
                skipBlank()
                guard let c = current else { throw fail("unterminated array") }
                if c == "]" {
                    advance()
                    return .array(items)
                }
                items.append(try parseValue())
                skipBlank()
                if current == "," {
                    advance()
                } else if current != "]" {
                    throw fail("expected ',' or ']' in array")
                }
            }
        }

        /// Consumes a balanced `{ ... }` and returns its raw text.
        mutating func parseInlineTable() throws -> String {
            var depth = 0
            var raw = ""
            while let c = current {
                if c == "\"" || c == "'" {
                    raw += "\(c)" + (try parseString()) + "\(c)"
                    continue
                }
                if c == "{" { depth += 1 }
                if c == "}" { depth -= 1 }
                raw.unicodeScalars.append(c)
                advance()
                if depth == 0 { return raw }
            }
            throw fail("unterminated inline table")
        }

        /// Parses a basic, literal or multi-line string starting at the opening quote.
        mutating func parseString() throws -> String {
            guard let quote = current else { throw fail("expected string") }
            let isMultiline = peek(1) == quote && peek(2) == quote
            let isBasic = quote == "\""
            pos += isMultiline ? 3 : 1
            if isMultiline, current == "\n" { advance() } // first newline is trimmed
            var result = ""
            while let c = current {
                if c == quote {
                    if !isMultiline {
                        advance()
                        return result
                    }
                    if peek(1) == quote, peek(2) == quote {
                        pos += 3
                        return result
                    }
                }
                if c == "\n", !isMultiline { throw fail("unterminated string") }
                if c == "\\", isBasic {
                    advance()
                    guard let e = current else { break }
                    if isMultiline, e == "\n" || e == " " || e == "\t" || e == "\r" {
                        // Line-ending backslash: swallow the whitespace that follows.
                        while let w = current, w == "\n" || w == " " || w == "\t" || w == "\r" { advance() }
                        continue
                    }
                    switch e {
                    case "n": result += "\n"
                    case "t": result += "\t"
                    case "r": result += "\r"
                    case "b": result += "\u{8}"
                    case "f": result += "\u{C}"
                    case "\"": result += "\""
                    case "\\": result += "\\"
                    case "u", "U":
                        let length = e == "u" ? 4 : 8
                        var hex = ""
                        for _ in 0..<length {
                            advance()
                            if let h = current { hex.unicodeScalars.append(h) }
                        }
                        guard let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) else {
                            throw fail("invalid unicode escape")
                        }
                        result.unicodeScalars.append(scalar)
                    default:
                        throw fail("invalid escape sequence")
                    }
                    advance()
                    continue
                }
                result.unicodeScalars.append(c)
                advance()
            }
            throw fail("unterminated string")
        }
    }
}
