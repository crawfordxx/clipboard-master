// Adapted for Clipboard Master from video-shotcraft recipes/demos (Apache-2.0).
// Changes: original pony identity, real native UI captures, blue/ivory palette,
// Chinese typography, screen geometry, shot-local timing and editable props.
import React from 'react';
import {AbsoluteFill,Img,interpolate,staticFile,useCurrentFrame,Easing} from 'remotion';
import {PageCam} from './lib/PageCam';

export const COLORS={bg:'#EDF5FC',ink:'#102A50',blue:'#2463D4',muted:'#526780',dark:'#122744',white:'#FFFFFF'};
export const FONT='-apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif';
export type SceneProps={title?:string;subtitle?:string;duration?:number;accent?:string;titleSize?:number};
const clamp={extrapolateLeft:'clamp',extrapolateRight:'clamp'} as const;
const tw=(f:number,a:number,b:number,x=0,y=1,ease=Easing.bezier(.3,0,.2,1))=>interpolate(f,[a,b],[x,y],{...clamp,easing:ease});
const fade=(f:number,d:number)=>Math.min(tw(f,0,8),tw(f,d-8,d,1,0));
const T=(name:string)=>staticFile(`textures/${name}.png`);
const Native:React.FC<{name:string;x:number;y:number;w:number;h:number;radius?:number;shadow?:boolean;style?:React.CSSProperties}>=({name,x,y,w,h,radius=0,shadow=false,style})=><Img src={T(name)} style={{position:'absolute',left:x,top:y,width:w,height:h,borderRadius:radius,boxShadow:shadow?'0 32px 70px #173c6829':undefined,...style}}/>;
const Copy:React.FC<{title:string;subtitle:string;tag?:string;x?:number;y?:number;w?:number;size?:number;dark?:boolean;accent?:string}>=({title,subtitle,tag,x=120,y=315,w=800,size=82,dark=false,accent=COLORS.blue})=><div style={{position:'absolute',left:x,top:y,width:w,fontFamily:FONT,color:dark?'#F7FAFE':COLORS.ink}}>{tag?<div style={{fontSize:34,fontWeight:600,letterSpacing:2,color:dark?'#A6C7FF':accent,marginBottom:30}}>{tag}</div>:null}<div style={{fontSize:size,fontWeight:700,lineHeight:1.22,letterSpacing:-2,whiteSpace:'pre-line'}}>{title}</div><div style={{fontSize:38,fontWeight:500,lineHeight:1.55,color:dark?'#CCDCEC':COLORS.muted,marginTop:38}}>{subtitle}</div></div>;
const Stage:React.FC<{children:React.ReactNode;dark?:boolean;style?:React.CSSProperties}>=({children,dark=false,style})=><AbsoluteFill style={{fontFamily:FONT,background:dark?COLORS.dark:'radial-gradient(ellipse at 25% 25%,#FFFFFF,#EDF5FC 70%)',overflow:'hidden',...style}}>{children}</AbsoluteFill>;
const CenteredNativeCamera:React.FC<{children:React.ReactNode;frame:number;dark?:boolean;cx?:number;cy?:number;endCx?:number;endCy?:number;zoom?:number;endZoom?:number;end?:number;rot?:number}>=({children,frame,dark=false,cx=960,cy=540,endCx=cx,endCy=cy,zoom=1,endZoom=zoom,end=80,rot=0})=><PageCam src={`textures/stage-${dark?'dark':'light'}.svg`} pageH={1080} frame={frame} keys={[{frame:0,cx,cy,zoom,rotY:rot,rotX:0,persp:1600},{frame:end,cx:endCx,cy:endCy,zoom:endZoom,rotY:0,rotX:0,persp:1600}]}>{children}</PageCam>;

