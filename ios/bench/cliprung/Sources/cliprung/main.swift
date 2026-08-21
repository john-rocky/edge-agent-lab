// Main.swift — spec E's A/B: labels-only vs labels+CLIP on one footage.
//
//   DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer \
//     swift run -c release cliprung --video ~/Desktop/journey.mp4
//
// Both arms read the same sampled frames, on the app's own cadence, and answer
// the same queries. Ground truth is the scene boundaries, written below as
// data. The threshold is arm B's whole ballgame, so it is swept rather than
// chosen.

import AVFoundation
import CoreAIKitVision
import Foundation

// MARK: - Ground truth (journey.mp4, cuts verified by eye at 6.08/12.17/19.25)

struct Scene {
    let name: String
    let start: Double
    let end: Double
}

let scenes = [
    Scene(name: "street", start: 0, end: 6.08),  // aerial junction, cars, crosswalk
    Scene(name: "forest", start: 6.08, end: 12.17),  // gravel path under trees
    Scene(name: "beach", start: 12.17, end: 19.25),  // puppy on sand, sun low over the sea
    Scene(name: "sunset", start: 19.25, end: 25.34),  // downtown skyline into the sun
]

/// `expect: nil` means the honest answer is "there isn't one" — a threshold
/// that says yes to everything has to be visible as a failure somewhere.
struct Query {
    let text: String
    let expect: String?
    let kind: String  // shelf | beyond | miss
}

let queries: [Query] = [
    // The label shelf can answer these: a detector noun, or a scene noun the
    // classifier actually says.
    Query(text: "dog", expect: "beach", kind: "shelf"),
    Query(text: "beach", expect: "beach", kind: "shelf"),
    Query(text: "ocean", expect: "beach", kind: "shelf"),
    Query(text: "city street with traffic", expect: "street", kind: "shelf"),
    // No detector, no on-screen text, and no single noun the shelf holds —
    // the playbook's own examples of what the rung is for.
    Query(text: "sunset over the city", expect: "sunset", kind: "beyond"),
    Query(text: "a path through trees", expect: "forest", kind: "beyond"),
    Query(text: "a puppy running on the sand", expect: "beach", kind: "beyond"),
    Query(text: "tall buildings seen from above", expect: "sunset", kind: "beyond"),
    // Nothing in this footage answers these. "a person walking away" is the
    // playbook's example, but no human is visible in any of the four scenes
    // (checked frame by frame), so here it is a should-miss, not a beyond.
    Query(text: "a cat", expect: nil, kind: "miss"),
    Query(text: "snow", expect: nil, kind: "miss"),
    Query(text: "a person walking away", expect: nil, kind: "miss"),
]

// MARK: - Scoring

func scene(named name: String) -> Scene? { scenes.first { $0.name == name } }

/// The seek target lands in the expected scene, ±0.6 s — the app's own range
/// tolerance, because a row start snapped to a cut sits on the boundary.
func lands(_ t: Double, in name: String) -> Bool {
    guard let s = scene(named: name) else { return false }
    return t >= s.start - 0.6 && t < s.end + 0.6
}

func overlaps(_ row: Row, _ name: String) -> Bool {
    guard let s = scene(named: name) else { return false }
    return row.start < s.end && row.end > s.start
}

func f(_ v: Double) -> String { String(format: "%.1f", v) }
func f2(_ v: Float) -> String { String(format: "%.3f", v) }

// MARK: - Arguments

var videoPath = ("~/Desktop/journey.mp4" as NSString).expandingTildeInPath
var bundlePath =
    ProcessInfo.processInfo.environment["KIT_CLIP_BUNDLE"]
    ?? ("~/Library/Application Support/CoreAIKit/Models/mlboydaisuke/clip-vit-base-patch32-CoreAI-official/model"
        as NSString).expandingTildeInPath
var thresholds: [Float] = [0.18, 0.21, 0.24, 0.27, 0.30]
var units = GraphModel.ComputeUnits.gpu
/// The package directory, so the default manifest and cache resolve wherever
/// `swift run` is invoked from.
let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Sources/cliprung
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // cliprung
var backgroundManifest: String? =
    packageDirectory.appendingPathComponent("background/null-corpus.txt").path
