import Foundation

/// Reads usage straight out of Claude Code's own local session transcripts
/// (`~/.claude/projects/**/*.jsonl`). Every assistant turn Claude Code writes
/// already carries a token-usage breakdown, so no network calls, no auth,
/// and nothing beyond what's already sitting on disk.
final class ClaudeCodeLogProvider: UsageProvider {
    let kind: ProviderKind = .claudeCode

    private let projectsRoot: URL
    private let isoFormatter: ISO8601DateFormatter

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.projectsRoot = homeDirectory
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFormatter = formatter
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: projectsRoot.path)
    }

    func fetchSamples(since: Date) throws -> [UsageSample] {
        guard isAvailable() else { return [] }

        var samples: [UsageSample] = []
        for file in transcriptFiles(modifiedSince: since) {
            samples.append(contentsOf: parse(file: file, since: since))
        }
        return samples.sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - File discovery

    private func transcriptFiles(modifiedSince: Date) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: projectsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values?.contentModificationDate, modified < modifiedSince {
                continue // can't contain anything newer than `since`
            }
            files.append(url)
        }
        return files
    }

    // MARK: - Parsing

    private func parse(file: URL, since: Date) -> [UsageSample] {
        guard let data = try? String(contentsOf: file, encoding: .utf8) else { return [] }

        let projectName = friendlyProjectName(for: file)
        var results: [UsageSample] = []

        data.enumerateLines { line, _ in
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  object["type"] as? String == "assistant",
                  let timestampString = object["timestamp"] as? String,
                  let timestamp = self.isoFormatter.date(from: timestampString),
                  timestamp >= since,
                  let message = object["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { return }

            let sample = UsageSample(
                id: UUID(),
                provider: .claudeCode,
                timestamp: timestamp,
                project: projectName,
                sessionId: (object["sessionId"] as? String) ?? "unknown",
                inputTokens: usage["input_tokens"] as? Int ?? 0,
                outputTokens: usage["output_tokens"] as? Int ?? 0,
                cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0
            )
            results.append(sample)
        }
        return results
    }

    /// Claude Code names each project directory after the working directory
    /// path with slashes swapped for dashes; turn that back into a short,
    /// readable label using the transcript's own `cwd` field when possible,
    /// falling back to the directory name.
    private func friendlyProjectName(for file: URL) -> String {
        let dirName = file.deletingLastPathComponent().lastPathComponent
        let candidate = dirName.split(separator: "-").last.map(String.init) ?? dirName
        return candidate.isEmpty ? dirName : candidate
    }
}
