// Quick Settings page: tiles for in-ear detection, low latency, Personal Sound,
// spatial audio, dual connection and Find Buds, plus the ear tip test and device info.

import NothingKit
import SwiftUI

struct QuickSettingsView: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation
    @StateObject private var spatialListOpen = Local(false)
    @StateObject private var findOpen = Local(false)

    private var state: DeviceState { device.state }
    private var caps: Capabilities { state.capabilities }

    var body: some View {
        VStack(spacing: 8) {
            SubpageHeader(title: "Quick Settings")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                if caps.inEar { toggleTile(.inEar, "In-Ear Detection", "ear", state.quick.inEar) }
                if caps.lowLatency { toggleTile(.lowLatency, "Low Latency", "bolt.fill", state.quick.lowLatency) }
                if caps.personalSound != nil {
                    toggleTile(.personalSound, "Personal Sound", "waveform.and.person.filled", state.quick.personalSound)
                }
                if !caps.spatialModes.isEmpty { spatialTile }
                if caps.dualConnection { dualTile }
                findTile
            }
            .padding(.horizontal, 12)

            if spatialListOpen.value && caps.spatialModes.count > 2 { spatialList }
            if caps.dualConnection && state.dual.enabled == true { DualConnectionList() }
            if caps.ring == .buds && (findOpen.value || state.quick.ringing != nil) { findPanel }

            if caps.earTipTest {
                Button { nav.page = .earTip } label: {
                    HStack(spacing: 10) {
                        IconBadge(symbol: "ear.badge.checkmark")
                        Text("Ear Tip Fit Test").font(.system(size: 13))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(HoverRowStyle())
            }

            DeviceInfo()
        }
    }

    // MARK: Tiles

    private func toggleTile(_ setting: QuickSetting, _ name: String, _ symbol: String, _ value: Bool?) -> some View {
        Tile(symbol: symbol, name: name,
             detail: value.map { $0 ? "On" : "Off" } ?? "—",
             on: value == true, pending: state.quick.pending.contains(setting)) {
            guard let value, !state.quick.pending.contains(setting) else { return }
            device.setToggle(setting, !value)
        }
    }

    /// Models with Off and one mode toggle directly; others open a list underneath.
    private var spatialTile: some View {
        let current = state.quick.spatial
        return Tile(symbol: "person.spatialaudio.fill", name: "Spatial Audio",
                    detail: current?.label ?? "—",
                    on: current != nil && current != .off,
                    pending: state.quick.pending.contains(.spatial)) {
            guard !state.quick.pending.contains(.spatial) else { return }
            if caps.spatialModes.count == 2 {
                device.setSpatialAudio(current == .off ? caps.spatialModes[1] : .off)
            } else {
                spatialListOpen.value.toggle()
            }
        }
    }

    private var dualTile: some View {
        let dual = state.dual
        let detail: String = {
            guard let enabled = dual.enabled else { return "—" }
            if dual.pending && caps.dualRestarts { return "Restarting buds…" }
            return enabled ? "\(dual.connectedCount) of \(dual.maxConnected) connected" : "Off"
        }()
        return Tile(symbol: "macbook.and.iphone", name: "Dual Connection", detail: detail,
                    on: dual.enabled == true, pending: dual.pending) {
            guard let enabled = dual.enabled, !dual.pending else { return }
            device.setDualConnection(!enabled)
        }
    }

    private var findTile: some View {
        let ringing = state.quick.ringing
        let detail: String = {
            guard let ringing else { return "Play sound" }
            return ringing == .all ? "Playing… tap to stop" : "Playing \(ringing.rawValue)"
        }()
        return Tile(symbol: "speaker.wave.2.fill", name: "Find Buds", detail: detail, on: ringing != nil) {
            if caps.ring == .buds {
                findOpen.value.toggle()
            } else {
                device.ring(.all, on: ringing == nil)
            }
        }
    }

    // MARK: Expanded panels

    private var spatialList: some View {
        VStack(spacing: 0) {
            ForEach(caps.spatialModes) { mode in
                Button { device.setSpatialAudio(mode) } label: {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(state.quick.spatial == mode ? 1 : 0)
                            .frame(width: 14)
                        Text(mode.label).font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(HoverRowStyle())
            }
        }
        .disabled(state.quick.pending.contains(.spatial))
    }

    private var findPanel: some View {
        VStack(spacing: 6) {
            FooterNote("The sound is loud. Take the earbuds out first.")
            HStack(spacing: 6) {
                ForEach([RingTarget.left, .right], id: \.self) { side in
                    let active = state.quick.ringing == side
                    Button(active ? "Stop" : side == .left ? "Left" : "Right") {
                        device.ring(side, on: !active)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(active ? .red : .accentColor)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

// MARK: - Dual connection devices

private struct DualConnectionList: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let dual = device.state.dual
        let full = dual.connectedCount >= dual.maxConnected
        VStack(spacing: 2) {
            HStack {
                Text("Devices").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(dual.connectedCount) of \(dual.maxConnected) connected")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)

            ForEach(dual.devices) { d in
                let busy = dual.busyMac == d.mac
                // Locked: this Mac, another device mid-change, or no free slot to connect.
                let locked = d.isSelf || (dual.busyMac != nil && !busy) || busy || (!d.isConnected && full)
                Button { device.setDualDevice(d.mac, connect: !d.isConnected) } label: {
                    HStack(spacing: 10) {
                        IconBadge(symbol: deviceSymbol(d), on: d.isConnected, pending: busy)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d.name.isEmpty ? (d.isSelf ? "This Mac" : "Unknown device") : d.name)
                                .font(.system(size: 13)).lineLimit(1)
                            Text(status(d, busy: busy)).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(HoverRowStyle())
                .disabled(locked && !d.isSelf)
                .allowsHitTesting(!locked)
            }

            if dual.devices.isEmpty {
                FooterNote("Loading remembered devices…")
            } else if full {
                FooterNote("\(dual.maxConnected) devices connected. Disconnect one to connect another.")
            }
        }
    }

    private func status(_ d: DualDevice, busy: Bool) -> String {
        if busy { return d.isConnected ? "Disconnecting…" : "Connecting…" }
        if d.isSelf { return "This Mac · Connected" }
        return d.isConnected ? "Connected" : "Not connected"
    }

    /// The earbuds only report names, so guess an icon from the name.
    private func deviceSymbol(_ d: DualDevice) -> String {
        if d.isSelf { return "laptopcomputer" }
        let rules: [(String, String)] = [
            (#"iphone|phone|pixel|galaxy|oneplus|redmi|xiaomi|android"#, "iphone"),
            (#"ipad|tablet|\btab\b"#, "ipad"),
            (#"watch"#, "applewatch"),
            (#"\btv\b|television|bravia"#, "tv"),
            (#"imac|desktop|\bpc\b|studio"#, "desktopcomputer"),
            (#"mac|book|laptop|thinkpad|surface|notebook"#, "laptopcomputer"),
        ]
        for (pattern, symbol) in rules
        where d.name.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return symbol
        }
        return "antenna.radiowaves.left.and.right"
    }
}

// MARK: - Device info

private struct DeviceInfo: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        let state = device.state
        VStack(spacing: 3) {
            Divider().padding(.bottom, 2)
            row("Firmware", state.quick.firmware)
            if let serial = state.quick.serial { row("Serial Number", serial) }
            if let address = state.address, !address.isEmpty { row("Bluetooth Address", address.uppercased()) }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }

    private func row(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value ?? "—").textSelection(.enabled)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
