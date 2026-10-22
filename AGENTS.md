# Swift JSON Query

The engine for a jq tool panel: a query run over JSON with the system's `jq`, fenced (no environment, no code but the query, a time and an output limit), its output counted and its failures sorted by fault. Never throws.

- Module `JSONQuery` in `Sources/JSONQuery`; tests in `Tests`; `swift test` is the whole check (it needs `/usr/bin/jq`, which macOS 15+ ships, and skips without it).
- Swift 6 language mode, tools 6.2, macOS 14+; depends on swift-foundation-extensions' `ProcessRunner` only.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Core/` — the engine: JSONQuery (`run`, `arguments(for:options:)`, the fence)
- `Enums/` — JSONQueryFailure (query / runtime / input / timedOut / unavailable, with jq's words)
- `Models/` — value types: JSONQueryOptions (`.compact`, `.rawStrings`), JSONQueryResult
- `Support/` — JQOutput (counting values in jq's output; reading its error text into a failure)

## The fence, and why each part is there (measured against jq 1.7.1, 22 Oct 2026)

- **`HOME=/var/empty`.** jq loads `~/.jq` as code. `-L` does not stop that, and with `HOME` unset jq falls back to the account's own home folder — so `HOME` is set, to a folder only the system writes.
- **Working directory `/var/empty`.** A relative `import "./x"` and a bare `import "x"` read jq's working directory, which is otherwise the app's.
- **`-L /var/empty`.** Replaces the module search path, which for a jq outside `/usr/bin` includes `lib/jq` beside its folder (`/opt/homebrew/lib/jq`), writable by the user. jq takes that folder from the path it was started by; the test uses a link, since macOS kills a copied system binary.
- **Empty environment otherwise.** `env` / `$ENV` show only `HOME`.
- **`--` before the query.** `-.a` and `--arg` are queries.
- **2 s and 1 MB.** ProcessRunner's `timeout` and `outputLimit`; a cut-off output is not counted.

Each part has a test that fails without it (mutation-checked).

## Rules

Read `CONTRIBUTING.md` for the folder layout and the pull-request rules.

@CONTRIBUTING.md

- **Auditing? Read `AUDIT.md` first** — what the last full audit checked and fixed, and the known non-issues to skip; extend it, do not redo it.