export const IntroScene:React.FC<SceneProps>=({title='Clipboard Master',subtitle='复制过的，随时找回。',duration=166,accent=COLORS.blue,titleSize=96})=>{
 const f=useCurrentFrame();
 // Exact source motion intervals: rise10f, hover54f, reseat18f, last36f hold.
 const rise=tw(f,48,58,0,1,Easing.bezier(.2,1.25,.3,1));
 const reseat=tw(f,112,130,0,1,Easing.bezier(.4,0,.3,1.05));
 const lift=rise*(1-reseat);const bob=Math.sin((f-58)/40*Math.PI*2)*4*lift;
 const press=interpolate(f,[126,129,130],[1,.997,1],clamp);
 const tilt=tw(f,32,48,0,34)*(1-tw(f,112,130));
 const spotX=interpolate(f,[4,8,16,22,28,48],[25,25,70,42,28,26],clamp);
 const spotY=interpolate(f,[4,8,16,22,28,48],[30,30,45,60,55,50],clamp);
 const on=tw(f,2,10)*(1-tw(f,116,130));
 const lap1=f>=59&&f<=75,lap2=f>=79&&f<=101;
 const lp=lap1?tw(f,60,74,0,1,Easing.linear):tw(f,80,100,0,1,Easing.bezier(.4,0,.4,1));
 return <Stage style={{opacity:fade(f,duration)}}><AbsoluteFill style={{background:`radial-gradient(600px 460px at ${spotX}% ${spotY}%,#FFFFFFCC,#EDF5FC00 70%)`,opacity:on}}/>
  <div style={{position:'absolute',left:160,top:225,width:600,height:600,borderRadius:80,background:'#DDECF8',border:`2px solid ${accent}22`}}/>
  <div style={{position:'absolute',left:160,top:225,width:600,height:600,transform:`perspective(1500px) translateY(${-22*lift-bob}px) rotateY(${tilt}deg) rotateX(${8*lift}deg) translateZ(${110*lift}px) scale(${press})`,transformStyle:'preserve-3d'}}>
   <div style={{position:'absolute',inset:0,borderRadius:80,overflow:'hidden',boxShadow:`0 ${14+8*lift}px ${28+12*lift}px #102A5014,0 ${30+46*lift}px ${65+90*lift}px #102A5025`}}><Img src={staticFile('brand/pony-master.png')} style={{width:'100%',height:'100%'}}/>
   {(lap1||lap2)&&lift>.4?<svg width="600" height="600" style={{position:'absolute',inset:0,opacity:lap1?1:.62}}><rect x="4" y="4" width="592" height="592" rx="77" fill="none" stroke={accent} strokeWidth={lap1?5:3.5} pathLength="1" strokeDasharray=".14 1" strokeDashoffset={-lp}/><rect x="4" y="4" width="592" height="592" rx="77" fill="none" stroke="#FFFFFF" strokeWidth={lap1?2.5:1.75} pathLength="1" strokeDasharray=".14 1" strokeDashoffset={-lp}/></svg>:null}</div>
  </div>
  <div style={{position:'absolute',left:890,top:315,width:910,opacity:tw(f,12,34),transform:`translateY(${tw(f,12,34,20,0)}px)`}}><div style={{fontSize:34,letterSpacing:2,color:accent,fontWeight:600,marginBottom:30}}>你的剪贴板小管家</div><div style={{fontSize:titleSize,fontWeight:750,lineHeight:1.06,letterSpacing:-3,color:COLORS.ink}}>{title.split(' ').map((w,i)=><React.Fragment key={i}>{i?<br/>:null}{w}</React.Fragment>)}</div><div style={{fontSize:62,color:COLORS.muted,lineHeight:1.35,marginTop:42}}>{subtitle}</div></div>
 </Stage>
};

const menuX=1140,menuY=80,menuScale=1.43;
const ROWS=[{y:140,name:'row_image'},{y:197,name:'row_text'},{y:254,name:'row_url'},{y:311,name:'row_note'}];
export const HistoryScene:React.FC<SceneProps>=({title='文字、图片，\n一起收好。',subtitle='最近 200 条，按需找回。',duration=166,accent=COLORS.blue,titleSize=82})=>{
 const f=useCurrentFrame();
 return <Stage style={{opacity:fade(f,duration)}}><CenteredNativeCamera frame={f} cx={960} cy={528} endCy={540} zoom={1.015} endZoom={1} end={90}>
  <Copy title={title} subtitle={subtitle} tag="文字 · 链接 · 图片" w={840} size={titleSize} accent={accent}/>
  <Native name="menu-light-filled" x={menuX} y={menuY} w={368*menuScale} h={637*menuScale} radius={32} shadow/>
  {ROWS.map((r,i)=>{const cue=12+i*9,land=cue+12;const p=tw(f,cue,land,0,1,Easing.bezier(.3,0,.25,1));const patch=tw(f,land,land+2,1,0);const x=menuX+16*menuScale,y=menuY+r.y*menuScale,w=336*menuScale,h=54*menuScale;const scale=f<land?1.06-.065*p:tw(f,land,land+4,.995,1,Easing.out(Easing.quad));return <React.Fragment key={r.name}>
   {patch>0?<div style={{position:'absolute',left:x-2,top:y-2,width:w+4,height:h+4,background:'#F0F0F0',opacity:patch}}/>:null}
   {f>=cue&&f<cue+16?<Native name={`menu-light-filled--${r.name}`} x={x} y={y} w={w} h={h} radius={10} style={{opacity:tw(f,cue,cue+3),transform:`perspective(900px) translateY(${-120*(1-p)}px) rotateX(${16*(1-p)}deg) scale(${scale})`,boxShadow:`0 ${30*(1-p)}px ${60*(1-p)}px #173c6833`}}/>:null}
   {f>=land&&f<land+8?<div style={{position:'absolute',left:x,top:y,width:w,height:h,borderRadius:10,overflow:'hidden'}}><div style={{position:'absolute',bottom:0,left:'50%',width:w*tw(f,land,land+5),height:2,transform:'translateX(-50%)',background:accent,opacity:tw(f,land+2,land+8,1,0)}}/></div>:null}
  </React.Fragment>})}
 </CenteredNativeCamera></Stage>
};

