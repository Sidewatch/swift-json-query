//
//  JSONQueryResult.swift
//  JSONQuery
//
//  What a query produced.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What a query produced: its output as jq wrote it, how many values that is, and what went
/// wrong — a runtime failure can come after some values were written, so both can be set.
public struct JSONQueryResult: Equatable, Sendable {
    /// The results as jq wrote them, a trailing newline removed (a cut-off output is kept as cut).
    public let output: String
    /// How many values the output holds; nil for raw strings, which have no boundaries.
    public let count: Int?
    /// What went wrong, if anything.
    public let failure: JSONQueryFailure?
    /// True when the output passed the limit: `output` is its start.
    public let truncated: Bool

    /// A result from its parts.
    public init(output: String, count: Int?, failure: JSONQueryFailure?, truncated: Bool) {
        self.output = output
        self.count = count
        self.failure = failure
        self.truncated = truncated
    }
}
