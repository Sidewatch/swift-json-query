//
//  JSONQueryFailure.swift
//  JSONQuery
//
//  What went wrong with a query, by whose fault.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation

/// What went wrong with a query, by whose fault, with jq's own words.
public enum JSONQueryFailure: Equatable, Sendable {
    /// The query does not compile: "syntax error, unexpected end of file".
    case query(String)
    /// The query compiled but failed on this input: "Cannot index number with "b"".
    case runtime(String)
    /// The input is not JSON: "Invalid numeric literal at line 1, column 4".
    case input(String)
    /// The query ran past its time and was stopped.
    case timedOut
    /// There is no `jq` to run.
    case unavailable

    /// jq's words for it; empty for the cases that have none.
    public var message: String {
        switch self {
        case .query(let m), .runtime(let m), .input(let m): m
        case .timedOut, .unavailable: ""
        }
    }
}
