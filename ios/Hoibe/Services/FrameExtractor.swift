import AVFoundation
import Accelerate
import CoreImage
import Foundation

/// Extracts frames from video, computes sharpness, and returns JPEG data.
struct FrameExtractor: FrameExtracting {

    func extractFrames(
        from url: URL,
        count: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        let startTime = duration * window.start
        let endTime = duration * window.end
        let span = endTime - startTime

        let times: [CMTime] = (0..<count).map { i in
            let t = count > 1 ? startTime + span * Double(i) / Double(count - 1) : startTime
            return CMTime(seconds: t, preferredTimescale: 600)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        var framesJPEG = [Data]()
        var timestamps = [Double]()
        var sharpnessScores = [Double]()

        for time in times {
            let (cgImage, actualTime) = try await generator.image(at: time)
            let ciImage = CIImage(cgImage: cgImage)
            let sharpness = computeSharpness(ciImage)
            let jpeg = encodeJPEG(cgImage: cgImage, quality: jpegQuality)

            framesJPEG.append(jpeg)
            timestamps.append(actualTime.seconds)
            sharpnessScores.append(sharpness)
        }

        return FrameData(framesJPEG: framesJPEG, timestamps: timestamps, sharpnessScores: sharpnessScores)
    }

    func extractSharpestFrames(
        from url: URL,
        topN: Int,
        candidateCount: Int,
        window: (start: Double, end: Double),
        maxWidth: Int,
        jpegQuality: Double
    ) async throws -> FrameData {
        let all = try await extractFrames(from: url, count: candidateCount, window: window, maxWidth: maxWidth, jpegQuality: jpegQuality)
        let ranked = all.indicesBySharpness.prefix(topN)

        let sortedIndices = ranked.sorted()
        return FrameData(
            framesJPEG: sortedIndices.map { all.framesJPEG[$0] },
            timestamps: sortedIndices.map { all.timestamps[$0] },
            sharpnessScores: sortedIndices.map { all.sharpnessScores[$0] }
        )
    }

    // MARK: - Private

    private func computeSharpness(_ image: CIImage) -> Double {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return 0 }

        let context = CIContext()
        let width = Int(min(extent.width, 512))
        let height = Int(min(extent.height, 512))

        guard let cgImage = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return 0
        }

        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return 0 }

        let bytesPerRow = cgImage.bytesPerRow
        let bpp = cgImage.bitsPerPixel / 8

        // Convert to grayscale float buffer
        var gray = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bpp
                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])
                gray[y * width + x] = 0.299 * r + 0.587 * g + 0.114 * b
            }
        }

        // Laplacian kernel convolution (approximate with 3x3)
        let kernel: [Float] = [0, 1, 0, 1, -4, 1, 0, 1, 0]
        var output = [Float](repeating: 0, count: width * height)
        var src = vImage_Buffer(data: &gray, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float>.size)
        var dst = vImage_Buffer(data: &output, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float>.size)

        vImageConvolve_PlanarF(&src, &dst, nil, 0, 0, kernel, 3, 3, 0, vImage_Flags(kvImageEdgeExtend))

        // Variance of Laplacian
        var mean: Float = 0
        var meanSq: Float = 0
        vDSP_meanv(output, 1, &mean, vDSP_Length(output.count))
        vDSP_measqv(output, 1, &meanSq, vDSP_Length(output.count))
        let variance = Double(meanSq - mean * mean)
        return max(variance, 0)
    }

    private func encodeJPEG(cgImage: CGImage, quality: Double) -> Data {
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        return context.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]) ?? Data()
    }
}
