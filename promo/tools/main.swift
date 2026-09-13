import AppKit
import SwiftUI
import ClipboardMasterCore

// Offline fixture capture: no app activation, ordered windows, keyboard or pasteboard APIs.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let fixtureImage = URL(fileURLWithPath: CommandLine.arguments[3])
let scale = 4
let fixtureDate = ISO8601DateFormatter().date(from: "2026-09-13T00:00:00Z")!
var store = HistoryStore()
store.insert(.text("会议纪要：确认图标与菜单体验。"), at: fixtureDate)
store.insert(.text("https://example.com/design"), at: fixtureDate.addingTimeInterval(60))
store.insert(.text("周一设计灵感：把重要的内容留在手边。"), at: fixtureDate.addingTimeInterval(120))
store.insert(.image(imageData: try! Data(contentsOf: fixtureImage), pixelWidth: 1254, pixelHeight: 1254), at: fixtureDate.addingTimeInterval(180))
let model = MenuPanelModel()
model.entries = store.entries
let fixtureDefaults = UserDefaults(suiteName: "com.clipboardmaster.pony-capture.fixture")!
var pending: ((Data?, URLResponse?, Error?) -> Void)?
let updater = UpdateChecker(dataDirectory: root.appendingPathComponent("data"), defaults: fixtureDefaults, version: "2.1.1", requestData: { _, done in pending = done })
let menu = MenuPanelView(model: model, updater: updater, onCopy: { _ in }, onReveal: { _ in }, onOpenHistory: {}, onClear: {}, onToggleLogin: {}, onClose: {}, onQuit: {})
let menuHost = NSHostingView(rootView: menu)
let menuWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 368, height: 637), styleMask: [.borderless], backing: .buffered, defer: false)
menuWindow.contentView = menuHost
menuHost.frame = NSRect(x: 0, y: 0, width: 368, height: 637)
let vm = HistoryViewModel()
vm.update(store.entries)
let historyHost = NSHostingView(rootView: HistoryView(vm: vm).background(Color(nsColor: .windowBackgroundColor)))
let historyWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 620), styleMask: [.borderless], backing: .buffered, defer: false)
historyWindow.contentView = historyHost
historyHost.frame = NSRect(x: 0, y: 0, width: 620, height: 620)
var records: [[String: Any]] = []
func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
func snapshot(_ name: String, _ view: NSView, _ window: NSWindow, dark: Bool = false) {
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.appearance?.performAsCurrentDrawingAppearance {
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        let size = view.bounds.size
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try! bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        let controls = descendants(view).compactMap { child -> [String: Any]? in
            guard child is NSTextField || child is NSButton || child is NSScrollView else { return nil }
            let box = view.convert(child.bounds, from: child)
            return ["class": NSStringFromClass(type(of: child)), "text": (child as? NSTextField)?.stringValue ?? (child as? NSButton)?.title ?? "", "box": [box.minX, box.minY, box.width, box.height]]
        }
        records.append(["name": name, "path": output.appendingPathComponent(name + ".png").path, "pointSize": [size.width, size.height], "pixelSize": [Int(size.width)*scale, Int(size.height)*scale], "nativeControls": controls])
        print("CAPTURE \(name) \(Int(size.width)*scale)x\(Int(size.height)*scale) windowVisible=\(window.isVisible) key=\(window.isKeyWindow)")
    }
}
func after(_ block: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: block) }
func finish() {
    let metadata: [String: Any] = ["scale": scale, "fixtureDate": "2026-09-13T00:00:00Z", "coordinateSystem": "NSView points", "captures": records, "safety": "Never ordered or activated windows; no keyboard, pasteboard, installed app, network, or real user records."]
    try! JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("layout-native.json"))
    exit(0)
}
after {
    snapshot("menu-light-filled", menuHost, menuWindow)
    snapshot("menu-dark-filled", menuHost, menuWindow, dark: true)
    model.entries = []
    after {
        snapshot("menu-light-empty", menuHost, menuWindow)
        snapshot("menu-dark-empty", menuHost, menuWindow, dark: true)
        model.entries = store.entries
        updater.checkNow()
        after {
            snapshot("menu-checking", menuHost, menuWindow)
            pending?(Data(#"{"tag_name":"v2.1.1"}"#.utf8), HTTPURLResponse(url: UpdateChecker.releasesURL, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
            after {
                snapshot("menu-current", menuHost, menuWindow)
                if let field = descendants(menuHost).compactMap({ $0 as? NSTextField }).first(where: { $0.placeholderString == "搜索文字或图片" }) {
                    field.stringValue = "灵感"
                    let note = Notification(name: NSControl.textDidChangeNotification, object: field)
                    field.delegate?.controlTextDidChange?(note)
                    print("SEARCH_NATIVE_FIELD_SET 灵感")
                } else { print("SEARCH_NATIVE_FIELD_UNAVAILABLE") }
                after {
                    snapshot("menu-search", menuHost, menuWindow)
                    snapshot("history-light", historyHost, historyWindow)
                    snapshot("history-dark", historyHost, historyWindow, dark: true)
                    vm.query = "灵感"
                    after {
                        snapshot("history-search", historyHost, historyWindow)
                        vm.query = ""
                        vm.update(store.entries.filter { if case .image = $0.content { return true }; return false })
                        after { snapshot("history-image", historyHost, historyWindow); finish() }
                    }
                }
            }
        }
    }
}
app.run()
