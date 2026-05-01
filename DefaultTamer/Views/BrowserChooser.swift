//
//  BrowserChooser.swift
//  Default Tamer
//
//  Browser picker popup with drag-to-reorder and inline rule-save options.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - BrowserChooser

struct BrowserChooser: View {
    let url: URL
    @EnvironmentObject var appState: AppState

    @State private var localBrowsers: [Browser] = []
    @State private var selectedIndex = 0
    @State private var hoveredIndex: Int? = nil
    @State private var draggingId: String? = nil
    @State private var keyMonitor: Any?
    @State private var saveOption: SaveRuleOption = .noSave

    private let sidePadding: CGFloat = 20
    private let cellSize: CGFloat = 60
    private let cellSpacing: CGFloat = 12

    private var isUnmatchedReason: Bool {
        appState.chooserReason == .noRuleMatch
    }

    /// In the unmatched case the user is also choosing a save-rule option,
    /// so number keys and clicks should only highlight — the user confirms
    /// via Enter or the Open button. Modifier-key invocations are quick
    /// one-off overrides and keep the immediate-commit behavior.
    private var requiresExplicitConfirm: Bool { isUnmatchedReason }

    private var ruleHost: String {
        guard let host = url.host, !host.isEmpty else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var sourceAppDisplayName: String? {
        guard let bundleId = appState.chooserSourceApp else { return nil }
        return SourceAppDetector.getAppName(for: bundleId) ?? bundleId
    }

    private var activeName: String {
        let idx = hoveredIndex ?? selectedIndex
        guard idx >= 0 && idx < localBrowsers.count else { return "" }
        return localBrowsers[idx].displayName
    }

    private var browserRowWidth: CGFloat {
        CGFloat(localBrowsers.count) * cellSize
            + CGFloat(max(0, localBrowsers.count - 1)) * cellSpacing
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open in...")
                        .font(.system(size: 13, weight: .semibold))
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, sidePadding)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Browser row
            HStack(spacing: cellSpacing) {
                ForEach(Array(localBrowsers.enumerated()), id: \.element.id) { index, browser in
                    BrowserIconItem(
                        browser: browser,
                        isSelected: index == selectedIndex,
                        isHovered: index == hoveredIndex,
                        shortcut: index < 9 ? index + 1 : nil,
                        action: {
                            // In the unmatched case the click only highlights — the user
                            // commits via Enter or the Open button so they can also pick
                            // a save-rule option without prematurely opening the link.
                            if requiresExplicitConfirm {
                                selectedIndex = index
                            } else {
                                commitBrowser(browser)
                            }
                        }
                    )
                    .opacity(draggingId == browser.id ? 0.4 : 1)
                    .onHover { over in hoveredIndex = over ? index : nil }
                    .onDrag {
                        draggingId = browser.id
                        return NSItemProvider(object: browser.id as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: BrowserDropDelegate(
                            targetId: browser.id,
                            browsers: $localBrowsers,
                            draggingId: $draggingId,
                            onComplete: { appState.setBrowserOrder($0.map(\.id)) }
                        )
                    )
                }
            }
            .frame(minWidth: browserRowWidth, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, sidePadding)
            .padding(.bottom, 4)

            // Active browser name
            Text(activeName)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 16)
                .animation(.easeInOut(duration: 0.12), value: activeName)
                .padding(.bottom, 8)

            // Save Rule section
            if isUnmatchedReason && !ruleHost.isEmpty {
                Divider()
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 6) {
                    RadioRow(isSelected: saveOption == .noSave, action: { saveOption = .noSave }) {
                        Text("Don't save rule").font(.system(size: 11))
                    }

                    if let appName = sourceAppDisplayName {
                        RadioRow(isSelected: saveOption == .byApp, action: { saveOption = .byApp }) {
                            HStack(spacing: 3) {
                                Text("By app:").font(.system(size: 11))
                                Text(appName).font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .help("Links from \(appName) always open in the chosen browser")
                    }

                    RadioRow(isSelected: saveOption == .byDomain, action: { saveOption = .byDomain }) {
                        HStack(spacing: 3) {
                            Text("By domain:").font(.system(size: 11))
                            Text(ruleHost).font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .help("\(ruleHost) and its subdomains always open in the chosen browser")

                    RadioRow(isSelected: saveOption == .byExact, action: { saveOption = .byExact }) {
                        HStack(spacing: 3) {
                            Text("Exact:").font(.system(size: 11))
                            Text(ruleHost).font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .help("Only \(ruleHost) (no subdomains) always opens in the chosen browser")
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 10)

                HStack {
                    Spacer()
                    Button(action: {
                        guard selectedIndex >= 0 && selectedIndex < localBrowsers.count else { return }
                        commitBrowser(localBrowsers[selectedIndex])
                    }) {
                        Text("Open in \(activeName)")
                            .font(.system(size: 12, weight: .medium))
                            .frame(minWidth: 140)
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 10)
            }

            // Hint
            Text("← →  or  1–\(min(localBrowsers.count, 9))  ·  Enter  ·  Esc  ·  drag to reorder")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)
        }
        .frame(minWidth: browserRowWidth + sidePadding * 2)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            ZStack {
                VisualEffectBlur()
                Color(nsColor: .windowBackgroundColor).opacity(0.82)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.55), radius: 30, y: 10)
        .onAppear {
            localBrowsers = sortedBrowsers()

            if isUnmatchedReason {
                let preferred = appState.settings.defaultChooserSaveOption
                saveOption = (preferred == .byApp && sourceAppDisplayName == nil) ? .byDomain : preferred
            } else {
                saveOption = .noSave
            }
            setupKeyboardMonitor()
        }
        .onDisappear { removeKeyboardMonitor() }
    }

    // MARK: - Browser Ordering

    private func sortedBrowsers() -> [Browser] {
        let available = appState.browserManager.availableBrowsers
        let order = appState.settings.browserOrder
        guard !order.isEmpty else { return available }
        let sorted = order.compactMap { id in available.first(where: { $0.id == id }) }
        let remaining = available.filter { b in !order.contains(b.id) }
        return sorted + remaining
    }

    // MARK: - Keyboard

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123, 126: // Left / Up
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 124, 125: // Right / Down
                if selectedIndex < localBrowsers.count - 1 { selectedIndex += 1 }
                return nil
            case 36: // Return
                if selectedIndex >= 0 && selectedIndex < localBrowsers.count {
                    commitBrowser(localBrowsers[selectedIndex])
                }
                return nil
            case 53: // Escape
                closeChooser()
                return nil
            default:
                if let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1 && num <= min(localBrowsers.count, 9) {
                    // In the unmatched case, number keys only highlight — the user
                    // confirms via Enter or the Open button so they can also pick a
                    // save-rule option without prematurely opening the link.
                    if requiresExplicitConfirm {
                        selectedIndex = num - 1
                    } else {
                        commitBrowser(localBrowsers[num - 1])
                    }
                    return nil
                }
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Actions

    private func commitBrowser(_ browser: Browser) {
        switch saveOption {
        case .noSave:   appState.openURLFromChooser(url, browserId: browser.id)
        case .byApp:    appState.openURLFromChooserAndSaveSourceAppRule(url, browserId: browser.id)
        case .byDomain: appState.openURLFromChooserAndSaveRule(url, browserId: browser.id, matchType: .suffix)
        case .byExact:  appState.openURLFromChooserAndSaveRule(url, browserId: browser.id, matchType: .exact)
        }
    }

    private func closeChooser() {
        appState.showChooser = false
        appState.chooserURL = nil
        appState.chooserSourceApp = nil
    }
}

// MARK: - Drag-to-reorder delegate

struct BrowserDropDelegate: DropDelegate {
    let targetId: String
    @Binding var browsers: [Browser]
    @Binding var draggingId: String?
    let onComplete: ([Browser]) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingId = nil }
        guard let fromId = draggingId,
              fromId != targetId,
              let fromIdx = browsers.firstIndex(where: { $0.id == fromId }),
              let toIdx   = browsers.firstIndex(where: { $0.id == targetId })
        else { return false }

        var updated = browsers
        updated.move(
            fromOffsets: IndexSet(integer: fromIdx),
            toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
        )
        browsers = updated
        onComplete(updated)
        return true
    }
}

// MARK: - Radio Row

struct RadioRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                content()
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Browser Icon Item

struct BrowserIconItem: View {
    let browser: Browser
    let isSelected: Bool
    let isHovered: Bool
    let shortcut: Int?
    let action: () -> Void

    private let iconSize: CGFloat = 38
    private let cellWidth: CGFloat = 60

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected ? Color.accentColor.opacity(0.18) :
                            isHovered  ? Color.primary.opacity(0.06) : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.accentColor.opacity(0.6) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: cellWidth, height: cellWidth)

                    if let icon = browser.getIcon() {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 26))
                            .frame(width: iconSize, height: iconSize)
                    }
                }

                if let num = shortcut {
                    Text("\(num)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .frame(width: cellWidth)
                }
            }
            .frame(width: cellWidth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(browser.displayName)
    }
}

// MARK: - Vibrancy background

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Key-accepting borderless panel

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
