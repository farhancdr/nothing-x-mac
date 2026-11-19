// Main page: header, dot-matrix battery cells, noise control (with intensity)
// and Bass Enhance. Before a connection it shows the "not connected" guide,
// or a skeleton while the control channel is opening.

import NothingKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    private var state: DeviceState { device.state }

    var body: some View {
        VStack(spacing: 0) {
            MainHeader()
            PanelSeparator()
            if state.connected {
                if !state.recognized {
                    TipBox(bold: "Limited support.",
                           text: "This model isn't recognised yet, so some controls may not work.")
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
                BatteryCells()
                PanelSeparator()
                NoiseControlSection()
                if state.capabilities.bassSteps > 0, state.bass != nil {
                    PanelSeparator()
                    BassSection()
                }
            } else if state.connecting != nil {
                ConnectingSkeleton()
            } else {
                NotConnectedView()
            }
        }
    }
}

// MARK: - Header

private struct MainHeader: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let state = device.state
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    if state.connected {
                        Circle().fill(Theme.label).frame(width: 6, height: 6)
                    } else if state.connecting != nil {
                        PendingSpinner(size: 9)
                    }
                    Text(status).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
            // Nothing to configure until the buds are connected; Quit stays in the right-click menu.
            if state.connected {
                if !state.capabilities.eq.presets.isEmpty {
                    HeaderIconButton(symbol: "slider.vertical.3", help: "Equalizer") { nav.page = .equalizer }
                }
                HeaderIconButton(symbol: "square.grid.2x2", help: "Quick Settings") { nav.page = .quickSettings }
                HeaderIconButton(symbol: "power", help: "Quit Nothing X Mac") { NSApp.terminate(nil) }
            }
        }
        .padding(.leading, Theme.inset)
        .padding(.trailing, 10)
        .frame(height: 50)
    }

    private var title: String {
        let state = device.state
        if state.connected { return state.name ?? "Earbuds" }
        return state.connecting ?? "Nothing X Mac"
    }

    private var status: String {
        let state = device.state
        if state.connected { return state.recognized ? "Connected" : "Unrecognised model" }
        return state.connecting != nil ? "Connecting…" : "Not connected"
    }
}

// MARK: - Battery

private struct BatteryCells: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let battery = device.state.battery
        let caps = device.state.capabilities
        let gestures = caps.gestures != nil
        HStack(spacing: 4) {
            if caps.ring == .buds || battery.left != nil || battery.right != nil {
                BatteryCell(icon: .bud(mirrored: true), label: "Left", info: battery.left,
                            action: gestures ? { nav.page = .controls(.left) } : nil)
                BatteryCell(icon: .bud(mirrored: false), label: "Right", info: battery.right,
                            action: gestures ? { nav.page = .controls(.right) } : nil)
                BatteryCell(icon: .symbol("earbuds.case"), label: "Case", info: battery.case, action: nil)
            } else {
                BatteryCell(icon: .symbol("headphones"), label: "Battery", info: battery.stereo, action: nil)
                Spacer().frame(maxWidth: .infinity)
                Spacer().frame(maxWidth: .infinity)
            }
        }
        .padding(8)
    }
}

enum CellIcon {
    case bud(mirrored: Bool)
    case symbol(String)
}

/// One battery column: icon + label, 5×7 dot numerals and a 10-dot level row.
/// ≤20% (not charging) turns the numerals accent; charging or low lights the row in accent.
struct BatteryCell: View {
    let icon: CellIcon
    let label: String
    let info: BatteryLevel?
    let action: (() -> Void)?
    var skeleton = false
    @Environment(\.accent) private var accent
    @StateObject private var hovering = Local(false)

