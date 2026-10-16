# PLAN: SCYDE: Photo & Video Editor

## Status
- DONE, green in CI and checked in simulator screenshots:
  - Phase 0-1: pipeline, Core model, undo/redo, JSON store (tests pass).
  - Phase 2: design system and screens. Navigation is a tab bar (Edit, Templates, AI Lab, Projects, Me) plus Settings, modelled on the reference screenshots in SCYDE style.
  - Phase 3: CompositionBuilder + SXCompositor (Core Image) + AVPlayer preview with chase-seek; filmstrip thumbnails. Note: source AVURLAssets must stay alive or inserts fail with -11800; photos and empty tails use a generated blank clip.
  - Phase 5: export via AVAssetExportSession with the shared compositor, progress, cancel, save to Photos, share.
  - Tools: speed, text/captions layer, filters + adjust + auto enhance, Vision background removal, on-device auto captions, AutoCut (silence removal), music from Files, voice-over recording, voice effects, cover maker, built-in templates, photo editor, collage.
  - Phases 7-11: transform + eased keyframes with drag/pinch/rotate on the preview (LiveTransforms, no rebuild while dragging), overlay track import, six single-source transitions at cuts (fade, flash, zoom, blur, slide, spin), volume up to 200% with fade in/out ramps, real waveforms, chroma key (colour cube), SRT import/export. Core type is `ClipTransition` (SwiftUI already has `Transition`).
  - Phase 13 (part): Croatian localisation (hr.lproj Localizable + InfoPlist strings, `.loc` / `.locf` helpers); CI captures screenshots in Croatian.
  - Template library: 120 own recipes (20 categories x 6) with on-device rendered looping previews (Engine/TemplatePreviews.swift); recipes apply transitions, look, Ken Burns and title. CapCut or other third-party templates are not used (copyright).
  - Pexels stock videos with the user's free API key (Keychain), credited per clip.
  - Pro tools: text styles (24 fonts, 20 presets, colour, background, outline, shadow, glow, spacing, position) and 12 in / 12 out / 6 loop animations; stickers (emoji + SF Symbols, own track); 32 video effects; masks (linear, mirror, circle, rectangle, heart, star, feather, invert); crop, rotate 90°, flip; 16 blend modes + opacity for overlays; canvas ratio (8 formats) and background (blur, colour, gradient); 12 transitions; 31 looks; 12 adjust sliders; reverse; freeze frame; extract audio; beat detection, markers, snap to markers and cut to the beat; text-to-speech.
- NOT verified on a real device yet: gestures, microphone, speech recognition, Photos saving, export speed.
  - Speed curves (8 ramps), Vision stabilisation, true cross dissolve on an A/B main track, effect intensity ramps, animated masks, first-run onboarding, Metal-backed compositor context, downscaled photo decode with a bounded cache, screen kept awake and background time during export.
  - CI self test (`-scydeSelfTest YES`) checks the stabiliser against known jitter, the reverser on a growing bar, and text-to-speech output.

## Scope and honesty
- Target: every core feature of a CapCut-class editor, implemented natively. Not copied: CapCut name, logo, UI art, effect/template/music libraries (ByteDance IP and cloud services). We ship our own assets and let users import theirs.
- Cloud features (online music, template marketplace, generative video) are replaced by on-device equivalents or user import.
- Feather signs the unsigned IPA. A free Apple ID signature lasts 7 days, a paid developer account 1 year.

## Phases (one session each; green CI and screenshots before moving on)
| # | Phase | Acceptance |
|---|---|---|
| 0 | Pipeline + shell | Push to main -> `latest` release IPA installs via Feather, launches with the SCYDE icon and name; CI publishes screenshots |
| 1 | Core model, undo/redo, JSON store | `swift test` green in CI |
| 2 | Design system + Home + Editor shell (UI spec below) with import (PhotosPicker, copy to `Documents/Media`, durations via AVURLAsset) | Screenshots of Home/Editor/Export in dark and light match the spec; import works on device |
| 3 | Composition engine + preview player | 2+ clips play with audio, scrub is accurate and smooth |
| 4 | Timeline gestures: trim, move, split, snapping, pinch zoom, multi-track | Every gesture is one undo step |
| 5 | Export | 1080p MP4/HEVC plays in Photos, matches preview, progress + cancel |
| 6 | Clip tools: speed, reverse, freeze, volume, crop, rotate, flip, canvas | Each undoable and visible in export |
| 7 | Text, stickers, PiP, keyframes | Preview and export identical |
| 8 | Filters, adjust, effects, transitions (Metal / Core Image) | 12+ filters, 10+ adjusts, 10+ effects, 8+ transitions in export |
| 9 | Audio: music import, extract, voice-over, fades, waveform, voice effects, TTS | Voice-over in sync |
| 10 | Masks, blend modes, chroma key, background removal, stabilization | Person cutout on a 10 s clip |
| 11 | Auto captions (Speech, offline), caption styles, SRT | 60 s clip captioned offline |
| 12 | Photo editor and collage | End-to-end with export |
| 13 | Templates, onboarding, settings, HR/EN localization, performance | Meets targets below |
| 14 | Release: About (scyde.net, scyde.dev), privacy, versioning, Feather source JSON | Tagged release |