var backgroundCache: String? =
    packageDirectory.appendingPathComponent(".build/background-embeds.bin").path
var backgroundFramesPerClip = 2
var zMargins: [Float] = [2.0, 2.5, 3.0, 3.5, 4.0]

var args = Array(CommandLine.arguments.dropFirst())
while let flag = args.first {
    args.removeFirst()
    switch flag {
    case "--video": videoPath = (args.removeFirst() as NSString).expandingTildeInPath
    case "--bundle": bundlePath = (args.removeFirst() as NSString).expandingTildeInPath
    case "--thresholds": thresholds = args.removeFirst().split(separator: ",").compactMap { Float($0) }
    case "--background": backgroundManifest = (args.removeFirst() as NSString).expandingTildeInPath
    case "--background-frames": backgroundFramesPerClip = Int(args.removeFirst()) ?? 2
    case "--no-background": backgroundManifest = nil
    case "--no-background-cache": backgroundCache = nil
    case "--z": zMargins = args.removeFirst().split(separator: ",").compactMap { Float($0) }
    case "--units":
        switch args.removeFirst() {
        case "ane", "neuralEngine": units = .neuralEngine
        case "cpu": units = .cpuOnly
        default: units = .gpu
        }
    default: FileHandle.standardError.write(Data("unknown flag \(flag)\n".utf8))
    }
}

// MARK: - Run

let video = URL(fileURLWithPath: videoPath)
let asset = AVURLAsset(url: video)
let duration = try await asset.load(.duration).seconds
let (step, times) = Sampler.sampleTimes(duration: duration)
print("# cliprung — spec E A/B")
print("")
print("video: \(video.lastPathComponent), \(f(duration)) s")
print("cadence: \(times.count) samples every \(f(step)) s, maxSize 512 (the app's buildIndex)")
let samples = await Sampler.frames(url: video, times: times, duration: duration)
print("frames decoded: \(samples.count)")

// Arm A -----------------------------------------------------------------
let startA = Date()
let index = LabelIndex.build(samples: samples, step: step)
let costA = Date().timeIntervalSince(startA)
print("")
print(
    "## arm A — the OS label shelf (\(index.visual.count) visual rows, \(index.written.count) text rows, \(f(costA)) s)"
)
print("")
print(
    "labels: "
        + index.coverage.prefix(14).map { "\($0.0)×\($0.1)" }.joined(separator: ", "))
if !index.detectorLabels.isEmpty {
    print("detector labels (scene-snapped): " + index.detectorLabels.sorted().joined(separator: ", "))
}
if index.written.isEmpty {
    print("on-screen text: none recognised")
} else {
    print("on-screen text: " + index.written.prefix(6).map { $0.text }.joined(separator: ", "))
}

// Arm B -----------------------------------------------------------------
print("")
let runner = try await ClipRunner(bundleAt: URL(fileURLWithPath: bundlePath), computeUnits: units)
print("## arm B — CLIP ViT-B/32 (\(runner.contract()))")
print("")
let startEmbed = Date()
var frameEmbeds: [[Float]] = []
for sample in samples { frameEmbeds.append(try await runner.encode(image: sample.image)) }
let imageCost = Date().timeIntervalSince(startEmbed)
let startText = Date()
let queryEmbeds = try await runner.encode(texts: queries.map { $0.text })
let textCost = Date().timeIntervalSince(startText)
print(
    "index: \(samples.count) frames in \(f(imageCost)) s (\(f(imageCost / Double(samples.count) * 1000)) ms/frame); "
        + "\(queries.count) queries in \(f(textCost)) s, \(runner.textBatch) per graph run"
)

/// Per query, the cosine against every sample.
let cosines: [[Float]] = queries.indices.map { q in
    frameEmbeds.map { ClipRunner.cosine($0, queryEmbeds[q]) }
}

/// Over-threshold samples merged with the app's own 3.2×step gap rule, so
/// arm B answers in the same Row shape arm A does.
func clipRows(_ scores: [Float], threshold: Float) -> [Row] {
    let hitTimes = samples.indices.filter { scores[$0] >= threshold }.map { samples[$0].time }
    return runs(hitTimes, label: "clip", step: step)
}

