// Ear tip fit test: instructions, a short listening state, then a result per bud.
// Command and result codes from nikiomori/nothing-x-macos.

import NothingKit
import SwiftUI

struct EarTipTestView: View {
    @EnvironmentObject var device: EarbudsController
    @EnvironmentObject var nav: PanelNavigation
    @StateObject private var startedAt = Local(Date())

    /// About how long the buds take to report (they play a ~5 s tone).
    private static let expected: TimeInterval = 5

    var body: some View {
        VStack(spacing: 0) {
            SubpageHeader(title: "Ear Tip Fit Test")

            switch device.state.earTip {
            case .idle:
                intro
            case .running:
                listening
            case .finished(let left, let right):
                results(left, right)
            case .failed:
                VStack(spacing: 12) {
                    hero(.disconnected)
                    Text("No result").font(.system(size: 15, weight: .semibold))
                    FooterNote("The earbuds didn't report a seal. Make sure both are in your ears and try again.")
                        .multilineTextAlignment(.center)
                    buttons(primary: "Try Again")
                }
                .padding(.vertical, 16)
            }
        }
        .onChange(of: device.state.earTip) { state in
            if state == .running { startedAt.value = Date() }
        }
        .onDisappear { device.resetEarTipTest() }
    }

    private func hero(_ look: DotBud.Look) -> some View {
        HStack(spacing: 28) {
            DotBudView(look: look, size: 56, mirrored: true)
            DotBudView(look: look, size: 56)
        }
        .padding(.top, 4)
    }

    private var intro: some View {
        VStack(spacing: 0) {
            hero(.connected).padding(.top, 18)
            Text("Check your seal").font(.system(size: 15, weight: .semibold)).padding(.top, 16)
            VStack(alignment: .leading, spacing: 6) {
                step(1, "Put both earbuds in your ears.")
                step(2, "Stay still and quiet.")
                step(3, "A short tone plays for about 5 seconds.")
            }
            .padding(.horizontal, Theme.inset + 4)
            .padding(.top, 12)
            HStack {
                Spacer()
                Button("Start Test") { device.startEarTipTest() }
                    .buttonStyle(PanelButtonStyle(primary: true))
            }
            .padding(Theme.inset)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.secondaryLabel)
            Text(text).font(.system(size: 12))
            Spacer(minLength: 0)
        }
    }

    private var listening: some View {
        VStack(spacing: 0) {
            hero(.connecting).padding(.top, 18)
            Text("Listening…").font(.system(size: 15, weight: .semibold)).padding(.top, 16)
            TimelineView(.periodic(from: startedAt.value, by: 0.4)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt.value)
                let left = max(1, Int((Self.expected - elapsed).rounded(.up)))
                VStack(spacing: 10) {
                    Text("Keep still. About \(left) second\(left == 1 ? "" : "s") left.")
                        .font(.system(size: 12)).foregroundStyle(Theme.secondaryLabel)
                    AccentMeter(lit: min(12, Int(elapsed / 0.4) + 1))
                }
            }
            .padding(.top, 6)
            HStack {
                Spacer()
                Button("Cancel") {
                    device.cancelEarTipTest()
                }
                .buttonStyle(PanelButtonStyle())
            }
            .padding(Theme.inset)
        }
    }

    private func results(_ left: EarTipFit, _ right: EarTipFit) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                ResultCard(side: "Left", mirrored: true, fit: left)
                ResultCard(side: "Right", mirrored: false, fit: right)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            buttons(primary: "Done")
        }
    }

    /// Test Again (secondary) and a primary button; Done goes back to Quick Settings.
    private func buttons(primary: String) -> some View {
        HStack(spacing: 8) {
            Spacer()
            if primary == "Done" {
                Button("Test Again") { device.startEarTipTest() }.buttonStyle(PanelButtonStyle())
                Button("Done") { nav.page = .quickSettings }.buttonStyle(PanelButtonStyle(primary: true))
            } else {
                Button(primary) { device.startEarTipTest() }.buttonStyle(PanelButtonStyle(primary: true))
            }
        }
        .padding(.horizontal, Theme.inset)
        .padding(.bottom, Theme.inset)
    }
}

private struct AccentMeter: View {
    let lit: Int
    @Environment(\.accent) private var accent

    var body: some View {
        DotMeter(count: 12, lit: lit, diameter: 4.4, pitch: 10, on: accent)
    }
}

private struct ResultCard: View {
    let side: String
    let mirrored: Bool
    let fit: EarTipFit
    @Environment(\.accent) private var accent

    var body: some View {
        let (title, detail, symbol, look): (String, String, String, DotBud.Look) = {
            switch fit {
            case .good: return ("Good seal", "Nothing to change.", "checkmark.circle", .connected)
            case .poor: return ("Try a different tip", "Sound is leaking. Try one size up.",
                                "exclamationmark.triangle", .low)
            case .notInEar: return ("Not in ear", "Put the earbud in and test again.", "xmark.circle", .disconnected)
            }
        }()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                DotBudView(look: look, size: 13, mirrored: mirrored, color: Theme.secondaryLabel)
                Text(side).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.secondaryLabel)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(fit == .poor ? accent : fit == .good ? Theme.label : Theme.secondaryLabel)
                Text(title).font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(detail).font(.system(size: 11)).foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.controlFill))
        .accessibilityElement(children: .combine)
    }
}
