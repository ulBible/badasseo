import CryptoKit
import Foundation

/// 받아써가 쓰는 유일한 모델의 단일 정보 출처 — URL·체크섬·경로.
public enum ModelInfo {
    public static let url = URL(string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
    public static let sha256 = "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69"
    public static let byteSize: Int64 = 1_624_555_275

    public static var destination: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Badasseo/models/ggml-large-v3-turbo.bin")
    }

    public static func hex(sha256Of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