func best(_ scores: [Float]) -> (time: Double, score: Float) {
    var bi = 0
    for i in scores.indices where scores[i] > scores[bi] { bi = i }
    return (samples[bi].time, scores[bi])
}

// MARK: - Per-scene cosine profile

print("")
print("### cosine by scene (max over the scene's samples)")
print("")
print("| query | " + scenes.map { $0.name }.joined(separator: " | ") + " | expected |")
print("|---|" + scenes.map { _ in "---|" }.joined() + "---|")
for (q, query) in queries.enumerated() {
    let cells = scenes.map { s -> String in
        let vals = samples.indices.filter { samples[$0].time >= s.start && samples[$0].time < s.end }
            .map { cosines[q][$0] }
        return f2(vals.max() ?? 0)
    }
    print("| \(query.text) | " + cells.joined(separator: " | ") + " | \(query.expect ?? "—") |")
}

// MARK: - Per-query verdicts

print("")
print("### per query")
print("")
let headline = thresholds.first ?? 0.24
print("| query | kind | expected | arm A rows | arm A seek | A? | arm B window @\(f2(headline)) | cos | B? |")
print("|---|---|---|---|---|---|---|---|---|")
for (q, query) in queries.enumerated() {
    let rowsA = labelSearch(rows: index.visual, query: query.text)
    let seekA = rowsA.first.map { $0.start }
    let verdictA: String
    if let expect = query.expect {
        verdictA = (seekA.map { lands($0, in: expect) } ?? false) ? "hit" : (rowsA.isEmpty ? "miss" : "wrong")
    } else {
        verdictA = rowsA.isEmpty ? "correct" : "FP"
    }
    let rowsB = clipRows(cosines[q], threshold: headline)
    let peak = best(cosines[q])
    let windowB = rowsB.first(where: { peak.time >= $0.start && peak.time <= $0.end })
    let verdictB: String
    if let expect = query.expect {
        if peak.score >= headline, lands(peak.time, in: expect) {
            verdictB = "hit"
        } else {
            verdictB = rowsB.isEmpty ? "miss" : "wrong"
        }
    } else {
        verdictB = rowsB.isEmpty ? "correct" : "FP"
    }
    let showA =
        rowsA.isEmpty
        ? "—"
        : rowsA.prefix(3).map { "\(f($0.start))–\(f($0.end)) \($0.text)" }.joined(separator: "; ")
        + (rowsA.count > 3 ? " (+\(rowsA.count - 3))" : "")
    let showB = windowB.map { "\(f($0.start))–\(f($0.end))" } ?? "—"
    print(
        "| \(query.text) | \(query.kind) | \(query.expect ?? "—") | \(showA) | \(seekA.map(f) ?? "—") | \(verdictA) | \(showB) | \(f2(peak.score)) | \(verdictB) |"
    )
}

// MARK: - Headline and sweep

func rateA() -> (hit: Int, any: Int, fp: Int, answerable: Int) {
    var hit = 0, any = 0, fp = 0, answerable = 0
    for query in queries {
        let rows = labelSearch(rows: index.visual, query: query.text)
        if let expect = query.expect {
            answerable += 1
            if let first = rows.first, lands(first.start, in: expect) { hit += 1 }
            if rows.contains(where: { overlaps($0, expect) }) { any += 1 }
        } else if !rows.isEmpty {
            fp += 1
        }
    }
    return (hit, any, fp, answerable)
}

func rateB(threshold: Float) -> (hit: Int, any: Int, fp: Int) {
    var hit = 0, any = 0, fp = 0
    for (q, query) in queries.enumerated() {
        let rows = clipRows(cosines[q], threshold: threshold)
        if let expect = query.expect {
            let peak = best(cosines[q])
            if peak.score >= threshold, lands(peak.time, in: expect) { hit += 1 }
            if rows.contains(where: { overlaps($0, expect) }) { any += 1 }
        } else if !rows.isEmpty {
            fp += 1
        }
    }
    return (hit, any, fp)
}

