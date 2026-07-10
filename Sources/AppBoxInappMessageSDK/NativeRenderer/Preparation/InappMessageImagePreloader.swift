import Foundation
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK
import ImageIO
import UIKit

final class InappMessageImagePreloader {
    private let maxDownloadedBytes: Int
    private let maxDecodedPixelSize: CGFloat
    private let timeoutInterval: TimeInterval
    private let defaultBaseURL = URL(string: "https://consoledev.appboxapp.com")

    init(
        maxDownloadedBytes: Int = 8 * 1024 * 1024,
        maxDecodedPixelSize: CGFloat = 1_400,
        timeoutInterval: TimeInterval = 8
    ) {
        self.maxDownloadedBytes = maxDownloadedBytes
        self.maxDecodedPixelSize = maxDecodedPixelSize
        self.timeoutInterval = timeoutInterval
    }

    func preload(image: InappMessageRenderSpec.Image) async -> [InappMessagePreparedImage] {
        var preparedImages = [InappMessagePreparedImage]()
        preparedImages.reserveCapacity(image.images.count)

        for item in image.images {
            if Task.isCancelled { break }
            preparedImages.append(await preload(item: item))
        }

        return preparedImages
    }

    private func preload(item: InappMessageRenderSpec.Image.Item) async -> InappMessagePreparedImage {
        do {
            let image = try await loadImage(from: item)
            return InappMessagePreparedImage(
                item: item,
                image: image,
                pixelSize: image.cgImage.map { CGSize(width: $0.width, height: $0.height) },
                failureDescription: nil
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return InappMessagePreparedImage(item: item, image: nil, pixelSize: nil, failureDescription: message)
        }
    }

    private func loadImage(from item: InappMessageRenderSpec.Image.Item) async throws -> UIImage {
        try Task.checkCancellation()

        guard let url = resolvedURL(from: item.src) else {
            throw InappMessageImagePreloadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw InappMessageImagePreloadError.httpStatus(httpResponse.statusCode)
        }

        guard data.count <= maxDownloadedBytes else {
            throw InappMessageImagePreloadError.responseTooLarge(data.count)
        }

        return try downsample(data: data)
    }

    private func resolvedURL(from source: String) -> URL? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        guard trimmed.hasPrefix("/"), let defaultBaseURL else { return nil }
        return URL(string: trimmed, relativeTo: defaultBaseURL)?.absoluteURL
    }

    private func downsample(data: Data) throws -> UIImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw InappMessageImagePreloadError.invalidImageData
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDecodedPixelSize)
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw InappMessageImagePreloadError.invalidImageData
        }

        return UIImage(cgImage: cgImage)
    }
}

private enum InappMessageImagePreloadError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case responseTooLarge(Int)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .httpStatus(let statusCode):
            return "Image request failed with HTTP \(statusCode)"
        case .responseTooLarge(let byteCount):
            return "Image response is too large (\(byteCount) bytes)"
        case .invalidImageData:
            return "Image data could not be decoded"
        }
    }
}
