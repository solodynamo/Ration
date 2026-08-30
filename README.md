# Ration

![Latest release](https://img.shields.io/github/v/release/solodynamo/Ration)

A tiny native macOS menu-bar app that shows how hard you're leaning on Claude
Code, without leaving your desktop or running a terminal command.

### [⬇ Download Ration for Mac](https://github.com/solodynamo/Ration/releases/latest/download/Ration.dmg)

Universal binary — one file, works on Apple Silicon and Intel. That link
always points at the newest release, so it's safe to bookmark or share as-is.

Open the `.dmg`, drag Ration into Applications, then **right-click → Open**
the first time you launch it. It's ad-hoc signed rather than notarized (see
[Signing caveat](#ci--releases) below), so Gatekeeper needs that one-time
override instead of a plain double-click.

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

## Onboarding

Zero setup. On first launch Ration scans your existing local history, finds
your busiest 5-hour stretch over the last 14 days, pads it by 20%, and uses
that as your starting budget — nothing to type or paste in. A dismissible
banner in the popover says so the first time. Change it anytime from
Settings with a one-tap picker (no text field); doing so takes over
permanently and Ration stops recalibrating it.

## Honest scope of what it shows

- **Ring = usage against a budget**, not Anthropic's actual plan ceiling.
  That real number isn't published anywhere Ration (or anything else
  running locally) can read. The ring is a pacing target, auto-calibrated
  from your own history (see Onboarding) and adjustable in Settings.
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

## Testing & packaging

```bash
swift test                    # unit tests (aggregation, calibration, log parsing)
./Scripts/build_app.sh        # release build -> dist/Ration.app (ad-hoc signed)
./Scripts/smoke_test.sh       # launches the .app, checks it stays up + is Dock-less
./Scripts/make_dmg.sh         # dist/Ration.app -> dist/Ration.dmg
```

## CI / releases

- `.github/workflows/ci.yml` runs on every push/PR to `main`: build, unit
  tests, then a smoke-test launch of the packaged `.app`.
- `.github/workflows/release.yml` runs on any `vX.Y.Z` tag push: re-runs
  tests, builds a universal (arm64 + x86_64) `Ration.app`, wraps it in a
  `.dmg` named exactly `Ration.dmg`, and publishes it as a GitHub Release —
  the fixed filename is what makes the `/releases/latest/download/Ration.dmg`
  link in the Download section above permanent across every future version.
- Both run on GitHub-hosted `macos-15` runners, which are free for public
  repositories (no per-minute billing, unlike private repos) — this
  pipeline costs nothing as long as the repo stays public.
- **Signing caveat:** the `.dmg` is only ad-hoc signed. That's enough to
  launch locally but not enough to skip Gatekeeper's "unidentified
  developer" prompt on someone else's Mac (right-click > Open works around
  it). Real signing + notarization needs a paid Apple Developer Program
  membership ($99/yr) — not part of this pipeline, and a separate call to
  make later if this needs to feel fully "installed from the App Store"
  smooth for outside users.

## Layout

```
Sources/Ration/
  RationApp.swift          entry point (MenuBarExtra)
  AppDelegate.swift         hides the Dock icon
  AppState.swift             refresh loop, glues everything together
  Models/                    UsageSample, UsageSnapshot
  Providers/                 UsageProvider protocol + ClaudeCodeLogProvider
  Services/                  aggregation, budget persistence + calibration, login item
  Views/                     RingView, popover, settings, project rows
Tests/RationTests/          unit tests for the above
Scripts/                    build_app.sh, make_dmg.sh, smoke_test.sh
.github/workflows/          ci.yml (push/PR), release.yml (tag push)
```

## Roadmap ideas (not built)

- Real code signing + notarization (needs a paid Apple Developer account).
- A proper app icon.
- Second real provider once a safe local data source turns up.
- Historical view (today vs. yesterday, weekly trend).
- Optional `ration status --json` companion for scripting/status-bar tools.