/// Threshold-free: the top-1 window every retrieval system can always return.
func rateBArgmax() -> (hit: Int, fp: Int) {
    var hit = 0, fp = 0
    for (q, query) in queries.enumerated() {
        let peak = best(cosines[q])
        if let expect = query.expect {
            if lands(peak.time, in: expect) { hit += 1 }
        } else {
            fp += 1  // argmax always answers, so every should-miss is a false positive
        }
    }
    return (hit, fp)
}

let a = rateA()
let misses = queries.filter { $0.expect == nil }.count
print("")
print("### headline")
print("")
print("| arm | answerable hits (seek lands) | any-row hits | false positives on \(misses) should-miss |")
print("|---|---|---|---|")
print("| A — labels only | \(a.hit)/\(a.answerable) | \(a.any)/\(a.answerable) | \(a.fp)/\(misses) |")
for t in thresholds {
    let b = rateB(threshold: t)
    print("| B — CLIP ≥ \(f2(t)) | \(b.hit)/\(a.answerable) | \(b.any)/\(a.answerable) | \(b.fp)/\(misses) |")
}
let argmax = rateBArgmax()
print("| B — CLIP argmax (no threshold) | \(argmax.hit)/\(a.answerable) | — | \(argmax.fp)/\(misses) |")

// The absolute cosine is a per-query scale, not a per-corpus one — a query
// that matches nothing still has a mean and a maximum. So measure the obvious
// alternative on the same numbers: how far the peak stands above the footage's
// own median for that query. This is a reading of the sweep, not a second arm.
print("")
print("### contrast rule — peak minus the query's own median over the footage")
print("")
print("| query | expected | peak | median | contrast | peak window width @0.21 |")
print("|---|---|---|---|---|---|")
func median(_ v: [Float]) -> Float {
    let s = v.sorted()
    return s.isEmpty ? 0 : s[s.count / 2]
}
for (q, query) in queries.enumerated() {
    let peak = best(cosines[q])
    let m = median(cosines[q])
    let width =
        clipRows(cosines[q], threshold: 0.21)
        .first(where: { peak.time >= $0.start && peak.time <= $0.end })
        .map { f($0.end - $0.start) + " s" } ?? "—"
    print(
        "| \(query.text) | \(query.expect ?? "—") | \(f2(peak.score)) | \(f2(m)) | \(f2(peak.score - m)) | \(width) |"
    )
}
print("")
print("| contrast margin | hits (argmax, gated) | false positives |")
print("|---|---|---|")
for margin: Float in [0.02, 0.04, 0.06, 0.08] {
    var hit = 0, fp = 0
    for (q, query) in queries.enumerated() {
        let peak = best(cosines[q])
        let passes = peak.score - median(cosines[q]) >= margin
        if let expect = query.expect {
            if passes, lands(peak.time, in: expect) { hit += 1 }
        } else if passes {
            fp += 1
        }
    }
    print("| \(f2(margin)) | \(hit)/\(a.answerable) | \(fp)/\(misses) |")
}

// MARK: - The answer the model actually reads

// The rates above are retrieval; this is the sentence. Spec E's ruling is that
// the CLIP rung may rank but must not claim, so its row can never open with a
// presence verb — the model has to keep "there isn't one" as an available
// answer (bench case 4) while still getting a candidate to act on. Rendered
// here with `MomentIndexBox.searchFrames`'s own wording on both paths, so the
// A/B shows what the phone would say, not only where it would seek.
//
// Nothing below feeds the rates: it re-renders the same rows.

/// `VideoEditBox.f` — the app drops a trailing .0, so a window reads "12–19 s".
func fa(_ v: Double) -> String {
    let r = (v * 10).rounded() / 10
    return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
}

/// `MomentIndexBox.clipSearch`'s window merge, keeping each window's peak —
/// strongest first, because the rendering names one window and ranks the rest.
func clipWindows(_ scores: [Float], threshold: Float) -> [(row: Row, peak: Float)] {
    var out: [(row: Row, peak: Float)] = []
    for i in samples.indices where scores[i] >= threshold {
        let time = samples[i].time
        if var last = out.last, time - last.row.end <= step * 3.2 {
            last.row.end = time + step / 2
            last.peak = max(last.peak, scores[i])
            out[out.count - 1] = last
        } else {
            out.append((Row(start: max(0, time - step / 2), end: time + step / 2, text: "clip"), scores[i]))
        }
    }
    return out.sorted { $0.peak > $1.peak }
}

