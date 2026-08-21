// N clips -> one 1280x720 mp4, aspect-fill, re-encoded via frame pull.
// Usage: concat.swift <a.mp4> <secondsA> [<b.mp4> <secondsB> ...] <out.mp4>
// Silent output on purpose: take footage for the frames/OCR indexes; add
// commentary in the source clips when the transcript side is the demo.
import AVFoundation
import AppKit

let argv = CommandLine.arguments
precondition(argv.count >= 4 && argv.count % 2 == 0, "usage: concat.swift <clip> <sec> [...] <out>")
var inputs: [(URL, Double)] = []
var i = 1
while i + 1 < argv.count - 1 {
  inputs.append((URL(fileURLWithPath: argv[i]), Double(argv[i + 1])!))
  i += 2
}
let out = URL(fileURLWithPath: argv.last!)
let width = 1280, height = 720, fps = 12

try? FileManager.default.removeItem(at: out)
let writer = try! AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(
  mediaType: .video,
  outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 5_000_000],
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

var n = 0
for (url, seconds) in inputs {
  let asset = AVURLAsset(url: url)
  let available = CMTimeGetSeconds(asset.duration)
  let take = min(seconds, available - 0.2)
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
  generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
  var t = 0.0
  while t < take {
    guard let cg = try? generator.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
    else { t += 1.0 / Double(fps); continue }
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    let pixel = buffer!
    CVPixelBufferLockBaseAddress(pixel, [])
    let ctx = CGContext(
      data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    let scale = max(CGFloat(width) / CGFloat(cg.width), CGFloat(height) / CGFloat(cg.height))
    let w = CGFloat(cg.width) * scale, h = CGFloat(cg.height) * scale
    ctx.draw(cg, in: CGRect(x: (CGFloat(width) - w) / 2, y: (CGFloat(height) - h) / 2, width: w, height: h))
    CVPixelBufferUnlockBaseAddress(pixel, [])
    adaptor.append(pixel, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(fps)))
    n += 1
    t += 1.0 / Double(fps)
  }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(out.path): \(n) frames = \(n / fps) s, \(inputs.count) scenes")
