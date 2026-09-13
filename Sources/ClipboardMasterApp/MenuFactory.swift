import AppKit
import ClipboardMasterCore

/// 从历史条目构建 NSMenu（纯构建，无状态）。
/// 文本条目用标准菜单项；图片条目用自定义视图行（大预览 + Finder 定位按钮）。
enum MenuFactory {
    static func makeMenu(
        target: AnyObject,
        copyAction: Selector,
        clearAction: Selector,
        launchAtLoginAction: Selector,
        quitAction: Selector,
        openWindowAction: Selector,
        checkUpdateAction: Selector,
        startUpdateAction: Selector,
        availableVersion: String?,
        entries: [ClipboardEntry],
        launchAtLogin: Bool,
        copyHandler: @escaping (UUID) -> Void,
        revealHandler: @escaping (UUID) -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        if entries.isEmpty {
            let empty = NSMenuItem(title: "暂无记录", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for entry in entries {
                switch entry.content {
                case .text:
                    let item = NSMenuItem(
                        title: PreviewFormatter.menuTitle(for: entry.content),
                        action: copyAction,
                        keyEquivalent: ""
                    )
                    item.target = target
                    item.representedObject = entry.id
                    item.toolTip = PreviewFormatter.tooltip(for: entry)
                    menu.addItem(item)
                case .image:
                    let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    let id = entry.id
                    item.view = ImageMenuRowView(
                        entry: entry,
                        onCopy: { copyHandler(id) },
                        onReveal: { revealHandler(id) }
                    )
                    menu.addItem(item)
                }
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("打开历史窗口", action: openWindowAction, target: target, key: "o"))
        menu.addItem(actionItem("清空历史", action: clearAction, target: target))
        menu.addItem(actionItem("开机自启动", action: launchAtLoginAction, target: target, state: launchAtLogin ? .on : .off))
        menu.addItem(.separator())
        if let version = availableVersion {
            let update = actionItem("🆕 更新到 v\(version)（自动重启）", action: startUpdateAction, target: target)
            menu.addItem(update)
        }
        menu.addItem(actionItem("检查更新…", action: checkUpdateAction, target: target))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出 Clipboard Master", action: quitAction, target: target))
        return menu
    }

    private static func actionItem(
        _ title: String,
        action: Selector,
        target: AnyObject,
        key: String = "",
        state: NSControl.StateValue = .off
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.state = state
        return item
    }
}
