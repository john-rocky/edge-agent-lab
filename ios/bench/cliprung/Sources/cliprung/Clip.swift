// Clip.swift — arm B: the CLIP rung over the same samples.
//
// The exported bundle is one joint graph — inputs pixel_values [1,3,224,224]
// and input_ids/attention_mask [3,77], outputs image_embeds [1,512] and
// text_embeds [3,512], both L2-normalized in graph, so cosine is a dot
// product. The text side is batched three at a time; `ImageTextEncoder.encode
// (text:)` spends a whole graph run on one query and pads the other two rows
// with dummies. This runner uses the batch instead of fighting it: three
// queries per run, all three rows read back.

import CoreAIKitVision
import CoreGraphics
import Foundation

final class ClipRunner {
    private let graph: GraphModel
    private let tokenizer: CLIPTokenizer
    private let preprocessor: ImagePreprocessor
    private let imageInput: String
    private let textInput: String
    private let maskInput: String?
    private let imageShape: [Int]
    private let textShape: [Int]
    let embeddingDimension: Int
    /// How many text rows one graph run carries (3 for this export).
    var textBatch: Int { textShape[0] }

    init(bundleAt url: URL, computeUnits: GraphModel.ComputeUnits) async throws {
        let fm = FileManager.default
        guard
            let modelURL = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "aimodel" })
        else { throw Failure("no .aimodel under \(url.path)") }
        let g = try await GraphModel(contentsOf: modelURL, computeUnits: computeUnits)
        graph = g
        tokenizer = try CLIPTokenizer(bundleAt: url)

        func pick(_ namePart: String, rank: Int) throws -> String {
            if let byName = g.inputNames.first(where: { $0.contains(namePart) }) { return byName }
            if let byRank = g.inputNames.first(where: { g.shape(ofInput: $0)?.count == rank }) {
                return byRank
            }
            throw Failure("could not identify '\(namePart)' among \(g.inputNames)")
        }
        let imageInput = try pick("pixel", rank: 4)
        let textInput = try pick("input_ids", rank: 2)
        self.imageInput = imageInput
        self.textInput = textInput
        maskInput = g.inputNames.first(where: { $0.contains("mask") })
        guard let imageShape = g.shape(ofInput: imageInput), imageShape.count == 4,
            let textShape = g.shape(ofInput: textInput), textShape.count == 2,
            let embeds = g.shape(ofOutput: "image_embeds")
        else { throw Failure("unexpected CLIP graph shapes") }
        self.imageShape = imageShape
        self.textShape = textShape
        embeddingDimension = embeds[embeds.count - 1]
        preprocessor = ImagePreprocessor(
            size: imageShape[2], mean: ImagePreprocessor.clip224.mean,
            std: ImagePreprocessor.clip224.std)
    }

    func contract() -> String {
        let ins = graph.inputNames.map { "\($0) \(graph.shape(ofInput: $0) ?? [])" }
        let outs = graph.outputNames.map { "\($0) \(graph.shape(ofOutput: $0) ?? [])" }
        return "in: " + ins.joined(separator: ", ") + " | out: " + outs.joined(separator: ", ")
    }

    func encode(image: CGImage) async throws -> [Float] {
        let pixels = try preprocessor.chw(from: image)
        let out = try await graph.run(inputs(pixels: pixels, rows: []))
        guard let value = out["image_embeds"] else { throw Failure("no image_embeds") }
        return Array(value.floats().prefix(embeddingDimension))
    }

    /// Embeds every text, `textBatch` per graph run.
    func encode(texts: [String]) async throws -> [[Float]] {
        var out: [[Float]] = []
        var i = 0
        while i < texts.count {
            let chunk = Array(texts[i..<min(i + textBatch, texts.count)])
            let rows = chunk.map { tokenizer.encode($0, contextLength: textShape[1]) }
            let result = try await graph.run(inputs(pixels: nil, rows: rows))
            guard let value = result["text_embeds"] else { throw Failure("no text_embeds") }
            let flat = value.floats()
            let stride = flat.count / textBatch
            for r in 0..<chunk.count {
                out.append(Array(flat[(r * stride)..<(r * stride + embeddingDimension)]))
            }
            i += textBatch
        }
        return out
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        var dot: Float = 0
        for i in 0..<min(a.count, b.count) { dot += a[i] * b[i] }
        return dot
    }

    private func inputs(pixels: [Float]?, rows: [[Int32]]) -> [String: TensorValue] {
        var result: [String: TensorValue] = [:]
        result[imageInput] = .float32(
            pixels ?? [Float](repeating: 0, count: imageShape.reduce(1, *)), shape: imageShape)
        let batch = textShape[0]
        let length = textShape[1]
        var dummy = [Int32](repeating: CLIPTokenizer.eotTokenId, count: length)
        dummy[0] = CLIPTokenizer.sotTokenId
        var ids: [Int32] = []
        ids.reserveCapacity(batch * length)
        for r in 0..<batch { ids += (r < rows.count ? rows[r] : dummy) }
        result[textInput] = .int32(ids, shape: textShape)
        if let maskInput {
            var mask: [Int32] = []
            mask.reserveCapacity(batch * length)
            for row in 0..<batch {
                let rowIds = Array(ids[(row * length)..<((row + 1) * length)])
                let eot = rowIds.firstIndex(of: CLIPTokenizer.eotTokenId) ?? (length - 1)
                for i in 0..<length { mask.append(i <= eot ? 1 : 0) }
            }
            result[maskInput] = .int32(mask, shape: textShape)
        }
        return result
    }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
