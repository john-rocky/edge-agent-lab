// Build the photo-library pack a library of real photographs, out of footage
// this lane already has on disk.
//
//   DEVELOPER_DIR=/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer \
//     xcrun swift libraryfixture.swift [out-dir]
//
// Default out-dir is the Mac stage's fixture folder:
//   ~/Library/Application Support/LFMTools/toolbench-fixtures/photo-library
//
// Why frames and not a photo set: the pack's perception rung has to be given
// *photographs* — VNClassify on a drawn gradient says nothing a case could be
// worded against, and the playbook's rule is that synthetic material proves
// plumbing and never appears in a take. journey.mp4 (four Pexels scenes, the
// moment-seek take's own footage) and a couple of what-can-ai-see's Pexels
// clips are real photography, already vetted, already licensed for this use.
//
// What is mock and what is measured, kept straight: the **metadata** here —
// dates, places, albums, favourites, the names of the people — is invented,
// exactly as a canned world's always was, because no pixel carries it. The
// **content** is not written down at all: `looks`, `text`, faces, sharpness
// and the duplicate pairs come from the OS shelf at index time
// (PhotoLibraryBox), which is the whole point of the rung.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let home = FileManager.default.homeDirectoryForCurrentUser
let outDir =
  CommandLine.arguments.count >= 2
  ? URL(fileURLWithPath: CommandLine.arguments[1])
  : home.appendingPathComponent(
    "Library/Application Support/LFMTools/toolbench-fixtures/photo-library", isDirectory: true)

/// One photo: where its pixels come from, and the metadata a library would
/// hold about it. Frames from one scene a few seconds apart are the duplicate
/// pairs — a real "same shot twice", not a copied file.
struct Shot {
  let id: Int
  let source: String
  let seconds: Double
  let date: String
  let place: String
  let album: String?
  let favorite: Bool
  let people: [String]
}

let journey = home.appendingPathComponent("Library/Application Support/LFMTools/journey.mp4").path
let clips = home.appendingPathComponent("code/what-can-ai-see/clips").path
let sign = "\(clips)/text-4517354/clip.mp4"
let office = "\(clips)/office-11903981/clip.mp4"

// The story the metadata tells, chosen so the pack's own beats are answerable:
// last summer holds the beach (the composition case), the trip album holds the
// forest walk, Work holds the office and the sign, and two pairs are one scene
// seconds apart (the duplicate rung).
let shots: [Shot] = [
  Shot(id: 1, source: journey, seconds: 14.2, date: "2025-07-19", place: "Kamakura", album: nil, favorite: true, people: []),
  Shot(id: 2, source: journey, seconds: 17.4, date: "2025-07-19", place: "Kamakura", album: nil, favorite: false, people: []),
  Shot(id: 3, source: journey, seconds: 1.6, date: "2025-08-02", place: "Tokyo", album: nil, favorite: false, people: []),
  Shot(id: 4, source: journey, seconds: 4.8, date: "2025-08-02", place: "Tokyo", album: nil, favorite: false, people: []),
  Shot(id: 5, source: journey, seconds: 7.9, date: "2025-10-12", place: "Kyoto", album: "Kyoto trip", favorite: false, people: []),
  Shot(id: 6, source: journey, seconds: 11.1, date: "2025-10-12", place: "Kyoto", album: "Kyoto trip", favorite: true, people: []),
  Shot(id: 7, source: journey, seconds: 20.6, date: "2026-06-20", place: "Osaka", album: nil, favorite: false, people: []),
  Shot(id: 8, source: journey, seconds: 23.7, date: "2026-06-20", place: "Osaka", album: nil, favorite: true, people: []),
  Shot(id: 9, source: sign, seconds: 1.8, date: "2026-07-11", place: "Tokyo", album: nil, favorite: false, people: []),
  Shot(id: 10, source: office, seconds: 2.2, date: "2026-08-06", place: "Tokyo", album: "Work", favorite: false, people: ["Mei"]),
  Shot(id: 11, source: office, seconds: 6.6, date: "2026-08-06", place: "Tokyo", album: "Work", favorite: false, people: ["Mei", "Ken"]),
  Shot(id: 12, source: office, seconds: 11.0, date: "2026-08-07", place: "Tokyo", album: "Work", favorite: false, people: ["Ken"]),
]

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func frame(_ path: String, at seconds: Double) -> CGImage? {
  let asset = AVURLAsset(url: URL(fileURLWithPath: path))
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.requestedTimeToleranceBefore = .zero
  generator.requestedTimeToleranceAfter = .zero
  generator.maximumSize = CGSize(width: 1280, height: 1280)
  return try? generator.copyCGImage(
    at: CMTime(seconds: seconds, preferredTimescale: 600), actualTime: nil)
}

var manifest: [[String: Any]] = []
var written = 0
for shot in shots {
  guard FileManager.default.fileExists(atPath: shot.source) else {
    print("skipped #\(shot.id): no \(shot.source)")
    continue
  }
  guard let image = frame(shot.source, at: shot.seconds) else {
    print("skipped #\(shot.id): could not read \(shot.seconds) s")
    continue
  }
  let file = String(format: "%02d.jpg", shot.id)
  let url = outDir.appendingPathComponent(file)
  guard
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
  else { continue }
  CGImageDestinationAddImage(
    destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
  guard CGImageDestinationFinalize(destination) else { continue }
  written += 1
  var row: [String: Any] = [
    "id": shot.id, "file": file, "date": shot.date, "place": shot.place,
    "favorite": shot.favorite, "people": shot.people,
    // Provenance travels with the row: a take has to be able to say where its
    // pixels came from, and a fixture nobody can trace is a fixture nobody
    // should publish.
    "source": "\((shot.source as NSString).lastPathComponent)@\(shot.seconds)s",
  ]
  if let album = shot.album { row["album"] = album }
  manifest.append(row)
}

let data = try JSONSerialization.data(
  withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: outDir.appendingPathComponent("library.json"))
print("wrote \(written) photos + library.json to \(outDir.path)")
print("scout them: xcrun swift libraryscout.swift \(outDir.path)")
