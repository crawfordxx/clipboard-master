# 安全原生UI采集

在macOS仓库中运行 `bash promo/tools/capture.sh`，再运行 `ruby promo/tools/cutouts.rb`。
可以通过 capture.sh 的两个参数覆盖项目根目录与角色PNG路径。

输出在 promo/qa/native/。脚本先编译实际MenuPanelView/HistoryView/HistoryViewModel/UpdateChecker，对四条固定虚构记录进行4x采集。窗口从不显示、激活或获取键盘焦点；不接触系统剪贴板、不访问真实用户历史、不发网络请求。

搜索在隔离进程内通过原生 NSTextField delegate 设置；截图来自实际SwiftUI视图。裁片用docs/native-layout-source.json中的逻辑坐标，不重画UI。固定记录的相对时间标签会随重新采集时间变化；提交的PNG已经冻结，视频渲染不读取时钟。

需要 Swift6+、ImageMagick 和 Ruby。不支持在 Windows 上重新采集 macOS 原生界面。
