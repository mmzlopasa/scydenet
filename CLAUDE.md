# SCYDE: Photo & Video Editor (iOS)

Native iOS video and photo editor. Developer: SCYDE (https://scyde.dev). Product site: https://scyde.net.
Goal: functional parity with mainstream mobile editors (CapCut-class) using ONLY our own name, UI, assets and code.
Distribution: unsigned .ipa built by GitHub Actions, signed and installed on-device with Feather. No App Store.

## Identity
- Name: `SCYDE: Photo & Video Editor` (About, metadata). Home screen name: `SCYDE`.
- Bundle ID `dev.scyde.editor`. Min iOS 16.0. iPhone first.
- Repo: https://github.com/mmzlopasa/scydenet (PUBLIC).

## Environment rules (read first)
- Sessions run on Linux in the cloud. There is NO Xcode, NO Swift toolchain and NO simulator locally. You write Swift blind; the compiler is GitHub Actions on `macos-15`.
- The proxy blocks the Actions API (`gh run ...` fails). The feedback loop is instead:
  1. `git push` to `main` (workflow `.github/workflows/build.yml` runs).
  2. Wait ~6-10 min, then `git fetch origin ci-results && git show FETCH_HEAD:SUMMARY.md` (the clone is shallow, so use `FETCH_HEAD`, not `origin/ci-results`). Extract a screenshot with `git show FETCH_HEAD:screenshots/home-dark.png > /tmp/x.png`.
  3. That orphan branch holds `SUMMARY.md` (all `error:` lines), `core-tests.log`, `build-sim.log`, `build-device.log`, and `screenshots/*.png` (simulator captures of Home, Editor and Export in dark and light).
  4. Read the screenshots with the Read tool and judge the UI before reporting it done.
  5. The Checks API still works: `gh api repos/mmzlopasa/scydenet/commits/<sha>/check-runs`.
- The unsigned IPA is published as the prerelease `latest` on GitHub Releases (download in Feather).
- Never claim UI works unless a screenshot shows it. State plainly what was not verified.
- The Xcode project is generated from `project.yml` with XcodeGen; never commit `*.xcodeproj` or `Config/Info.plist`.
- Swift language mode is 5 (`SWIFT_VERSION: 5.0`) on purpose: strict concurrency errors are expensive when you cannot compile locally. Use `@MainActor` on view models; avoid iOS 17-only APIs (`@Observable`, `onChange` two-arg, `sensoryFeedback`, `scrollPosition`).
- The repo is PUBLIC. Never commit secrets, server config or the ScyHost PHP site source (`landing.zip` contains `includes/config.php` and API keys). Only design references are allowed in `reference/`.

## Stack
Swift, SwiftUI, AVFoundation (AVMutableComposition + custom AVVideoCompositing), Core Image + Metal, PhotosUI, Vision, Speech, AVAudioEngine. No third-party dependencies unless unavoidable.

## Layout
- `Core/` Swift package `SCYDECore` (Foundation only, unit-tested): Project/Track/Clip model, Editing ops (split, trim, move, delete, duplicate, volume), snapping, `History` (snapshot undo/redo + transactions for drags), Timecode, ExportSettings, ProjectStore (JSON).
- `App/` SwiftUI app: `DesignSystem/`, `Screens/`, `Engine/`, `Resources/` (fonts, asset catalog).
- `scripts/ci/` CI helpers. `.github/workflows/build.yml` CI.
- `reference/scyhost/site.css` the ScyHost stylesheet (source of the design tokens).

## Design system (match https://scyhost.com, real tokens from its CSS)
Fonts bundled as static TTF (SIL OFL): Sora (headings, Regular/SemiBold/Bold), Geist (UI, Regular/Medium/SemiBold), Geist Mono (numbers, labels), Doto Bold (dot-matrix timecode). PostScript names: `Sora-SemiBold`, `Geist-Medium`, `GeistMono-Regular`, `Doto-Bold`, etc.

| token | dark | light |
|---|---|---|
| bg | `#0D0F14` | `#EEF0F3` |
| surface / navy | `#14161D`, `#1A1D25`, `#262A35` | white at 60-85% |
| ink | `#F5F2FF` | `#12141A` |
| body | `#B8B4DD` | `#4A4670` |
| muted | `#8F8BBA` | `#6B678F` |
| line | `rgba(184,180,235,.13)` | `rgba(18,20,26,.12)` |
| brand | `#C4BBFF` (on-brand `#1B1530`) | `#5A49E6`, brand-2 `#4333BE` (on-brand white) |
| accent (CTA, playhead, selection) | gold `#FFD76A`, `#FFE7A0`, `#E9B84A` | violet `#5A49E6` -> `#4333BE` |
| ok / err / warn | `#8EF0C8` / `#FF9AA8` / `#FFC98A` | `#0C8A60` / `#C42A46` / `#A35A00` |

Radii 10 / 14 / 20 / 28. Card = vertical-ish gradient `white .10 -> .03 -> .055` with 1 px edge `white .14` and an inset top highlight `white .2`, big soft shadow (`0 22 50 -30 black .85`). Light cards: `white .86 -> .5 -> .7`, edge white. Ease `cubic-bezier(.22,1,.36,1)`. Wordmark `scyde.` (Sora Bold, trailing accent dot). Numbered section labels (`01 · Format`) in Geist Mono uppercase. Calm, plain copy, no fake stats or reviews.

## Working rules
- One phase from PLAN.md per session: plan mode, implement, push, read `ci-results`, fix until green, commit.
- Every phase has acceptance criteria; do not start the next until they pass.
- All edits go through `History.perform` (discrete) or `beginTransaction/revise/commitTransaction` (drags).
- Preview and export must use the same compositor.
- Clip `assetID` is a file name inside `Documents/Media`, never an absolute path (the container path changes on every sideload).
- No copyrighted assets, no CapCut/ByteDance names, icons, templates, fonts or sounds. Track assets in `ASSETS.md`.
- Commits end with the attribution lines from the session reminder.
