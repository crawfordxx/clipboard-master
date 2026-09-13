import AppKit
import ClipboardMasterCore

/// 下拉菜单中的图片条目行：48pt 大预览 + 标题 + 相对时间/尺寸 + 「在 Finder 中显示」按钮。
/// 自定义 NSView 菜单项不自动响应 action，点击后需手动 cancelTracking 收起菜单。
final class ImageMenuRowView: NSView {
    private let onCopy: () -> Void
    private let onReveal: () -> Void
    private var hover = false {
        didSet { needsDisplay = true }
    }

    init(entry: ClipboardEntry, onCopy: @escaping () -> Void, onReveal: @escaping () -> Void) {
        self.onCopy = onCopy
        self.onReveal = onReveal
        super.init(frame: NSRect(x: 0, y: 0, width: 330, height: 64))
        setup(entry: entry)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("不支持 storyboard 创建") }

    private func setup(entry: ClipboardEntry) {
        guard case let .image(data, _, _) = entry.content else { return }

        let imageView = NSImageView(frame: NSRect(x: 8, y: 8, width: 48, height: 48))
        if let image = NSImage(data: data) {
            let ratio = min(48 / max(image.size.width, 1), 48 / max(image.size.height, 1))
            image.size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            imageView.image = image
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(imageView)

        let title = NSTextField(labelWithString: PreviewFormatter.menuTitle(for: entry.content))
        title.font = .menuFont(ofSize: 0)
        title.frame = NSRect(x: 66, y: 24, width: 210, height: 18)
        addSubview(title)

        let reveal = NSButton(
            image: NSImage(systemSymbolName: "folder", accessibilityDescription: "在 Finder 中显示")!,
            target: self,
            action: #selector(revealClicked)
        )
        reveal.isBordered = false
        reveal.toolTip = "在 Finder 中显示"
        reveal.frame = NSRect(x: 292, y: 20, width: 28, height: 24)
        addSubview(reveal)

        toolTip = PreviewFormatter.tooltip(for: entry)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        ))
    }

    @objc private func revealClicked() {
        onReveal()
        cancelMenu()
    }

    override func mouseDown(with event: NSEvent) {
        onCopy()
        cancelMenu()
    }

    private func cancelMenu() {
        enclosingMenuItem?.menu?.cancelTracking()
    }

    override func draw(_ dirtyRect: NSRect) {
        if hover {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).setFill()
            bounds.fill()
        }
    }

    override func mouseEntered(with event: NSEvent) { hover = true }
    override func mouseExited(with event: NSEvent) { hover = false }
}