const Cursor:React.FC<{x:number;y:number;opacity?:number}>=({x,y,opacity=1})=><svg width="44" height="58" viewBox="0 0 44 58" style={{position:'absolute',left:x,top:y,opacity,filter:'drop-shadow(0 3px 3px #102A5040)'}}><path d="M5 4 L5 44 L16 33 L25 53 L34 49 L24 30 L40 30 Z" fill="white" stroke="#102A50" strokeWidth="3" strokeLinejoin="round"/></svg>;
export const SearchScene:React.FC<SceneProps>=({title='搜得到，\n也拿得回。',subtitle='点一下复制，再回到原应用粘贴。',duration=222,accent=COLORS.blue,titleSize=78})=>{
 const f=useCurrentFrame(),k=2.65,x=835,y=100;const filter=90;const slide=tw(f,filter,filter+10,0,1,Easing.bezier(.35,0,.2,1));const query=f<40?'':f<57?'灵':'灵感';const click=130;
 return <Stage style={{opacity:fade(f,duration)}}><CenteredNativeCamera frame={f} zoom={1} endZoom={1.015} end={155}>
  <Copy title={title} subtitle={subtitle} tag="搜索 → 找到 → 再次复制" x={110} y={265} w={650} size={titleSize} accent={accent}/>
  <div style={{position:'absolute',left:x,top:y,width:368*k,height:820,overflow:'hidden',borderRadius:32,boxShadow:'0 35px 85px #183b6426'}}>
   <Native name={f>=filter?'menu-search':'menu-light-filled'} x={0} y={0} w={368*k} h={637*k}/>
   {f<filter?<><div style={{position:'absolute',left:47*k,top:70*k,width:290*k,height:28*k,background:'#FAFAFA'}}/><div style={{position:'absolute',left:48*k,top:72*k,fontFamily:FONT,fontSize:13*k,lineHeight:'30px',color:'#222'}}>{query}{f>=38&&(f<72||Math.floor(f/8)%2===0)?<span style={{display:'inline-block',width:2*k,height:18*k,background:accent,marginLeft:2,verticalAlign:'middle'}}/>:null}</div></>:null}
   <div style={{position:'absolute',left:16*k,top:140*k,width:336*k,height:248*k,background:'#F0F0F0'}}/>
   {ROWS.map((r,i)=>{if(i===1)return null;const t=tw(f,filter+i*.4,filter+i*.4+5);return t>=1?null:<Native key={r.name} name={`menu-light-filled--${r.name}`} x={16*k} y={(r.y+8*t)*k} w={336*k} h={54*k} radius={10} style={{opacity:1-t}}/>})}
   <Native name={f>=110?'menu-search--row_image':'menu-light-filled--row_text'} x={16*k} y={(197-57*slide)*k} w={336*k} h={54*k} radius={12} style={{transform:`translateZ(${18*Math.sin(slide*Math.PI)}px) scale(${1+.02*Math.sin(slide*Math.PI)})`,boxShadow:`0 ${14*Math.sin(slide*Math.PI)}px ${28*Math.sin(slide*Math.PI)}px #173c6826`}}/>
   {[0,1].map(i=>{const start=click+i*3;if(f<start||f>start+10)return null;const t=tw(f,start,start+10,0,1,Easing.out(Easing.cubic)),rad=14+t*(i?64:40);return <div key={i} style={{position:'absolute',left:200*k-rad,top:166*k-rad,width:rad*2,height:rad*2,borderRadius:'50%',border:`3px solid ${accent}`,opacity:1-t}}/>})}
   <Cursor x={tw(f,106,128,335*k,200*k)} y={tw(f,106,128,260*k,166*k)} opacity={tw(f,104,110)*(1-tw(f,143,150))}/>
  </div>
  {f>=145?<div style={{position:'absolute',left:112,top:750,color:accent,fontSize:40,fontWeight:600,opacity:tw(f,145,156)}}>已复制到剪贴板</div>:null}
 </CenteredNativeCamera></Stage>
};

