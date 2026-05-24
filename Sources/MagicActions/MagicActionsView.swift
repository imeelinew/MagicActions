import AppKit
import PermissionFlow
import SwiftUI

struct MagicActionsView: View {
    @State private var selection: SettingsPage? = .contextMenu
    @State private var contextMenuEnabled = MenuActionConfiguration.isEnabled()
    @State private var enabledActionIDs = MenuActionConfiguration.enabledIDs()
    @State private var windowOperationsEnabled = WindowOperationConfiguration.isEnabled()
    @State private var enabledWindowOperationIDs = WindowOperationConfiguration.enabledIDs()
    @State private var showsNetworkSpeed = MenuBarConfiguration.showsNetworkSpeed()
    @State private var contextMenuSearchText = ""
    @State private var windowOperationsSearchText = ""
    @State private var menuBarSearchText = ""
    private let sidebarIconTileSize: Double = 22
    private let sidebarIconSymbolSize: Double = 11
    private let sidebarIconCornerRadius: Double = 6

    enum SettingsPage: String, CaseIterable, Hashable, Identifiable {
        case contextMenu
        case windowOperations
        case menuBar

        var id: String { rawValue }
        var title: String {
            switch self {
            case .contextMenu:
                return "右键菜单"
            case .windowOperations:
                return "窗口操作"
            case .menuBar:
                return "菜单栏"
            }
        }

        var symbolName: String {
            switch self {
            case .contextMenu:
                return "contextualmenu.and.cursorarrow"
            case .windowOperations:
                return "rectangle.on.rectangle"
            case .menuBar:
                return "menubar.rectangle"
            }
        }

