# Draft render audio audit

**Result: source audio is correctly selected and intact; the render pipeline adds a common 1.28-frame lag. Correct centrally before final delivery.**

## Inputs and scope

- BGM draft: `out/draft-bgm.mp4`
- SFX-only draft: `out/draft-nobgm.mp4`
- Both:1108video frames,30fps,1920×1080; AAC LC48kHz stereo inMP4. At render,OUTPUT_AUDIO_OFFSET_F=0.
- Actual decoded audio was measured; no movie code or media was edited. Source/timeline/movie hashes and every probe are retained in the JSON.

## Common output offset

- Median SFX lag: **42.666667ms =1.28frames =2048samples@48kHz**.
- Median BGM lag: **42.666667ms =1.28frames**. Six separated BGM excerpts agree; local cut probes also agree.
- Eleven SFX probes with normalized correlation above0.8 span1.27–1.29frames. Intro whoosh and outro riser overlap other effects and have weak correlation, so they are reported but excluded from the common-lag estimate.
- This consistent delay is compatible with codec priming, but the measured offset—not a presumed encoder constant—is the basis of the correction.

| Probe | Sequence start frame | Measured lag frames | Correlation |
|---|---:|---:|---:|
| single pony card rises | 26 | 1.290 | 0.5236 |
| single perimeter beam begins | 37 | 1.270 | 0.8551 |
| pony returns to its slot | 121 | 1.270 | 0.9999 |
| native history reveal | 164 | 1.290 | 0.9998 |
| move into search | 330 | 1.280 | 0.9998 |
| only the search typing interval | 372 | 1.280 | 0.9988 |
| click matching clipboard result | 456 | 1.280 | 0.9901 |
| image detail handoff | 557 | 1.290 | 0.9999 |
| check update result confirmed | 707 | 1.290 | 0.9948 |
| local storage promise | 773 | 1.290 | 0.9998 |
| outro gathering builds | 897 | 1.280 | 0.1978 |
| wordmark stage peak | 923 | 1.290 | 0.9401 |
| outro rule and CTA settle | 951 | 1.280 | 0.9284 |

## Correction

Set **OUTPUT_AUDIO_OFFSET_F=1.28** and keep sourcebeat0=0.0023/BPM=130 unchanged. SFX use `round(target - sourcePeak*FPS - OUTPUT_AUDIO_OFFSET_F)`.

**Keyboard exception:** its entry currently bypasses `hit()`. Advance its original scheduled start by the same offset before final rounding; do not align the full19.6s source global peak. Short-window source peak is0.120770975s.

Current Main advances BGM by `round(offset)=1` frame. That leaves approximately **0.28frames/9.33ms**, small enough for cut tolerance; measure the final output again. Keep workbench audio start/trim behavior consistent.

## Musical cut residuals

Measured by cross-correlating each cut’s local BGM waveform against the mastered source, then mapping the stored source transient into the actual rendered audio. Errors below include visual frame quantization; they are not a claim of sub-frame visual rendering.

| Entering scene | Beat | Frame | Visual minus audible attack (frames) |
|---|---:|---:|---:|
| history | 12 | 166 | -1.504 |
| search | 24 | 332 | -1.657 |
| images | 40 | 554 | -1.189 |
| updates | 48 | 665 | -0.965 |
| local | 56 | 775 | -1.734 |
| outro | 64 | 886 | -1.502 |

- All six interior cuts satisfy≤3frames already; worst is **1.734frames early**. The systematic lag should still be corrected for tighter SFX targets.
- Opening frame0 cannot fully compensate a positive pipeline latency with ordinary nonnegative playback start; the first isolated SFX is later, so no forced frame0impact exists. The final end boundary is not an audible attack and is not mislabeled as a cut.

## Peak and loudness

| Version | Sample peak | True peak | Integrated loudness | Clipped samples |
|---|---:|---:|---:|---:|
| BGM+SFX | −7.989dBFS | −7.99dBTP | −23.30LUFS |0|
| SFX only | −9.627dBFS | −9.63dBTP | −28.31LUFS |0|

These are source input readings from the rendered MP4. Loudnorm was run only to a null sink; its normalized output readings were ignored. There is ample headroom. The mix is restrained rather than loud; no automatic gain boost was applied. Silence betweenSFX is intentional.

AAC decoded duration is36.992s versus visual36.933333s; trailing codec padding is recorded rather than confused with extra visual frames. Final listening-in-context and independent visual review remain separate checks.

## Recheck after correction

Render both versions again. Re-run separated SFX probes; their **actual target-peak residual**, not source-start lag itself, should be≤0.5frame after quantization. Confirm common source-start lag still matches the pipeline, cuts≤3frames, zero clipped samples, and identical workbench scheduling.
