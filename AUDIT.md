# Audit log

Package created 22 Oct 2026. No full audit yet; the record below is what was checked when it was written.

## What a full audit checks

1. `swift build` warnings (none allowed) and `swift test` green.
2. Dead code: every declaration referenced somewhere in the package, the app or the family.
3. Risky patterns: `as!`, `try!`, `fatalError`, `print(` outside tests, TODO/FIXME left behind.
4. Docs drift: every name in AGENTS.md's module map exists; README Usage matches the API.
5. The fence, against the `jq` macOS ships: re-measure each part in AGENTS.md when jq's version changes.

## Known non-issues

- **Raw output (`-r`) is not counted.** Raw strings have no boundaries; `count` is nil by design.
- **Tests skip without `/usr/bin/jq`** (macOS 14). The engine reports `.unavailable` there.

## History

- 22 Oct 2026 — written. 17 tests. Mutants: 11 tried; 10 failed the tests, one survived and showed a dead branch
  (a separate counting rule for compact output, identical to the pretty one), which was removed. Found while
  writing: `-L` does not stop `~/.jq`; a relative `import "./x"` reads jq's working directory; a jq outside
  `/usr/bin` searches a user-writable folder beside it; jq 1.7.1 says `Cannot index number with string "b"`.
