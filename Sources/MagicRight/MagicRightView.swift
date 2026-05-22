import SwiftUI

struct MagicRightView: View {
    @State private var selection: SettingsPage? = .contextMenu
    @State private var enabledActionIDs = MenuActionConfiguration.enabledIDs()
    @State private var searchText = ""
    private let sidebarIconTileSize: Double = 22
    private let sidebarIconSymbolSize: Double = 11
    private let sidebarIconCornerRadius: Double = 6

    enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
        case contextMenu

        var id: String { rawValue }
        var title: String { "右键菜单" }
        var symbolName: String { "contextualmenu.and.cursorarrow" }
        var iconGradient: LinearGradient {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.50, blue: 0.40), Color(red: 0.96, green: 0.28, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: SettingsPage.contextMenu) {
                    SidebarPageLabel(page: .contextMenu)
                }
            }
            .navigationTitle("设置")
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        } detail: {
            NavigationStack {
                Form {
                    Section("右键显示选项") {
                        ForEach(filteredActions) { action in
                            Toggle(isOn: binding(for: action)) {
                                Label(action.title, systemImage: action.symbolName)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .settingsContentMargins()
                .scrollContentBackground(.hidden)
                .navigationTitle(selection?.title ?? SettingsPage.contextMenu.title)
            }
        }
        .environment(\.sidebarIconTileSize, sidebarIconTileSize)
        .environment(\.sidebarIconSymbolSize, sidebarIconSymbolSize)
        .environment(\.sidebarIconCornerRadius, sidebarIconCornerRadius)
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索右键菜单")
        .background {
            WindowTransparencyConfigurator(enabled: true)
                .frame(width: 0, height: 0)

            WindowBackgroundBlur(materialAlpha: 1)
                .ignoresSafeArea()
        }
        .onAppear {
            persistEnabledActions()
        }
        .onChange(of: enabledActionIDs) { _, _ in
            persistEnabledActions()
        }
    }

    private var filteredActions: [MenuAction] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MenuAction.all }
        return MenuAction.all.filter { action in
            action.title.localizedStandardContains(query)
        }
    }

    private func binding(for action: MenuAction) -> Binding<Bool> {
        Binding(
            get: { enabledActionIDs.contains(action.id) },
            set: { isEnabled in
                if isEnabled {
                    enabledActionIDs.insert(action.id)
                } else {
                    enabledActionIDs.remove(action.id)
                }
            }
        )
    }

    private func persistEnabledActions() {
        MenuActionConfiguration.setEnabledIDs(enabledActionIDs)
        MenuActionConfiguration.writeEnabledIDs(enabledActionIDs)
    }
}

private struct SidebarPageLabel: View {
    let page: MagicRightView.SettingsPage

    var body: some View {
        HStack(spacing: 12) {
            SidebarCategoryIcon(page: page)
            Text(page.title)
        }
    }
}

private struct SidebarCategoryIcon: View {
    let page: MagicRightView.SettingsPage
    @Environment(\.sidebarIconTileSize) private var tileSize
    @Environment(\.sidebarIconSymbolSize) private var symbolSize
    @Environment(\.sidebarIconCornerRadius) private var cornerRadius

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(page.iconGradient)

            Image(systemName: page.symbolName)
                .font(.system(size: symbolSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: tileSize, height: tileSize)
    }
}

private struct SidebarIconTileSizeKey: EnvironmentKey {
    static let defaultValue: Double = 32
}

private struct SidebarIconSymbolSizeKey: EnvironmentKey {
    static let defaultValue: Double = 15
}

private struct SidebarIconCornerRadiusKey: EnvironmentKey {
    static let defaultValue: Double = 8
}

private extension EnvironmentValues {
    var sidebarIconTileSize: Double {
        get { self[SidebarIconTileSizeKey.self] }
        set { self[SidebarIconTileSizeKey.self] = newValue }
    }

    var sidebarIconSymbolSize: Double {
        get { self[SidebarIconSymbolSizeKey.self] }
        set { self[SidebarIconSymbolSizeKey.self] = newValue }
    }

    var sidebarIconCornerRadius: Double {
        get { self[SidebarIconCornerRadiusKey.self] }
        set { self[SidebarIconCornerRadiusKey.self] = newValue }
    }
}

private extension View {
    func settingsContentMargins() -> some View {
        self
            .contentMargins(.horizontal, 18, for: .scrollContent)
            .contentMargins(.top, 0, for: .scrollContent)
    }
}