export const ImageScene:React.FC<SceneProps>=({title='截图，\n也在这里。',subtitle='图片预览 · 本地文件定位',duration=111,accent=COLORS.blue,titleSize=80})=>{
 const f=useCurrentFrame();return <Stage dark style={{opacity:fade(f,duration)}}><CenteredNativeCamera dark frame={f} cx={960} cy={535} endCy={540} zoom={1.03} endZoom={1} end={68} rot={-5}>
  <Copy title={title} subtitle={subtitle} tag="图片历史" dark x={110} y={240} w={655} size={titleSize} accent={accent}/>
  <Native name="history-light" x={870} y={120} w={860} h={860} radius={30} shadow/>
  <Native name="menu-light-filled--row_image" x={115} y={685} w={720} h={720*54/336} radius={20} shadow/>
  <div style={{position:'absolute',left:130,top:875,color:'#A6C7FF',fontSize:34}}>真实原生历史窗口</div>
 </CenteredNativeCamera></Stage>
};

export const UpdateScene:React.FC<SceneProps>=({title='更新状态，\n看得明白。',subtitle='检查中有反馈，失败可重试。',duration=110,accent=COLORS.blue,titleSize=82})=>{
 const f=useCurrentFrame();return <Stage style={{opacity:fade(f,duration)}}>
 <CenteredNativeCamera frame={f} cx={960} cy={540} zoom={1} endZoom={1} end={50}>
  <div style={{position:'absolute',left:300,top:590,width:1320,height:216,borderRadius:44,overflow:'hidden',boxShadow:'0 32px 85px #173c6829',transform:`perspective(1400px) translateZ(20px) rotateX(${tw(f,0,28,5,0)}deg)`}}>
   <Native name="menu-checking--update" x={0} y={0} w={1320} h={1320*55/336}/>
   <Native name="menu-current--update" x={0} y={0} w={1320} h={1320*55/336} style={{opacity:f>=48?1:0}}/>
  </div>
 </CenteredNativeCamera>
 <Copy title={title} subtitle={subtitle} tag="不打断的更新体验" x={120} y={160} w={1200} size={titleSize} accent={accent}/>
 <div style={{position:'absolute',left:300,top:864,fontSize:34,color:COLORS.muted}}>检查中 → 返回真实结果</div>
 </Stage>
};

export const LocalScene:React.FC<SceneProps>=({title='历史留在本机',subtitle='不需要账号，不上传剪贴板内容。',duration=111,accent=COLORS.blue,titleSize=90})=>{
 const f=useCurrentFrame();return <Stage style={{opacity:fade(f,duration)}}><Img src={staticFile('brand/pony-master.png')} style={{position:'absolute',right:170,top:225,width:550,height:550,borderRadius:75,boxShadow:'0 35px 70px #173c681c'}}/>
 <div style={{position:'absolute',left:130,top:285,width:950}}><div style={{fontSize:34,color:accent,fontWeight:600,marginBottom:32}}>属于你的本机记忆</div><div style={{display:'flex',gap:12,fontSize:titleSize,fontWeight:700,lineHeight:1.2,color:COLORS.ink}}>{(title==='历史留在本机'?['历史','留在','本机']:[title]).map((s,i)=>{const t=tw(f,4+i*4,13+i*4,0,1,Easing.bezier(.2,.75,.3,1));return <span key={s} style={{opacity:t,transform:`scale(${1.28-.28*t})`,filter:`blur(${7*(1-t)}px)`,color:i===2?accent:undefined}}>{s}</span>})}</div><div style={{height:6,width:220,background:accent,borderRadius:4,marginTop:32,transform:`scaleX(${tw(f,16,34)})`,transformOrigin:'left'}}/><div style={{fontSize:48,fontWeight:500,lineHeight:1.5,color:COLORS.muted,marginTop:34,maxWidth:880,opacity:tw(f,20,34)}}>{subtitle}</div><div style={{fontSize:34,color:COLORS.muted,marginTop:35,opacity:tw(f,34,45)}}>本地存储，不是云端同步。</div></div>
 </Stage>
};

