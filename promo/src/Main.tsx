import React from 'react';
import {AbsoluteFill,Audio,Sequence,staticFile} from 'remotion';
import {COMPONENTS,COLORS,TITLE_SIZES} from './Scenes';
import {SHOTS,SFX,TOTAL} from './timeline.mjs';
export const ClipboardPromo:React.FC<{bgm?:boolean}>=({bgm=true})=><AbsoluteFill style={{backgroundColor:COLORS.bg}}>
 {SHOTS.map(s=>{const C=COMPONENTS[s.id as keyof typeof COMPONENTS];return <Sequence key={s.id} from={s.from} durationInFrames={s.duration}><C title={s.title} subtitle={s.subtitle} duration={s.duration} titleSize={TITLE_SIZES[s.id as keyof typeof COMPONENTS]}/></Sequence>})}
 {SFX.map((s,i)=><Sequence key={i} from={s.from} durationInFrames={s.duration}><Audio src={staticFile(s.src)} volume={s.volume}/></Sequence>)}
 {bgm?<Sequence from={0} durationInFrames={TOTAL}><Audio src={staticFile('audio/bgm-aligned.wav')} volume={.24}/></Sequence>:null}
</AbsoluteFill>;
