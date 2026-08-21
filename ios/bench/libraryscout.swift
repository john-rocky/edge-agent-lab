// What the OS shelf actually says about a folder of photos.
//
// The photo-library pack's rungs are Vision and CoreImage, and its canned rows
// are a *claim* about what those rungs would say. This scouts the claim: the
// same requests the pack's perception rung will make, run over real pixels,
// printed as the vocabulary they produce. The playbook's rule for footage
// holds for stills — scout, then word: never write a case against a label that
// never fired.
//
//   DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer \
//     xcrun swift libraryscout.swift <image|folder|video.mp4> …
//
// A .mp4 argument is sampled (default 6 frames, `--frames N`) — real
// photographs are what this needs, and the lane already has real footage on
// disk. Nothing is written anywhere; the output is the instrument.
//
// The five rungs, in the order the pack prices them:
//   classify  VNClassifyImageRequest      — scene nouns, the cheap shelf
//   animals   VNRecognizeAnimalsRequest   — dog and cat, and nothing else
//   text      VNRecognizeTextRequest      — the OCR rung
//   faces     VNDetectFaceRectanglesRequest — presence and count, never a name
//   sharp     variance of the Laplacian over a 256-px grey render
//   ahash     8×8 average hash, for the duplicate rung
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision

// MARK: - Arguments

var paths: [String] = []
var framesPerVideo = 6
var argv = Array(CommandLine.arguments.dropFirst())
while let first = argv.first {
  argv.removeFirst()
  if first == "--frames", let value = argv.first, let n = Int(value) {
    framesPerVideo = n
    argv.removeFirst()
  } else {
    paths.append(first)
  }
}
guard !paths.isEmpty else {
  print("usage: swift libraryscout.swift [--frames N] <image|folder|video.mp4> …")
  exit(1)
}

// MARK: - Loading

struct Frame {
  let name: String
  let image: CGImage
}

func imagesIn(folder: URL) -> [URL] {
  let kinds = ["jpg", "jpeg", "png", "heic", "heif"]
  let listed =
    (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
    ?? []
  return listed.filter { kinds.contains($0.pathExtension.lowercased()) }.sorted {
    $0.lastPathComponent < $1.lastPathComponent
  }
}

func load(_ url: URL) -> CGImage? {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// Frames at even spacing, skipping the first and last half-interval — a cut's
/// own boundary is the least representative frame in a scene.
func sample(video url: URL, count: Int) -> [Frame] {
  let asset = AVURLAsset(url: url)
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.requestedTimeToleranceBefore = .zero
  generator.requestedTimeToleranceAfter = .zero
  generator.maximumSize = CGSize(width: 1280, height: 1280)
  let seconds = CMTimeGetSeconds(asset.duration)
  guard seconds > 0 else { return [] }
  let step = seconds / Double(count)
  var out: [Frame] = []
  for index in 0..<count {
    let at = step / 2 + step * Double(index)
    guard
      let image = try? generator.copyCGImage(at: CMTime(seconds: at, preferredTimescale: 600), actualTime: nil)
    else { continue }
    out.append(
      Frame(
        name: "\(url.deletingPathExtension().lastPathComponent)@\(String(format: "%.1f", at))s",
        image: image))
  }
  return out
}

var frames: [Frame] = []
for path in paths {
  let url = URL(fileURLWithPath: path)
  var isDirectory: ObjCBool = false
  guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
    print("missing: \(path)")
    continue
  }
  if isDirectory.boolValue {
    for image in imagesIn(folder: url) {
      if let cg = load(image) { frames.append(Frame(name: image.lastPathComponent, image: cg)) }
    }
  } else if ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) {
    frames += sample(video: url, count: framesPerVideo)
  } else if let cg = load(url) {
    frames.append(Frame(name: url.lastPathComponent, image: cg))
  }
}
guard !frames.isEmpty else {
  print("nothing to scout")
  exit(1)
}

// MARK: - The pixel rungs (sharpness and the duplicate hash)

