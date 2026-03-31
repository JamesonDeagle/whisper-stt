import SwiftUI

struct WaveformView: View {
    @EnvironmentObject var panel: WaveformPanel

    private let barCount = 11
    private let barWidth: CGFloat = 3.5
    private let barSpacing: CGFloat = 3.5
    private let baseHeights: [CGFloat] = [8, 14, 20, 26, 30, 36, 30, 26, 20, 14, 8]

    var body: some View {
        ZStack {
            if panel.isVisible {
                Group {
                    switch panel.mode {
                    case .recording:
                        recordingPill
                    case .transcribing:
                        transcribingOrb
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: panel.isVisible)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: panel.mode == .transcribing)
    }

    // MARK: - Recording

    private let maxBarHeight: CGFloat = 36
    private let pillHeight: CGFloat = 68

    @ViewBuilder
    private var recordingPill: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { i in
                let level = CGFloat(i < panel.levels.count ? max(0.15, panel.levels[i]) : 0.15)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: barWidth, height: baseHeights[i] * level)
                    .animation(.easeOut(duration: 0.08), value: panel.levels)
            }
        }
        .frame(height: pillHeight)
        .padding(.horizontal, 28)
        .liquidGlass(shape: Capsule())
    }

    // MARK: - Transcribing

    @ViewBuilder
    private var transcribingOrb: some View {
        OrbitalLoader()
            .frame(width: 64, height: 64)
            .liquidGlass(shape: Circle())
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}

// MARK: - Liquid Glass Modifier

extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(shape: S) -> some View {
        if #available(macOS 26, *) {
            self
                .glassEffect(.regular, in: shape)
                .shadow(color: .primary.opacity(0.06), radius: 24, y: 0)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(Color.black.opacity(0.5), in: shape)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
        }
    }
}

// MARK: - Orbital Loader

struct OrbitalLoader: View {
    @State private var outerAngle: Double = 0
    @State private var innerAngle: Double = 0
    @State private var corePulse: CGFloat = 1.0

    private let outerCount = 8
    private let innerCount = 5
    private let outerR: CGFloat = 22
    private let innerR: CGFloat = 12

    var body: some View {
        ZStack {
            // Outer ring — gradient dots with trail fade
            ForEach(0..<outerCount, id: \.self) { i in
                let size = 4.5 - CGFloat(i) * 0.35
                let fade = 1.0 - Double(i) / Double(outerCount) * 0.7

                Circle()
                    .fill(Color.primary)
                    .frame(width: size, height: size)
                    .shadow(color: .primary.opacity(0.3), radius: 3)
                    .offset(x: outerR)
                    .rotationEffect(.degrees(Double(i) / Double(outerCount) * 360 + outerAngle))
                    .opacity(fade)
            }

            // Inner ring — counter-rotating, subtle
            ForEach(0..<innerCount, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: innerR)
                    .rotationEffect(.degrees(Double(i) / Double(innerCount) * 360 - innerAngle))
            }

            // Core glow pulse
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.primary.opacity(0.2), Color.primary.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .frame(width: 24, height: 24)
                .scaleEffect(corePulse)

            // Tiny bright center dot
            Circle()
                .fill(Color.primary.opacity(0.7))
                .frame(width: 3, height: 3)
                .shadow(color: .primary.opacity(0.3), radius: 4)
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            outerAngle = 360
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            innerAngle = 360
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever()) {
            corePulse = 1.35
        }
    }
}
