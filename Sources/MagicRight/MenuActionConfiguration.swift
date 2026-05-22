import Foundation

struct MenuAction: Identifiable, Hashable {
    let id: String
    let title: String
    let filename: String
    let symbolName: String
    let allowsEmpty: Bool

    static let all: [MenuAction] = [
        MenuAction(id: "subtitles", title: "生成字幕", filename: "gen_subtitles.sh", symbolName: "captions.bubble", allowsEmpty: false),
        MenuAction(id: "new-text", title: "新建文本文件", filename: "new_txt.sh", symbolName: "doc.text", allowsEmpty: false),
        MenuAction(id: "new-markdown", title: "新建 Markdown 文件", filename: "new_md.sh", symbolName: "doc.badge.plus", allowsEmpty: false),
        MenuAction(id: "new-word", title: "新建 Word 文档", filename: "new_docx.sh", symbolName: "doc.richtext", allowsEmpty: false),
        MenuAction(id: "open-ghostty", title: "用 Ghostty 打开", filename: "open_ghostty.sh", symbolName: "terminal", allowsEmpty: false),
        MenuAction(id: "open-vscode", title: "用 VS Code 打开", filename: "open_vscode.sh", symbolName: "curlybraces", allowsEmpty: false),
        MenuAction(id: "git-commit-push", title: "提交并推送当前仓库", filename: "git_commit_push.sh", symbolName: "arrow.up.doc", allowsEmpty: false),
        MenuAction(id: "copy-path", title: "复制路径", filename: "copy_path.sh", symbolName: "point.topleft.down.curvedto.point.bottomright.up", allowsEmpty: false)
    ]
}

enum MenuActionConfiguration {
    static let enabledIDsKey = "enabledMenuActionIDs"
    static let filename = "menu-actions.json"
    static let extensionBundleIdentifier = "local.elidev.MagicRight.FinderSync"

    static var defaultEnabledIDs: Set<String> {
        Set(MenuAction.all.map(\.id))
    }

    static func enabledIDs() -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: enabledIDsKey) ?? []
        return stored.isEmpty ? defaultEnabledIDs : Set(stored)
    }

    static func setEnabledIDs(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: enabledIDsKey)
    }

    static func configurationURL() -> URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts/\(extensionBundleIdentifier)", isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func writeEnabledIDs(_ ids: Set<String>) {
        do {
            let url = configurationURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Array(ids).sorted())
            if let existingData = try? Data(contentsOf: url), existingData == data {
                return
            }
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[MagicRight] Failed to write menu configuration: \(error)")
        }
    }
}
