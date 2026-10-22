//
//  JSONQueryTests.swift
//  JSONQueryTests
//
//  Queries run through the system jq: results counted, jq's errors sorted by fault, and the
//  fences — no environment, no modules, a time and an output limit — holding.
//
//  Created by David Sherlock on 10/22/26.
//  Copyright © 2026 ArrayPress Limited. MIT licence.
//

import XCTest
@testable import JSONQuery

final class JSONQueryTests: XCTestCase {
    private func run(_ query: String, _ json: String, _ options: JSONQueryOptions = [], timeout: TimeInterval = 2, limit: Int = 1 << 20)
        -> JSONQueryResult
    {
        JSONQuery.run(query, on: Data(json.utf8), options: options, timeout: timeout, outputLimit: limit)
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: JSONQuery.systemJQ), "this Mac has no /usr/bin/jq")
    }

    // MARK: - Results

    func testValuesAreWrittenAndCounted() {
        let r = run(".a[] | select(. > 1)", #"{"a":[1,2,3]}"#)
        XCTAssertEqual(r.output, "2\n3")
        XCTAssertEqual(r.count, 2)
        XCTAssertNil(r.failure)
        XCTAssertFalse(r.truncated)
    }

    func testPrettyValuesSpanningLinesCountOnce() {
        let r = run(".[]", #"[{"a":1},{"b":[1,[2]]},"}",[]]"#)
        XCTAssertEqual(r.count, 4, r.output)
        XCTAssertTrue(r.output.hasPrefix("{\n  \"a\": 1\n}"))
    }

    func testCompactWritesAValueALine() {
        let r = run(".[]", #"[{"a":1},{"b":[1,2]}]"#, .compact)
        XCTAssertEqual(r.output, "{\"a\":1}\n{\"b\":[1,2]}")
        XCTAssertEqual(r.count, 2)
    }

    func testRawStringsLoseTheirQuotesAndAreNotCounted() {
        let r = run(".[].name", #"[{"name":"Ada"},{"name":"Alan"}]"#, .rawStrings)
        XCTAssertEqual(r.output, "Ada\nAlan")
        XCTAssertNil(r.count)
    }

    func testNoResultsIsZero() {
        let r = run("empty", "{}")
        XCTAssertEqual(r.output, "")
        XCTAssertEqual(r.count, 0)
        XCTAssertNil(r.failure)
    }

    func testAQueryStartingWithAMinusIsAQueryNotAFlag() {
        XCTAssertEqual(run("-.a", #"{"a":2}"#).output, "-2")
        guard case .query = run("--arg", "{}").failure else { return XCTFail("read as a flag") }
    }

    // MARK: - Failures, by fault

    func testAQueryThatDoesNotCompileIsTheQuerysFault() {
        guard case .query(let message) = run(".a |", "{}").failure else { return XCTFail() }
        XCTAssertTrue(message.hasPrefix("syntax error"), message)
    }

    func testAFailureOnThisInputIsARuntimeOne() {
        XCTAssertEqual(run(".a.b", #"{"a":1}"#).failure, .runtime(#"Cannot index number with string "b""#))
    }

    func testValuesBeforeARuntimeFailureAreKept() {
        let r = run(".[] | .x", #"[{"x":1}, 2]"#)
        XCTAssertEqual(r.output, "1")
        XCTAssertEqual(r.count, 1)
        guard case .runtime = r.failure else { return XCTFail("\(String(describing: r.failure))") }
    }

    func testInputThatIsNotJSONIsTheInputsFault() {
        guard case .input(let message) = run(".", "not json").failure else { return XCTFail() }
        XCTAssertTrue(message.hasPrefix("Invalid"), message)
    }

    func testNoJQIsSaidSo() {
        XCTAssertEqual(JSONQuery.run(".", on: Data("{}".utf8), jq: "/nonexistent/jq").failure, .unavailable)
    }

    // MARK: - Fences

    func testTheQuerySeesNoEnvironment() {
        setenv("JSONQUERY_TEST_SECRET", "s3cret", 1)
        defer { unsetenv("JSONQUERY_TEST_SECRET") }
        XCTAssertEqual(run("$ENV.JSONQUERY_TEST_SECRET", "{}").output, "null")
        XCTAssertEqual(run("env | keys | join(\",\")", "{}", .rawStrings).output, "HOME", "only the fenced home")
        XCTAssertEqual(run("env.HOME", "{}", .rawStrings).output, "/var/empty")
    }

    func testAHomeDotJQIsNotLoaded() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("jqhome-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try "def secret: 42;".write(to: home.appendingPathComponent(".jq"), atomically: true, encoding: .utf8)
        let saved = ProcessInfo.processInfo.environment["HOME"]
        setenv("HOME", home.path, 1)
        defer { saved.map { setenv("HOME", $0, 1) } }
        guard case .query = run("secret", "{}").failure else { return XCTFail("~/.jq was loaded as code") }
    }

    /// A module in the folder the app was started in: jq reads a relative `import "./x"` from
    /// its working directory, and a bare `import "x"` searches it by default.
    func testModulesBesideTheAppAreNotImported() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("jqcwd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try #"def f: "LOADED";"#.write(to: folder.appendingPathComponent("x.jq"), atomically: true, encoding: .utf8)
        let saved = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(folder.path)
        defer { FileManager.default.changeCurrentDirectoryPath(saved) }
        for query in [#"import "./x" as x; x::f"#, #"import "x" as x; x::f"#, #"include "./x"; f"#] {
            let r = run(query, "{}")
            XCTAssertNotEqual(r.output, #""LOADED""#, query)
            guard case .query = r.failure else { return XCTFail("\(query) ran") }
        }
    }

    /// A jq outside `/usr/bin` (Homebrew's) searches `lib/jq` beside its own folder, which a user
    /// can write; the search path is replaced, so a module put there is not found. A link stands
    /// in for another jq: jq takes that folder from the path it was started by, and macOS kills
    /// a copied system binary.
    func testAModuleBesideAnotherJQIsNotImported() throws {
        let prefix = FileManager.default.temporaryDirectory.appendingPathComponent("jqprefix-\(UUID().uuidString)")
        let bin = prefix.appendingPathComponent("bin"), lib = prefix.appendingPathComponent("lib/jq")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: lib, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: prefix) }
        try FileManager.default.createSymbolicLink(atPath: bin.appendingPathComponent("jq").path, withDestinationPath: JSONQuery.systemJQ)
        try #"def f: "LOADED";"#.write(to: lib.appendingPathComponent("x.jq"), atomically: true, encoding: .utf8)
        let jq = bin.appendingPathComponent("jq").path
        XCTAssertEqual(JSONQuery.run(".a", on: Data(#"{"a":1}"#.utf8), jq: jq).output, "1", "the linked jq runs")
        guard case .query = JSONQuery.run(#"import "x" as x; x::f"#, on: Data("{}".utf8), jq: jq).failure else {
            return XCTFail("a module beside the jq was imported")
        }
    }

    func testAQueryThatNeverStopsWritingIsCutOff() {
        let start = Date()
        let r = run("repeat(1)", "null", limit: 10_000)
        XCTAssertTrue(r.truncated)
        XCTAssertEqual(r.output.utf8.count, 10_000)
        XCTAssertNil(r.count, "a cut-off output is not counted")
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testAQueryThatRunsTooLongIsStopped() {
        let start = Date()
        XCTAssertEqual(run("last(range(1e12))", "null", timeout: 0.5).failure, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }
}