/// `MomentIndexBox.searchFrames`, verbatim in shape: the label rows if the
/// shelf speaks, then the CLIP candidate, then the shelf's own negative.
func searchFramesAnswer(_ q: Int, threshold: Float) -> String {
    let rowsA = labelSearch(rows: index.visual, query: queries[q].text)
    let negative = "no moments found for \"\(queries[q].text)\" in the picture"
    if !rowsA.isEmpty {
        let lines = rowsA.prefix(8).map { "\(fa($0.start))–\(fa($0.end)) s — \($0.text)" }
        return "found \(rowsA.count) moment\(rowsA.count == 1 ? "" : "s"): "
            + lines.joined(separator: "; ")
    }
    let windows = clipWindows(cosines[q], threshold: threshold)
    guard let best = windows.first else { return negative }
    var answer =
        "no labelled moment matches \"\(queries[q].text)\" — the closest-looking window is "
        + "\(fa(best.row.start))–\(fa(best.row.end)) s "
        + "(visual similarity \(String(format: "%.2f", best.peak)), not a confirmed sighting)"
    if windows.count > 1 {
        answer += " · other close-looking windows: "
            + windows.dropFirst().prefix(4).map {
                "\(fa($0.row.start))–\(fa($0.row.end)) s (\(String(format: "%.2f", $0.peak)))"
            }.joined(separator: ", ")
    }
    return answer
}

print("")
print("### what search_frames answers at the shipped threshold (\(f2(0.27)))")
print("")
print("| query | verdict word | the row the model reads |")
print("|---|---|---|")
for q in queries.indices {
    let answer = searchFramesAnswer(q, threshold: 0.27)
    let word = answer.hasPrefix("found") ? "found (labels)"
        : (answer.hasPrefix("no labelled moment matches") ? "no + candidate (CLIP)" : "no (labels)")
    print("| \(queries[q].text) | \(word) | \(answer) |")
}

// The union the rung actually ships as: labels first, CLIP where labels are
// silent — which is what "labels+CLIP" means in the ROADMAP's promise.
print("")
print("### labels+CLIP (the union: arm A's rows, arm B where arm A returns nothing)")
print("")
print("| threshold | hits | false positives |")
print("|---|---|---|")
for t in thresholds {
    var hit = 0, fp = 0
    for (q, query) in queries.enumerated() {
        let rowsA = labelSearch(rows: index.visual, query: query.text)
        let peak = best(cosines[q])
        let rowsB = clipRows(cosines[q], threshold: t)
        if let expect = query.expect {
            if let first = rowsA.first {
                if lands(first.start, in: expect) { hit += 1 }
            } else if peak.score >= t, lands(peak.time, in: expect) {
                hit += 1
            }
        } else if !rowsA.isEmpty || !rowsB.isEmpty {
            fp += 1
        }
    }
    print("| \(f2(t)) | \(hit)/\(a.answerable) | \(fp)/\(misses) |")
}

// MARK: - The z rule: each query read in its own units
//
// Everything above measures the cosine on an absolute scale, which is the
// thing the A/B found does not exist. Below, the same 11 queries are scored
// against a background corpus of unrelated footage first, and the peak inside
// journey.mp4 is reported as z = (peak − mean_bg) / sd_bg. A z cut is
// equivalently a per-query cosine cut at mean_bg + z·sd_bg, so the two are the
// same rule expressed in different units — which is the whole claim under
// test. Nothing here touches the rates above; it is an added section.

