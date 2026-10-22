//
//  JSONQueryOptions.swift
//  JSONQuery
//
//  How a query's results are written.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// How a query's results are written: jq's `-c` and `-r`.
public struct JSONQueryOptions: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    /// Creates options from their raw bits.
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Each result on one line (`-c`).
    public static let compact = JSONQueryOptions(rawValue: 1 << 0)
    /// A string result written as its text, without quotes (`-r`); results are then not counted.
    public static let rawStrings = JSONQueryOptions(rawValue: 1 << 1)
}
