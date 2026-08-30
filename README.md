# Ration

A tiny native macOS menu-bar app that shows how hard you're leaning on Claude
Code, without leaving your desktop or running a terminal command.

This is an original build — architecture and every line of Swift were
written from scratch for this project. No code was copied from any existing
usage-monitor app.

## Why it looks the way it does

- **Menu bar item + native SwiftUI window (`MenuBarExtra`), not a custom
  edge-hover panel.** Apple already ships the idiom this kind of tool wants
  — click the icon, get a small floating window, click away to dismiss.
  Reimplementing that with a custom screen-edge overlay would add real
  complexity for a worse, less "at home on macOS" result.
- **No login, no network calls.** Claude Code already writes a full
  token-usage breakdown into its own local session transcripts
  (`~/.claude/projects/**/*.jsonl`) on every turn. Ration just reads those.
  That means zero auth flow, nothing that can leak a token, and nothing that
  depends on an undocumented vendor API staying stable.

## Honest scope of what it shows

- **Ring = usage against a budget you set**, not Anthropic's actual plan
  ceiling. That real number isn't published anywhere Ration (or anything
  else running locally) can read. The ring is a personal pacing target —
  set it in Settings, default is 2M tokens per rolling 5-hour window.
- **"This 5h window"** mirrors the shape of Claude's actual rate-limit
  windows, but the *contents* are only what Ration can see in your local
  logs — reliable for solo usage, not a source of truth for team billing.
- **Burn rate** is tokens/minute over the trailing 15 minutes, used to
  estimate "time left at current pace" against your budget.
- **Top projects** breaks down the current window by working directory, so
  you can see what's actually eating your budget.

## Provider support

Only Claude Code today, on purpose — its local transcripts are structured,
undocumented-API-free, and low risk to depend on. Codex and Cursor were
investigated but don't expose comparable local usage data without either
reverse-engineering a private endpoint or parsing opaque encrypted local
storage — both were out of scope for a first pass.

Adding a provider means writing one type that conforms to `UsageProvider`
(see `Sources/Ration/Providers/`) — the aggregation, ring, burn-rate math,
and UI are all provider-agnostic already.

## Build & run

Requires Xcode 16 / Swift 6 toolchain (already on this machine) and macOS 13+.

```bash
cd Ration
swift build            # or: swift run
./.build/debug/Ration &
```

It installs no Dock icon — look for the ring in the menu bar. Quit from the
"Quit Ration" item inside the popover.

This is a Swift Package executable, not a code-signed `.app` bundle yet, so
"Launch at login" may silently fail to register (macOS is stricter about
that for unsigned binaries) — packaging into a proper signed `.app` is the
natural next step before daily-driving this.

## Layout

```
Sources/Ration/
  RationApp.swift          entry point (MenuBarExtra)
  AppDelegate.swift         hides the Dock icon
  AppState.swift             refresh loop, glues everything together
  Models/                    UsageSample, UsageSnapshot
  Providers/                 UsageProvider protocol + ClaudeCodeLogProvider
  Services/                  aggregation, budget persistence, login item
  Views/                     RingView, popover, settings, project rows
```

## Roadmap ideas (not built)

- Package as a signed `.app` with a proper icon and DMG.
- Second real provider once a safe local data source turns up.
- Historical view (today vs. yesterday, weekly trend).
- Optional `ration status --json` companion for scripting/status-bar tools.
