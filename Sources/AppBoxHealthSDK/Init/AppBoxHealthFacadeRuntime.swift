import Foundation
import AppBoxCoreSDK

extension AppBoxHealth: AppBoxHealthFacadeRuntimeProviding {
    public static var appBoxHealthFacadeRuntime: AppBoxHealthFacadeRuntime {
        AppBoxHealthFacadeRuntimeAdapter.shared
    }
}

private final class AppBoxHealthFacadeRuntimeAdapter: AppBoxHealthFacadeRuntime {
    static let shared = AppBoxHealthFacadeRuntimeAdapter()

    private init() {}

    func fetchSteps(
        startDate: Date,
        numberOfDays: Int,
        completion: @escaping ([[String: Any]]?, NSError?) -> Void
    ) {
        AppBoxHealthRepository.shared.fetchStepsDetailed(
            startDate: startDate,
            numberOfDays: numberOfDays
        ) { values, failure in
            guard let failure else {
                completion(values, nil)
                return
            }

            completion(nil, Self.error(for: failure))
        }
    }

    /// 실패 원인을 facade가 되돌릴 수 있는 `NSError`로 만든다.
    ///
    /// `code`는 `AppBoxSDK`의 `AppBoxHealthErrorCode`와 같은 정수다. `AppBoxHealthSDK`는
    /// `AppBoxSDK`를 import할 수 없어(의존 방향이 반대) 타입 대신 정수로 계약을 맞춘다.
    /// 구버전 `AppBoxHealthSDK`가 링크되면 이 세분 code가 오지 않고 facade가 `unknown`으로 접는다.
    private static func error(for failure: AppBoxHealthStepFailure) -> NSError {
        let message: String
        switch failure {
        case .permissionDenied:
            message = "HealthKit read authorization was not granted"
        case .notSupported:
            message = "HealthKit is not available on this device"
        case .serviceUnavailable:
            message = "HealthKit step query failed"
        case .unknown:
            message = "HealthKit step query failed for an unknown reason"
        }

        return NSError(
            domain: AppBoxHealthErrorDomain,
            code: failure.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
