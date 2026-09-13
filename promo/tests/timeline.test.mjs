import test from 'node:test';
import assert from 'node:assert/strict';
import {SHOTS, TOTAL, FPS, beatF, SFX} from '../src/timeline.mjs';
test('one contiguous, beat-aligned seven-shot timeline',()=>{assert.equal(SHOTS.length,7);assert.equal(FPS,30);assert.equal(TOTAL,1108);assert.equal(new Set(SHOTS.map(s=>s.id)).size,7);SHOTS.forEach((s,i)=>{assert.equal(s.from,beatF(s.beats[0]));assert.ok(s.duration>90);if(i) assert.equal(s.from,SHOTS[i-1].from+SHOTS[i-1].duration)});assert.equal(SHOTS.at(-1).from+SHOTS.at(-1).duration,TOTAL)});
test('sound cues are bounded and explicitly trimmed',()=>{for(const cue of SFX){assert.ok(cue.from>=0);assert.ok(cue.duration>0);assert.ok(cue.from+cue.duration<=TOTAL);assert.ok(cue.volume>0&&cue.volume<=1);assert.ok(cue.note.length>0)}});
test('wordmark motion leaves at least a second of hold',()=>{assert.ok(SHOTS[0].duration-130>=30);assert.ok(SHOTS.at(-1).duration-150>=30)});