        var iconGradient: LinearGradient {
            switch self {
            case .contextMenu:
                return LinearGradient(
                    colors: [Color(red: 1.0, green: 0.50, blue: 0.40), Color(red: 0.96, green: 0.28, blue: 0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .windowOperations:
                return LinearGradient(
                    colors: [Color(red: 0.28, green: 0.52, blue: 0.98), Color(red: 0.16, green: 0.34, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .menuBar:
                return LinearGradient(
                    colors: [Color(red: 0.32, green: 0.68, blue: 0.58), Color(red: 0.10, green: 0.48, blue: 0.42)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var selectedPage: SettingsPage {
        selection ?? .contextMenu
    }

    private var searchPrompt: String {
        switch selectedPage {
        case .contextMenu:
            return "搜索右键菜单"
        case .windowOperations:
            return "搜索窗口操作"
        case .menuBar:
            return "搜索菜单栏"
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: {
                switch selectedPage {
                case .contextMenu:
                    return contextMenuSearchText
                case .windowOperations:
                    return windowOperationsSearchText
                case .menuBar:
                    return menuBarSearchText
                }
            },
            set: { newValue in
                switch selectedPage {
                case .contextMenu:
                    contextMenuSearchText = newValue
                case .windowOperations:
                    windowOperationsSearchText = newValue
                case .menuBar:
                    menuBarSearchText = newValue
                }
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsPage.allCases) { page in
                    NavigationLink(value: page) {
                        SidebarPageLabel(page: page)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        } detail: {
            NavigationStack {
                detailContent
                .formStyle(.grouped)
                .settingsContentMargins()
                .scrollContentBackground(.hidden)
                .navigationTitle(selectedPage.title)
            }
        }
        .environment(\.sidebarIconTileSize, sidebarIconTileSize)
        .environment(\.sidebarIconSymbolSize, sidebarIconSymbolSize)
        .environment(\.sidebarIconCornerRadius, sidebarIconCornerRadius)
        .searchable(text: searchTextBinding, placement: .toolbar, prompt: Text(searchPrompt))
        .background {
            WindowTransparencyConfigurator(enabled: true)
                .frame(width: 0, height: 0)

            WindowBackgroundBlur(materialAlpha: 1)
                .ignoresSafeArea()
        }
        .onAppear {
            persistEnabledActions()
            persistEnabledWindowOperations()
            persistMenuBarConfiguration()
        }
        .onChange(of: contextMenuEnabled) { _, _ in
            persistEnabledActions()
        }
        .onChange(of: enabledActionIDs) { _, _ in
            persistEnabledActions()
        }
        .onChange(of: windowOperationsEnabled) { _, _ in
            persistEnabledWindowOperations()
        }
        .onChange(of: enabledWindowOperationIDs) { _, _ in
            persistEnabledWindowOperations()
        }
        .onChange(of: showsNetworkSpeed) { _, _ in
            persistMenuBarConfiguration()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedPage {
        case .contextMenu:
            Form {
                Section("总开关") {
                    Toggle("启用右键菜单", isOn: $contextMenuEnabled)
                }

                if contextMenuEnabled {
                    Section("右键显示选项") {
                        ForEach(filteredActions) { action in
                            Toggle(isOn: binding(for: action)) {
                                HStack(spacing: 10) {
                                    MenuActionIcon(actionID: action.id, size: 24)
                                    Text(action.title)
                                }
                            }
                        }
                    }
                }
            }
        case .windowOperations:
            Form {
                Section("总开关") {
                    Toggle("启用窗口操作", isOn: $windowOperationsEnabled)
                }

                if windowOperationsEnabled {
                    Section("窗口操作") {
                        ForEach(filteredWindowOperations) { operation in
                            Toggle(isOn: binding(for: operation)) {
                                HStack(spacing: 10) {
                                    WindowOperationIcon(operation: operation, size: 24)
                                    Text(operation.title)
                                }
                            }
                        }
                    }
                }

                if windowOperationsEnabled && !enabledWindowOperationIDs.isEmpty {
                    Section("权限") {
                        AccessibilityPermissionRow()
                    }
                }
            }
        case .menuBar:
            Form {
                Section("总开关") {
                    Toggle("显示实时网速", isOn: $showsNetworkSpeed)
                }
            }
        }
    }

    private var filteredActions: [MenuAction] {
        let query = contextMenuSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MenuAction.all }
        return MenuAction.all.filter { action in
            action.title.localizedStandardContains(query)
        }
    }

    private var filteredWindowOperations: [WindowOperation] {
        let query = windowOperationsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return WindowOperation.all }
        return WindowOperation.all.filter { operation in
            operation.title.localizedStandardContains(query)
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

    private func binding(for operation: WindowOperation) -> Binding<Bool> {
        Binding(
            get: { enabledWindowOperationIDs.contains(operation.id) },
            set: { isEnabled in
                if isEnabled {
                    enabledWindowOperationIDs.insert(operation.id)
                } else {
                    enabledWindowOperationIDs.remove(operation.id)
                }
            }
        )
    }

    private func persistEnabledActions() {
        MenuActionConfiguration.setEnabled(contextMenuEnabled)
        MenuActionConfiguration.setEnabledIDs(enabledActionIDs)
        MenuActionConfiguration.writeEnabledIDs(enabledActionIDs, isEnabled: contextMenuEnabled)
    }

    private func persistEnabledWindowOperations() {
        WindowOperationConfiguration.setEnabled(windowOperationsEnabled)
        WindowOperationConfiguration.setEnabledIDs(enabledWindowOperationIDs)
    }

    private func persistMenuBarConfiguration() {
        MenuBarConfiguration.setShowsNetworkSpeed(showsNetworkSpeed)
    }
}

private struct AccessibilityPermissionRow: View {
    @StateObject private var controller = PermissionFlow.makeController(
        configuration: .init(localeIdentifier: "zh-Hans")
    )
    @State private var authorizationState = PermissionStatusRegistry.provider(for: .accessibility).authorizationState()

    private let statusTimer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()

    private var statusTitle: String {
        authorizationState == .granted ? "已申请" : "未申请"
    }

    var body: some View {
        HStack {
            Button("申请无障碍权限") {
                controller.authorize(
                    pane: .accessibility,
                    suggestedAppURLs: [Bundle.main.bundleURL],
                    sourceFrameInScreen: clickSourceFrameInScreen()
                )
                refreshAuthorizationState()
            }

            Spacer()

            Text(statusTitle)
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: refreshAuthorizationState)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAuthorizationState()
        }
        .onReceive(statusTimer) { _ in
            refreshAuthorizationState()
        }
    }

    private func refreshAuthorizationState() {
        let latestState = PermissionStatusRegistry.provider(for: .accessibility).authorizationState()
        authorizationState = latestState

        if latestState == .granted {
            controller.closePanel(returnToPreviousApp: true)
        }
    }

    private func clickSourceFrameInScreen() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        return CGRect(x: mouseLocation.x - 16, y: mouseLocation.y - 16, width: 32, height: 32)
    }
}

private struct MenuActionIcon: View {
    let actionID: String
    let size: CGFloat

    private var iconAssetName: String? {
        switch actionID {
        case "new-markdown":
            return "logo-markdown"
        case "open-ghostty":
            return "logo-ghostty"
        case "open-vscode":
            return "logo-vscode"
        case "git-commit-push":
            return "logo-github"
        default:
            return nil
        }
    }

    private var symbolName: String {
        switch actionID {
        case "subtitles":
            return "captions.bubble"
        case "new-text":
            return "doc.text"
        case "new-markdown":
            return "chevron.left.forwardslash.chevron.right"
        case "new-word":
            return "doc.richtext"
        case "open-ghostty":
            return "terminal"
        case "open-vscode":
            return "curlybraces"
        case "git-commit-push":
            return "arrow.up.doc"
        case "copy-path":
            return "point.topleft.down.curvedto.point.bottomright.up"
        default:
            return "circle"
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch actionID {
        case "new-text":
            return [
                Color(red: 0.48, green: 0.58, blue: 0.70),
                Color(red: 0.25, green: 0.34, blue: 0.48)
            ]
        case "new-markdown":
            return [
                Color(red: 0.20, green: 0.22, blue: 0.26),
                Color(red: 0.05, green: 0.06, blue: 0.08)
            ]
        case "new-word":
            return [
                Color(red: 0.22, green: 0.46, blue: 0.96),
                Color(red: 0.07, green: 0.22, blue: 0.68)
            ]
        case "open-ghostty":
            return [
                Color(red: 0.28, green: 0.26, blue: 0.34),
                Color(red: 0.10, green: 0.10, blue: 0.14)
            ]
        case "open-vscode":
            return [
                Color(red: 0.15, green: 0.55, blue: 0.92),
                Color(red: 0.00, green: 0.32, blue: 0.67)
            ]
        case "git-commit-push":
            return [
                Color(red: 0.98, green: 0.42, blue: 0.22),
                Color(red: 0.76, green: 0.18, blue: 0.12)
            ]
        case "copy-path":
            return [
                Color(red: 0.98, green: 0.50, blue: 0.36),
                Color(red: 0.83, green: 0.22, blue: 0.18)
            ]
        default:
            return [
                Color(red: 0.18, green: 0.78, blue: 0.35),
                Color(red: 0.12, green: 0.64, blue: 0.28)
            ]
        }
    }

    private var assetPadding: CGFloat {
        switch actionID {
        case "new-markdown", "git-commit-push":
            return 5
        default:
            return 6
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)

            if let iconAssetName {
                Image(iconAssetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(assetPadding)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct WindowOperationIcon: View {
    let operation: WindowOperation
    let size: CGFloat

    private var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch operation.id {
        case WindowOperation.leftHalf.id:
            return [
                Color(red: 0.24, green: 0.58, blue: 0.96),
                Color(red: 0.10, green: 0.34, blue: 0.76)
            ]
        case WindowOperation.rightHalf.id:
            return [
                Color(red: 0.40, green: 0.52, blue: 0.96),
                Color(red: 0.18, green: 0.28, blue: 0.72)
            ]
        case WindowOperation.maximized.id:
            return [
                Color(red: 0.26, green: 0.70, blue: 0.52),
                Color(red: 0.12, green: 0.52, blue: 0.36)
            ]
        case WindowOperation.centered.id:
            return [
                Color(red: 0.56, green: 0.46, blue: 0.90),
                Color(red: 0.36, green: 0.26, blue: 0.68)
            ]
        case WindowOperation.minimizeOthers.id:
            return [
                Color(red: 0.86, green: 0.48, blue: 0.26),
                Color(red: 0.66, green: 0.24, blue: 0.16)
            ]
        default:
            return [
                Color(red: 0.48, green: 0.58, blue: 0.70),
                Color(red: 0.25, green: 0.34, blue: 0.48)
            ]
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)

            Image(systemName: operation.symbolName)
                .font(.system(size: size * 0.48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct SidebarPageLabel: View {
    let page: MagicActionsView.SettingsPage

    var body: some View {
        HStack(spacing: 12) {
            SidebarCategoryIcon(page: page)
            Text(page.title)
        }
    }
}

private struct SidebarCategoryIcon: View {
    let page: MagicActionsView.SettingsPage
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
