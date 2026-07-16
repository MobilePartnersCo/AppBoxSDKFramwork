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
        AppBoxHealthRepository.shared.fetchStepsForPeriod(
            startDate: startDate,
            numberOfDays: numberOfDays
        ) { values, success in
            if success {
                completion(values, nil)
            } else {
                completion(
                    nil,
                    NSError(
                        domain: "kr.co.mobpa.appbox.health",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKit authorization or step query failed"]
                    )
                )
            }
        }
    }
}
