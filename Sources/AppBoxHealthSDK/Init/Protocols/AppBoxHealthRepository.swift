//
//  File.swift
//  
//
//  Created by mobilePartners on 2/11/25.
//

import Foundation
import HealthKit

/// 걸음수 조회 실패를 담는 `NSError`의 domain.
///
/// `AppBoxSDK` facade가 같은 문자열로 자기 오류를 판별한다. **한쪽만 바꾸면 오류 종류가
/// `unknown`으로 접힌다.**
let AppBoxHealthErrorDomain = "kr.co.mobpa.appbox.health"

/// 걸음수 조회 실패 원인. `rawValue`는 `AppBoxSDK`의 `AppBoxHealthErrorCode`와 같은 값을 쓴다.
///
/// `AppBoxHealthSDK`는 `AppBoxSDK`를 import하지 않으므로(의존 방향이 반대) 그 enum을 직접 참조할 수 없다.
/// 그래서 같은 정수를 `NSError.code`에 실어 보내고, facade가 명시적 switch로 되돌린다.
/// **양쪽 값을 함께 바꾸지 않으면 오류 종류가 조용히 어긋난다.**
enum AppBoxHealthStepFailure: Int {
    /// 권한 거부·미결정·제한을 하나로 병합한 값.
    case permissionDenied = 3
    /// 기기가 HealthKit을 지원하지 않음.
    case notSupported = 5
    /// 모든 날짜의 쿼리가 실패함.
    case serviceUnavailable = 6
    case unknown = 7
}

class AppBoxHealthRepository: NSObject, AppBoxHealthProtocol {
    static let shared = AppBoxHealthRepository()
    let healthStore = HKHealthStore()

    /// 병렬 쿼리 결과를 모으는 전용 직렬 큐.
    ///
    /// `HKSampleQuery` 콜백은 HealthKit이 정한 백그라운드 큐에서 온다. 이 큐를 거치지 않고
    /// 수집 배열을 건드리면 data race다.
    private let collectQueue = DispatchQueue(label: "kr.co.mobpa.appbox.health.collect")

    /// 한 번에 띄우는 하루치 쿼리 수.
    ///
    /// HealthKit이 권장 동시 쿼리 수를 공개하지 않고 시뮬레이터에는 걸음 데이터가 없어
    /// 측정할 수 없다. **근거 없는 임의값이다.** 목적은 최적 성능이 아니라, 넓은 날짜 범위에서
    /// 수천 개 쿼리가 한꺼번에 뜨는 것을 막는 데 있다.
    ///
    /// 이 값 이하의 범위(일주일 조회 등)는 한 배치로 끝나 이전과 동일하게 동작한다.
    /// 넓은 범위는 배치가 순차로 돌아 느려지는 대신 동시 부하가 상한을 넘지 않는다.
    ///
    /// 테스트가 이 값을 직접 참조하므로 `private`이 아니다.
    static let queryBatchSize = 8

    /// 배치 크기만큼 잘라 나눈다.
    ///
    /// `size`가 0 이하면 나누지 않고 전체를 한 배치로 본다(호출자 실수로 조회가 멈추지 않게).
    ///
    /// 실제 동시 실행 수는 관측할 수 없어 이 분할 로직만 순수 함수로 떼어 검증한다.
    /// 그래서 `private`이 아니다.
    static func batched<T>(_ items: [T], size: Int) -> [[T]] {
        guard !items.isEmpty else { return [] }
        guard size > 0 else { return [items] }

        return stride(from: 0, to: items.count, by: size).map { start in
            Array(items[start..<min(start + size, items.count)])
        }
    }

    /// 걸음수 날짜 문자열 전용 포매터.
    ///
    /// `locale`을 고정하지 않으면 기기의 기본 캘린더가 그대로 반영된다. 태국 기기에서는
    /// 불교력이 적용돼 `"2569-05-01"`처럼 연도가 543 더해진 값이 나가는 것이 실측 확인됐다.
    /// `en_US_POSIX`는 사용자 설정과 무관하게 그레고리력을 강제한다.
    ///
    /// `timeZone`은 **Asia/Seoul로 고정**한다. AppBox는 한국 전용 서비스이고, Android도
    /// 날짜 키를 KST로 만든다. 고정하지 않으면 기기 타임존이 그대로 반영돼 해외에 있는
    /// 같은 사용자가 Android와 다른 날짜를 받는다.
    ///
    /// 조회 범위(`HKSampleQuery`의 predicate)는 기기 로컬 존으로 해석된다. 국내에서는 두 기준이
    /// 같아 무해하고, Android도 같은 구조다. 해외 대응을 하게 되면 범위와 키를 모두 KST로
    /// 통일해야 하며 그때는 양 플랫폼이 함께 바꾼다.
    ///
    /// 테스트가 이 포매터를 직접 검증하므로 `private`이 아니다.
    static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func requestAuthorization(readType: Set<HKObjectType>, completion: @escaping (Bool, (any Error)?) -> Void) {
        requestAuthorization(readType: readType, writeType: [], completion: completion)
    }
    