const GROUP=[
 {file:'menu-light-filled--row_text',x:100,y:135,w:610,h:98,dx:-500,dy:-120,rot:-3},
 {file:'menu-light-filled--row_image',x:1240,y:160,w:560,h:90,dx:500,dy:-100,rot:3},
 {file:'menu-search--search',x:100,y:870,w:635,h:68,dx:-460,dy:260,rot:-2},
 {file:'menu-current--update',x:1200,y:870,w:610,h:100,dx:480,dy:260,rot:2}
];
export const OutroScene:React.FC<SceneProps>=({title='Clipboard Master',subtitle='让每一次复制，都有下文。',duration=222,accent=COLORS.blue,titleSize=100})=>{
 const f=useCurrentFrame(),stop=Math.min(f,duration-46),recede=tw(f,78,90),crane=tw(stop,0,40);const letters=title.split('');
 return <Stage><AbsoluteFill style={{transform:`perspective(1400px) rotateX(${4*(1-crane)}deg) scale(${1.06-.06*crane+tw(stop,40,150,0,.012)})`,transformOrigin:'50% 45%'}}>
  {GROUP.map((el,i)=>{const cue=4+i*3,t=tw(f,cue,cue+12,0,1,Easing.bezier(.34,1.4,.44,1));return <Native key={el.file} name={el.file} x={el.x} y={el.y} w={el.w} h={el.h} radius={18} shadow style={{opacity:tw(f,cue,cue+3)*(1-.2*recede),transform:`translate(${el.dx*(1-t)}px,${el.dy*(1-t)}px) rotate(${el.rot*(2-t)}deg) scale(${1.12-.12*t})`,filter:`blur(${.5*recede}px)`}}/>})}
  <div style={{position:'absolute',inset:0,background:'radial-gradient(ellipse 800px 540px at 50% 46%,#FFFFFFDD,transparent 80%)',opacity:tw(f,42,58,0,.7)}}/>
  <Img src={staticFile('brand/pony-master.png')} style={{position:'absolute',left:815,top:140,width:290,height:290,borderRadius:55,opacity:tw(f,20,36),transform:`translateY(${tw(f,20,36,35,0)}px)`}}/>
  <div style={{position:'absolute',top:485,width:'100%',textAlign:'center'}}><div style={{display:'flex',justifyContent:'center',fontSize:titleSize,fontWeight:750,color:COLORS.ink,letterSpacing:-2}}>{letters.map((ch,i)=>{const delay=Math.round(42+i*1.8),t=tw(f,delay,delay+8,0,1,Easing.bezier(.2,.75,.3,1));return <span key={i} style={{display:'inline-block',whiteSpace:'pre',opacity:t,transform:`translateY(${(1-t)*28}px) scale(${1.35-.35*t})`,filter:`blur(${(1-t)*8}px)`}}>{ch}</span>})}</div><div style={{height:6,width:220,background:accent,borderRadius:4,margin:'28px auto',transform:`scaleX(${tw(f,82,94)})`}}/><div style={{fontSize:60,fontWeight:650,color:COLORS.ink,opacity:tw(f,92,105)}}>{subtitle}</div><div style={{fontSize:36,fontWeight:600,color:accent,marginTop:32,opacity:tw(f,105,118)}}>github.com/crawfordxx/clipboard-master</div></div>
 </AbsoluteFill>
 {Array.from({length:18},(_,i)=>{const t=Math.min(f,150);return <div key={i} style={{position:'absolute',left:(i*439+137)%1920+Math.sin(t*.022+i*.83)*9,top:((i*613+271-t*(.3+i%5*.11))%1080+1080)%1080,width:2+i%3*.5,height:2+i%3*.5,borderRadius:'50%',background:accent,opacity:.12*(1-tw(f,130,150))}}/>})}
 </Stage>
};
export const COMPONENTS={intro:IntroScene,history:HistoryScene,search:SearchScene,images:ImageScene,updates:UpdateScene,local:LocalScene,outro:OutroScene};

export const TITLE_SIZES:Record<keyof typeof COMPONENTS,number>={intro:96,history:82,search:78,images:80,updates:82,local:90,outro:100};