Targets: 1080p30 preview at 30 fps on iPhone 12; export at most 2x realtime at 1080p.

## UI/UX spec (Phase 2), the "best in the world" brief
Principles: one-handed, thumb zone, content first, chrome quiet, everything undoable, motion that explains. Dark default look, light supported, Auto follows system.

**Home**
- Header: `scyde.` wordmark left, appearance menu (Auto / Light / Dark) right as a 40 pt glass circle.
- Hero: Sora 38, "What are we making?" and one line of plain copy ("Cut video, shape photos, add sound. Everything stays on your phone."). Slow aurora background (gold glow top right, lavender bottom left), drifting 9 s ease-in-out.
- `01 · Format`: cards for 9:16, 16:9, 1:1, 4:5 drawn as proportional outlines; selected card gets the accent border and a soft glow.
- Primary CTA full width, 56 pt, accent gradient (gold on dark, violet on light), label "Create project".
- `02 · Projects`: 2-column grid of cards (aspect-shaped thumbnail, name, `0:12 · 9:16 · edited today`), context menu (Duplicate, Rename, Delete). Empty state: "Nothing here yet. Projects save automatically."
- Only show tools that work. No "coming soon" clutter and no fake demo data (fixtures only behind `-scydeDemo YES`).

**Editor** (portrait)
- Top bar: close (chevron), project name, Export pill (accent).
- Preview: canvas drawn at the project's aspect, 18 pt radius, centered in the free space; empty state with a big "Import media" button.
- Transport row: timecode in Doto (`0:03.12`) plus total in Geist Mono, big round Play/Pause (accent gradient), Undo/Redo.
- Timeline panel (~230 pt): CapCut-style fixed center playhead, content scrolls under it. Playhead is the model truth: `x(t) = centerX + (t - playhead) * pxPerSecond`. Implement with a custom drag gesture (not ScrollView, iOS 16 has no scroll position API): drag pans, release glides (ease-out task at 60 fps), pinch zooms. Ruler drawn with `Canvas` (step chosen from 0.5, 1, 2, 5, 10, 30, 60 s so ticks stay >= 56 px apart). Playhead: 2 pt accent line, knob on top, glow.
- Clips: 10 pt radius blocks. Video = brand lavender gradient, audio = gold tint, text = white tint, photo = light lavender. Label (icon + name) top-left, duration in mono bottom-left. 1.5 pt gaps. Selected clip: 2 pt accent stroke plus glow and two 14 pt trim handles; drag a handle to trim, drag the body to move. Snapping within 8 px to playhead, 0 and clip edges, with a light haptic on snap.
- Tool dock (bottom, scrollable): only working tools (Import, Split, Duplicate, Mute, Delete), 56 pt targets, accent when enabled, 35% opacity when disabled. New tools appear as phases land.
- Export sheet (`presentationDetents` medium/large): resolution segmented (720p, 1080p, 2K, 4K), fps chips (24, 25, 30, 50, 60), codec (H.264, HEVC), output size and estimated file size from `ExportSettings`, primary "Export" button. Until Phase 5 the button is disabled with a plain explanation.
- Motion: springs `response .35 damping .8` for selection, tool dock and sheets; no decorative animation in the editor; respect Reduce Motion.
- Haptics: light impact on snap and split, medium on delete, success on export done.
- Accessibility: Dynamic Type for Home, VoiceOver labels on every control, contrast of text on clips >= 4.5:1.
- Launch arguments for CI screenshots (UserDefaults argument domain): `-scydeDemo YES`, `-scydeTheme dark|light`, `-scydeScreen home|editor|export`, `-scydePlayhead <s>`, `-scydeSelect 1`.

## Risks
- No local compiler: keep phases small, read `ci-results` after every push, avoid clever generics.
- Compositor bugs are hard to debug blind: keep it tiny, test with golden frames in CI.
- Old phones: proxy media for 4K, cap preview resolution.
- Licensing: only own/CC0 assets; fonts here are SIL OFL.

## Prompt to paste into Claude Code (web)
"Read CLAUDE.md and PLAN.md. Enter plan mode. Do the next phase listed under Status. After each push, read SUMMARY.md and the screenshots from `ci-results` and iterate until the acceptance criteria pass."
