//
//  JQOutput.swift
//  JSONQuery
//
//  Reads jq's output and error text.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// Reads jq's standard output and standard error.
enum JQOutput {
    /// How many values jq's JSON output holds. Each value starts at column 0; pretty output
    /// indents everything inside it except the closing bracket, and JSON output never holds a raw
    /// newline inside a string — so a value starts on every non-empty line not beginning with a
    /// space, `}` or `]`. Compact output (a value a line) never starts a line with those either.
    static func count(_ output: String) -> Int {
        output.split(separator: "\n", omittingEmptySubsequences: true).count { line in
            !(line.first == " " || line.first == "}" || line.first == "]")
        }
    }

    /// The failure jq's standard error and exit status describe, nil when there is none. The
    /// first `jq: error` or `jq: parse error` line decides; jq's own prefix is removed.
    static func failure(stderr: String, status: Int32) -> JSONQueryFailure? {
        for line in stderr.split(separator: "\n").map(String.init) {
            if let rest = line.dropPrefix("jq: error: ") { return status == 3 ? .query(rest) : .runtime(rest) }
            if line.hasPrefix("jq: error (at "), let close = line.range(of: "): ") {
                return .runtime(String(line[close.upperBound...]))
            }
            if let rest = line.dropPrefix("jq: parse error: ") { return .input(rest) }
        }
        guard status != 0 else { return nil }
        let first = stderr.split(separator: "\n").first.map(String.init) ?? ""
        return status == 3 ? .query(first) : .runtime(first)
    }
}

extension String {
    /// The rest after `prefix`, nil when the string does not start with it.
    fileprivate func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
