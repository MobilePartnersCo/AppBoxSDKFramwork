import CoreGraphics
import Foundation

/// 워터마크에 표시할 문구.
///
/// 과거에는 3개 문구 중 하나를 무작위로 골랐다. 무작위는 노출 결과가 실행마다 달라져
/// 재현이 어렵고, 어떤 문구는 사용자에게 한 번도 보이지 않을 수 있다.
/// marquee가 전체 문자열을 순환시키므로 3개를 하나로 이어 붙여 모두 노출되게 한다.
enum AppBoxWatermarkTextProvider {
    /// 문구 사이 구분자. 공백 6칸 + 가운뎃점 + 공백 6칸.
    /// Android와 동일한 값을 써야 두 플랫폼의 체감 간격이 같다.
    static let separator = "      ·      "

    static let messages = [
        "Powered by Appbox",
        "Appbox 플랜을 업그레이드하면 워터마크가 제거됩니다.",
        "이 앱은 Appbox로 제작되었습니다."
    ]

    static var text: String {
        messages.joined(separator: separator)
    }
}

/// 워터마크 탭 시 열 AppBox 프론트 URL.
///
/// 환경 판정은 별도 플래그를 새로 만들지 않고 워터마크 상태 조회에 이미 쓰는
/// `apiDomain`에서 끌어낸다. 판정 근거를 한 곳으로 모아 두 값이 어긋날 여지를 없앤다.
enum AppBoxWatermarkFrontURLResolver {
    static let productionURLString = "https://www.appboxapp.com"
    static let developmentURLString = "https://wwwdev.appboxapp.com"

    /// `apidev.appboxapp.com` 처럼 개발 API 도메인이면 개발 프론트로 판정한다.
    static func isDevelopment(apiDomain: String) -> Bool {
        apiDomain.lowercased().contains("apidev.")
    }

    static func frontURLString(apiDomain: String) -> String {
        isDevelopment(apiDomain: apiDomain) ? developmentURLString : productionURLString
    }

    static func frontURL(apiDomain: String) -> URL? {
        URL(string: frontURLString(apiDomain: apiDomain))
    }
}

/// 외곽선 두께 계산.
///
/// `NSAttributedString.Key.strokeWidth`는 폰트 크기 대비 **백분율**이고, 음수를 주어야
/// 외곽선과 채움을 한 번에 그린다(양수는 채움이 사라진다). 한 겹으로 끝나므로
/// 외곽선 레이어와 채움 레이어가 따로 움직여 어긋나는 문제가 생기지 않는다.
///
/// 음수 `strokeWidth`는 CoreGraphics `.fillStroke`이고, 이는 **fill을 그린 뒤 stroke를 그린다**.
/// stroke가 채움 위에 얹히므로 안쪽 절반이 덮이지 않고 **전체 폭이 그대로 보인다**.
///
/// Android의 2층 방식은 stroke를 먼저 그리고 흰색 fill로 덮어 바깥 절반만 남으므로
/// 폭을 2배로 지정해야 하지만, 여기서는 전제가 반대다.
/// 이 차이를 계산으로만 주장하지 않도록 `AppBoxWatermarkStrokeRenderingTests`가
/// 실제 렌더링 픽셀을 계측해 전제를 고정한다.
enum AppBoxWatermarkStrokePolicy {
    /// 화면에서 눈에 보여야 하는 검은 외곽선 띠의 두께(물리 픽셀).
    ///
    /// stroke는 글리프 윤곽선을 중심으로 그려지므로 이 값의 절반이 바깥,
    /// 절반이 안쪽(흰색 채움을 잠식)에 놓인다. 값을 키우면 흰 글자가 얇아 보인다.
    static let targetVisiblePixels: CGFloat = 1

    /// 가시 두께를 물리 픽셀 기준으로 맞추기 위한 전체 stroke 폭(포인트).
    ///
    /// `.fillStroke`에서는 가시 두께가 곧 전체 stroke 폭이므로 2배를 곱하지 않는다.
    static func totalStrokeWidthInPoints(displayScale: CGFloat) -> CGFloat {
        let scale = displayScale > 0 ? displayScale : 1
        return targetVisiblePixels / scale
    }

    /// `NSAttributedString.Key.strokeWidth`에 넣을 값. 음수여야 채움이 함께 그려진다.
    static func strokeWidthAttribute(fontSize: CGFloat, displayScale: CGFloat) -> CGFloat {
        guard fontSize > 0 else { return 0 }
        return -(totalStrokeWidthInPoints(displayScale: displayScale) / fontSize * 100)
    }
}

/// marquee의 거리·시간 계산.
///
/// 두 벌의 텍스트를 `텍스트폭 + 간격` 만큼 벌려 놓고 컨테이너를 그만큼 왼쪽으로 옮기면,
/// 한 주기가 끝나는 순간의 화면이 시작 순간과 동일해 이음매가 보이지 않는다.
/// 그래서 시작·반복 지연을 0으로 두어도 멈칫하는 구간이 생기지 않는다.
enum AppBoxWatermarkMarqueeGeometry {
    /// 흐르는 속도(초당 포인트). Android 기본값과 맞춘 값이다.
    static let pointsPerSecond: CGFloat = 30

    /// 텍스트 꼬리와 다음 머리 사이의 빈 구간. Android 기본값인 컨테이너 폭의 1/3.
    static func gap(containerWidth: CGFloat) -> CGFloat {
        max(0, containerWidth / 3)
    }

    /// 한 주기 이동 거리. 이 값이 곧 두 번째 텍스트의 시작 x이기도 하다.
    static func travelDistance(textWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        textWidth + gap(containerWidth: containerWidth)
    }

    /// 텍스트가 컨테이너를 넘지 않으면 흐를 이유가 없다.
    static func shouldAnimate(textWidth: CGFloat, containerWidth: CGFloat) -> Bool {
        containerWidth > 0 && textWidth > containerWidth
    }

    static func duration(travelDistance: CGFloat) -> CFTimeInterval {
        guard travelDistance > 0, pointsPerSecond > 0 else { return 0 }
        return CFTimeInterval(travelDistance / pointsPerSecond)
    }
}

/// 워터마크 스트립의 배치 상수.
enum AppBoxWatermarkLayout {
    /// 시스템 글자 크기 배율을 따르지 않는 고정 크기. 제품 공통 사양이다.
    static let fontSize: CGFloat = 13
    /// 스트립 상하 여백.
    static let verticalPadding: CGFloat = 4
}
