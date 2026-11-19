// Equalizer page: preset tiles and, for Custom, a live curve over Bass / Mid /
// Treble sliders (−6..+6 dB), plus locally saved custom EQs.

import NothingKit
import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var settings: AppSettings

    private var eq: EqState { device.state.eq }
    private var caps: EqCapabilities { device.state.capabilities.eq }

    var body: some View {
        VStack(spacing: 8) {
            SubpageHeader(title: "Equalizer")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(caps.presets) { preset in
                    let selected = eq.preset == preset.id
                    Tile(symbol: Self.symbol(for: preset.key), name: preset.label,
                         detail: selected ? "Selected" : " ",
                         on: selected, pending: selected && eq.pending) {
                        device.setEqPreset(preset.id)
                    }
                    .disabled(eq.pending && !selected)
                }
            }
            .padding(.horizontal, 12)

            if let customId = caps.customId, eq.preset == customId {
                CustomEqEditor(bands: eq.custom ?? CustomEq())
            }
        }
    }

    static func symbol(for key: String) -> String {
        switch key {
        case "balanced": return "equal.circle"
        case "moreBass": return "speaker.wave.3.fill"
        case "moreTreble": return "waveform.path.ecg"
        case "voice": return "person.wave.2"
        case "dirac": return "sparkles"
        case "pop": return "music.note"
        case "rock": return "guitars.fill"
        case "classical": return "pianokeys"
        case "electronic": return "waveform.path"
        case "vocals": return "music.mic"
        case "custom": return "slider.horizontal.3"
        default: return "music.note"
        }
    }
}

private struct CustomEqEditor: View {
    let bands: CustomEq
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var settings: AppSettings
    @StateObject private var saving = Local(false)
    @StateObject private var newName = Local("")

    var body: some View {
        VStack(spacing: 6) {
            EqCurve(bands: bands)
                .frame(height: 64)
                .padding(.horizontal, 14)

            slider("Bass", bands.bass) { var b = bands; b.bass = $0; device.setCustomEq(b) }
            slider("Mid", bands.mid) { var b = bands; b.mid = $0; device.setCustomEq(b) }
            slider("Treble", bands.treble) { var b = bands; b.treble = $0; device.setCustomEq(b) }

            savedPresets
        }
    }

    private func slider(_ name: String, _ value: Int, _ set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.system(size: 12)).frame(width: 44, alignment: .leading)
            Slider(value: Binding(get: { Double(value) }, set: { set(Int($0.rounded())) }), in: -6...6, step: 1)
                .controlSize(.small)
            Text(formatGain(value)).font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
    }

    private func formatGain(_ v: Int) -> String {
        v > 0 ? "+\(v) dB" : v < 0 ? "−\(abs(v)) dB" : "0 dB"
    }

    // Saved custom EQs live on this Mac (idea from nikiomori/nothing-x-macos).
    private var savedPresets: some View {
        VStack(spacing: 4) {
            HStack {
                Text("My Presets").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if !saving.value {
                    Button("Save Current…") { newName.value = ""; saving.value = true }
                        .buttonStyle(.link).font(.system(size: 11))
                }
            }
            .padding(.horizontal, 14)

            if saving.value {
                HStack(spacing: 6) {
                    TextField("Preset name", text: $newName.value)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .onSubmit(save)
                    Button("Save", action: save).controlSize(.small)
                        .disabled(newName.value.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { saving.value = false }.controlSize(.small)
                }
                .padding(.horizontal, 14)
            }

            ForEach(settings.savedEqs) { saved in
                let active = saved.bands == bands
                Button { device.setCustomEq(saved.bands) } label: {
                    HStack {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                            .opacity(active ? 1 : 0).frame(width: 14)
                        Text(saved.name).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text("\(formatShort(saved.bass)) / \(formatShort(saved.mid)) / \(formatShort(saved.treble))")
                            .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(HoverRowStyle())
                .contextMenu {
                    Button("Delete “\(saved.name)”", role: .destructive) { settings.deleteEq(saved) }
                }
            }
            if settings.savedEqs.isEmpty && !saving.value {
                FooterNote("Save the current bands to switch back to them later. Right-click a preset to delete it.")
            }
        }
        .padding(.top, 4)
    }

    private func formatShort(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

    private func save() {
        settings.saveEq(name: newName.value, bands: bands)
        saving.value = false
    }
}

/// Smooth curve: bass shelf on the left, mid peak in the centre, treble shelf on the right.
private struct EqCurve: View {
    let bands: CustomEq

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, pad: CGFloat = 6
            let y = { (gain: Int) in h / 2 - CGFloat(gain) / 6 * (h / 2 - pad) }
            let curve = Path { p in
                p.move(to: CGPoint(x: 0, y: y(bands.bass)))
                p.addCurve(to: CGPoint(x: w * 0.5, y: y(bands.mid)),
                           control1: CGPoint(x: w * 0.22, y: y(bands.bass)),
                           control2: CGPoint(x: w * 0.32, y: y(bands.mid)))
                p.addCurve(to: CGPoint(x: w, y: y(bands.treble)),
                           control1: CGPoint(x: w * 0.68, y: y(bands.mid)),
                           control2: CGPoint(x: w * 0.78, y: y(bands.treble)))
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h / 2))
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                Path { p in
                    p.addPath(curve)
                    p.addLine(to: CGPoint(x: w, y: h / 2))
                    p.addLine(to: CGPoint(x: 0, y: h / 2))
                    p.closeSubpath()
                }
                .fill(Color.accentColor.opacity(0.18))
                curve.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .animation(.easeOut(duration: 0.15), value: bands)
        }
    }
}
