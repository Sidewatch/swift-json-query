//
//  JSONQuery.swift
//  JSONQuery
//
//  Runs a jq query over JSON, fenced: no environment, no modules, a time and an output limit.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import Foundation
import ProcessRunner

/// Runs a jq query over JSON text with the system's `jq` (macOS 15 and later ship one at
/// `/usr/bin/jq`) and hands back what it wrote, counted, with jq's own error words.
///
/// A query is typed by a person, often pasted from an agent's script, so it is fenced (each part
/// measured against jq 1.7.1):
/// - **No environment.** jq's `env` and `$ENV` read the process environment, where an app may
///   hold tokens; the query sees only `HOME`.
/// - **No code but the query.** jq loads `~/.jq` as code — `-L` does not stop it, and with `HOME`
///   unset jq falls back to the account's own home — so `HOME` is `/var/empty`, an empty system
///   folder. A relative `import "./x"` reads jq's working directory, so jq runs in `/var/empty`
///   too. `-L /var/empty` replaces the module search path, which for a jq outside `/usr/bin`
///   includes a folder beside it (`/opt/homebrew/lib/jq`) that a user can write.
/// - **A time limit and an output limit.** `repeat(1)` never ends; `[range(1e8)]` is enormous.
///
/// Blocks for as long as the query runs (at most `timeout` plus the kill grace): call it off
/// the main thread.
public enum JSONQuery {
    /// Where macOS keeps its `jq`.
    public static let systemJQ = "/usr/bin/jq"
    /// An empty folder only the system writes: jq's home, working directory and module path.
    static let fence = "/var/empty"

    /// The output of `query` over `input`. A runtime failure after some values keeps them.
    public static func run(
        _ query: String, on input: Data, options: JSONQueryOptions = [],
        jq: String = systemJQ, timeout: TimeInterval = 2, outputLimit: Int = 1 << 20
    ) -> JSONQueryResult {
        guard FileManager.default.isExecutableFile(atPath: jq) else {
            return JSONQueryResult(output: "", count: nil, failure: .unavailable, truncated: false)
        }
        let result = ProcessRunner.run(
            jq, arguments(for: query, options: options), directory: URL(fileURLWithPath: fence, isDirectory: true), input: input,
            environment: ["HOME": fence], removing: Set(ProcessInfo.processInfo.environment.keys), augmentPATH: false,
            timeout: timeout, outputLimit: outputLimit)
        var output = result.outputText
        if !result.truncated, output.hasSuffix("\n") { output.removeLast() }
        let failure: JSONQueryFailure? =
            result.timedOut ? .timedOut : result.truncated ? nil : JQOutput.failure(stderr: result.errorText, status: result.status)
        let count = options.contains(.rawStrings) || result.truncated ? nil : JQOutput.count(output)
        return JSONQueryResult(output: output, count: count, failure: failure, truncated: result.truncated)
    }

    /// jq's arguments: the module fence, the options, then the query as one argument after `--`,
    /// so a query starting with `-` is never read as a flag.
    static func arguments(for query: String, options: JSONQueryOptions) -> [String] {
        var args = ["-L", fence]
        if options.contains(.compact) { args.append("-c") }
        if options.contains(.rawStrings) { args.append("-r") }
        return args + ["--", query]
    }
}
