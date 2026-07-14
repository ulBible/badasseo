import Foundation
import BadasseoCore
import BadasseoEngine

// 사용법: badasseo-cli <model.bin> <audio.wav> — 파이프라인(전사→정제) 검증용
let args = CommandLine.arguments
guard args.count == 3 else {
    print("usage: badasseo-cli <model.bin> <audio-file>")
    exit(1)
}
do {
    let engine = try WhisperEngine(modelPath: args[1])
    let samples = try WavLoader.loadSamples(url: URL(fileURLWithPath: args[2]))
    let dict = UserDictionary.defaultSeed
    let t0 = Date()
    let raw = engine.transcribe(samples: samples, promptTerms: Array(Set(dict.values)).sorted())
    let refined = Refiner.refine(raw, dictionary: dict)
    print("raw    : \(raw)")
    print("refined: \(refined)")
    print(String(format: "latency: %.2fs (모델 로드 제외)", -t0.timeIntervalSinceNow))
} catch {
    print("error: \(error)")
    exit(2)
}
