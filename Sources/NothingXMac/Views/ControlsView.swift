// Controls page (gestures), styled after macOS AirPods settings: pick the left
// or right bud, then a grouped list of its gestures with pop-up menus. When a
// gesture is set to Noise Control, checkboxes choose which modes it cycles.
// Opened by clicking a bud in the battery row (models with gesture support).

import NothingKit
import SwiftUI

struct ControlsView: View {
    let side: GestureSide
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let state = device.state
        VStack(spacing: 8) {
            SubpageHeader(title: "Controls")

            HStack(spacing: 8) {
                ForEach(GestureSide.allCases) { s in
                    Button { nav.page = .controls(s) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: s == .left ? "airpodpro.left" : "airpodpro.right")
                                .font(.system(size: 24, weight: .light))
                            Text(s.label).font(.system(size: 12))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(s == side ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: s == side ? 2 : 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            if let caps = state.capabilities.gestures {
                group(title: "\(side.label) Earbud") {
                    ForEach(caps.slots) { slot in
                        GestureRow(side: side, slot: slot)
                        if slot.id != caps.slots.last?.id { Divider().padding(.leading, 10) }
                    }
                }

                // Noise Control checkboxes for the gesture that's set to Noise Control.
                if let slot = caps.slots.first(where: { $0.actions.contains { $0.choice == .noiseControl } }),
                   let code = state.gestures.code(side, slot.key),
                   let cycle = GestureCapabilities.noiseCycles[code] {
                    group(title: "Noise Control") {
                        NoiseCycleRows(side: side, slotKey: slot.key, cycle: cycle)
                    }
                    FooterNote("Tap and hold switches between these. Choose at least two.")
                }
            }
        }
    }

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0, content: content)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
        }
        .padding(.horizontal, 12)
    }
}

private struct GestureRow: View {
    let side: GestureSide
    let slot: GestureSlot
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let code = device.state.gestures.code(side, slot.key)
        let current = code.map(GestureCapabilities.choice(for:))
        let pending = device.state.gestures.pending.contains("\(side.rawValue).\(slot.key)")
        HStack {
            Text(slot.label).font(.system(size: 12))
            Spacer()
            if pending { ProgressView().controlSize(.small).scaleEffect(0.6) }
            Menu {
                ForEach(slot.actions, id: \.self) { action in
                    Button {
                        device.setGesture(side, slot: slot.key, choice: action.choice)
                    } label: {
                        if action.choice == current {
                            Label(action.label, systemImage: "checkmark")
                        } else {
                            Text(action.label)
                        }
                    }
                }
            } label: {
                Text(slot.actions.first { $0.choice == current }?.label ?? "—")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private struct NoiseCycleRows: View {
    let side: GestureSide
    let slotKey: String
    let cycle: NoiseCycle
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let onCount = [cycle.anc, cycle.transparency, cycle.off].filter { $0 }.count
        VStack(spacing: 0) {
            row("Noise Cancellation", cycle.anc, onCount) { var c = cycle; c.anc = $0; return c }
            Divider().padding(.leading, 10)
            row("Transparency", cycle.transparency, onCount) { var c = cycle; c.transparency = $0; return c }
            Divider().padding(.leading, 10)
            row("Off", cycle.off, onCount) { var c = cycle; c.off = $0; return c }
        }
    }

    private func row(_ label: String, _ on: Bool, _ onCount: Int, _ change: @escaping (Bool) -> NoiseCycle) -> some View {
        Toggle(isOn: Binding(get: { on }, set: { device.setGestureNoiseCycle(side, slot: slotKey, cycle: change($0)) })) {
            Text(label).font(.system(size: 12))
        }
        .toggleStyle(.checkbox)
        // Keep at least two modes: the last two can't be unticked.
        .disabled(on && onCount <= 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
