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

        let directoryFallback = file.deletingLastPathComponent().lastPathComponent
        // Session files nearly always carry one `cwd` throughout; memoize
        // per unique value instead of hitting the filesystem on every line.
        var resolvedNames: [String: String] = [:]
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

            let cwd = object["cwd"] as? String
            let projectName: String
            if let cwd, !cwd.isEmpty {
                if let cached = resolvedNames[cwd] {
                    projectName = cached
                } else {
                    let resolved = self.friendlyProjectName(cwd: cwd)
                    resolvedNames[cwd] = resolved
                    projectName = resolved
                }
            } else {
                projectName = self.legacyDirectoryName(directoryFallback)
            }

            let cacheCreation = usage["cache_creation"] as? [String: Any]
            let sample = UsageSample(
                id: UUID(),
                provider: .claudeCode,
                timestamp: timestamp,
                project: projectName,
                gitBranch: self.normalizedGitBranch(object["gitBranch"] as? String),
                sessionId: (object["sessionId"] as? String) ?? "unknown",
                inputTokens: usage["input_tokens"] as? Int ?? 0,
                outputTokens: usage["output_tokens"] as? Int ?? 0,
                cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                model: message["model"] as? String,
                cacheWrite1hTokens: cacheCreation?["ephemeral_1h_input_tokens"] as? Int ?? 0
            )
            results.append(sample)
        }
        return results
    }

    /// Claude Code names each project *directory* after the working
    /// directory path with slashes swapped for dashes, which is lossy for
    /// any real folder name that itself contains a hyphen — a repo named
    /// "my-app" round-trips as "-Users-me-my-app", and reading the name back
    /// off the last dash-separated segment gives "app", not "my-app". The
    /// transcript's own `cwd` field carries the real, unambiguous path, so
    /// prefer that; only fall back to the lossy directory-name split when a
    /// transcript line has no `cwd` at all.
    ///
    /// A `cwd` that isn't a git repo root (e.g. Claude Code launched
    /// directly in a container folder like ~/Documents/github rather than a
    /// project inside it) is grouped under "Other" instead of putting a
    /// misleadingly specific-looking name on what isn't really a project.
    private func friendlyProjectName(cwd: String) -> String {
        let cwdURL = URL(fileURLWithPath: cwd)
        let name = cwdURL.lastPathComponent
        guard !name.isEmpty else { return legacyDirectoryName(cwdURL.path) }
        let gitDir = cwdURL.appendingPathComponent(".git").path
        return FileManager.default.fileExists(atPath: gitDir) ? name : "Other"
    }

    private func legacyDirectoryName(_ dirName: String) -> String {
        let candidate = dirName.split(separator: "-").last.map(String.init) ?? dirName
        return candidate.isEmpty ? dirName : candidate
    }

    /// Git reserves the literal name "HEAD" — no real branch can ever be
    /// called that — so a `gitBranch` of exactly "HEAD" always means the
    /// repo was in a detached-HEAD state for that turn (e.g. mid-rebase, or
    /// a checkout of a specific commit), never an actual branch. Passing it
    /// through unchanged would show "HEAD" in the UI looking like a sibling
    /// of "main", which is exactly the confusing, wrong-looking thing this
    /// exists to avoid.
    private func normalizedGitBranch(_ branch: String?) -> String? {
        guard let branch, !branch.isEmpty else { return nil }
        return branch == "HEAD" ? "(detached)" : branch
    }
}
