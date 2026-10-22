# Swift JSON Query

The engine for a jq tool panel: run a jq query over JSON text with the system's `jq` and get back
what it wrote, how many values that is, and jq's own words when something is wrong — sorted by
whose fault it is (the query, this input, or the JSON). Never throws.

A query is something a person types or pastes from an agent's script, so every run is fenced:
no environment (jq's `env` and `$ENV` see only an empty `HOME`), no code but the query (no
`~/.jq`, no `import` from beside the app or beside the jq), a time limit and an output limit.

## Features

- **Results counted** — `JSONQuery.run(_:on:options:)` returns `output` as jq wrote it and `count`, the number of values in it (pretty or compact); raw strings are not counted
- **Failures by fault** — `.query` (does not compile), `.runtime` (failed on this input, after any values it wrote, which are kept), `.input` (not JSON), `.timedOut`, `.unavailable` (no `jq`)
- **Options** — `.compact` (`-c`) and `.rawStrings` (`-r`)
- **Fenced** — an empty environment except `HOME=/var/empty`; jq runs in `/var/empty` with `-L /var/empty`, so `~/.jq`, a relative `import "./x"` and a module beside a Homebrew jq are all out of reach (each measured against jq 1.7.1); the query is passed after `--`, so `-.a` is a query, not a flag
- **Bounded** — 2 seconds and 1 MB of output by default (`repeat(1)` is cut off, `truncated` says so)

## Requirements

- macOS 14+; a `jq` to run — macOS 15 and later ship one at `/usr/bin/jq`, the default
- Swift 6.2+ (Swift 6 language mode)
- Depends on swift-foundation-extensions' `ProcessRunner` (the family's one process launcher)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Sidewatch/swift-json-query.git", from: "0.1.0")
]
```

## Usage

```swift
import JSONQuery

let json = Data(#"{"orders":[{"id":1,"total":40},{"id":2,"total":95}]}"#.utf8)
let result = JSONQuery.run(".orders[] | select(.total > 50) | .id", on: json)
result.output    // "2"
result.count     // 1

switch JSONQuery.run(".orders |", on: json).failure {
case .query(let message)?: print("the query:", message)      // "syntax error, unexpected end of file …"
case .runtime(let message)?: print("on this input:", message)
case .input(let message)?: print("the JSON:", message)
case .timedOut?, .unavailable?, nil: break
}

JSONQuery.run(".orders[].id", on: json, options: [.compact]).output   // "1\n2"
```

Call it off the main thread: it waits for `jq` (at most the time limit plus half a second).

## For agents

Read `CONTRIBUTING.md` first: the folder layout and the PR rules. `swift test` is the whole
check, and a new test must fail before the change it covers. `AGENTS.md` carries a
module map and the fence's reasons (`CLAUDE.md` imports it).

## License

MIT — see [LICENSE](LICENSE).
