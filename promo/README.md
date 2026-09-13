# Clipboard Master · 小马管家宣传片

原生 SwiftUI 截图与统一小马+剪贴板IP，1920×1080，30fps，80拍，约37秒。主时间线在 src/timeline.mjs，视觉在 src/Scenes.tsx，src/workbench.ts 与主合成同源。

## 本地制作

```sh
npm ci
# 先按 docs/audio-plan.md 下载并处理获授权音频（音频源文件不随公开仓库分发）
npm test
npm run typecheck
npm run render
npx remotion render src/index.ts ClipboardPromo out/clipboard-master-nobgm.mp4 --props=props-nobgm.json
```

可以通过 Remotion CLI 的 `--browser-executable` 指定已有 Chrome Headless Shell；否则 Remotion 会下载自己的浏览器。所有动画由帧驱动，可重复渲染。静态界面纹理和裁片是实际App组件的离屏4x采集，不是重画的仿UI。没有使用真实剪贴板数据。

- docs/DESIGN_SPEC.md：产品简报、决策、视觉tokens、分镜、Gallery选卡。
- docs/audio-plan.md / beats.json / sfx-analysis.json：声音来源、节拍网格、源峰值测量。
- tools/：安全原生采集脚本；不展示或激活窗口，不使用用户键盘或剪贴板。
- src/workbench.ts：可编辑镜头/文字参数与独立音效、配乐轨。

## 素材与许可

影片中的IP/插画由 image_gen 生成。App内容与品牌素材属于本项目。相机和部分动作实现改编自 [video-shotcraft](https://github.com/Vincentwei1021/video-shotcraft)，Copyright2026 Wei Yihao，Apache2.0，见 docs/VIDEO-SHOTCRAFT-LICENSE.txt；改编文件均标注来源及修改。

成片使用的音乐/拟音许可与来源见 docs/audio-plan.md。仅将已合成视频作为README宣传素材；不把独立音频文件作为公共素材包重新分发。Remotion本身遵循其独立许可，不由本项目MIT许可证覆盖。
