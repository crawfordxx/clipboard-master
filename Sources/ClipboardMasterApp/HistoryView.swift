import SwiftUI
import ClipboardMasterCore

/// 历史窗口主界面：搜索 + 列表（双击复制/右键菜单）+ 底部统计与清空。
struct HistoryView: View {
    @ObservedObject var vm: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar.padding(8)
            Divider()
            if vm.filtered.isEmpty {
                emptyState
            } else {
                entryList
            }
            Divider()
            footer.padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        }
        .frame(minWidth: 500, minHeight: 560)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索剪贴板历史…", text: $vm.query)
                .textFieldStyle(.plain)
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    private var entryList: some View {
        List(vm.filtered) { entry in
            EntryRow(entry: entry, vm: vm)
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(vm.entries.isEmpty ? "暂无记录，复制点什么吧" : "没有匹配「\(vm.query)」的记录")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(vm.countText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("清空全部") { vm.clearAll() }
        }
    }
}

/// 单条历史行：缩略图/图标 + 两行标题 + 相对时间；双击复制，右键菜单。
private struct EntryRow: View {
    let entry: ClipboardEntry
    let vm: HistoryViewModel

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            Text(PreviewFormatter.menuTitle(for: entry.content))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { vm.copy(entry.id) }
        .contextMenu {
            Button("复制到剪贴板") { vm.copy(entry.id) }
            if entry.content.isImage {
                Button("在 Finder 中显示") { vm.reveal(entry.id) }
            }
            Divider()
            Button("删除", role: .destructive) { vm.delete(entry.id) }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch entry.content {
        case .image(let data, _, _):
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.separator, lineWidth: 0.5)
                    )
            } else {
                placeholderIcon
            }
        case .text:
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "doc.plaintext")
            .font(.system(size: 20))
            .foregroundStyle(.tertiary)
            .frame(width: 48, height: 48)
    }
}

private extension ClipboardContent {
    var isImage: Bool {
        if case .image = self { return true }
        return false
    }
}
