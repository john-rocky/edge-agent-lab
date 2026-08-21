// Frame sequence -> mp4. Usage: assemble.swift <framesDir> <out.mp4> <fps>
import AVFoundation
import AppKit

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let fps = Int(CommandLine.arguments[3]) ?? 2

let frames = try! FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
  .filter { $0.pathExtension == "png" }
  .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = NSImage(contentsOf: frames[0])?.cgImage(forProposedRect: nil, context: nil, hints: nil)
else { fatalError("no frames") }
let width = first.width - first.width % 2
let height = first.height - first.height % 2

try? FileManager.default.removeItem(at: out)
let writer = try! AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(
  mediaType: .video,
  outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000],
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
for (n, url) in frames.enumerated() {
  guard let cg = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
  else { continue }
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
  ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
  CVPixelBufferUnlockBaseAddress(pixel, [])
  adaptor.append(pixel, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: CMTimeScale(fps)))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(out.path): \(frames.count) frames at \(fps) fps = \(frames.count / fps) s")
