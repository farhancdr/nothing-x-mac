// Controls page (gestures): pick the left or right bud, then a pop-up per
// gesture. When a gesture is set to Noise Control, checkboxes choose which
// modes it cycles through. Opened by clicking a bud on the main page.

import NothingKit
import SwiftUI

struct ControlsView: View {
    let side: GestureSide
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation

    var body: some View {
        let state = device.state
        VStack(spacing: 0) {
            SubpageHeader(title: "Controls", back: .main)

            DotSegmented(items: GestureSide.allCases.map { SegmentItem(id: $0, label: $0.label) },
                         selection: side, height: 28, labelSize: 12) { nav.page = .controls($0) }
                .padding(.horizontal, Theme.inset)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if let caps = state.capabilities.gestures {
                ForEach(caps.slots) { slot in
                    GestureRow(side: side, slot: slot)
                    if slot.actions.contains(where: { $0.choice == .noiseControl }),
                       let code = state.gestures.code(side, slot.key),
                       let cycle = GestureCapabilities.noiseCycles[code] {
                        NoiseCycleRows(side: side, slotKey: slot.key, cycle: cycle)
                    }
                }
            }

            FooterNote("Changes apply to the \(side.label) earbud only.")
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
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
        HStack(spacing: 10) {
            Image(systemName: "hand.tap").font(.system(size: 13)).foregroundStyle(Theme.secondaryLabel)
                .frame(width: 16)
            Text(slot.label.replacingOccurrences(of: " and ", with: " & "))
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if pending { PendingSpinner(size: 11) }
            Picker(slot.label, selection: Binding(
                get: { current ?? slot.actions.first!.choice },
                set: { device.setGesture(side, slot: slot.key, choice: $0) })) {
                ForEach(slot.actions, id: \.self) { action in
                    Text(action.label).tag(action.choice)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 132)
            .disabled(pending || current == nil)
        }
        .padding(.horizontal, Theme.inset)
        .frame(minHeight: 40)
    }
}

private struct NoiseCycleRows: View {
    let side: GestureSide
    let slotKey: String
    let cycle: NoiseCycle
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let onCount = [cycle.anc, cycle.transparency, cycle.off].filter { $0 }.count
        VStack(alignment: .leading, spacing: 5) {
            Text("Cycles through").font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
            row("Noise Cancellation", cycle.anc, onCount) { var c = cycle; c.anc = $0; return c }
            row("Transparency", cycle.transparency, onCount) { var c = cycle; c.transparency = $0; return c }
            row("Off", cycle.off, onCount) { var c = cycle; c.off = $0; return c }
            Text("Pick at least two.").font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.inset + 26)
        .padding(.trailing, Theme.inset)
        .padding(.bottom, 8)
    }

    private func row(_ label: String, _ on: Bool, _ onCount: Int, _ change: @escaping (Bool) -> NoiseCycle) -> some View {
        Toggle(isOn: Binding(get: { on }, set: { device.setGestureNoiseCycle(side, slot: slotKey, cycle: change($0)) })) {
            Text(label).font(.system(size: 13))
        }
        .toggleStyle(.checkbox)
        // The last two ticked modes can't be cleared.
        .disabled(on && onCount <= 2)
    }
}