    var body: some View {
        let low = info.map { !$0.charging && $0.level <= 20 } ?? false
        let charging = info?.charging == true
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 4) {
                    switch icon {
                    case .bud(let mirrored):
                        DotBudView(look: skeleton ? .disconnected : .connected, size: 12,
                                   mirrored: mirrored, color: Theme.secondaryLabel)
                    case .symbol(let name):
                        Image(systemName: name).font(.system(size: 10)).foregroundStyle(Theme.secondaryLabel)
                            .frame(width: 12, height: 12)
                    }
                    Text(label).font(.system(size: 11, weight: .medium))
                    Spacer(minLength: 0)
                    if charging {
                        Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(accent)
                            .accessibilityLabel("Charging")
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    DotDigits(text: info.map { "\($0.level)" } ?? "--",
                              on: info == nil ? Theme.tertiary : low ? accent : Theme.label)
                    Text("%").font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                }
                DotMeter(count: 10, lit: info.map { Int((Double($0.level) / 10).rounded(.up)) } ?? 0,
                         on: charging || low ? accent : Theme.label)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(action != nil && hovering.value ? Theme.controlFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
        .help(action != nil ? "\(label) earbud controls" : "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(info.map { "\($0.level) percent\($0.charging ? ", charging" : "")" } ?? "unknown")")
        .onHover { hovering.value = $0 }
    }
}

// MARK: - Noise control

private struct NoiseControlSection: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let state = device.state
        let caps = state.capabilities
        var modes: [SegmentItem<NoiseMode>] = [SegmentItem(id: .anc, label: "ANC", symbol: "circle.inset.filled")]
        if caps.transparency {
            modes.append(SegmentItem(id: .transparency, label: "Transparency", symbol: "circle.dashed"))
        }
        modes.append(SegmentItem(id: .off, label: "Off", symbol: "circle.slash"))
        let strengths = caps.adaptive ? caps.strengths + [.adaptive] : caps.strengths

        return VStack(spacing: 0) {
            SectionCaption("Noise Control").padding(.top, 12)
            DotSegmented(items: modes, selection: state.noiseMode, pending: state.noisePending) {
                device.setNoiseMode($0)
            }
            .padding(.horizontal, Theme.inset)

            if state.noiseMode == .anc, !strengths.isEmpty {
                HStack(spacing: 8) {
                    Text("Intensity").font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                    DotSegmented(items: strengths.map { SegmentItem(id: $0, label: Self.label($0)) },
                                 selection: state.ancStrength, pending: state.noisePending,
                                 height: 28) { device.setAncStrength($0) }
                }
                .padding(.horizontal, Theme.inset)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.2), value: state.noiseMode == .anc)
    }

    static func label(_ strength: AncStrength) -> String {
        switch strength {
        case .low: return "Low"
        case .mid: return "Mid"
        case .high: return "High"
        case .adaptive: return "Adaptive"
        }
    }
}

// MARK: - Bass Enhance

private struct BassSection: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let bass = device.state.bass ?? BassValue(enabled: false, level: 1)
        let pending = device.state.bassPending
        let levels = device.state.capabilities.bassLevels
        let index = levels.firstIndex(of: bass.level) ?? 0

        VStack(spacing: 10) {
            HStack {
                Text("Bass Enhance").font(.system(size: 13))
                if pending { PendingSpinner(size: 11) }
                Spacer()
                Toggle("Bass Enhance", isOn: Binding(get: { bass.enabled },
                                                     set: { device.setBass(enabled: $0) }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            HStack {
                SteppedSlider(steps: levels.count, index: index) { i in
                    device.setBass(enabled: true, level: levels[i])
                }
                .frame(width: 200)
                Spacer()
                Text("Level \(index + 1)").font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .opacity(bass.enabled ? 1 : 0.4)
        }
        .padding(.horizontal, Theme.inset)
        .padding(.vertical, 14)
        .allowsHitTesting(!pending)
    }
}

/// Slider with detents: 4 pt track, accent fill, 16 pt white knob, a tick per step.
struct SteppedSlider: View {
    let steps: Int
    let index: Int
    let onChange: (Int) -> Void
    @Environment(\.accent) private var accent

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 16
            let usable = geo.size.width - knob
            let step = steps > 1 ? usable / CGFloat(steps - 1) : 0
            let x = knob / 2 + CGFloat(index) * step
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.trackOff).frame(height: 4)
                Capsule().fill(accent).frame(width: x, height: 4)
                ForEach(0..<max(steps, 0), id: \.self) { i in
                    Circle().fill(i <= index ? Color.white.opacity(0.9) : Theme.tertiary)
                        .frame(width: 3, height: 3)
                        .position(x: knob / 2 + CGFloat(i) * step, y: geo.size.height / 2)
                }
                Circle().fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .frame(width: knob, height: knob)
                    .position(x: x, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                guard steps > 1 else { return }
                let i = Int(((value.location.x - knob / 2) / step).rounded())
                let clamped = min(max(i, 0), steps - 1)
                if clamped != index { onChange(clamped) }
            })
            .animation(.easeOut(duration: 0.15), value: index)
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Level")
        .accessibilityValue("\(index + 1) of \(steps)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if index < steps - 1 { onChange(index + 1) }
            case .decrement: if index > 0 { onChange(index - 1) }
            @unknown default: break
            }
        }
    }
}

