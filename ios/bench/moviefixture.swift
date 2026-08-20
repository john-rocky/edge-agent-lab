#!/usr/bin/env xcrun swift
// A test video for the moment-seek pack: 40 s of colored "match" scenes
// with scoreboard text burned in and a spoken commentary track, so every
// side of the real index (Vision scene labels, OCR, on-device speech) has
// something true to find. Synthetic on purpose — the pipeline is what is
// under test; the postable take uses real footage.
//
//   xcrun swift ios/bench/moviefixture.swift /tmp/match.mp4
//
// Timeline (seconds → what is on screen / said):
//    0–8   green pitch, "BLU 0-0 RED"          say@1  "The match is underway here in the summer heat."
//    8–16  green pitch, "BLU 0-0 RED"          say@10 "A long ball forward, the keeper comes out."
//   16–24  gold flash,  "GOAL!" big            say@17 "What a goal! An absolute rocket into the top corner!"
//   24–32  green pitch, "BLU 1-0 RED"          say@26 "They lead one nil with ten minutes to play."
//   32–40  blue dusk,   "FULL TIME BLU 1-0"    say@34 "And that is full time. A famous win."
import AVFoundation
import AppKit
import CoreGraphics

let out = CommandLine.arguments.count > 1
  ? URL(fileURLWithPath: CommandLine.arguments[1])
  : URL(fileURLWithPath: "/tmp/match.mp4")

let width = 1280, height = 720, fps = 12, seconds = 40

struct Scene {
  let start: Double
  let end: Double
  let top: (r: CGFloat, g: CGFloat, b: CGFloat)
  let bottom: (r: CGFloat, g: CGFloat, b: CGFloat)
  let text: String
  let big: Bool
}
let scenes: [Scene] = [
  Scene(start: 0, end: 8, top: (0.13, 0.45, 0.18), bottom: (0.07, 0.30, 0.10), text: "BLU 0-0 RED", big: false),
  Scene(start: 8, end: 16, top: (0.16, 0.50, 0.20), bottom: (0.08, 0.32, 0.12), text: "BLU 0-0 RED", big: false),
  Scene(start: 16, end: 24, top: (0.95, 0.75, 0.10), bottom: (0.85, 0.45, 0.05), text: "GOAL!", big: true),
  Scene(start: 24, end: 32, top: (0.13, 0.45, 0.18), bottom: (0.07, 0.30, 0.10), text: "BLU 1-0 RED", big: false),
  Scene(start: 32, end: 40, top: (0.10, 0.15, 0.40), bottom: (0.05, 0.07, 0.22), text: "FULL TIME BLU 1-0 RED", big: false),
]
let lines: [(at: Double, text: String)] = [
  (1, "The match is underway here in the summer heat."),
  (10, "A long ball forward, and the keeper comes out."),
  (17, "What a goal! An absolute rocket into the top corner!"),
  (26, "They lead one nil with ten minutes to play."),
  (34, "And that is full time. A famous win."),
]

func frame(at t: Double) -> CGImage {
  let scene = scenes.last { t >= $0.start } ?? scenes[0]
  let ctx = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  let colors = [
    CGColor(red: scene.top.r, green: scene.top.g, blue: scene.top.b, alpha: 1),
    CGColor(red: scene.bottom.r, green: scene.bottom.g, blue: scene.bottom.b, alpha: 1),
  ]
  let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(
    gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: .zero, options: [])
  // A moving "ball" so consecutive frames differ and encoders stay honest.
  ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
  let x = 80 + (CGFloat(t) * 27).truncatingRemainder(dividingBy: CGFloat(width - 160))
  ctx.fillEllipse(in: CGRect(x: x, y: 90, width: 36, height: 36))
  // The scoreboard / banner, sharp and high-contrast for OCR.
  let text = scene.text as NSString
  let size: CGFloat = scene.big ? 180 : 64
  let font = NSFont.boldSystemFont(ofSize: size)
  let attributes: [NSAttributedString.Key: Any] = [
    .font: font, .foregroundColor: NSColor.white,
  ]
  let bounds = text.size(withAttributes: attributes)
  let origin = CGPoint(
    x: (CGFloat(width) - bounds.width) / 2,
    y: scene.big ? (CGFloat(height) - bounds.height) / 2 : CGFloat(height) - bounds.height - 40)
  ctx.setFillColor(CGColor(gray: 0, alpha: 0.55))
  ctx.fill(CGRect(origin: origin, size: bounds).insetBy(dx: -24, dy: -12))
  let nsContext = NSGraphicsContext(cgContext: ctx, flipped: false)
  NSGraphicsContext.current = nsContext
  text.draw(at: origin, withAttributes: attributes)
  NSGraphicsContext.current = nil
  return ctx.makeImage()!
}