/// One grey byte buffer, used by both: a Laplacian needs neighbours and an
/// average hash needs a thumbnail, and neither wants a colour space argument.
func grey(_ image: CGImage, side: Int) -> [Double] {
  var pixels = [UInt8](repeating: 0, count: side * side)
  guard
    let context = CGContext(
      data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
  else { return [] }
  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
  return pixels.map(Double.init)
}

/// Variance of the Laplacian — the standard focus measure. Scale-free enough
/// to rank one library's photos against each other, which is all the "blurry"
/// rung ever has to do; it is not a number to threshold across cameras.
func sharpness(_ image: CGImage) -> Double {
  let side = 256
  let g = grey(image, side: side)
  guard g.count == side * side else { return 0 }
  var values: [Double] = []
  values.reserveCapacity((side - 2) * (side - 2))
  for y in 1..<(side - 1) {
    for x in 1..<(side - 1) {
      let i = y * side + x
      values.append(g[i - side] + g[i + side] + g[i - 1] + g[i + 1] - 4 * g[i])
    }
  }
  let mean = values.reduce(0, +) / Double(values.count)
  return values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
}

func averageHash(_ image: CGImage) -> UInt64 {
  let g = grey(image, side: 8)
  guard g.count == 64 else { return 0 }
  let mean = g.reduce(0, +) / 64
  var bits: UInt64 = 0
  for (index, value) in g.enumerated() where value > mean { bits |= (1 << UInt64(index)) }
  return bits
}

func hamming(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }

// MARK: - The Vision rungs

struct Reading {
  let name: String
  var labels: [(String, Float)] = []
  var animals: [String] = []
  var text: [String] = []
  var faces: Int = 0
  var sharp: Double = 0
  var hash: UInt64 = 0
}

var readings: [Reading] = []
for frame in frames {
  var reading = Reading(name: frame.name)
  let classify = VNClassifyImageRequest()
  let animals = VNRecognizeAnimalsRequest()
  let text = VNRecognizeTextRequest()
  text.recognitionLevel = .accurate
  text.recognitionLanguages = ["en-US", "ja-JP"]
  let faces = VNDetectFaceRectanglesRequest()
  let handler = VNImageRequestHandler(cgImage: frame.image)
  do {
    try handler.perform([classify, animals, text, faces])
  } catch {
    print("\(frame.name): vision failed — \(error.localizedDescription)")
    continue
  }
  reading.labels = (classify.results ?? []).filter { $0.confidence > 0.35 }.prefix(8)
    .map { ($0.identifier.lowercased().replacingOccurrences(of: "_", with: " "), $0.confidence) }
  reading.animals = (animals.results ?? []).flatMap { observation in
    observation.labels.filter { $0.confidence > 0.5 }.map { $0.identifier.lowercased() }
  }
  reading.text = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count >= 2 }
  reading.faces = (faces.results ?? []).count
  reading.sharp = sharpness(frame.image)
  reading.hash = averageHash(frame.image)
  readings.append(reading)
}

// MARK: - The report

print("SCOUT \(readings.count) photos\n")
for reading in readings {
  print(reading.name)
  print(
    "  classify: "
      + (reading.labels.isEmpty
        ? "(nothing over 0.35)"
        : reading.labels.map { "\($0.0) \(String(format: "%.2f", $0.1))" }.joined(separator: ", ")))
  if !reading.animals.isEmpty { print("  animals:  " + reading.animals.joined(separator: ", ")) }
  if !reading.text.isEmpty {
    print("  text:     " + reading.text.prefix(6).joined(separator: " | "))
  }
  if reading.faces > 0 { print("  faces:    \(reading.faces)") }
  print("  sharp:    \(String(format: "%.0f", reading.sharp))")
}

print("\nVOCABULARY — every label the shelf produced, most photos first")
var counts: [String: Int] = [:]
for reading in readings {
  for (label, _) in reading.labels { counts[label, default: 0] += 1 }
  for animal in reading.animals { counts["\(animal) (detector)", default: 0] += 1 }
}
print(
  counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
    .map { "\($0.key)×\($0.value)" }.joined(separator: ", "))

print("\nSHARPNESS — softest first; the blurry rung is a ranking, not a threshold")
for reading in readings.sorted(by: { $0.sharp < $1.sharp }).prefix(8) {
  print("  \(String(format: "%8.0f", reading.sharp))  \(reading.name)")
}

print("\nDUPLICATES — average-hash pairs within 8 bits of each other")
var pairs = 0
for (i, a) in readings.enumerated() {
  for b in readings.dropFirst(i + 1) {
    let distance = hamming(a.hash, b.hash)
    guard distance <= 8 else { continue }
    print("  \(distance) bits: \(a.name)  ≈  \(b.name)")
    pairs += 1
  }
}
if pairs == 0 { print("  none") }

print("\nWHO IS IN THEM — faces are presence, never a name")
let withFaces = readings.filter { $0.faces > 0 }
print(
  withFaces.isEmpty
    ? "  no faces in any photo"
    : "  " + withFaces.map { "\($0.name)×\($0.faces)" }.joined(separator: ", "))
