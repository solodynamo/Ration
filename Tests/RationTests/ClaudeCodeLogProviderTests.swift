import XCTest
@testable import Ration

final class ClaudeCodeLogProviderTests: XCTestCase {
    private var tempHome: URL!

    override func setUpWithError() throws {
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("RationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
    }

    private func writeProjectFile(dirName: String, fileName: String, lines: [String]) throws {
        let dir = tempHome.appendingPathComponent(".claude/projects/\(dirName)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }

    private func assistantLine(timestamp: String, sessionId: String, input: Int, output: Int, cacheRead: Int = 0, cacheWrite: Int = 0, cwd: String? = nil, gitBranch: String? = nil) -> String {
        let cwdField = cwd.map { "\"cwd\":\"\($0)\"," } ?? ""
        let branchField = gitBranch.map { "\"gitBranch\":\"\($0)\"," } ?? ""
        return """
        {"type":"assistant",\(cwdField)\(branchField)"timestamp":"\(timestamp)","sessionId":"\(sessionId)","message":{"usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_read_input_tokens":\(cacheRead),"cache_creation_input_tokens":\(cacheWrite)}}}
        """
    }

    func testReturnsNoSamplesWhenClaudeDirectoryMissing() throws {
        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        XCTAssertFalse(provider.isAvailable())
        XCTAssertTrue(try provider.fetchSamples(since: .distantPast).isEmpty)
    }

    func testParsesAssistantTurnsAndSumsUsage() throws {
        try writeProjectFile(
            dirName: "-Users-me-Documents-github-myrepo",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2026-01-01T10:00:00.000Z", sessionId: "s1", input: 10, output: 20, cacheRead: 5, cacheWrite: 3),
                "{\"type\":\"attachment\",\"timestamp\":\"2026-01-01T10:01:00.000Z\"}", // non-assistant, ignored
                "not even json", // malformed, ignored
                assistantLine(timestamp: "2026-01-01T10:02:00.000Z", sessionId: "s1", input: 1, output: 2)
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let samples = try provider.fetchSamples(since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].project, "myrepo")
        XCTAssertEqual(samples[0].totalTokens, 10 + 20 + 5 + 3)
        XCTAssertEqual(samples[1].totalTokens, 1 + 2)
        // Oldest-first ordering.
        XCTAssertLessThan(samples[0].timestamp, samples[1].timestamp)
    }

    func testFiltersOutSamplesBeforeSinceCutoff() throws {
        try writeProjectFile(
            dirName: "-Users-me-repo",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2020-01-01T00:00:00.000Z", sessionId: "old", input: 100, output: 0),
                assistantLine(timestamp: "2099-01-01T00:00:00.000Z", sessionId: "future", input: 50, output: 0)
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let since = Date(timeIntervalSince1970: 1_600_000_000) // 2020-09-13
        let samples = try provider.fetchSamples(since: since)

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.sessionId, "future")
    }

    func testPrefersRealCwdOverLossyHyphenatedDirectoryName() throws {
        // Real folder name contains a hyphen, so the encoded directory name
        // ("-Users-me-Documents-github-my-cool-app") is ambiguous: naively
        // reading the last dash-separated segment would give "app", not
        // "my-cool-app". A git repo lives at the real cwd, so it should be
        // recognized as a genuine project under its real name.
        let repoDir = tempHome.appendingPathComponent("Documents/github/my-cool-app")
        try FileManager.default.createDirectory(at: repoDir.appendingPathComponent(".git"), withIntermediateDirectories: true)

        try writeProjectFile(
            dirName: "-Users-me-Documents-github-my-cool-app",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2026-01-01T10:00:00.000Z", sessionId: "s1", input: 10, output: 20, cwd: repoDir.path)
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let samples = try provider.fetchSamples(since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].project, "my-cool-app")
    }

    func testGroupsNonGitContainerDirectoriesUnderOther() throws {
        // Claude Code launched directly in a generic container folder, not
        // inside any actual project — should not masquerade as one.
        let containerDir = tempHome.appendingPathComponent("Documents/github")
        try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)

        try writeProjectFile(
            dirName: "-Users-me-Documents-github",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2026-01-01T10:00:00.000Z", sessionId: "s1", input: 10, output: 20, cwd: containerDir.path)
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let samples = try provider.fetchSamples(since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].project, "Other")
    }

    func testCapturesGitBranchPerTurn() throws {
        try writeProjectFile(
            dirName: "-Users-me-repo",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2026-01-01T10:00:00.000Z", sessionId: "s1", input: 10, output: 20, gitBranch: "feature/x"),
                assistantLine(timestamp: "2026-01-01T10:01:00.000Z", sessionId: "s1", input: 5, output: 5) // no branch recorded
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let samples = try provider.fetchSamples(since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].gitBranch, "feature/x")
        XCTAssertNil(samples[1].gitBranch)
    }

    func testDetachedHeadIsNotShownAsARealBranch() throws {
        // Git reserves "HEAD" — no branch can actually be named that. A
        // gitBranch of "HEAD" means detached HEAD (e.g. mid-rebase), and
        // should never be presented as if it were a sibling of "main".
        try writeProjectFile(
            dirName: "-Users-me-repo",
            fileName: "abc.jsonl",
            lines: [
                assistantLine(timestamp: "2026-01-01T10:00:00.000Z", sessionId: "s1", input: 10, output: 20, gitBranch: "HEAD")
            ]
        )

        let provider = ClaudeCodeLogProvider(homeDirectory: tempHome)
        let samples = try provider.fetchSamples(since: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(samples.count, 1)
        XCTAssertNotEqual(samples[0].gitBranch, "HEAD")
        XCTAssertEqual(samples[0].gitBranch, "(detached)")
    }
}