// 1. The silent video track.
let silent = out.deletingLastPathComponent().appendingPathComponent("fixture-silent.mp4")
try? FileManager.default.removeItem(at: silent)
let writer = try! AVAssetWriter(outputURL: silent, fileType: .mp4)
let input = AVAssetWriterInput(
  mediaType: .video,
  outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
  ])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
  assetWriterInput: input,
  sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
  ])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
for n in 0..<(seconds * fps) {
  while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
  let t = Double(n) / Double(fps)
  let image = frame(at: t)
  var buffer: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
  let pixel = buffer!
  CVPixelBufferLockBaseAddress(pixel, [])
  let ctx = CGContext(
    data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  CVPixelBufferUnlockBaseAddress(pixel, [])
  adaptor.append(pixel, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(fps)))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("video track written")

// 2. The commentary lines, one aiff per line via the system voice.
var spoken: [(at: Double, url: URL)] = []
for (index, line) in lines.enumerated() {
  let url = out.deletingLastPathComponent().appendingPathComponent("fixture-line\(index).aiff")
  try? FileManager.default.removeItem(at: url)
  let say = Process()
  say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
  // An explicit English voice: the system default followed the device
  // locale and the recognizer got one garbled line out of five.
  say.arguments = ["-v", "Daniel", "-r", "170", "-o", url.path, line.text]
  try! say.run()
  say.waitUntilExit()
  spoken.append((line.at, url))
}
print("\(spoken.count) commentary lines synthesized")

// 2.5 A crowd-noise bed under the whole clip: the recognizer finalizes and
// stops at a long silence, and with 5–9 s gaps between lines it kept only
// the last one. Continuous low noise keeps it listening — and sounds like
// a stadium.
let noiseURL = out.deletingLastPathComponent().appendingPathComponent("fixture-noise.m4a")
try? FileManager.default.removeItem(at: noiseURL)
do {
  let rate = 22050.0
  let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
  let file = try AVAudioFile(
    forWriting: noiseURL,
    settings: [
      AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: 1,
    ])
  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate))!
  buffer.frameLength = buffer.frameCapacity
  var held: Float = 0
  for _ in 0..<seconds {
    let samples = buffer.floatChannelData![0]
    for i in 0..<Int(buffer.frameLength) {
      // Brown-ish noise: integrated white, quiet.
      held = max(-1, min(1, held + Float.random(in: -0.02...0.02)))
      samples[i] = held * 0.05
    }
    try file.write(from: buffer)
  }
}
print("crowd bed written")

// 3. Mux: video + each line at its offset.
let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: silent)
let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let sourceVideo = videoAsset.tracks(withMediaType: .video).first!
try! videoTrack.insertTimeRange(
  CMTimeRange(start: .zero, duration: videoAsset.duration), of: sourceVideo, at: .zero)
let bedTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
let bedAsset = AVURLAsset(url: noiseURL)
if let bed = bedAsset.tracks(withMediaType: .audio).first {
  try! bedTrack.insertTimeRange(
    CMTimeRange(start: .zero, duration: bedAsset.duration), of: bed, at: .zero)
}
let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
for (at, url) in spoken {
  let asset = AVURLAsset(url: url)
  guard let track = asset.tracks(withMediaType: .audio).first else { continue }
  try! audioTrack.insertTimeRange(
    CMTimeRange(start: .zero, duration: asset.duration), of: track,
    at: CMTime(seconds: at, preferredTimescale: 600))
}
try? FileManager.default.removeItem(at: out)
let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
export.outputURL = out
export.outputFileType = .mp4
let exported = DispatchSemaphore(value: 0)
export.exportAsynchronously { exported.signal() }
exported.wait()
try? FileManager.default.removeItem(at: silent)
try? FileManager.default.removeItem(at: noiseURL)
for (_, url) in spoken { try? FileManager.default.removeItem(at: url) }
print("wrote \(out.path) (\(seconds) s)")
