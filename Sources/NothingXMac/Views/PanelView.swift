// The popover panel: the main page plus sub-pages that slide in from the right,
// and the small building blocks they share.

import NothingKit
import SwiftUI

enum PanelPage: Equatable {
    case main, quickSettings, equalizer, earTip
    case controls(GestureSide)
}

final class PanelNavigation: ObservableObject {
    @Published var page: PanelPage = .main
}

struct PanelView: View {
    static let width: CGFloat = 300

    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        ZStack {
            switch nav.page {
            case .main:
                MainView().transition(.move(edge: .leading).combined(with: .opacity))
            case .quickSettings:
                QuickSettingsView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .equalizer:
                EqualizerView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .controls(let side):
                ControlsView(side: side).transition(.move(edge: .trailing).combined(with: .opacity))
            case .earTip:
                EarTipTestView().transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: Self.width)
        .padding(.vertical, 6)
        .animation(.easeOut(duration: 0.18), value: nav.page)
        .background(
            // Esc returns to the main page.
            Button("") { nav.page = .main }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
        .onChange(of: device.state.connected) { connected in
            if !connected { nav.page = .main }
        }
    }
}

// MARK: - Shared pieces

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }
}

struct PanelDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 14).padding(.vertical, 5)
    }
}

/// Round icon badge, accent-filled when on, with a spinner while a change is unconfirmed.
struct IconBadge: View {
    let symbol: String
    var on = false
    var pending = false
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(on ? Color.accentColor : Color.primary.opacity(0.1))
            if pending {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                    .tint(on ? .white : .secondary)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .medium))
                    .foregroundStyle(on ? Color.white : Color.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A full-width row that highlights on hover, like menu items.
struct HoverRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRow(configuration: configuration)
    }

    private struct HoverRow: View {
        let configuration: ButtonStyle.Configuration
        @StateObject private var hovering = Local(false)
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(hovering.value && enabled ? 0.08 : 0))
                )
                .padding(.horizontal, 6)
                .opacity(enabled ? 1 : 0.45)
                .onHover { hovering.value = $0 }
        }
    }
}

/// Control Center style tile: badge + name + state line.
struct Tile: View {
    let symbol: String
    let name: String
    let detail: String
    var on = false
    var pending = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IconBadge(symbol: symbol, on: on, pending: pending)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 12, weight: .medium))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Back chevron + title for sub-pages.
struct SubpageHeader: View {
    let title: String
    @EnvironmentObject var nav: PanelNavigation
    var back: PanelPage = .main

    var body: some View {
        HStack(spacing: 4) {
            Button { nav.page = back } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back")
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

struct FooterNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
    }
}

/// View-local state. Stands in for @State, which is a macro in the current SDK
/// whose plugin only ships with Xcode, not the Command Line Tools.
final class Local<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
