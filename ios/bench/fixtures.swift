// Generate the polish loop's fixtures: one base photo, seven variants, each
// defect injected with the app's own filter recipe (PhotoEditTools.swift)
// run backwards — so every defect is, by construction, fixable by the tool
// that names it. The base photo is not committed and neither are the
// outputs; any reasonably exposed landscape or portrait works, and the
// provenance of the one a run used belongs in the run's notes.
//
//   DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer \
//     xcrun swift fixtures.swift <base-photo> [out-dir]
//
// Default out-dir is the Mac bench's fixture folder:
//   ~/Library/Application Support/LFMTools/toolbench-fixtures
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
  print("usage: swift fixtures.swift <base-photo> [out-dir]")
  exit(1)
}
let baseURL = URL(fileURLWithPath: arguments[1])
let outDir =
  arguments.count >= 3
  ? URL(fileURLWithPath: arguments[2])
  : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("LFMTools/toolbench-fixtures", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard var base = CIImage(contentsOf: baseURL) else {
  print("could not read \(baseURL.path)")
  exit(1)
}
// Longest side 1024: vision prefill cost, not pixels, is the loop's budget.
let longest = max(base.extent.width, base.extent.height)
if longest > 1024 {
  base = base.transformed(by: CGAffineTransform(scaleX: 1024 / longest, y: 1024 / longest))
}

func exposure(_ image: CIImage, ev: Float) -> CIImage {
  let filter = CIFilter.exposureAdjust()
  filter.inputImage = image
  filter.ev = ev
  return filter.outputImage!
}

// The app's warmth recipe verbatim: targetNeutral = 6500 - amount * 30,
// LOWER target warms (verified by pixel in PhotoCheck). Negative amount
// here means "make it too cool".
func warmth(_ image: CIImage, amount: CGFloat) -> CIImage {
  let filter = CIFilter.temperatureAndTint()
  filter.inputImage = image
  filter.neutral = CIVector(x: 6500, y: 0)
  filter.targetNeutral = CIVector(x: 6500 - amount * 30, y: 0)
  return filter.outputImage!
}

func colorControls(_ image: CIImage, contrast: Float = 1, saturation: Float = 1) -> CIImage {
  let filter = CIFilter.colorControls()
  filter.inputImage = image
  filter.contrast = contrast
  filter.saturation = saturation
  return filter.outputImage!
}

let variants: [(String, CIImage)] = [
  ("loop-dark", exposure(base, ev: -1.4)),
  ("loop-bright", exposure(base, ev: 1.4)),
  // Deeper than warm's +70: at -70 the cast was too subtle to read as a
  // defect (eyes on it, 2026-08-20). Two gentle warmer rounds fix it.
  ("loop-cool", warmth(base, amount: -110)),
  ("loop-warm", warmth(base, amount: 70)),
  ("loop-flat", colorControls(base, contrast: 0.68)),
  ("loop-dull", colorControls(base, saturation: 0.35)),
  ("loop-good", base),
]

let context = CIContext()
for (name, image) in variants {
  guard let cgImage = context.createCGImage(image, from: image.extent) else {
    print("render failed: \(name)")
    exit(1)
  }
  let url = outDir.appendingPathComponent("\(name).jpg")
  guard
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
  else {
    print("write failed: \(name)")
    exit(1)
  }
  CGImageDestinationAddImage(
    destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
  CGImageDestinationFinalize(destination)
  print("wrote \(url.path)")
}
