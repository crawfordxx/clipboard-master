import React from 'react';
import {Composition,registerRoot} from 'remotion';
import {ClipboardPromo} from './Main';
import {FPS,TOTAL} from './timeline.mjs';
const Root=()=>React.createElement(Composition,{id:'ClipboardPromo',component:ClipboardPromo,durationInFrames:TOTAL,fps:FPS,width:1920,height:1080,defaultProps:{bgm:true}});
registerRoot(Root);
