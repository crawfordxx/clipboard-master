import AppKit
import ClipHistoryCore

// LSUIElement 应用：不显示 Dock 图标，仅菜单栏。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
