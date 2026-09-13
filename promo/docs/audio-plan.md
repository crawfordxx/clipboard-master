# Clipboard Master pony promo — audio plan

## Locked musical spine

- **Cat Walk — Arulo**, local Mixkit house track. Positive, driving electronic pulse; blue/ivory native-utility presentation should remain the protagonist. Music is a quiet bed, not a game-feedback layer. Contextual audition with the finished video remains required.
- Source: `$SHOTCRAFT_ROOT/assets/audio/bgm/cat-walk.mp3`.
- Delivered: `public/audio/bgm.mp3`.
- Source trim: **25.846153846153847 seconds**, original beat 56. Exported duration **37.100 seconds**; no tempo change, pitch change, looping, or mastering. Original file unchanged.
- Grid: **130 BPM**, **60/130 = 0.46153846153846156 seconds per beat**. Eight beats = 3.6923076923 seconds. The initial tracker fit was 129.996656 BPM; its phase was on an offbeat. Multiband waveform attacks establish the final quarter-note phase.
- First grid attack in the trimmed file: **0.0023 seconds**. `beatF(n) = Math.round((0.0023 + OUTPUT_AUDIO_OFFSET_SEC + n * (60 / 130)) * FPS)`.
- `OUTPUT_AUDIO_OFFSET_SEC = 0` is **unmeasured**, not an assurance of zero codec latency. Keep it separate from source phase; measure from the final render before delivery.
- Director's locked scene boundaries: **0 / 12 / 24 / 40 / 48 / 56 / 64 / 80** beats. The first two 12-beat scenes are the director's deliberate exception to 8-beat scene-length multiples; every cut remains beat-aligned. End: 36.9253769231 seconds; use 1108 frames at 30fps or 2216 at 60fps.
- Intro starts in the lower-density groove; fuller drum energy enters eight beats later, supporting the transition into native-history demonstration. Do not pulse the entire canvas every beat.

## Grid evidence

`beats.json` records floating-point source/output times, all three metrical candidates (65/130/260 BPM), all detected hits, RMS energy, scene boundaries, and coverage. The independently detected four-band transient union uses a 30ms match window. Selected-span result: 100% coverage, mean absolute error about 0.76ms, maximum 27.97ms, accumulated drift about 1.60ms. This is a **selected-span** assertion, not a whole-song grid claim. Sparse emphasis should use the actual stored transient, not only its interpolated grid point.

Method: librosa decoding and initial beat-track fit; HPSS inspection for resolving the offbeat/bass confusion; scipy third-order SOS bandpasses; 5ms RMS envelope, positive 5ms difference, unconstrained global peak detection. Kick candidates: 40–160Hz; snare: coincident 150–500Hz body and 1–3kHz face; hats: 6–14kHz. These are timbral candidates, not guaranteed isolated instruments. Bass can appear among low-band candidates.

An exploratory full-file script failed with `ValueError: attempt to get argmin of an empty sequence` after floating-point roundoff made a nearly silent squared-envelope sample negative. Corrected by flooring the smoothed power at zero before square root; the corrected command completed and is the method in `beats.json`.

## Sound vocabulary and alignment

Eight local assets are in `public/audio/`. Exact durations, measured 5ms-RMS peak lags, peaks, hashes, IDs and recommended gains are in `sfx-analysis.json`:

1. `transition-soft.mp3` — restrained scene transitions, Mixkit 2608.
2. `whoosh-fast.mp3` — the major window/card move only, Mixkit 1490.
3. `swoosh-quick.mp3` — small title/card entrance, Mixkit 166.
4. `keyboard.mp3` — **real laptop keyboard**, only during visible search typing, Mixkit 2531. Keep the full source intact; explicitly limit playback to the actual input duration (usually 0.8–1.2s).
5. `click-camera.mp3` — actual selection/confirmation, Mixkit 1133.
6. `riser-soft.mp3` — restrained outro approach, derived by reversing documented `whoosh-fast.mp3`, with short fades. The untraceable library `riser-cine.mp3` was not used.
7. `impact-deep-whoosh.mp3` — optional, one restrained outro landing, Mixkit 1143.
8. `shimmer-sparkle-sweep.mp3` — brief outro light tail only, Mixkit 2633. No decorative sound on every card.

