import UIKit
@_spi(AppBoxInappMessageSDK) import AppBoxCoreSDK

enum InappMessageContainerMeasurer {
    static func fittingHeight(
        for content: InappMessagePreparedContent,
        width: CGFloat,
        maxHeight: CGFloat,
        environment: InappMessageRenderEnvironment
    ) -> CGFloat {
        guard width > 0, maxHeight > 0 else { return 1 }

        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: maxHeight))
        let container = InappMessageContainerView(content: content, environment: environment)
        hostView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: hostView.topAnchor),
            container.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            container.widthAnchor.constraint(equalToConstant: width),
            container.heightAnchor.constraint(lessThanOrEqualToConstant: maxHeight)
        ])

        hostView.setNeedsLayout()
        hostView.layoutIfNeeded()

        let fittingSize = container.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        return min(pixelAlignedHeight(fittingSize.height), maxHeight)
    }

    private static func pixelAlignedHeight(_ height: CGFloat) -> CGFloat {
        let scale = max(UIScreen.main.scale, 1)
        return max(1, ceil(height * scale) / scale)
    }
}

struct InappMessageResolvedPresentationLayout {
    let width: CGFloat
    let height: CGFloat

    static func resolve(
        content: InappMessagePreparedContent,
        bounds: CGRect,
        safeAreaFrame: CGRect,
        environment: InappMessageRenderEnvironment
    ) -> InappMessageResolvedPresentationLayout {
        let spec = content.spec

        guard spec.frame.position != .fullscreen else {
            return InappMessageResolvedPresentationLayout(width: max(bounds.width, 1), height: max(bounds.height, 1))
        }

        let safeWidth = max(safeAreaFrame.width, 1)
        let safeHeight = max(safeAreaFrame.height, 1)
        let widthPercent = CGFloat(spec.frame.widthPercent / 100)
        let heightPercent = CGFloat(spec.frame.heightPercent / 100)

        let width: CGFloat
        let contentMaxHeight: CGFloat

        switch spec.frame.position {
        case .bottom:
            width = max(min(safeWidth * widthPercent, safeWidth), 1)
            contentMaxHeight = max(safeHeight * 0.92, 1)
        case .center:
            let availableWidth = max(safeWidth - 48, 1)
            width = max(min(safeWidth * widthPercent, 520, availableWidth), 1)
            contentMaxHeight = max(safeHeight * 0.9, 1)
        case .fullscreen:
            width = max(bounds.width, 1)
            contentMaxHeight = max(bounds.height, 1)
        }

        let maxHeight = contentMaxHeight
        let height: CGFloat
        if spec.frame.fitContentHeight {
            let fittingHeight = InappMessageContainerMeasurer.fittingHeight(
                for: content,
                width: width,
                maxHeight: contentMaxHeight,
                environment: environment
            )
            height = min(fittingHeight, maxHeight)
        } else {
            height = min(max(safeHeight * heightPercent, 1), maxHeight)
        }

        return InappMessageResolvedPresentationLayout(width: width, height: height)
    }
}
