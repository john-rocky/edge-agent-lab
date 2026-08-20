// Replay the polish loop's recorded ops over the fixtures and compose a
// before/after contact sheet. The filter recipes are the app's own
// (PhotoEditTools.swift), so the "after" is pixel-faithful to what the
// model's calls produced during the run.
//
//   xcrun swift replay.swift <run-jsonl> <fixtures-dir> <cases.json> <out.png>
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

let args = CommandLine.arguments
guard args.count == 5 else {
  print("usage: replay.swift <run-jsonl> <fixtures-dir> <cases.json> <out.png>")
  exit(1)
}
let jsonlURL = URL(fileURLWithPath: args[1])
let fixturesDir = URL(fileURLWithPath: args[2])
let casesURL = URL(fileURLWithPath: args[3])
let outURL = URL(fileURLWithPath: args[4])

// case id -> fixture filename (the JSONL rows don't carry the image field)
var fixtureOf: [String: String] = [:]
if let cases = try? JSONSerialization.jsonObject(with: Data(contentsOf: casesURL)) as? [[String: Any]] {
  for c in cases {
    if let id = c["id"] as? String, let image = c["image"] as? String { fixtureOf[id] = image }
  }
}

func percent(_ strength: String) -> Int {
  switch strength.lowercased() { case "a_lot": return 60; case "some": return 35; default: return 15 }
}
func stops(_ strength: String) -> Double {
  switch strength.lowercased() { case "a_lot": return 1.2; case "some": return 0.7; default: return 0.3 }
}

func apply(_ tool: String, _ a: [String: Any], to image: CIImage) -> CIImage {
  let direction = (a["direction"] as? String ?? "").lowercased()
  let strength = a["strength"] as? String ?? "a_little"
  switch tool {
  case "adjust_photo_brightness":
    let amount = (direction == "darker" ? -1 : 1) * percent(strength)
    let f = CIFilter.colorControls()
    f.inputImage = image
    f.brightness = Float(amount) / 250
    return f.outputImage ?? image
  case "adjust_photo_exposure":
    let f = CIFilter.exposureAdjust()
    f.inputImage = image
    f.ev = Float((direction == "down" ? -1.0 : 1.0) * stops(strength))
    return f.outputImage ?? image
  case "adjust_photo_contrast":
    let amount = (direction == "less" ? -1 : 1) * percent(strength)
    let f = CIFilter.colorControls()
    f.inputImage = image
    f.contrast = 1 + Float(amount) / 250
    return f.outputImage ?? image
  case "adjust_photo_saturation":
    let amount = (direction == "more_muted" ? -1 : 1) * percent(strength)
    let f = CIFilter.colorControls()
    f.inputImage = image
    f.saturation = 1 + Float(amount) / 100
    return f.outputImage ?? image
  case "adjust_photo_warmth":
    let amount = CGFloat((direction == "cooler" ? -1 : 1) * percent(strength))
    let f = CIFilter.temperatureAndTint()
    f.inputImage = image
    f.neutral = CIVector(x: 6500, y: 0)
    f.targetNeutral = CIVector(x: 6500 - amount * 30, y: 0)
    return f.outputImage ?? image
  case "auto_enhance_photo":
    var output = image
    for filter in image.autoAdjustmentFilters(options: [.redEye: false]) {
      filter.setValue(output, forKey: kCIInputImageKey)
      if let next = filter.outputImage { output = next }
    }
    return output
  case "apply_photo_filter":
    let names = [
      "mono": "CIPhotoEffectMono", "sepia": "CISepiaTone", "noir": "CIPhotoEffectNoir",
      "vivid": "CIPhotoEffectChrome", "fade": "CIPhotoEffectFade",
    ]
    guard let look = a["look"] as? String, let name = names[look.lowercased()],
      let f = CIFilter(name: name)
    else { return image }
    f.setValue(image, forKey: kCIInputImageKey)
    return f.outputImage ?? image
  default:
    return image  // save / note fakes, redact etc. — no pixel change replayed
  }
}