if let backgroundManifest {
    let manifest = URL(fileURLWithPath: backgroundManifest)
    let cache = backgroundCache.map { URL(fileURLWithPath: $0) }
    let background = try await BackgroundCorpus.build(
        manifest: manifest, cache: cache, framesPerClip: backgroundFramesPerClip, runner: runner)

    print("")
    print("## the z rule — each query against its own null")
    print("")
    let sourceNote =
        background.fromCache
        ? "read from cache"
        : "decoded in \(f(background.decodeCost)) s, embedded in \(f(background.embedCost)) s "
            + "(\(f(background.embedCost / Double(max(1, background.frames)) * 1000)) ms/frame)"
    print(
        "background: \(background.clips) clips, \(background.frames) frames "
            + "(\(backgroundFramesPerClip) per clip), manifest \(manifest.lastPathComponent) — \(sourceNote)"
    )
    let bytes = background.frames * runner.embeddingDimension * MemoryLayout<Float>.size
    print(
        "background embeddings: \(background.frames)×\(runner.embeddingDimension) float32 = "
            + "\(String(format: "%.0f", Double(bytes) / 1024)) KB (\(String(format: "%.0f", Double(bytes) / 2048)) KB as float16)"
    )

    let stats = queries.indices.map { background.stats(for: queryEmbeds[$0]) }
    func z(_ score: Float, _ q: Int) -> Float {
        stats[q].sd > 0 ? (score - stats[q].mean) / stats[q].sd : 0
    }
    /// The same z bar applied per frame — i.e. the per-query cosine cut.
    func zRows(_ q: Int, margin: Float) -> [Row] {
        let cut = stats[q].mean + margin * stats[q].sd
        let hitTimes = samples.indices.filter { cosines[q][$0] >= cut }.map { samples[$0].time }
        return runs(hitTimes, label: "clip", step: step)
    }

    print("")
    print("### z by query (peak inside journey.mp4, in that query's own background units)")
    print("")
    print("| query | kind | expected | peak | bg mean | bg sd | z | cut at z=3.0 |")
    print("|---|---|---|---|---|---|---|---|")
    for (q, query) in queries.enumerated() {
        let peak = best(cosines[q])
        print(
            "| \(query.text) | \(query.kind) | \(query.expect ?? "—") | \(f2(peak.score)) "
                + "| \(f2(stats[q].mean)) | \(f2(stats[q].sd)) | \(String(format: "%.3f", z(peak.score, q))) "
                + "| \(f2(stats[q].mean + 3.0 * stats[q].sd)) |")
    }

    print("")
    print("### z sweep — CLIP alone, accepting the peak only when z ≥ margin")
    print("")
    print("| rule | answerable hits (seek lands) | any-row hits | false positives on \(misses) should-miss |")
    print("|---|---|---|---|")
    for margin in zMargins {
        var hit = 0, any = 0, fp = 0
        for (q, query) in queries.enumerated() {
            let peak = best(cosines[q])
            let rows = zRows(q, margin: margin)
            if let expect = query.expect {
                if z(peak.score, q) >= margin, lands(peak.time, in: expect) { hit += 1 }
                if rows.contains(where: { overlaps($0, expect) }) { any += 1 }
            } else if !rows.isEmpty {
                fp += 1
            }
        }
        print("| B — CLIP z ≥ \(String(format: "%.1f", margin)) | \(hit)/\(a.answerable) | \(any)/\(a.answerable) | \(fp)/\(misses) |")
    }

    print("")
    print("### labels+CLIP under the z rule (arm A's rows, arm B where arm A is silent)")
    print("")
    print("| z | hits | false positives |")
    print("|---|---|---|")
    for margin in zMargins {
        var hit = 0, fp = 0
        for (q, query) in queries.enumerated() {
            let rowsA = labelSearch(rows: index.visual, query: query.text)
            let peak = best(cosines[q])
            let rowsB = zRows(q, margin: margin)
            if let expect = query.expect {
                if let first = rowsA.first {
                    if lands(first.start, in: expect) { hit += 1 }
                } else if z(peak.score, q) >= margin, lands(peak.time, in: expect) {
                    hit += 1
                }
            } else if !rowsA.isEmpty || !rowsB.isEmpty {
                fp += 1
            }
        }
        print("| \(String(format: "%.1f", margin)) | \(hit)/\(a.answerable) | \(fp)/\(misses) |")
    }

    // The arithmetic a phone would do per query, from the numbers just used:
    // one dot product per background frame plus a mean and a variance.
    print("")
    print(
        "per-query cost at query time: \(background.frames) dot products of \(runner.embeddingDimension) "
            + "floats = \(background.frames * runner.embeddingDimension / 1000)K multiply-adds, "
            + "against \(samples.count * runner.embeddingDimension / 1000)K for the video's own frames.")
}
