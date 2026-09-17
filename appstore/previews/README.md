# App Previews (App Store videos)

Two iPhone 6.9″ App Previews, in en-US, fr-FR, de-DE and es-ES, filmed from the
real app in the simulator and edited automatically.

| File | Storyboard | Length |
|---|---|---|
| `out/preview-1-paste-<locale>.mp4` | **Paste it as written** — an appointment, a Wi-Fi card, a signature and an address each become their form (the change played in slow motion); ends on a gradient | 22 s |
| `out/preview-2-style-<locale>.mp4` | **Make it yours** — a link, two gradients, rounded modules and eyes, the logo and its caption, SVG at 4096 px | ~24 s |

Every file matches Apple's App Preview specification for the 6.9″ slot (which
also covers 6.7″ and 6.5″): 886×1920 portrait, H.264, 30 fps, stereo AAC 48 kHz
track, 15–30 s. The audio track is silent — Apple requires one; add music in
Final Cut Pro if you want it, it only plays once the viewer taps the preview.

**Upload:** App Store Connect → the version → *App Previews and Screenshots* →
iPhone 6.9″ → drag the files for each localization, then pick the poster frame
there (a still with the finished form or the styled code works best).

## Re-shooting (e.g. after a UI change)

```bash
./appstore/previews/shoot.sh              # all 8 videos (~40 min)
./appstore/previews/shoot.sh sb2 de       # one storyboard, one language
./appstore/previews/shoot.sh validate     # check the pasted examples still become forms
```

Requires ffmpeg, Python 3 with Pillow, SF Pro Display in `/Library/Fonts`, and
the "iPhone 17 Pro Max" simulator (override with `PREVIEW_DEVICE`). Scratch
files go to `PREVIEW_WORK` (default `/tmp/radicalqr-previews`).

## How it works

1. **A scratch copy of the project** gets `demo-hooks.patch`: two `#if DEBUG`
   hand-offs the UI test uses instead of controls it cannot operate. iOS's
   `PasteButton` is a secure control that ignores synthesized taps, so the test
   writes the text to a file and `LaunchCard` runs *the same assignment* the
   Paste button's closure runs. The Photos picker is replaced the same way for
   the logo. The repository itself is never modified.
2. **`uitests/`** drive each storyboard with XCTest and write a wall-clock mark
   before every visible action. `examples` in `DemoSupport.swift` holds the
   pasted text per language — each one checked to produce its form at *high*
   confidence (a contact needs the job title on the name's line, a website with
   a common TLD, nothing left over).
3. **`shoot.sh`** records the simulator (`simctl io recordVideo`) during the
   test. Parallel testing stays off: with it on, xcodebuild runs UI tests on a
   *clone* of the simulator and the recording films the idle original.
4. **`edit.py`** keeps, for each action, the frames that really changed between
   its mark and the next (ffmpeg scene score above noise), squeezes the pauses a
   busy machine inserts, holds the settled state, then composites the screen
   into the phone frame with the captions (`captions.json`, rendered by
   `assets.py` in the style of the store screenshots).
   In preview 1 each paste plays its change into the form at 0.55× (`SLOW`),
   after a pause on the appointment's text as pasted (`RAW_HOLD`); the encoded
   flashes the field passes through (`BEGIN:VEVENT`, `WIFI:T:…`) are cut, and the
   final holds shrink so the preview stays at 22 s (`TARGETS`). Wi-Fi, contacts
   and places show no raw text: the app re-encodes them before the first frame.

To change a caption, edit `captions.json` and re-run `edit.py sb1 fr` — no
re-shoot needed as long as `PREVIEW_WORK` still holds the recording.