struct Row {
  let id: String
  let before: NSImage
  let after: NSImage
  let label: String
}

let context = CIContext()
func render(_ image: CIImage) -> NSImage? {
  guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
  return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

func shortOp(_ tool: String, _ a: [String: Any]) -> String {
  let d = (a["direction"] as? String).map { " \($0)" } ?? ""
  let s = (a["strength"] as? String).map { " \($0)" } ?? ""
  let l = (a["look"] as? String).map { " \($0)" } ?? ""
  let name = tool.replacingOccurrences(of: "adjust_photo_", with: "")
    .replacingOccurrences(of: "_photo", with: "").replacingOccurrences(of: "apply_", with: "")
  return name + d + s + l
}

var rows: [Row] = []
for line in try String(contentsOf: jsonlURL, encoding: .utf8).split(separator: "\n") {
  guard let r = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
    r["type"] == nil, r["loop"] as? Bool == true,
    let id = r["case"] as? String, let fixture = fixtureOf[id],
    let ops = r["ops"] as? [[[String: Any]]]
  else { continue }
  guard let base = CIImage(contentsOf: fixturesDir.appendingPathComponent(fixture)) else {
    print("no fixture for \(id)")
    continue
  }
  var current = base
  var chain: [String] = []
  for round in ops {
    for call in round {
      guard let tool = call["tool"] as? String else { continue }
      let raw = call["args"] as? String ?? "{}"
      let parsed =
        (try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any] ?? [:]
      current = apply(tool, parsed, to: current)
      chain.append(shortOp(tool, parsed))
    }
  }
  let stopped = r["stopped"] as? Bool ?? false
  let pass = r["pass"] as? Bool ?? false
  let died = r["error"] != nil
  let verdict = died ? "died: context window" : (stopped ? (pass ? "stopped, PASS" : "stopped") : "never stopped")
  guard let before = render(base), let after = render(current) else { continue }
  rows.append(
    Row(
      id: id, before: before, after: after,
      label: "\(id) — \(verdict)\n\(chain.joined(separator: " → "))"))
}

// Compose: two panels per row, labels above.
let panelW: CGFloat = 480
let panelH: CGFloat = 270
let margin: CGFloat = 10
let textH: CGFloat = 40
let headerH: CGFloat = 34
let rowH = panelH + textH + margin
let sheetW = margin + panelW + margin + panelW + margin
let sheetH = headerH + CGFloat(rows.count) * rowH + margin

let sheet = NSImage(size: NSSize(width: sheetW, height: sheetH))
sheet.lockFocus()
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

let labelAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
  .foregroundColor: NSColor.white,
]
let headAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
  .foregroundColor: NSColor.white,
]

("polish loop r32 (forced-choice reprompt) — before | after, replayed from the recorded calls"
  as NSString)
  .draw(at: NSPoint(x: margin, y: sheetH - headerH + 8), withAttributes: headAttrs)

for (index, row) in rows.enumerated() {
  let top = sheetH - headerH - CGFloat(index) * rowH
  (row.label as NSString).draw(
    in: NSRect(x: margin, y: top - textH, width: sheetW - 2 * margin, height: textH - 4),
    withAttributes: labelAttrs)
  let y = top - textH - panelH
  row.before.draw(
    in: NSRect(x: margin, y: y, width: panelW, height: panelH), from: .zero,
    operation: .copy, fraction: 1)
  row.after.draw(
    in: NSRect(x: margin + panelW + margin, y: y, width: panelW, height: panelH), from: .zero,
    operation: .copy, fraction: 1)
}
sheet.unlockFocus()

guard let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
  let png = rep.representation(using: .png, properties: [:])
else {
  print("compose failed")
  exit(1)
}
try png.write(to: outURL)
print("wrote \(outURL.path) (\(rows.count) rows)")
