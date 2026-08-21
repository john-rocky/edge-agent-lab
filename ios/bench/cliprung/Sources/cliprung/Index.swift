// Index.swift — the app's visual index, mirrored outside the app.
//
// Arm A of spec E. Everything here is a transcription of
// `MomentIndexBox.buildIndex` in lfm-tools-ios
// (Sources/Tools/VideoEditTools.swift): the ≤90-sample cadence, maxSize 512,
// the confidence floors, the 3.2×step run merge, the Jaccard ≥ 0.5 / 4 s
// scene-snap for detector rows, and `search`'s tokenizer rule. Where the app
// says something, this file says it the same way — a harness that measures a
// different index measures nothing.

import AVFoundation
import CoreGraphics
import Foundation
import Vision

struct Row {
    var start: Double
    var end: Double
    var text: String
}

/// One sampled frame, held once and handed to both arms — the arms must see
/// the same pixels or the A/B is between two footages.
struct Sample {
    let time: Double
    let image: CGImage
}

enum Sampler {
    /// `buildIndex`'s cadence: ≤ ~90 samples however long the video, first
    /// sample at step/2, maxSize 512, ±0.3 s tolerance.
    static func sampleTimes(duration: Double) -> (step: Double, times: [Double]) {
        let step = max(1.0, duration / 90)
        var times: [Double] = []
        var t = step / 2
        while t < duration {
            times.append(t)
            t += step
        }
        return (step, times)
    }

    static func frames(url: URL, times: [Double], duration: Double) async -> [Sample] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)
        var out: [Sample] = []
        for time in times {
            let t = min(max(0, time), max(0, duration - 0.05))
            guard
                let image = try? await generator.image(
                    at: CMTime(seconds: t, preferredTimescale: 600)
                ).image
            else { continue }
            out.append(Sample(time: time, image: image))
        }
        return out
    }
}

/// Arm A — the OS label shelf: VNClassifyImageRequest (> 0.35, first 8),
/// VNRecognizeAnimalsRequest (> 0.5), VNRecognizeTextRequest.
struct LabelIndex {
    var visual: [Row] = []
    var written: [Row] = []
    /// label → how many samples saw it, for the coverage line the stage logs.
    var coverage: [(String, Int)] = []
    var detectorLabels: Set<String> = []

    static func build(samples: [Sample], step: Double) -> LabelIndex {
        var labelTimes: [String: [Double]] = [:]
        var textTimes: [String: [Double]] = [:]
        var scenes: [(time: Double, scene: Set<String>)] = []
        var detectorLabels = Set<String>()

        for sample in samples {
            let classify = VNClassifyImageRequest()
            let read = VNRecognizeTextRequest()
            read.recognitionLevel = .fast
            read.usesLanguageCorrection = false
            let animals = VNRecognizeAnimalsRequest()
            let handler = VNImageRequestHandler(cgImage: sample.image)
            try? handler.perform([classify, read, animals])

            var scene = Set<String>()
            for result in (classify.results ?? []).filter({ $0.confidence > 0.35 }).prefix(8) {
                let label = result.identifier.lowercased().replacingOccurrences(of: "_", with: " ")
                labelTimes[label, default: []].append(sample.time)
                scene.insert(label)
            }
            scenes.append((sample.time, scene))
            for animal in animals.results ?? [] {
                for label in animal.labels where label.confidence > 0.5 {
                    labelTimes[label.identifier.lowercased(), default: []].append(sample.time)
                    detectorLabels.insert(label.identifier.lowercased())
                }
            }
            for text in (read.results ?? []).compactMap({ $0.topCandidates(1).first?.string }) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else { continue }
                textTimes[trimmed, default: []].append(sample.time)
            }
        }

        /// Detector rows start late: walk the start backward while the
        /// classifier's scene signature still matches (Jaccard ≥ 0.5), 4 s cap.
        func snapped(_ rows: [Row]) -> [Row] {
            rows.map { row in
                var row = row
                let firstSample = row.start + step / 2
                guard var i = scenes.firstIndex(where: { abs($0.time - firstSample) < step / 4 })
                else { return row }
                let base = scenes[i].scene
                guard !base.isEmpty else { return row }
                var budget = 4.0
                while i > 0, budget > 0 {
                    let prev = scenes[i - 1].scene
                    let union = base.union(prev).count
                    guard union > 0,
                        Double(base.intersection(prev).count) / Double(union) >= 0.5
                    else { break }
                    i -= 1
                    budget -= step
                }
                row.start = max(0, scenes[i].time - step / 2)
                return row
            }
        }

        var index = LabelIndex()
        index.detectorLabels = detectorLabels
        index.visual = labelTimes.flatMap { entry -> [Row] in
            let rows = runs(entry.value, label: entry.key, step: step)
            return detectorLabels.contains(entry.key) ? snapped(rows) : rows
        }.sorted { $0.start < $1.start }
        index.written = textTimes.flatMap { runs($0.value, label: "\"\($0.key)\"", step: step) }
            .sorted { $0.start < $1.start }
        index.coverage = labelTimes.map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
        return index
    }
}

/// The app's run merge: a gap of up to 3.2×step keeps a run alive.
func runs(_ times: [Double], label: String, step: Double) -> [Row] {
    var out: [Row] = []
    for time in times.sorted() {
        if var last = out.last, time - last.end <= step * 3.2 {
            last.end = time + step / 2
            out[out.count - 1] = last
        } else {
            out.append(Row(start: max(0, time - step / 2), end: time + step / 2, text: label))
        }
    }
    return out
}

/// `MomentIndexBox.search`'s tokenizer, verbatim: ≥ 3 characters or carries a
/// digit, plus the 犬/猫 detector-noun aliases.
func queryTokens(_ query: String) -> [String] {
    var tokens = query.lowercased()
        .split(whereSeparator: { " ,.!?'\"「」『』、。".contains($0) })
        .map(String.init)
        .filter { $0.count >= 3 || $0.contains(where: \.isNumber) }
    for (ja, en) in [("犬", "dog"), ("いぬ", "dog"), ("猫", "cat"), ("ねこ", "cat")]
    where query.contains(ja) {
        tokens.append(en)
    }
    return tokens
}

func labelSearch(rows: [Row], query: String) -> [Row] {
    let tokens = queryTokens(query)
    return rows.filter { row in
        let text = row.text.lowercased()
        return tokens.contains { text.contains($0) }
    }
}
