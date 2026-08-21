// Background.swift — the null corpus behind the z acceptance rule.
//
// The A/B's open problem is that a cosine has no absolute meaning: "a person
// walking away" peaks at 0.265 on footage with no person, above "ocean" at
// 0.232 on the beach it is looking at. The scale is per-query. So give every
// query its own null: score it against a few hundred frames of *unrelated*
// footage, and read the peak in that query's own units,
//
//     z = (peak_in_video − mean_background) / stddev_background
//
// which is equivalently a per-query cosine cut at mean + z·sd. The frames come
// from a manifest (background/null-corpus.txt) so the corpus is a committed,
// reviewable fact; the embeddings are derived data and are cached under
// .build/, which is gitignored — the source clips are not redistributable and
// the cache is not repo content.

import AVFoundation
import CoreGraphics
import Foundation

struct BackgroundSet {
    var clips: Int
    var frames: Int
    var embeds: [[Float]]
    var fromCache: Bool
    var decodeCost: Double
    var embedCost: Double

    /// Cosines of one query against every background frame, as (mean, sd).
    func stats(for query: [Float]) -> (mean: Float, sd: Float) {
        guard !embeds.isEmpty else { return (0, 0) }
        var sum: Float = 0
        var sumsq: Float = 0
        for e in embeds {
            let c = ClipRunner.cosine(e, query)
            sum += c
            sumsq += c * c
        }
        let n = Float(embeds.count)
        let mean = sum / n
        // Sample standard deviation; n is in the hundreds, so the correction is
        // cosmetic, but the estimator should be the one we would name.
        let variance = max(0, (sumsq - n * mean * mean) / (n - 1))
        return (mean, variance.squareRoot())
    }
}

enum BackgroundCorpus {
    /// Manifest lines: `#` comments and blanks dropped, `~` expanded.
    static func paths(in manifest: URL) throws -> [URL] {
        let text = try String(contentsOf: manifest, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line -> URL? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
    }

    /// A cache is only valid for the manifest and cadence that made it.
    private static func fingerprint(paths: [URL], framesPerClip: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in (paths.map { $0.path }.joined(separator: "\n") + "|\(framesPerClip)").utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x1000_0000_01b3
        }
        return hash
    }

    /// `framesPerClip` frames per clip, evenly spaced inside it — 2 gives 30%
    /// and 70%, which is one frame either side of a cut in most short clips.
    static func build(
        manifest: URL, cache: URL?, framesPerClip: Int, runner: ClipRunner
    ) async throws -> BackgroundSet {
        let paths = try paths(in: manifest)
        let stamp = fingerprint(paths: paths, framesPerClip: framesPerClip)

        if let cache, let hit = readCache(cache, expecting: stamp, dimension: runner.embeddingDimension) {
            return BackgroundSet(
                clips: paths.count, frames: hit.count, embeds: hit, fromCache: true,
                decodeCost: 0, embedCost: 0)
        }

        var images: [CGImage] = []
        let startDecode = Date()
        for path in paths {
            guard FileManager.default.fileExists(atPath: path.path) else {
                FileHandle.standardError.write(Data("background: missing \(path.path)\n".utf8))
                continue
            }
            let asset = AVURLAsset(url: path)
            guard let duration = try? await asset.load(.duration).seconds, duration > 0 else { continue }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 512, height: 512)
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.3, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.3, preferredTimescale: 600)
            for i in 0..<framesPerClip {
                let fraction = Double(i + 1) / Double(framesPerClip + 1)
                let t = min(max(0, duration * fraction), max(0, duration - 0.05))
                guard
                    let image = try? await generator.image(
                        at: CMTime(seconds: t, preferredTimescale: 600)
                    ).image
                else { continue }
                images.append(image)
            }
        }
        let decodeCost = Date().timeIntervalSince(startDecode)

        let startEmbed = Date()
        var embeds: [[Float]] = []
        embeds.reserveCapacity(images.count)
        for image in images { embeds.append(try await runner.encode(image: image)) }
        let embedCost = Date().timeIntervalSince(startEmbed)

        if let cache { writeCache(cache, embeds: embeds, stamp: stamp) }
        return BackgroundSet(
            clips: paths.count, frames: embeds.count, embeds: embeds, fromCache: false,
            decodeCost: decodeCost, embedCost: embedCost)
    }

    // MARK: - Cache (header line + raw float32; ~2 KB per frame at dim 512)

    private static func readCache(_ url: URL, expecting stamp: UInt64, dimension: Int) -> [[Float]]? {
        guard let data = try? Data(contentsOf: url),
            let newline = data.firstIndex(of: 0x0a),
            let header = String(data: data[data.startIndex..<newline], encoding: .utf8)
        else { return nil }
        let fields = header.split(separator: " ")
        guard fields.count == 4, fields[0] == "CLIPBG1",
            let count = Int(fields[1]), let dim = Int(fields[2]), let mark = UInt64(fields[3]),
            mark == stamp, dim == dimension
        else { return nil }
        let body = data[data.index(after: newline)...]
        guard body.count == count * dim * MemoryLayout<Float>.size else { return nil }
        let floats: [Float] = body.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
        return (0..<count).map { Array(floats[($0 * dim)..<(($0 + 1) * dim)]) }
    }

    private static func writeCache(_ url: URL, embeds: [[Float]], stamp: UInt64) {
        guard let dim = embeds.first?.count else { return }
        var data = Data("CLIPBG1 \(embeds.count) \(dim) \(stamp)\n".utf8)
        for e in embeds { data.append(e.withUnsafeBufferPointer { Data(buffer: $0) }) }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}
