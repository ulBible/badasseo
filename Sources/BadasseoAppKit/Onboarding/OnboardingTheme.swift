import SwiftUI

enum OnboardingTheme {
    static let green = Color(red: 10/255, green: 132/255, blue: 10/255)
}

/// 오로라 메시 배경 — 라이트/다크에 적응하는 베이스 컬러 위로 흐릿한 원 3개가 천천히 떠다닌다.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    @State private var drift = false

    private var baseColor: Color {
        scheme == .dark ? Color(red: 16/255, green: 17/255, blue: 18/255)
                         : Color(red: 244/255, green: 246/255, blue: 244/255)
    }

    private var blobColors: [Color] {
        scheme == .dark
            ? [Color(red: 18/255, green: 59/255, blue: 30/255),
               Color(red: 13/255, green: 42/255, blue: 22/255),
               Color(red: 28/255, green: 90/255, blue: 46/255)]
            : [Color(red: 182/255, green: 240/255, blue: 194/255),
               Color(red: 216/255, green: 245/255, blue: 222/255),
               Color(red: 234/255, green: 255/255, blue: 240/255)]
    }

    private var blobOpacity: [Double] {
        scheme == .dark ? [0.5, 0.7, 0.9] : [0.55, 0.55, 0.55]
    }

    var body: some View {
        ZStack {
            baseColor
            blob(blobColors[0], opacity: blobOpacity[0], size: 320, x: -140, y: -160, driftX: 40, driftY: 30, delay: 0)
            blob(blobColors[1], opacity: blobOpacity[1], size: 280, x: 160, y: -60, driftX: -35, driftY: 45, delay: 1.5)
            blob(blobColors[2], opacity: blobOpacity[2], size: 300, x: 20, y: 200, driftX: 30, driftY: -35, delay: 3)
        }
        .ignoresSafeArea()
        .onAppear { drift = true }
    }

    private func blob(_ color: Color, opacity: Double, size: CGFloat, x: CGFloat, y: CGFloat,
                       driftX: CGFloat, driftY: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(color)
            .opacity(opacity)
            .frame(width: size, height: size)
            .blur(radius: 38)
            .offset(x: x + (drift ? driftX : -driftX), y: y + (drift ? driftY : -driftY))
            .animation(
                .easeInOut(duration: 9).repeatForever(autoreverses: true).delay(delay),
                value: drift)
    }
}

/// 떠 있는 유리 패널 — ultraThinMaterial + 미묘한 보더/섀도.
private struct GlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(26)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.6))
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.12), radius: 24, y: 12)
    }
}

extension View {
    func glassPanel() -> some View { modifier(GlassPanel()) }
}

/// 그린 그라디언트 아이콘 배지 — 각 스텝 헤더에 사용.
struct IconBadge: View {
    let symbol: String
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(
                colors: [Color(red: 0.25, green: 0.87, blue: 0.42), OnboardingTheme.green],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 58, height: 58)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: OnboardingTheme.green.opacity(0.35), radius: 10, y: 5)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .bold))
                .foregroundStyle(scheme == .dark ? Color(red: 0.29, green: 0.89, blue: 0.48) : .white)
                .padding(.horizontal, 40).padding(.vertical, 9)
                .background(
                    scheme == .dark ? Color.green.opacity(0.16) : OnboardingTheme.green.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    if scheme == .dark {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.green.opacity(0.35), lineWidth: 1)
                    } else {
                        // 인셋 상단 하이라이트
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .center))
                    }
                }
                .shadow(color: OnboardingTheme.green.opacity(scheme == .dark ? 0 : 0.35), radius: 10, y: 5)
        }.buttonStyle(.plain)
    }
}

/// 캡슐 스텝 바 — 5단계 라벨, 현재 단계만 그린 필로 강조.
struct StepBar: View {
    let current: Int
    @Environment(\.colorScheme) private var scheme
    private let labels = ["환영", "모델", "마이크", "단축키", "첫 발화"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(labels.indices, id: \.self) { i in
                Text(labels[i])
                    .font(.system(size: 11, weight: i == current ? .bold : .regular))
                    .foregroundStyle(i == current
                        ? (scheme == .dark ? OnboardingTheme.green : .white)
                        : Color.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Group {
                            if i == current {
                                Capsule().fill(
                                    scheme == .dark
                                        ? Color(red: 0.29, green: 0.89, blue: 0.48).opacity(0.18)
                                        : OnboardingTheme.green
                                )
                            }
                        }
                    )
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.spring(duration: 0.35), value: current)
    }
}

/// 6개 바가 각자 다른 딜레이로 오르내리는 "듣고 있어요" 파형.
struct ListeningWave: View {
    @State private var animate = false
    private let delays: [Double] = [0, 0.12, 0.24, 0.36, 0.48, 0.6]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(delays.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.25, green: 0.87, blue: 0.42), OnboardingTheme.green],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: animate ? 16 : 5)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(delays[i]),
                        value: animate)
            }
        }
        .frame(height: 16)
        .onAppear { animate = true }
    }
}

/// 톤 B 시그니처 — 말→파형→텍스트 프로세스 다이어그램 (유리 캡슐 스타일)
struct ProcessDiagram: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            Text("🗣️").font(.system(size: 26))
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            ListeningWave()
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Text("안녕하세요|").font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(scheme == .dark ? 0.1 : 0.5)))
        .shadow(color: OnboardingTheme.green.opacity(0.12), radius: 7, y: 4)
    }
}
