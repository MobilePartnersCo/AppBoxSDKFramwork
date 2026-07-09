import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

struct InappMessagePreparedContent {
    static let fallbackImageAspectRatio: CGFloat = 1.72

    let spec: InappMessageRenderSpec
    let images: [InappMessagePreparedImage]
    let imageAspectRatio: CGFloat

    init(spec: InappMessageRenderSpec, images: [InappMessagePreparedImage]) {
        self.spec = spec.normalized()
        self.images = images
        self.imageAspectRatio = Self.resolveImageAspectRatio(from: images)
    }

    var failedImageCount: Int {
        images.filter { $0.image == nil }.count
    }

    var loadedImageCount: Int {
        images.count - failedImageCount
    }

    private static func resolveImageAspectRatio(from images: [InappMessagePreparedImage]) -> CGFloat {
        guard let aspectRatio = images.first(where: { $0.aspectRatio != nil })?.aspectRatio else {
            return fallbackImageAspectRatio
        }

        return min(max(aspectRatio, 0.35), 4.0)
    }
}

struct InappMessagePreparedImage {
    let item: InappMessageRenderSpec.Image.Item
    let image: UIImage?
    let pixelSize: CGSize?
    let failureDescription: String?

    var aspectRatio: CGFloat? {
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        return pixelSize.width / pixelSize.height
    }
}
