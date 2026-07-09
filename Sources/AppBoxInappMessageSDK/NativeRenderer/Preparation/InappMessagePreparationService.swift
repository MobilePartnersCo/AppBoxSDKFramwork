import Foundation
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

final class InappMessagePreparationService {
    private let imagePreloader: InappMessageImagePreloader

    init(imagePreloader: InappMessageImagePreloader = InappMessageImagePreloader()) {
        self.imagePreloader = imagePreloader
    }

    func prepare(spec: InappMessageRenderSpec) async throws -> InappMessagePreparedContent {
        try Task.checkCancellation()

        let normalizedSpec = spec.normalized()
        guard normalizedSpec.card.image.enabled else {
            return InappMessagePreparedContent(spec: normalizedSpec, images: [])
        }

        let images = await imagePreloader.preload(image: normalizedSpec.card.image)
        try Task.checkCancellation()
        return InappMessagePreparedContent(spec: normalizedSpec, images: images)
    }
}
