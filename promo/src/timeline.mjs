// One source of truth for rendering, beat alignment and workbench import.
export const FPS = 30;
export const BPM = 130;
export const SOURCE_BEAT0 = 0.0023;
export const OUTPUT_AUDIO_OFFSET_F = 1.28; // measured2048samples @48k AAC/MP4, see render-audio-audit.md
export const beatF = n => Math.round((SOURCE_BEAT0+n*60/BPM)*FPS);
/** @type {[string,number,number,string,string][]} */
const definitions=[
 ['intro',0,12,'Clipboard Master','复制过的，随时找回。'],
 ['history',12,24,'文字、图片，\n一起收好。','最近 200 条，按需找回。'],
 ['search',24,40,'搜得到，\n也拿得回。','点一下复制，再回到原应用粘贴。'],
 ['images',40,48,'截图，\n也在这里。','图片预览 · 本地文件定位'],
 ['updates',48,56,'更新状态，\n看得明白。','检查中有反馈，失败可重试。'],
 ['local',56,64,'历史留在本机','不需要账号，不上传剪贴板内容。'],
 ['outro',64,80,'Clipboard Master','让每一次复制，都有下文。']
];
export const SHOTS=definitions.map(([id,start,end,title,subtitle])=>({id,beats:[start,end],from:beatF(start),duration:beatF(end)-beatF(start),title,subtitle}));
export const TOTAL=beatF(80);
const S=Object.fromEntries(SHOTS.map(s=>[s.id,s]));
const peak={'transition-soft.mp3':.453877551,'whoosh-fast.mp3':.721564626,'swoosh-quick.mp3':.295646259,'click-camera.mp3':.1938322,'impact-deep-whoosh.mp3':.629297052,'shimmer-sparkle-sweep.mp3':.9132,'riser-soft.mp3':1.0351};
const hit=(target,src,volume,duration,note)=>({target,from:Math.max(0,Math.round(target-peak[src]*FPS-OUTPUT_AUDIO_OFFSET_F)),src:`audio/${src}`,volume,duration,note});
export const SFX=[
 hit(S.intro.from+48,'whoosh-fast.mp3',.20,53,'single pony card rises'),
 hit(S.intro.from+64,'shimmer-sparkle-sweep.mp3',.14,80,'single perimeter beam begins'),
 hit(S.intro.from+130,'swoosh-quick.mp3',.18,24,'pony returns to its slot'),
 hit(S.history.from+12,'transition-soft.mp3',.18,39,'native history reveal'),
 hit(S.search.from+12,'transition-soft.mp3',.16,39,'move into search'),
 {from:Math.round(S.search.from+40-OUTPUT_AUDIO_OFFSET_F),src:'audio/keyboard.mp3',volume:.27,duration:32,note:'only the search typing interval',target:S.search.from+44},
 hit(S.search.from+130,'click-camera.mp3',.48,11,'click matching clipboard result'),
 hit(S.images.from+12,'swoosh-quick.mp3',.18,24,'image detail handoff'),
 hit(S.updates.from+48,'click-camera.mp3',.36,11,'check update result confirmed'),
 hit(S.local.from+12,'transition-soft.mp3',.18,39,'local storage promise'),
 hit(S.outro.from+42,'riser-soft.mp3',.28,53,'outro gathering builds'),
 hit(beatF(68),'impact-deep-whoosh.mp3',.34,122,'wordmark stage peak'),
 hit(S.outro.from+92,'shimmer-sparkle-sweep.mp3',.18,100,'outro rule and CTA settle')
];
