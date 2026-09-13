# Final audio review — PASS

## Verified result

- BGM alignment: six separated master-waveform probes return **0 samples residual** after baked2048-sample compensation.
- SFX target peaks: **maximum0.3445frame residual**, below0.5frame tolerance.
- Interior musical cuts: **maximum0.4542frame residual**, below3frame tolerance.
- Both versions use the same SFX timing: **0sample onset difference for every cue**. BGM-subtracted waveform correlation is≥**0.9939**. Independently encoded AAC mixes are not expected to be byte-identical.
- **Zero clipped samples** in both decoded renders. No new audio correction is required.

## Files audited

- BGM version: `out/clipboard-master-promo.mp4`
- SFX-only version: `out/clipboard-master-promo-nobgm.mp4`
- Pipeline:30fps,1108visualframes,AAC LC48kHz stereo,MP4. Source offsets and file hashes are in the companion JSON. Draft audit records were preserved.

## Measured SFX target residuals

| Cue | Target frame | Measured target residual (frames) | Mix/no-music waveform correlation |
|---|---:|---:|---:|
| single pony card rises | 48 | -0.0831 | 0.99836 |
| single perimeter beam begins | 64 | -0.3154 | 0.99796 |
| pony returns to its slot | 130 | +0.1494 | 0.99901 |
| native history reveal | 178 | -0.1137 | 0.99746 |
| move into search | 344 | -0.0937 | 0.99694 |
| only the search typing interval | 376 | -0.0869 | 0.99654 |
| click matching clipboard result | 462 | +0.1050 | 0.99392 |
| image detail handoff | 566 | +0.1394 | 0.99949 |
| check update result confirmed | 713 | +0.0850 | 0.99508 |
| local storage promise | 787 | -0.1137 | 0.99760 |
| outro gathering builds | 928 | +0.3444 | 0.99973 |
| wordmark stage peak | 942 | +0.1489 | 0.99964 |
| outro rule and CTA settle | 978 | -0.3354 | 0.99839 |

Each source was decoded, matched against the actual final SFX-only track with normalized cross-correlation, and its previously measured internal energy peak added to the recovered playback start. The source-start codec latency remains approximately1.28frames, but scheduled compensation now places the peaks on their intended visual targets.

Confidence note: eleven full-source probes correlate strongly. The overlapping intro whoosh was separately confirmed with an unoverlapped0.28s excerpt at0.99964correlation. The outro riser overlaps the stronger impact and has a quiet leading tail; its full-source correlation is0.197 and its nonoverlap confirmation0.438, both returning the same start. Its reported peak is therefore a **source-template mapped estimate**, corroborated by the independently measured common latency and cross-version waveform agreement, rather than an isolated loudness-peak measurement. Searchclick, transition and outroimpact provide independent separated high-confidence timing checks.

## Actual musical cut residuals

| Entering scene | Beat | Video frame | Video minus audible attack (frames) |
|---|---:|---:|---:|
| history | 12 | 166 | -0.2242 |
| search | 24 | 332 | -0.3773 |
| images | 40 | 554 | +0.0907 |
| updates | 48 | 665 | +0.3145 |
| local | 56 | 775 | -0.4542 |
| outro | 64 | 886 | -0.2222 |

Local mastered-BGM waveform templates locate the actual audio around every interior cut. Stored source transient times are then mapped into that decoded output. Visual frame rounding is reported separately in JSON; it is not confused with audio-analysis precision. The maximum0.4542frame error is within ordinary30fps nearest-frame quantization. Frame0 and finaltail are not mislabeled as independent musical cuts.

## Levels

| Version | Sample peak | True peak | Integrated loudness | Clipped samples |
|---|---:|---:|---:|---:|
| BGM+SFX | −7.496dBFS | −7.46dBTP | −23.30LUFS |0|
| SFX only | −9.580dBFS | −9.58dBTP | −28.30LUFS |0|

Loudnorm input measurements were read from a null-sink analysis only; no normalization or movie edits were made. There is ample peak headroom. Silence between action-specific effects is intentional. AAC decoded duration36.992s includes trailing codec padding; the visual duration stays36.933333s.

## Parity method and scope

Known aligned-master PCM×0.24 was shifted by measured2048-sample codec latency and subtracted from the BGM mix. The remaining waveform was compared with the SFX-only render in every cue window. All detected onsets agree to the48kHz sample; residual AAC quantization explains imperfect amplitude correlation. This verifies audio parity, not visual-frame parity.

Technical waveform review passed. No OS audio was played, no full-mix subjective listening claim is made, and no source/movie file was modified. Independent visual review and in-context listening remain distinct review activities.

## Final v3 / remux recheck — PASS

The v3 files include a visual-only S5 clipping fix. All13SFX onset probes were remeasured: **0sample difference from v2**, with target-peak error still≤0.3444frame. All six BGM waveform probes again show0sample residual. Existing beat-cut residuals therefore remain valid against the unchanged timeline. Both sample peaks and zero-clipping findings are unchanged.

The decoded48kHz stereo float32 PCM of `clipboard-master-promo-nobgm.mp4` is **byte-for-byte identical** to `nobgm-rendered.mp4` (14204928bytes). SHA256:bbc24775cdb9dfbcc291c7bd24a207a7bda226a75a81568d71d2db504d6efb8e. Thus the remux did not alter SFX samples or timing.

Current audited v3 movie SHA256 values:
- BGM:`0353189939bae1040aa053d9d880d205393a5c8b7e44b5d6ec02dd63ec01680d`
- No BGM:`ffa459b1f4b0a2ee13a19494de7e38826b8f7c917d6f1062d11dd7d9aa7eb6cf`

Companion JSON points to these actual v3 hashes and preserves prior v2 identities plus all new probes. No movie/source edits, subjective listening or OS audio playback were performed.
