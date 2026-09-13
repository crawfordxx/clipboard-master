import AppKit
import ClipHistoryCore

/// 从历史条目构建 NSMenu（纯构建，无状态）。
enum MenuFactory {
    static func makeMenu(
        target: AnyObject,
        copyAction: Selector,
        clearAction: Selector,
        launchAtLoginAction: Selector,
        quitAction: Selector,
        entries: [ClipboardEntry],
        launchAtLogin: Bool
    ) -> NSMenu {
        let menu = NSMenu()

        if entries.isEmpty {
            let empty = NSMenuItem(title: "暂无记录", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for entry in entries {
                let item = NSMenuItem(
                    title: PreviewFormatter.menuTitle(for: entry.content),
                    action: copyAction,
                    keyEquivalent: ""
                )
                item.target = target
                item.representedObject = entry.id
                item.toolTip = PreviewFormatter.tooltip(for: entry)
                attachThumbnail(to: item, content: entry.content)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("清空历史", action: clearAction, target: target))

        let login = actionItem("开机自启动", action: launchAtLoginAction, target: target)
        login.state = launchAtLogin ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(actionItem("退出 ClipHistory", action: quitAction, target: target))
        return menu
    }

    private static func actionItem(_ title: String, action: Selector, target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        return item
    }

    /// 图片条目挂缩略图（约 20pt 高，等比缩放）。
    private static func attachThumbnail(to item: NSMenuItem, content: ClipboardContent) {
        guard case let .image(data, _, _) = content,
              let image = NSImage(data: data)
        else { return }
        let maxHeight: CGFloat = 20
        let ratio = maxHeight / max(image.size.height, 1)
        image.size = NSSize(width: max(1, image.size.width * ratio), height: maxHeight)
        item.image = image
    }
}
