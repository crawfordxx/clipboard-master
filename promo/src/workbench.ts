import {ClipboardPromo} from './Main';
import {COMPONENTS,COLORS,TITLE_SIZES} from './Scenes';
import {SHOTS,SFX,FPS,TOTAL} from './timeline.mjs';
export const WORKBENCH={name:'Clipboard Master · 小马管家',fps:FPS,width:1920,height:1080,total:TOTAL,background:COLORS.bg,revision:'pony-master-v3',
 shots:SHOTS.map(s=>({id:s.id,label:s.title.replace('\n',''),from:s.from,duration:s.duration,component:COMPONENTS[s.id as keyof typeof COMPONENTS],props:{title:s.title,subtitle:s.subtitle,duration:s.duration,titleSize:TITLE_SIZES[s.id as keyof typeof COMPONENTS]},durationProp:'duration',schema:[{type:'textarea',key:'title',label:'标题',default:s.title},{type:'textarea',key:'subtitle',label:'副标题',default:s.subtitle},{type:'color',key:'accent',label:'强调色',default:COLORS.blue},{type:'number',key:'titleSize',label:'标题字号',default:TITLE_SIZES[s.id as keyof typeof COMPONENTS],min:50,max:120}]})),
 transitions:[],captions:[],overlays:[],sfx:SFX.map(s=>({from:s.from,duration:s.duration,src:s.src,volume:s.volume})),bgm:[{from:0,duration:TOTAL,src:'audio/bgm-aligned.wav',volume:.24}],original:ClipboardPromo};
