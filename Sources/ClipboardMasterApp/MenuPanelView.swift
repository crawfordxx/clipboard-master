import AppKit
import SwiftUI
import ClipboardMasterCore

final class MenuPanelModel: ObservableObject {
    @Published var entries: [ClipboardEntry] = []
    @Published var launchAtLogin = false
    @Published var notice: String?
}

/// A bounded, native popover: history scrolls independently from the tool section.
struct MenuPanelView: View {
    @ObservedObject var model: MenuPanelModel
    @ObservedObject var updater: UpdateChecker
    let onCopy: (UUID) -> Void
    let onReveal: (UUID) -> Void
    let onOpenHistory: () -> Void
    let onClear: () -> Void
    let onToggleLogin: () -> Void
    let onClose: () -> Void
    let onQuit: () -> Void
    @State private var query = ""
    @State private var confirmClear = false
    @FocusState private var focusedEntry: UUID?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var filtered: [ClipboardEntry] {
        model.entries.filter { HistoryFilter.matches($0.content, query: query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            search
            HStack {
                Text(query.isEmpty ? "最近复制" : "搜索结果").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(filtered.count) 条").font(.system(size: 11, design: .monospaced))
            }.foregroundStyle(.secondary).padding(.horizontal, 6)
            history
            VStack(spacing: 2) {
                action("打开历史窗口", icon: "clock.arrow.circlepath", hint: "⌘ O", action: onOpenHistory)
                    .keyboardShortcut("o")
                action("开机自启动", icon: "power", hint: model.launchAtLogin ? "已开启" : "已关闭", action: onToggleLogin)
                    .accessibilityValue(model.launchAtLogin ? "已开启" : "已关闭")
                action("清空历史…", icon: "trash") { confirmClear = true }
                    .disabled(model.entries.isEmpty)
            }.padding(5).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            updateCard
            HStack {
                Text("内容仅保存在本机").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(action: onQuit) { Image(systemName: "power").frame(width: 28, height: 26) }
                    .buttonStyle(PanelButtonStyle()).help("退出 Clipboard Master")
                    .accessibilityLabel("退出 Clipboard Master")
            }.padding(.horizontal, 6)
        }
        .padding(16)
        .frame(width: 368)
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
            else { Rectangle().fill(.regularMaterial) }
        }
        .onExitCommand(perform: onClose)
        .alert("清空所有剪贴板历史？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清空历史", role: .destructive, action: onClear)
        } message: { Text("文字和图片记录都会删除，此操作无法撤销。") }
        .alert("操作未完成", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) {
            Button("好", role: .cancel) { model.notice = nil }
        } message: { Text(model.notice ?? "") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text("Clipboard Master").font(.system(size: 15, weight: .semibold))
                Text("复制过的，随时找回").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("v\(updater.currentVersion)").font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索文字或图片", text: $query).textFieldStyle(.plain)
                .accessibilityLabel("搜索剪贴板历史")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel("清除搜索")
            }
        }.font(.system(size: 13)).padding(10)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator.opacity(0.45), lineWidth: 0.5))
    }

    private var history: some View {
        ScrollView {
            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: query.isEmpty ? "clipboard" : "magnifyingglass").font(.system(size: 28))
                    Text(query.isEmpty ? "还没有复制记录" : "没有匹配的记录").font(.system(size: 13, weight: .medium))
                    Text(query.isEmpty ? "复制文字或图片，就会出现在这里。" : "试试其他关键词，或清除搜索。")
                        .font(.system(size: 11))
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                LazyVStack(spacing: 3) {
                    ForEach(filtered) { entry in
                        HStack(spacing: 2) {
                            Button { onCopy(entry.id) } label: {
                                HStack(spacing: 10) {
                                    thumbnail(entry.content)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(PreviewFormatter.menuTitle(for: entry.content))
                                            .font(.system(size: 12, weight: .medium)).lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(Text(entry.capturedAt, style: .relative))前")
                                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }.padding(8).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            }
                            .buttonStyle(PanelButtonStyle())
                            .focused($focusedEntry, equals: entry.id)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(focusedEntry == entry.id ? Color.accentColor : .clear, lineWidth: 2))
                            .onKeyPress(.return) { onCopy(entry.id); return .handled }
                            .help(PreviewFormatter.tooltip(for: entry))
                            if case .image = entry.content {
                                Button { onReveal(entry.id) } label: {
                                    Image(systemName: "folder").frame(width: 28, height: 34)
                                }.buttonStyle(PanelButtonStyle()).help("在 Finder 中显示")
                                    .accessibilityLabel("在 Finder 中显示图片")
                            }
                        }
                    }
                }
            }
        }.frame(height: 248)
    }

    @ViewBuilder private func thumbnail(_ content: ClipboardContent) -> some View {
        if case let .image(data, _, _) = content, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityLabel("图片缩略图")
        } else {
            Image(systemName: "doc.text").font(.system(size: 15)).foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func action(_ title: String, icon: String, hint: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                    .frame(width: 26, height: 26).background(.quaternary, in: Circle())
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(hint).font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 8).padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(PanelButtonStyle())
    }

    private var updateCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                if updater.isBusy { ProgressView().controlSize(.small).frame(width: 22) }
                else { Image(systemName: updateIcon).frame(width: 22).foregroundStyle(.tint) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(updateTitle).font(.system(size: 12, weight: .medium))
                    Text(updateDetail).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if !updater.isBusy {
                    Button(updateActionTitle, action: performUpdateAction).controlSize(.small)
                }
            }
            if case .failed = updater.state {
                HStack {
                    Button("查看发布页", action: updater.openReleasePage)
                    if updater.hasUpdateLog { Button("查看日志", action: updater.openUpdateLog) }
                }.font(.system(size: 10)).buttonStyle(.link).padding(.leading, 30)
            }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var updateIcon: String {
        switch updater.state {
        case .upToDate: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        default: return "arrow.down.circle"
        }
    }
    private var updateTitle: String {
        switch updater.state {
        case .idle: return "软件更新"
        case .checking: return "正在检查更新…"
        case .upToDate: return "已是最新版本"
        case .available(let v): return "发现新版本 v\(v)"
        case .installing: return "正在更新…"
        case .manualInstall: return "需要手动更新"
        case .failed: return "更新未完成"
        }
    }
    private var updateDetail: String {
        switch updater.state {
        case .checking: return "正在连接 GitHub，请稍候。"
        case .available: return "更新完成后自动重启，保留历史记录。"
        case .installing: return "正在获取、构建并安装，请勿退出应用。"
        case .manualInstall: return "未找到源码目录，可前往发布页获取版本。"
        case .failed(let message): return message
        default: return "当前版本 v\(updater.currentVersion)"
        }
    }
    private var updateActionTitle: String {
        switch updater.state {
        case .available: return "更新"
        case .manualInstall: return "发布页"
        case .failed: return "重试"
        default: return "检查"
        }
    }
    private func performUpdateAction() {
        switch updater.state {
        case .available: updater.startUpdate()
        case .manualInstall: updater.openReleasePage()
        default: updater.checkNow()
        }
    }
}

private struct PanelButtonStyle: ButtonStyle {
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(enabled && (hovered || configuration.isPressed) ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 9))
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovered)
    }
}
