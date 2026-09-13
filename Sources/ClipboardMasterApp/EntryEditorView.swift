import AppKit
import SwiftUI
import ClipboardMasterCore

struct EntryEditorView: View {
    @ObservedObject var model: EntryEditorModel
    @State private var zoom = 1.0
    @State private var pendingFile: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: model.isText ? "doc.text" : "photo")
                    .font(.title2).foregroundStyle(.tint)
                    .frame(width: 42, height: 42).background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isFileList ? "文件预览" : model.isText ? "预览与编辑" : "图片预览").font(.headline)
                    Text(model.entry.capturedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isDirty { Text("未保存").font(.caption).foregroundStyle(.orange) }
            }.padding(20)
            Divider()
            if model.isFileList {
                if let preview = model.filePreview {
                    Image(nsImage: preview).resizable().scaledToFit().padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityLabel("本地图片文件预览")
                } else {
                    ContentUnavailableView("\(model.references.count) 个本地文件", systemImage: "doc.on.doc", description: Text("点击下方文件链接打开，或在 Finder 中定位。\n这里只保存引用，原文件移动或删除后可能无法打开。"))
                }
            } else if model.isText {
                TextEditor(text: $model.draft)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12).accessibilityLabel("记录文字编辑器")
                    .accessibilityIdentifier("entry-editor-text")
                HStack {
                    Text("\(model.draft.count) / \(HistoryLimits.storedTextCap) 字")
                    Spacer()
                    Text("只修改历史副本，不改动磁盘文件")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 12)
            } else {
                imagePreview
            }
            if !model.references.isEmpty { referenceList }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.red)
                        .textSelection(.enabled)
                } else if let notice = model.notice {
                    Label(notice, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
                }
                HStack {
                    if model.isText && !model.isFileList {
                        Button("还原草稿") { model.resetDraft() }.disabled(!model.isDirty)
                    }
                    Spacer()
                    if model.isText && !model.isFileList {
                        Button("保存修改") { model.save() }
                            .keyboardShortcut("s").disabled(!model.available || !model.isDirty || !model.validDraft)
                    }
                    Button(model.isDirty ? "保存并复制" : "复制内容") { model.saveAndCopy() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!model.available || (model.isText && !model.validDraft))
                        .accessibilityIdentifier("entry-editor-copy")
                }
            }.padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 500, minHeight: 420)
        .alert("打开本地文件？", isPresented: Binding(get: { pendingFile != nil }, set: { if !$0 { pendingFile = nil } })) {
            Button("取消", role: .cancel) { pendingFile = nil }
            Button("打开") { if let url = pendingFile { open(url) }; pendingFile = nil }
        } message: { Text("将使用系统默认应用打开，请确认这是可信文件。\n\(pendingFile?.path ?? "")") }
    }

    private var imagePreview: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if let image = model.image {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(width: max(1, geometry.size.width - 24) * zoom, height: max(1, geometry.size.height - 24) * zoom)
                            .padding(12).accessibilityLabel("完整图片预览")
                    } else {
                        ContentUnavailableView("无法解码图片", systemImage: "photo.badge.exclamationmark")
                    }
                }
            }.background(.quaternary.opacity(0.25))
            HStack {
                if case .image(_, let width, let height) = model.entry.content {
                    Text("\(width) × \(height) 像素").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("−") { zoom = max(1, zoom - 0.5) }.disabled(zoom <= 1).accessibilityLabel("缩小图片")
                Text("\(zoom, specifier: "%.1f")×").font(.caption.monospacedDigit()).frame(width: 42)
                Button("+") { zoom = min(4, zoom + 0.5) }.disabled(zoom >= 4).accessibilityLabel("放大图片")
                Button("适应窗口") { zoom = 1 }
            }.padding(12)
        }
    }

    private var referenceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("链接与文件").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.references, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(systemName: url.isFileURL ? "doc" : "link").foregroundStyle(.secondary)
                            Button { requestOpen(url) } label: {
                                Text(url.isFileURL ? url.lastPathComponent : url.absoluteString)
                                    .lineLimit(1).truncationMode(.middle)
                            }.buttonStyle(.link).help(url.isFileURL ? url.path : url.absoluteString)
                            Spacer(minLength: 2)
                            if url.isFileURL {
                                Button("所在文件夹") { reveal(url) }.help("在 Finder 中显示")
                                Button("打开文件") { requestOpen(url) }
                            } else { Button("打开链接") { requestOpen(url) } }
                        }.font(.callout).padding(8)
                            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }.frame(maxHeight: 116)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func requestOpen(_ url: URL) {
        guard EntryReferences.isSupported(url) else { return }
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else { model.error = "文件已移动或删除，无法打开。"; return }
            pendingFile = url
        } else { open(url) }
    }

    private func open(_ url: URL) {
        if !NSWorkspace.shared.open(url) { model.error = "无法打开，请检查文件权限或默认应用。" }
    }

    private func reveal(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { model.error = "文件已移动或删除，无法在 Finder 中定位。"; return }
        NSWorkspace.shared.activateFileViewerSelecting([url.standardizedFileURL])
    }
}
