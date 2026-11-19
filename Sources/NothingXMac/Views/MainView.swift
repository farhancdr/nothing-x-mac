// Main page: header, battery, noise control (with intensity) and Bass Enhance.

import NothingKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    private var state: DeviceState { device.state }

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.connected {
                BatteryRow()
                PanelDivider()
                NoiseControlSection()
                if state.capabilities.bassSteps > 0, state.bass != nil {
                    PanelDivider()
                    BassSection()
                }
            } else {
                Text("Connect your Nothing or CMF earbuds in Bluetooth settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                Button("Open Bluetooth Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .padding(.bottom, 10)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(state.connected ? Color.accentColor : Color.primary.opacity(0.1))
                Image(nsImage: MenuBarIcon.make())
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(state.connected ? Color.white : Color.primary)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.connected ? (state.name ?? "Earbuds") : "No Earbuds")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(state.connected ? "Connected" : "Not connected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HeaderButton(symbol: "slider.vertical.3", help: "Equalizer") { nav.page = .equalizer }
                .disabled(!state.connected || state.capabilities.eq.presets.isEmpty)
            HeaderButton(symbol: "gearshape", help: "Quick Settings") { nav.page = .quickSettings }
                .disabled(!state.connected)
            HeaderButton(symbol: "power", help: "Quit Nothing X Mac") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @StateObject private var hovering = Local(false)
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(hovering.value && enabled ? 0.1 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .help(help)
        .onHover { hovering.value = $0 }
    }
}

// MARK: - Battery

private struct BatteryRow: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let battery = device.state.battery
        let gestures = device.state.capabilities.gestures != nil
        HStack(spacing: 0) {
            if device.state.capabilities.ring == .buds || battery.left != nil || battery.right != nil {
                BudColumn(symbol: "airpodpro.left", label: "Left", info: battery.left,
                          clickable: gestures) { nav.page = .controls(.left) }
                BudColumn(symbol: "airpodpro.right", label: "Right", info: battery.right,
                          clickable: gestures) { nav.page = .controls(.right) }
            } else {
                BudColumn(symbol: "headphones", label: "Battery", info: battery.stereo, clickable: false) {}
            }
            // No case data (e.g. closed or out of range): drop the column so the buds sit centred.
            if let info = battery.case {
                BudColumn(symbol: "earbuds.case.fill", label: "Case", info: info, clickable: false) {}
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private struct BudColumn: View {
    let symbol: String
    let label: String
    let info: BatteryLevel?
    let clickable: Bool
    let action: () -> Void
    @StateObject private var hovering = Local(false)

    var body: some View {
        Button { if clickable { action() } } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .light))
                    .frame(height: 34)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if info?.charging == true {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(.green)
                    }
                    Text(info.map { "\($0.level)%" } ?? "—")
                        .font(.system(size: 11).monospacedDigit())
                    BatteryGlyph(info: info)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(clickable && hovering.value ? 0.07 : 0)))
            .opacity(info == nil ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(clickable)
        .help(clickable ? "\(label) earbud controls" : "")
        .onHover { hovering.value = $0 }
    }
}

private struct BatteryGlyph: View {
    let info: BatteryLevel?

    var body: some View {
        let level = CGFloat(info?.level ?? 0) / 100
        let low = (info.map { !$0.charging && $0.level <= 20 }) ?? false
        let color: Color = info?.charging == true ? .green : low ? .red : .primary
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: max(0, 18 * level))
                    .padding(1.5)
            }
            .frame(width: 22, height: 10)
            RoundedRectangle(cornerRadius: 1).fill(Color.primary.opacity(0.35)).frame(width: 1.5, height: 4)
        }
    }
}

// MARK: - Noise control

private struct NoiseControlSection: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let state = device.state
        let caps = state.capabilities
        VStack(spacing: 0) {
            SectionTitle("Noise Control")
            option(.anc, "Noise Cancellation", "person.wave.2.fill")
            if caps.transparency {
                option(.transparency, "Transparency", "ear.and.waveform")
            }
            option(.off, "Off", "person.fill")

            if state.noiseMode == .anc, !caps.strengths.isEmpty {
                SectionTitle("Intensity").padding(.top, 4)
                StrengthPicker()
            }
        }
    }

    private func option(_ mode: NoiseMode, _ label: String, _ symbol: String) -> some View {
        let selected = device.state.noiseMode == mode
        return Button { device.setNoiseMode(mode) } label: {
            HStack(spacing: 10) {
                IconBadge(symbol: symbol, on: selected, pending: selected && device.state.noisePending)
                Text(label).font(.system(size: 13))
                Spacer()
            }
        }
        .buttonStyle(HoverRowStyle())
        .disabled(device.state.noisePending && !selected)
    }
}

private struct StrengthPicker: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let caps = device.state.capabilities
        let options = caps.adaptive ? caps.strengths + [.adaptive] : caps.strengths
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { strength in
                segment(strength)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .disabled(device.state.noisePending)
    }

    private func segment(_ strength: AncStrength) -> some View {
        let selected = device.state.ancStrength == strength
        let (label, symbol): (String, String) = {
            switch strength {
            case .low: return ("Low", "dial.low")
            case .mid: return ("Mid", "dial.medium")
            case .high: return ("High", "dial.high")
            case .adaptive: return ("Auto", "sparkles")
            }
        }()
        return Button { device.setAncStrength(strength) } label: {
            VStack(spacing: 2) {
                if selected && device.state.noisePending {
                    ProgressView().controlSize(.small).scaleEffect(0.6).frame(height: 14)
                } else {
                    Image(systemName: symbol).font(.system(size: 12)).frame(height: 14)
                }
                Text(label).font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color(nsColor: .controlBackgroundColor) : .clear)
                .shadow(color: .black.opacity(selected ? 0.15 : 0), radius: 1, y: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(strength == .adaptive ? "Adaptive" : label)
    }
}

// MARK: - Bass Enhance

private struct BassSection: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let bass = device.state.bass ?? BassValue(enabled: false, level: 1)
        let pending = device.state.bassPending
        let levels = device.state.capabilities.bassLevels
        let filled = bass.enabled ? (levels.firstIndex(of: bass.level).map { $0 + 1 } ?? 0) : 0

        VStack(spacing: 0) {
            SectionTitle("Bass Enhance")
            HStack(spacing: 10) {
                Button { device.setBass(enabled: !bass.enabled) } label: {
                    IconBadge(symbol: "hifispeaker.fill", on: bass.enabled, pending: pending, size: 30)
                }
                .buttonStyle(.plain)
                .help(bass.enabled ? "Turn off Bass Enhance" : "Turn on Bass Enhance")

                // Stepped capsule: each step shows a waveform that grows with the level.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(filled) / CGFloat(max(levels.count, 1)))
                        HStack(spacing: 0) {
                            ForEach(Array(levels.enumerated()), id: \.offset) { i, level in
                                Button { device.setBass(enabled: true, level: level) } label: {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 7 + 8 * CGFloat(i) / CGFloat(max(levels.count - 1, 1))))
                                        .foregroundStyle(i < filled ? Color.white : Color.secondary)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Level \(level)")
                            }
                        }
                    }
                }
                .frame(height: 30)
                .opacity(bass.enabled ? 1 : 0.6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .disabled(pending)
        }
    }
}
