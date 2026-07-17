import SwiftUI

enum OnboardingTheme {
    static let green = Color(red: 10/255, green: 132/255, blue: 10/255)
    static let background = LinearGradient(
        colors: [Color(red: 234/255, green: 251/255, blue: 234/255), .white],
        startPoint: .topLeading, endPoint: .bottom)
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white).padding(.horizontal, 40).padding(.vertical, 9)
                .background(OnboardingTheme.green, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}

/// 톤 B 시그니처 — 말→파형→텍스트 프로세스 다이어그램
struct ProcessDiagram: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("🗣️").font(.system(size: 26))
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Image(systemName: "waveform").font(.system(size: 22)).foregroundStyle(OnboardingTheme.green)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            Text("안녕하세요").font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08)))
        .shadow(color: OnboardingTheme.green.opacity(0.10), radius: 7, y: 4)
    }
}