SFX start rule: `Math.max(0, Math.round(targetPeakF - peak_lag_sec * FPS - OUTPUT_AUDIO_OFFSET_SEC * FPS))`. Keep targets relative to `SHOTS` or `beatF`, never unrelated absolute frame constants. For long keyboard source, use the peak within the selected short window, not the global 19-second file peak. No continuous typing under non-typing scenes. Use only actual visual actions. Riser → impact → soft light tail once at outro; no 24/7 sound, game bleeps, plucks or cartoon pops.

Provisional BGM gain: 0.20–0.26 (start 0.22), short entry fade 0.15–0.35s, last 2 beats fade to zero. This is a mix starting point, not a loudness measurement. SFX gains are asset-specific; mix must be auditioned and checked for clipping in the rendered video. Deliver BGM-on and BGM-off (SFX retained) from the same timeline.

## Provenance and permitted use

Verified 2026-09-13 against the local attribution ledger and current official Mixkit pages:

- [Cat Walk on the official House catalog](https://mixkit.co/free-stock-music/house/) identifies **Cat Walk by Arulo**. Original asset URL: `https://assets.mixkit.co/music/371/371.mp3`.
- [Mixkit license](https://mixkit.co/license/) applies separate Music and Sound Effects Free Licenses. The current music modal (`https://mixkit.co/license/modal/musicFree/`) permits commercial/noncommercial online videos, social posts and online ads; excludes TV/radio broadcasts, games, CDs/DVDs and standalone music remixes/rights-registration. This selection is for an online promo, not those excluded distribution channels.
- Current sound-effects modal (`https://mixkit.co/license/modal/sfxFree/`) permits modification within a larger end product, including commercial films and online videos. It prohibits standalone asset/stock/tool/template or source-file redistribution. **Do not publish this working audio folder as a reusable asset pack or bundled public source archive.** The finished audiovisual promo is the intended end product.
- [Official typing catalog](https://mixkit.co/free-sound-effects/type/) identifies “Typing on a laptop keyboard”. The old local ledger marked `keyboard.mp3` unresolved; this session recovered it by **exact SHA-256 match** to official asset 2531: `152f78c3bff50cf018654a66e5de0260bdbad45d87af6051725fa479c517bdf9`. Current official bytes were hashed in memory only. Local copy remains unchanged.
- The remaining six unchanged SFX have explicit IDs/URLs in `$SHOTCRAFT_ROOT/assets/audio/ATTRIBUTION.md`. The riser derives from the documented 1490 source. No untraceable BGM, pop, sparkle or cinematic-riser asset was selected.

## Actual processing

BGM trim: `ffmpeg -i SOURCE -af 'atrim=start=25.846153846153847:duration=37.1,asetpts=PTS-STARTPTS' -c:a libmp3lame -q:a 2 bgm.mp3`.

Derived riser: `ffmpeg -i whoosh-fast.mp3 -af 'areverse,afade=t=in:d=0.15,afade=t=out:st=1.55:d=0.2' -c:a libmp3lame -q:a 2 riser-soft.mp3`.

The other seven SFX are unchanged copies. No OS audio was played. Peak measurement does not substitute for listening to the final mix.

## Required render follow-up

1. Decode finished MP4 audio and compare it to BGM plus two or three sharp SFX with cross-correlation.
2. Record measured codec/container output offset; compensate centrally, never by rewriting source BPM/phase or moving individual beat numbers.
3. Verify every scene cut within 3 frames of measured musical attack (ideal ≤1.5); SFX corrected probe residual ≤0.5 frame. Report audio truth error separately from frame quantization.
4. Audit clipping/loudness and listen in context; preserve semantic keyboard/click windows and outro breathing room. No claim of completed render/audio alignment is made by this source-analysis report.

## Rehydrate ignored working audio locally

The source archive may include this text and the JSON manifests, but **not audio binaries**. Run from the promo project directory, after reviewing the current linked licenses. These URLs recreate the seven unchanged SFX and the two derived files; no secrets or accounts are required.

```sh
set -eu
mkdir -p public/audio
BGM_SOURCE=$(mktemp /tmp/clipboard-cat-walk.XXXXXX)
trap 'rm -f "$BGM_SOURCE"' EXIT HUP INT TERM
curl --fail --location 'https://assets.mixkit.co/music/371/371.mp3' --output "$BGM_SOURCE"
ffmpeg -v error -y -i "$BGM_SOURCE" \
  -af 'atrim=start=25.846153846153847:duration=37.1,asetpts=PTS-STARTPTS' \
  -c:a libmp3lame -q:a 2 public/audio/bgm.mp3
while read -r name id; do
  curl --fail --location "https://assets.mixkit.co/active_storage/sfx/$id/$id-preview.mp3" \
    --output "public/audio/$name.mp3"
done <<'ASSETS'
transition-soft 2608
whoosh-fast 1490
swoosh-quick 166
keyboard 2531
click-camera 1133
impact-deep-whoosh 1143
shimmer-sparkle-sweep 2633
ASSETS
ffmpeg -v error -y -i public/audio/whoosh-fast.mp3 \
  -af 'areverse,afade=t=in:d=0.15,afade=t=out:st=1.55:d=0.2' \
  -c:a libmp3lame -q:a 2 public/audio/riser-soft.mp3
```

Upstream files or encoding libraries may change: compare decoded duration and SHA-256 to the JSON manifests. If a downloaded unchanged SFX hash differs, stop and inspect provenance instead of silently assuming an identical asset. Re-encoded MP3 hashes can differ across FFmpeg/libmp3lame versions; remeasure phase and SFX peaks after rebuilding on another pipeline.

## Locked workbench-parity master (2026-09-13)

Main composition and workbench now share `public/audio/bgm-master.wav` at **constant 0.24 gain**. This supersedes the provisional live-envelope guidance above. Baked envelope: fade-in from frame 0 through frame 20; fade-out from frame 1063 through frame 1108 at 30fps. Total is `1108 / 30 = 36.93333333333333` seconds. This avoids workbench/export differences where its manifest only supports constant gain. No gain normalization, tempo or phase change was added; the 0.24 playback gain is not baked into the master.

Reproduce after rehydrating `bgm.mp3`:

```sh
ffmpeg -v error -y -i public/audio/bgm.mp3 \
  -af 'atrim=duration=36.93333333333333,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.6666666666666666,afade=t=out:st=35.43333333333333:d=1.5' \
  -ar 48000 -ac 2 -c:a pcm_s16le public/audio/bgm-master.wav
```

Observed exit status 0; ffprobe confirms **PCM signed 16-bit little-endian, 48,000Hz, 2 channels, 36.933333s**. Master SHA-256: `a8b3440a1ece9f957583f9c2827cea27af587d9b209ca5c1ef547586291c28ec`. The input `bgm.mp3` remains unchanged, SHA-256 `8fbed9f14b8ecedbe5426670de3e979ca86e6936526bc0609c1f1eb5c13c5381`. This working WAV is also excluded from public source archives. Final MP4 latency and mix still require rendered-output measurement.

## Final pipeline-aligned master

Draft cross-correlation established2048samples/48kHz=42.6666667ms=1.28frames output latency. `public/audio/bgm-aligned.wav` advances the mastered music by exactly2048samples, then appends2048zero-valued stereo samples. Main and workbench must both play this file **from frame0 at constant0.24**, with **no further BGM advance**. Workbench clamps negative audio starts; baking the alignment makes the two paths equivalent. SFX still use measured `OUTPUT_AUDIO_OFFSET_F=1.28` in their source-peak start calculation. Do not alter sourcebeat0/BPM.

Rehydrate after building `bgm-master.wav` using the preceding command:

```sh
ffmpeg -v error -y -i public/audio/bgm-master.wav \
  -af 'atrim=start_sample=2048,asetpts=PTS-STARTPTS,apad=pad_len=2048,atrim=end_sample=1772800' \
  -ar 48000 -ac 2 -c:a pcm_s16le public/audio/bgm-aligned.wav
```


Observed exit0; reopened WAV has1772800stereo frames,48kHz,PCM16,36.933333s. Byte-for-byte decoded PCM assertion confirms output excluding its last2048frames equals master starting at frame2048; all appended frames are zero. Both assertions passed. Master SHA256 remains `a8b3440a1ece9f957583f9c2827cea27af587d9b209ca5c1ef547586291c28ec`; aligned WAV SHA256 is `65ad50e259639cb3842d0ea63349e91c5b157f9c351685c495573e0c1346517c`. This derivation supersedes negative BGM Sequence scheduling and, like all working audio, stays outside public source archives. Final render latency recheck remains required.