    private func requestAuthorization(readType: Set<HKObjectType>, writeType: Set<HKSampleType>, completion: @escaping (Bool, (any Error)?) -> Void) {
        
        guard HKHealthStore.isHealthDataAvailable() else {
            debugLog("HealthKit not used")
            completion(false, NSError(domain: "com.apple.HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "헬스데이터를 가져올 수 없습니다."]))
            return
        }
        
        
        healthStore.requestAuthorization(toShare: writeType, read: readType) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    private func getQuantityType(healthType: HealthType) -> HKObjectType? {
        if healthType == .step {
            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                return nil
            }
            
            return type
        }
        
        return nil
    }
    
    /// 하루치 걸음수를 조회한다. 쿼리가 실패하면 `nil`을 넘긴다.
    ///
    /// 실패를 `0.0`이 아니라 `nil`로 구분하는 이유는 "걸음이 0인 날"과 "조회에 실패한 날"이
    /// 서로 다른 결과여야 하기 때문이다. 전자는 결과에서 빠지고, 후자는 실패 집계에 들어간다.
    ///
    /// **completion은 어떤 경로로도 정확히 한 번, main에서 비동기로 호출된다.**
    /// 호출자가 `DispatchGroup`의 enter/leave를 짝지으므로 한 번이라도 빠지면 notify가
    /// 영원히 오지 않는다.
    private func fetchStep(time: Date, completion: @escaping (Double?) -> Void) {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            debugLog("Step Count Type is unavailable")
            // 호출자는 이미 getQuantityType으로 같은 타입을 확인했으므로 여기는 실질적으로
            // 도달하지 않는다. 그래도 completion 없이 반환하면 조회 전체가 멈추므로 알린다.
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let now = time
        let startOfDay = Calendar.current.startOfDay(for: now)
        let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let endOfDay = Calendar.current.date(byAdding: .second, value: -1, to: nextDayStart)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: stepCountType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, results, error in
            guard error == nil else {
                debugLog("Error fetching steps: \(error!.localizedDescription)")
                // 이 콜백은 HealthKit이 정한 백그라운드 큐에서 온다. 성공 경로와 같은 큐로
                // 넘겨야 호출자의 수집 로직이 한 곳에서만 실행된다.
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let totalSteps = results?
                    .compactMap { $0 as? HKQuantitySample }
                    .filter { !$0.sourceRevision.source.name.contains("Watch") }
                    .reduce(0) { $0 + $1.quantity.doubleValue(for: HKUnit.count()) } ?? 0

            DispatchQueue.main.async {
                completion(totalSteps)
            }
        }

        healthStore.execute(query)
    }

    /// 배치를 순서대로 실행한다. 한 배치가 모두 끝나야 다음 배치를 띄운다.
    ///
    /// 하루치 쿼리를 전부 한꺼번에 `execute`하면 넓은 날짜 범위에서 수천 개가 동시에 뜬다.
    /// 배치 사이에 경계를 둬서 동시 실행 수를 `queryBatchSize` 이하로 묶는다.
    ///
    /// `onResult`는 `collectQueue`에서, `completion`은 main에서 호출된다.
    /// 재귀 호출은 `group.notify` 콜백 안에서 일어나므로 스택이 쌓이지 않는다.
    private func fetchSteps(
        batches: [[(index: Int, date: Date)]],
        onResult: @escaping (Int, Double?) -> Void,
        completion: @escaping () -> Void
    ) {
        guard let batch = batches.first else {
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        let rest = Array(batches.dropFirst())
        let group = DispatchGroup()

        for day in batch {
            group.enter()
            fetchStep(time: day.date) { steps in
                self.collectQueue.async {
                    onResult(day.index, steps)
                    group.leave()
                }
            }
        }

        // 모든 `group.leave()`가 collectQueue 안에서 호출되므로, notify 시점에는
        // 이 배치의 수집이 끝났고 그 결과가 보인다.
        group.notify(queue: .main) {
            self.fetchSteps(batches: rest, onResult: onResult, completion: completion)
        }
    }

    /// 실패 원인을 구분해 돌려주는 걸음수 조회.
    ///
    /// 배포된 `fetchStepsForPeriod(startDate:numberOfDays:completion:)`은 성공 여부를 `Bool`
    /// 하나로만 표현해 `permissionDenied` / `notSupported` / `serviceUnavailable`을 구분할 수 없다.
    /// facade가 오류 종류를 그대로 전달해야 하므로 원인을 유지하는 경로를 따로 둔다.
    ///
    /// 결과는 **날짜 오름차순**이며, 걸음 기록이 없는 날은 항목을 만들지 않는다(0으로 채우지 않는다).
    func fetchStepsDetailed(
        startDate: Date,
        numberOfDays: Int,
        completion: @escaping ([[String: Any]]?, AppBoxHealthStepFailure?) -> Void
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            debugLog("HealthKit is not available on this device")
            completion(nil, .notSupported)
            return
        }

        guard let stepsType = getQuantityType(healthType: .step) else {
            completion(nil, .unknown)
            return
        }

        // numberOfDays가 0 이하여도 권한 요청은 그대로 거친다. 배포된
        // fetchStepsForPeriod(startDate:numberOfDays:)가 이 경우에도 권한 시트를 띄웠고,
        // 그 부수효과를 없애면 시그니처를 유지해도 동작이 달라진다.
        requestAuthorization(readType: [stepsType]) { success, error in
            guard success, error == nil else {
                // HealthKit은 읽기 권한의 거부·미결정·제한을 호출자에게 구분해 알려주지 않는다.
                // Android와 합의한 계약도 이 셋을 permissionDenied 하나로 병합한다.
                debugLog("permission denied or authorization failed")
                completion(nil, .permissionDenied)
                return
            }

            debugLog("permission granted")

            let formatter = Self.dayFormatter()
            // 음수가 들어와도 배열 생성과 Range에서 죽지 않게 정규화한다.
            let dayCount = max(0, numberOfDays)
            // 완료 순서가 아니라 인덱스 위치에 담는다. 하루치 쿼리가 병렬로 끝나므로
            // append로는 날짜 순서를 보장할 수 없다.
            var collected = [Double?](repeating: nil, count: dayCount)
            var failureCount = 0

            let days: [(index: Int, date: Date)] = (0..<dayCount).compactMap { index in
                guard let date = Calendar.current.date(byAdding: .day, value: index, to: startDate) else {
                    return nil
                }
                return (index, date)
            }
            // 실제로 쿼리를 띄운 날의 수. dayCount와 다를 수 있어 따로 센다.
            // 이 값으로 비교하지 않으면 전부 실패해도 failureCount가 dayCount에 못 미쳐
            // serviceUnavailable이 나오지 않는다.
            let expectedCount = days.count

            self.fetchSteps(
                batches: Self.batched(days, size: Self.queryBatchSize),
                onResult: { index, steps in
                    // collectQueue에서 호출된다.
                    if let steps {
                        collected[index] = steps
                    } else {
                        failureCount += 1
                    }
                }
            ) {
                // 띄운 쿼리가 전부 실패했으면 조회 자체가 안 된 것으로 본다.
                // 일부만 실패한 경우는 나머지 날짜를 그대로 돌려준다.
                // 애초에 조회할 날이 없었다면(dayCount == 0) 실패가 아니라 빈 결과다.
                guard expectedCount == 0 || failureCount < expectedCount else {
                    completion(nil, .serviceUnavailable)
                    return
                }

                // days는 인덱스 오름차순이므로 그대로 순회하면 날짜 오름차순이 된다.
                var stepsData: [[String: Any]] = []
                for day in days {
                    guard let steps = collected[day.index], steps > 0 else { continue }

                    stepsData.append([
                        "date": formatter.string(from: day.date),
                        "step": steps,
                    ])
                }

                completion(stepsData, nil)
            }
        }
    }

    @objc(fetchStepsForPeriodWithStartDate:numberOfDays:completion:)
    func fetchStepsForPeriod(startDate: Date, numberOfDays: Int, completion: @escaping ([[String : Any]], Bool) -> Void) {
        // 배포된 시그니처를 유지하기 위해 실패 원인을 Bool로 접는다.
        // 정렬·동기화·locale 수정은 fetchStepsDetailed에 모여 있어 두 경로가 같은 동작을 공유한다.
        fetchStepsDetailed(startDate: startDate, numberOfDays: numberOfDays) { values, failure in
            // serviceUnavailable은 성공으로 접는다. 이전 구현은 쿼리 에러를 0걸음으로 삼켜
            // 빈 배열과 true를 돌려줬다. 이 경로는 배포돼 있으므로 그 관측 동작을 유지한다.
            if case .serviceUnavailable = failure {
                completion([], true)
                return
            }

            guard failure == nil, let values else {
                completion([], false)
                return
            }

            completion(values, true)
        }
    }
}
