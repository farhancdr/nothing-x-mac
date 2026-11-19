// Ear tip fit test: the buds play a tone and report the seal for each side.
// Command and result codes from nikiomori/nothing-x-macos.

import NothingKit
import SwiftUI

struct EarTipTestView: View {
    @EnvironmentObject var device: EarbudsController

    var body: some View {
        VStack(spacing: 10) {
            SubpageHeader(title: "Ear Tip Fit Test", back: .quickSettings)

            switch device.state.earTip {
            case .idle:
                FooterNote("Put both earbuds in, stay still and start the test. A short tone plays to check how well each ear tip seals.")
                startButton("Start Test")
            case .running:
                VStack(spacing: 8) {
                    ProgressView().controlSize(.regular)
                    Text("Testing… keep still").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            case .finished(let left, let right):
                HStack(spacing: 8) {
                    result("Left", "airpodpro.left", left)
                    result("Right", "airpodpro.right", right)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                if left == .poor || right == .poor {
                    FooterNote("Try adjusting the earbud, or a different ear tip size, then test again.")
                }
                startButton("Test Again")
            case .failed:
                FooterNote("No result from the earbuds. Make sure both are in your ears and try again.")
                startButton("Try Again")
            }
        }
        .padding(.bottom, 6)
        .onDisappear { device.resetEarTipTest() }
    }

    private func startButton(_ title: String) -> some View {
        Button(title) { device.startEarTipTest() }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
    }

    private func result(_ label: String, _ symbol: String, _ fit: EarTipFit) -> some View {
        let (text, icon, color): (String, String, Color) = {
            switch fit {
            case .good: return ("Good Seal", "checkmark.circle.fill", .green)
            case .poor: return ("Adjust or Try Another Tip", "exclamationmark.triangle.fill", .orange)
            case .notInEar: return ("Not in Ear", "questionmark.circle", .secondary)
            }
        }()
        return VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light))
            Text(label).font(.system(size: 12, weight: .medium))
            Label(text, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}