// MARK: - Before a connection

private struct ConnectingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                BatteryCell(icon: .bud(mirrored: true), label: "Left", info: nil, action: nil, skeleton: true)
                BatteryCell(icon: .bud(mirrored: false), label: "Right", info: nil, action: nil, skeleton: true)
                BatteryCell(icon: .symbol("earbuds.case"), label: "Case", info: nil, action: nil, skeleton: true)
            }
            .padding(8)
            PanelSeparator()
            VStack(spacing: 0) {
                SectionCaption("Noise Control").padding(.top, 12)
                DotSegmented(items: [SegmentItem(id: 0, label: "ANC", symbol: "circle.inset.filled"),
                                     SegmentItem(id: 1, label: "Transparency", symbol: "circle.dashed"),
                                     SegmentItem(id: 2, label: "Off", symbol: "circle.slash")],
                             selection: nil) { _ in }
                    .padding(.horizontal, Theme.inset)
                    .padding(.bottom, 12)
            }
            .opacity(0.4)
            FooterNote("If this takes long, close the Nothing X or CMF app on your phone. The earbuds accept one controller at a time.")
                .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }
}

private struct NotConnectedView: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        VStack(spacing: 0) {
            DotBudView(look: .disconnected, size: 44, color: Theme.label)
                .padding(.top, 18)
            Text("No earbuds connected")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 12)
            Text("Pair your earbuds in System Settings › Bluetooth. They show up here once connected.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open Bluetooth Settings").frame(maxWidth: .infinity)
            }
            .buttonStyle(PanelButtonStyle())
            .padding(.horizontal, Theme.inset)
            .padding(.top, 14)

            if !device.paired.isEmpty {
                SectionCaption("Paired").padding(.top, 16)
                VStack(spacing: 4) {
                    ForEach(device.paired) { buds in
                        PairedRow(buds: buds)
                    }
                }
                .padding(.horizontal, Theme.inset)
            }

            TipBox(bold: "Phone app open?",
                   text: "Close Nothing X on your phone. The earbuds accept only one controller at a time.")
                .padding(.horizontal, Theme.inset)
                .padding(.top, 12)
                .padding(.bottom, Theme.inset)
        }
    }
}

private struct PairedRow: View {
    let buds: BluetoothTransport.PairedEarbuds
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let linking = device.linking == buds.address
        HStack(spacing: 10) {
            DotBudView(look: linking ? .connecting : .disconnected, size: 14, color: Theme.secondaryLabel)
            Text(buds.name).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 4)
            if linking {
                PendingSpinner(size: 12)
            } else {
                Button("Connect") { device.connectPaired(buds.address) }
                    .buttonStyle(PanelButtonStyle())
                    .controlSize(.small)
                    .disabled(device.linking != nil)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.separator))
    }
}
