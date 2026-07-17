import XCTest
@testable import BadasseoCore

final class ModelInfoTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(ModelInfo.url.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")
        XCTAssertEqual(ModelInfo.sha256,
            "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69")
        XCTAssertEqual(ModelInfo.byteSize, 1_624_555_275)
        XCTAssertTrue(ModelInfo.destination.path.hasSuffix("Badasseo/models/ggml-large-v3-turbo.bin"))
    }
    func testSha256Hex() {
        // 알려진 벡터: SHA256("abc")
        XCTAssertEqual(ModelInfo.hex(sha256Of: Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
