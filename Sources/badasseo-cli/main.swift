import Foundation
import BadasseoCore
import BadasseoEngine

// 사용법: badasseo-cli <model.bin> <audio.wav | record> — 파이프라인(전사→정제) 검증용
let args = CommandLine.arguments

func runPipeline(engine: WhisperEngine, samples: [Float]) throws {
    let dict = UserDictionary.defaultSeed
    let t0 = Date()
    let raw = try engine.transcribe(samples: samples, promptTerms: Array(Set(dict.values)).sorted())
    let refined = Refiner.refine(raw, dictionary: dict)
    print("raw    : \(raw)")
    print("refined: \(refined)")
    print(String(format: "latency: %.2fs (모델 로드 제외)", -t0.timeIntervalSinceNow))
}

do {
    switch args.count {
    case 3 where args[2] == "record":  // badasseo-cli <model> record — 5초 녹음 후 전사
        let engine = try WhisperEngine(modelPath: args[1])
        let cap = AudioCapture()
        print("5초간 말하세요…")
        try cap.start()
        Thread.sleep(forTimeInterval: 5)
        let samples = cap.stop()
        print("샘플 수: \(samples.count) (기대: ~80000)")
        try runPipeline(engine: engine, samples: samples)
    case 3:  // badasseo-cli <model> <audio-file>
        let engine = try WhisperEngine(modelPath: args[1])
        let samples = try WavLoader.loadSamples(url: URL(fileURLWithPath: args[2]))
        try runPipeline(engine: engine, samples: samples)
    default:
        print("usage: badasseo-cli <model.bin> <audio-file | record>")
        exit(1)
    }
} catch {
    print("error: \(error)")
    exit(2)
}
