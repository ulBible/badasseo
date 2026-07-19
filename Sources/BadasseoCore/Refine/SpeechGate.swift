import Foundation

/// 무음·환각 방어 — whisper는 무음 입력에 "-", "..." 같은 토큰을 환각한다.
public enum SpeechGate {
    /// RMS 기반 무음 판정 — 무음이면 전사 자체를 건너뛴다 (환각 원천 차단 + 전력 절약).
    /// 임계값 0.004는 보수적: 조용한 발화(RMS ~0.01+)는 통과, 무음실 배경(~0.001)은 차단.
    public static func isSilence(samples: [Float], threshold: Float = 0.004) -> Bool {
        guard !samples.isEmpty else { return true }
        let meanSquare = samples.reduce(Float(0)) { $0 + $1 * $1 } / Float(samples.count)
        return meanSquare.squareRoot() < threshold
    }

    /// 글자·숫자가 하나도 없는 출력(구두점·기호뿐)은 환각으로 간주 — 삽입하지 않는다.
    public static func isJunk(_ text: String) -> Bool {
        !text.contains { $0.isLetter || $0.isNumber }
    }

    /// 세그먼트 환각 판정 — 오디오 끝자락의 1초 미만 자투리에서 직전 문장을
    /// 통째로 반복하는 세그먼트가 나온다 (관측: 0.24초에 20+자). 사람이 낼 수
    /// 없는 글자 밀도(1초 미만 & 초당 25자 초과)만 환각으로 간주한다 —
    /// 실제 한국어 발화는 최대 ~10음절/초라 여유가 크다.
    public static func isImpossiblyDense(_ text: String, duration: Double) -> Bool {
        guard duration < 1.0 else { return false }
        let letters = text.count { $0.isLetter || $0.isNumber }
        return Double(letters) > duration * 25
    }
}
